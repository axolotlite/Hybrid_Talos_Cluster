output "nodes_public_ips" {
  value = {
    for name,node in oci_core_instance.nodes:
        name => {
          public_ip = node.public_ip
        }
    }
}
output "nodes" {
  value = {
    for name,node in local.cloud_nodes: 
      name => merge(node,{
        public_ip = oci_core_instance.nodes[name].public_ip
      })
  }
}