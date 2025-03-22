#key creation, one for each
resource "wireguard_asymmetric_key" "nodes" {
  for_each = var.nodes
}

locals {
    peers = [
        for name, node in var.nodes : {
            publicKey = wireguard_asymmetric_key.nodes[name].public_key
            endpoint = node.endpoint
            persistentKeepaliveInterval = "5s"
            allowedIPs = node.addresses
        
        }
    ]
    wg_interface = {
        for name, node in var.nodes: name =>{
            inteface = var.wg_iface
            addresses = node.addresses
            mtu = var.mtu
            wireguard = {
                listenPort = node.listen_port
                private_key = wireguard_asymmetric_key.nodes[name].private_key
                peers = local.peers
            }
        }
    }
}
