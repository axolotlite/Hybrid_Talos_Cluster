#key creation, one for each
resource "wireguard_asymmetric_key" "nodes" {
  for_each = var.site
}

locals {
  wg_interfaces = {
    for name, node in var.site: name => {
      machine = {
          kubelet = {
              nodeIP = {
                  validSubnets = [var.wg_kubelet_subnet]
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
                          privateKey = coalesce(node.private_key,wireguard_asymmetric_key.nodes[name].private_key)
                          peers = [
                            for peer in node.peers : {
                              publicKey = coalesce(var.site[peer].public_key,wireguard_asymmetric_key.nodes[peer].public_key)
                              endpoint = node.ingress_tunnel == true && var.site[peer].egress_endpoint != null ? var.site[peer].egress_endpoint : var.site[peer].endpoint
                              persistentKeepaliveInterval = "5s"
                              allowedIPs = var.site[peer].allowedIPs
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