locals {
  cluster_endpoint = "https://${var.cluster_url}:6443"
  controlplane_node_name = [
    for name,node in var.nodes : name
    if node.role == "controlplane"
  ][0]
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
  node = var.nodes[local.controlplane_node_name].public_ip
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
    config_patches = each.value.config_patches
}
resource "talos_machine_bootstrap" "this" {
  count         = var.bootstrap_nodes ? 1 : 0
  node                 = var.nodes[local.controlplane_node_name].public_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}