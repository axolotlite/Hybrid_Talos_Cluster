#key creation, one for each
resource "wireguard_asymmetric_key" "nodes" {
  for_each = var.nodes
}

locals {
  cluster_endpoint = "https://${var.cluster_url}:6443"
  cluster_endpoint_wg = "https://${var.controlplane_ip}:6443"
  control_planes = [
    for name,node in var.nodes : node.public_ip
    if node.role == "controlplane"
  ]
  # cert_sans_config = 
  default_controlplane_node_name = local.control_planes[0]
  ## wireguard
  peers = [
        for name, node in var.nodes : {
            publicKey = wireguard_asymmetric_key.nodes[name].public_key
            endpoint = node.wg.endpoint
            persistentKeepaliveInterval = "5s"
            allowedIPs = node.wg.allowedIPs
        
        }
    ]
    wg_interface = {
        for name, node in var.nodes: name => {
        machine = {
            kubelet = {
                nodeIP = {
                    validSubnets = [var.wg_cidr]
                }
            }
            network = {
                interfaces = [
                    {
                        interface = var.wg_iface
                        addresses = node.wg.addresses
                        mtu = var.mtu
                        wireguard = {
                            listenPort = node.wg.listen_port
                            privateKey = wireguard_asymmetric_key.nodes[name].private_key
                            peers = local.peers
                        }
                    }
                ]
            }
        }
        cluster = {
            controlPlane = {
                endpoint = node.role == "controlplane" ? local.cluster_endpoint : local.cluster_endpoint_wg
            }
        }
    }
    }
}
## Main talos secret
resource "talos_machine_secrets" "this" {}

## Configuration Files
resource"local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint                 = var.cluster_url
  node = local.default_controlplane_node_name
}
resource"local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}
## Node Configuration
resource "talos_machine_configuration_apply" "nodes" {
    for_each = var.nodes
    client_configuration        = talos_machine_secrets.this.client_configuration
    machine_configuration_input = data.talos_machine_configuration.role[each.value.role].machine_configuration
    node                        = each.value.public_ip
    endpoint = local.default_controlplane_node_name
    config_patches = [
      yamlencode(local.wg_interface[each.key]),
      yamlencode({
        machine = {
          certSANs = [
            var.cluster_url,
            each.value.public_ip
          ]
        }
        cluster = {
          allowSchedulingOnControlPlanes = true
          apiServer = {
            certSANs = [
              var.cluster_url,
              each.value.public_ip
            ]
          }
        }
      })
    ]
}
resource "talos_machine_bootstrap" "this" {
  depends_on = [ talos_machine_configuration_apply.nodes ]
  count         = var.bootstrap_nodes ? 1 : 0
  node                 = local.default_controlplane_node_name
  client_configuration = talos_machine_secrets.this.client_configuration
}