#key creation, one for each
resource "wireguard_asymmetric_key" "nodes" {
  for_each = var.nodes
}

locals {
  cluster_endpoint = "https://${var.cluster_url}:6443"
  cluster_endpoint_wg = "https://${var.wg_controlplane_ip}:6443"
  control_planes = [
    for name,node in var.nodes : node.public_ip
      if node.role == "controlplane"
  ]
  # cert_sans_config = 
  default_controlplane_public_ip = local.control_planes[0]
  ## wireguard
  wg_interfaces = {
    for name, node in var.wg: name => {
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
                      addresses = node.addresses
                      mtu = var.mtu
                      wireguard = {
                          listenPort = node.listen_port
                          privateKey = wireguard_asymmetric_key.nodes[name].private_key
                          # peers = local.peers
                          peers = [
                            for peer in node.peers : {
                              publicKey = wireguard_asymmetric_key.nodes[peer].public_key
                              endpoint = node.ingress_tunnel == true && var.wg[peer].egress_endpoint != null ? var.wg[peer].egress_endpoint : var.wg[peer].endpoint
                              persistentKeepaliveInterval = "5s"
                              allowedIPs = var.wg[peer].allowedIPs
                            }
                          ]
                      }
                  }
              ]
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
  node = local.default_controlplane_public_ip
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
    node                        = each.key
    endpoint = each.value.public_ip
    config_patches = concat(
      [for name,parameters in each.value.config_patches :
        templatefile(name,parameters)
      ],
      [
        yamlencode({machine = {
          network = {
              hostname = each.key
            }
          }
        }),
        yamlencode(local.wg_interfaces[each.key]),
        yamlencode({
          machine = {
            certSANs = [
              var.cluster_url,
              each.value.public_ip,
              local.default_controlplane_public_ip
            ]
          }
          cluster = {
            allowSchedulingOnControlPlanes = true
            apiServer = {
              certSANs = [
                var.cluster_url,
                each.value.public_ip,
                local.default_controlplane_public_ip
              ]
            }
          }
        })
      ]
    )
}
resource "talos_machine_bootstrap" "this" {
  depends_on = [ talos_machine_configuration_apply.nodes ]
  count         = var.bootstrap_nodes ? 1 : 0
  node                 = local.default_controlplane_public_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}