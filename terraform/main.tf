locals {
  controlplane_node_address = module.oracle.nodes[var.controlplane_node]
  cluster_url = coalesce(var.cluster_url,local.controlplane_node_address)
  cluster_endpoint = "https://${local.cluster_url}:6443"
  wg_cluster_endpoint = "https://${var.wg_controlplane_adderess}:6443"
  roles = {
    "controlplane" = local.cluster_endpoint
    "worker" = var.site != null ? local.wg_cluster_endpoint : local.cluster_endpoint
  }
  control_plane_scheduling = yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    })
}
module "images" {
  source = "./modules/image"
  talos_version = var.talos_version
}
module "wg_site" {
  source = "./modules/wireguard_site"
  site = var.site
  wg_kubelet_subnet = var.wg_kubelet_subnet
}
module "oracle" {
  source = "./modules/oracle"
  compartment_ocid = var.compartment_ocid
  availability_domain                 = 1
  talos_version = var.talos_version
  images = module.images.images
  nodes = var.cloud_nodes
}
## Main talos secret
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}
## Configuration Files
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [var.cluster_url]
  nodes                = [
    for name,address in module.oracle.nodes :  address
  ]
}
data "talos_machine_configuration" "role" {
  for_each = local.roles
  cluster_name     = var.cluster_name
  machine_type     = each.key
  cluster_endpoint = each.value
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}
resource"local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint                 = var.cluster_url
  node = local.controlplane_node_address
}
resource"local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
resource "talos_machine_bootstrap" "this" {
  depends_on = [ talos_machine_configuration_apply.cloud_nodes ]
  count         = var.bootstrap_nodes ? 1 : 0
  node                 = local.controlplane_node_address
  client_configuration = talos_machine_secrets.this.client_configuration
}
resource "talos_machine_configuration_apply" "cloud_nodes" {
  for_each = var.cloud_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.role[each.value.role].machine_configuration
  endpoint                        = module.oracle.nodes[each.key]
  node                            = each.key
  config_patches = concat(
    [ # node specific patches
      for template,paramater in each.value.config_patches :
        templatefile(template,paramater)
    ],
    [ # cloud specific patches
      local.control_plane_scheduling,
      yamlencode({
          machine = {
            certSANs = [
              var.cluster_url,
              module.oracle.nodes[each.key]
            ]
          }
      }),
      yamlencode(
        coalesce(module.wg_site.wg_interfaces[each.key])
      )
    ]
  )
}
resource "talos_machine_configuration_apply" "local_nodes" {
  for_each = var.onprem_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.role[each.value.role].machine_configuration
  endpoint                        = each.value.public_ip
  node                            = each.value.public_ip
  config_patches = concat(
    [ for template,paramater in each.value.config_patches :
      templatefile(template,paramater)
    ],
    [
      yamlencode(
      {
        machine = {
          network = {
            hostname = each.key
          }
        }
      }),
      yamlencode({
          machine = {
            certSANs = [
              var.cluster_url,
              each.value.public_ip
            ]
          }
      }),
      yamlencode(
        coalesce(module.wg_site.wg_interfaces[each.key])
      )
    ]
  )
}

#     templatefile("templates/piraeus.yaml",{}),