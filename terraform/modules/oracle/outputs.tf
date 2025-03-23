output "nodes_public_ips" {
  value = {
    for name,node in oci_core_instance.nodes:
        name => node.public_ip
    }
}