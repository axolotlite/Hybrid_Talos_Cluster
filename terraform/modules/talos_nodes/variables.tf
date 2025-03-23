variable "cluster_name" {
  
}
variable "cluster_url" {
  
}
variable "nodes" {
  
}
variable "bootstrap_nodes" {
  type = bool
  default = true
}
variable "controlplane_ip" {
  
}
variable "wg_cidr" {
  default = "10.10.0.0/24"
}
variable "mtu" {
  default = 1500
}
variable "wg_iface" {
  default = "wg0"
}