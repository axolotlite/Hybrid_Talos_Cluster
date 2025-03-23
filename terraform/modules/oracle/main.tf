## Talos Image
resource "random_id" "bucket" {
  byte_length = 8
}

resource "oci_objectstorage_bucket" "this" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "talos-${random_id.bucket.hex}-bucket"
  access_type    = "NoPublicAccess"
  auto_tiering   = "Disabled"
  versioning     = "Disabled"
}

resource "oci_objectstorage_object" "this" {
  for_each = var.images

  bucket      = oci_objectstorage_bucket.this.name
  namespace   = data.oci_objectstorage_namespace.ns.namespace
  object      = "talos-${var.talos_version}-${lower(each.key)}.oci"
  source      = each.value
}

resource "oci_core_image" "this" {
  for_each       = var.images
  compartment_id = var.compartment_ocid
  display_name   = "Talos-${lower(each.key)}-${var.talos_version}"
  freeform_tags  = { "OS" : "Talos", "Arch" : lower(each.key), "Version": var.talos_version }
  launch_mode    = "PARAVIRTUALIZED"

  image_source_details {
    source_type    = "objectStorageTuple"
    namespace_name = oci_objectstorage_bucket.this.namespace
    bucket_name    = oci_objectstorage_bucket.this.name
    object_name    = oci_objectstorage_object.this[each.key].object

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
resource "oci_core_vcn" "this" {
  cidr_blocks     = var.vcn_cidr_blocks
  compartment_id = var.compartment_ocid
  display_name   = "vcn-${var.vcn_name}"
  dns_label      = "vcn${var.vcn_name}"
}

resource "oci_core_security_list" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_name}-permissive-sl"

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

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.vcn_name}-gw"
  vcn_id         = oci_core_vcn.this.id
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id
  display_name               = "${var.vcn_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_subnet" "this" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  cidr_block          = var.subnet
  display_name        = "vcn-${var.subnet_name}"
  dns_label           = "${var.subnet_name}sub"
  security_list_ids   = [oci_core_security_list.this.id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.this.id
  route_table_id      = oci_core_vcn.this.default_route_table_id
  dhcp_options_id     = oci_core_vcn.this.default_dhcp_options_id
}

## VM
resource "oci_core_instance" "nodes" {
  for_each = var.nodes
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = each.key
  shape               = each.value.shape.instance_shape

  shape_config {
    ocpus         = each.value.shape.ocpus
    memory_in_gbs = each.value.shape.memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.this.id
    display_name              = "vnic-${each.key}"
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = each.key
  }

  source_details {
    source_type = "image"
    source_id = oci_core_image.this[each.value.arch].id
    boot_volume_size_in_gbs = 50
  }
  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }
  launch_options {
    firmware                = "UEFI_64"
    boot_volume_type        = "PARAVIRTUALIZED"
    remote_data_volume_type = "PARAVIRTUALIZED"
    network_type            = "PARAVIRTUALIZED"
  }
  timeouts {
    create = "10m"
  }
}