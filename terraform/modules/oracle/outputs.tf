output "nodes" {
  value = {
    for name,node in oci_core_instance.nodes: 
      name => node.public_ip
  }
}