
# Talos Configs
resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = var.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = var.worker_ips
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint                 = var.cluster_url
  node = oci_core_instance.talos_controlplane.public_ip
}

resource"local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}
resource"local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}


resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = oci_core_instance.talos_controlplane.public_ip
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sda"
        }
      },
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),
    templatefile(
        "templates/certsans.yaml",
        {
            dns_name = var.cluster_url,
            node_ip = oci_core_instance.talos_controlplane.public_ip
        }
    ),
    templatefile(
        "templates/tunnel/egress.yaml",
        {
            ws_secret = var.ws_secret,
            listen_port = var.listen_port,
            ws_port = var.ws_port
        }
    ),
    templatefile(
        "templates/wireguard/server.yaml",
        {
            wg_cidr = var.wg_cidr,
            control_node_ip = var.control_node_ip,
            wg_subnet = var.wg_subnet,
            server_key = wireguard_asymmetric_key.server.private_key,
            server_pub = wireguard_asymmetric_key.server.public_key,
            listen_port = var.listen_port
        }
    ),
    templatefile(
        "templates/wireguard/peer.yaml",
        {
            pub_key = wireguard_asymmetric_key.peer1.public_key,
            node_ip = var.worker_node_ips[0]
        }
    ),
    templatefile(
        "templates/wireguard/peer.yaml",
        {
            pub_key = wireguard_asymmetric_key.peer2.public_key,
            node_ip = var.worker_node_ips[1]
        }
    ),
  ]
}
#need to merge both workers into one resource and use looping to create both
resource "talos_machine_configuration_apply" "worker_1" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[0]
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sdb"
        }
      }
    }),
    templatefile(
        "templates/tunnel/ingress.yaml",
        {
            egress_uri = var.cluster_url,
            ws_secret = var.ws_secret,
            listen_port = var.listen_port,
            ws_port = var.ws_port
        }
    ),
    templatefile(
        "templates/wireguard/client.yaml",
        {
            wg_cidr = var.wg_cidr,
            node_ip = var.worker_node_ips[0],
            wg_subnet = var.wg_subnet
            control_node_ip = var.control_node_ip,
            node_key = wireguard_asymmetric_key.peer1.private_key,
            controller_pub = wireguard_asymmetric_key.server.public_key,
            listen_port = var.listen_port
        }
    )
  ]
}
resource "talos_machine_configuration_apply" "worker_2" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ips[1]
  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/sdb"
        }
      }
    }),
    templatefile(
        "templates/tunnel/ingress.yaml",
        {
            egress_uri = var.cluster_url,
            ws_secret = var.ws_secret,
            listen_port = var.listen_port,
            ws_port = var.ws_port
        }
    ),
    templatefile(
        "templates/wireguard/client.yaml",
        {
            wg_cidr = var.wg_cidr,
            node_ip = var.worker_node_ips[1],
            wg_subnet = var.wg_subnet,
            control_node_ip = var.control_node_ip,
            node_key = wireguard_asymmetric_key.peer2.private_key,
            controller_pub = wireguard_asymmetric_key.server.public_key,
            listen_port = var.listen_port
        }
    )
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
  node                 = oci_core_instance.talos_controlplane.public_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

## wireguard keys
resource "wireguard_asymmetric_key" "server" {}
resource "wireguard_asymmetric_key" "peer1" {}
resource "wireguard_asymmetric_key" "peer2" {}

## image factory image
resource "talos_image_factory_schematic" "this" {
  # # leaving this here for when I need to install extensions
  # schematic = yamlencode(
  #   {
  #     customization = {}
  #   }
  # )
}
data "talos_image_factory_urls" "arch" {
  for_each = toset(var.arch)
  talos_version = "v1.9.4"
  schematic_id  = talos_image_factory_schematic.this.id
  architecture = each.value
  platform      = "oracle"
}
resource"local_file" "metadata" {
  for_each = toset(var.arch)
  content  = templatefile("images/image_metadata_${each.value}.json",{version = var.talos_version})
  filename = "images/${each.value}/image_metadata.json"
}
resource "null_resource" "create_ocis" {
  for_each = toset(var.arch)

  depends_on = [ local_file.metadata ]
  triggers = {
    on_version_change = "${data.talos_image_factory_urls.arch[each.key].urls.disk_image}"
  }
  provisioner local-exec { 
    interpreter = ["/bin/bash" ,"-c"]
    command = <<-EOT
      cd images/${each.key}
      curl -o oracle-${each.key}.raw.xz ${data.talos_image_factory_urls.arch[each.key].urls.disk_image}
      xz -fdk oracle-${each.key}.raw.xz
      qemu-img convert -f raw -O qcow2 oracle-${each.key}.raw oracle-${each.key}.qcow2
      tar zcf oracle-${each.key}.oci oracle-${each.key}.qcow2 image_metadata.json
    EOT
  }
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      rm -f images/${each.key}/*
      touch images/${each.key}/oracle-${each.key}.oci
    EOT
  }
}

##Oracle image creation
### create talos image
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = var.availability_domain
}

resource "random_id" "bucket" {
  byte_length = 8
}

resource "oci_objectstorage_bucket" "images" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "images-${random_id.bucket.hex}"
  access_type    = "NoPublicAccess"
  auto_tiering   = "Disabled"
  versioning     = "Disabled"
}

resource "oci_objectstorage_object" "talos" {
  depends_on = [ null_resource.create_ocis ]
  for_each = toset(var.arch)

  bucket      = oci_objectstorage_bucket.images.name
  namespace   = data.oci_objectstorage_namespace.ns.namespace
  object      = "talos-${lower(each.key)}.oci"
  source      = "images/${lower(each.key)}/oracle-${lower(each.key)}.oci"
  # content_md5 = filemd5("images/${lower(each.key)}/oracle-${lower(each.key)}.oci")
}

resource "oci_core_image" "talos" {
  for_each       = toset(var.arch)
  compartment_id = var.compartment_ocid
  display_name   = "Talos-${lower(each.key)}-${var.talos_version}"
  freeform_tags  = { "OS" : "Talos", "Arch" : lower(each.key) }
  launch_mode    = "PARAVIRTUALIZED"

  image_source_details {
    source_type    = "objectStorageTuple"
    namespace_name = oci_objectstorage_bucket.images.namespace
    bucket_name    = oci_objectstorage_bucket.images.name
    object_name    = oci_objectstorage_object.talos[each.key].object

    operating_system         = "Talos"
    operating_system_version = var.talos_version
    source_image_type        = "QCOW2"
  }

  lifecycle {
    ignore_changes = [
      defined_tags,
    ]
    # replace_triggered_by = [oci_objectstorage_object.talos[each.key].content_md5]
  }

  timeouts {
    create = "30m"
  }
}

## VM networking
resource "oci_core_vcn" "talos_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = format("%sVCN", replace(title(var.instance_name), "/\\s/", ""))
  dns_label      = format("%svcn", lower(replace(var.instance_name, "/\\s/", "")))
}

resource "oci_core_security_list" "talos_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.talos_vcn.id
  display_name   = format("%sSecurityList", replace(title(var.instance_name), "/\\s/", ""))

  # Allow outbound traffic on all ports for all protocols
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  # Allow inbound traffic on all ports for all protocols
  ingress_security_rules {
    protocol  = "all"
    source    = "0.0.0.0/0"
    stateless = false
  }

  # Allow inbound icmp traffic of a specific type
  ingress_security_rules {
    protocol  = 1
    source    = "0.0.0.0/0"
    stateless = false

    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_internet_gateway" "talos_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = format("%sIGW", replace(title(var.instance_name), "/\\s/", ""))
  vcn_id         = oci_core_vcn.talos_vcn.id
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.talos_vcn.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos_internet_gateway.id
  }
}

resource "oci_core_subnet" "talos_subnet" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  cidr_block          = "10.1.20.0/24"
  display_name        = format("%sSubnet", replace(title(var.instance_name), "/\\s/", ""))
  dns_label           = format("%ssub", lower(replace(var.instance_name, "/\\s/", "")))
  security_list_ids   = [oci_core_security_list.talos_security_list.id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.talos_vcn.id
  route_table_id      = oci_core_vcn.talos_vcn.default_route_table_id
  dhcp_options_id     = oci_core_vcn.talos_vcn.default_dhcp_options_id
}

## VM
resource "oci_core_instance" "talos_controlplane" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_name
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.talos_subnet.id
    display_name              = format("%sVNIC", replace(title(var.instance_name), "/\\s/", ""))
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = format("%s", lower(replace(var.instance_name, "/\\s/", "")))
  }

  source_details {
    source_type = var.instance_source_type
    source_id = oci_core_image.talos["arm64"].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }
  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }

  timeouts {
    create = "10m"
  }
}