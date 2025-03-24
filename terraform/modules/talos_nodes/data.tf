data "talos_machine_configuration" "role" {
    for_each = toset([ "controlplane", "worker" ])
  cluster_name     = var.cluster_name
  machine_type     = each.key
  cluster_endpoint = each.key == "controlplane" ? local.cluster_endpoint : local.cluster_endpoint_wg
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [var.cluster_url]
  nodes                = [for node in var.nodes : node.public_ip ]
}