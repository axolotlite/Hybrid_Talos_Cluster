# # output "images" {
# #   value = module.images.images
# # }
# output "hetzner_ip_addresses" {
#   value = module.hetzner_vm.ipv4_address
# }

output "node_controlplane_installer_urls" {
  value = module.hetzner_controlplane.urls.installer
}
output "node_a_installer_urls" {
  value = module.home_worker_a.urls.installer
}
output "node_b_installer_urls" {
  value = module.home_worker_b.urls.installer
}
output "node_c_installer_urls" {
  value = module.home_worker_c.urls.installer
}
output "node_gpu_installer_urls" {
  value = module.home_worker_gpu.urls.installer
}
