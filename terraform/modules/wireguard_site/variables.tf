variable "site" {
  description = "The wireguard mesh network configs."
  type = map(object({
    egress_endpoint = optional(string)
    ingress_tunnel = optional(bool,false)
    endpoint = optional(string)
    listen_port = optional(number)
    addresses = list(string)
    allowedIPs = list(string)
    peers = list(string)
    private_key = optional(string)
    public_key = optional(string)
  }))
}
variable "wg_iface" {
  description = "The wireguard interface name used in talos config"
  type = string
  default = "wg0"
}
variable "mtu" {
  description = "The wireguard packet mtu"
  type = number
  default = 1500
}
variable "wg_kubelet_subnet" {
  description = "the k8s kubelet subnet used to specify the kubelet ip address, it allows the controlplane to use wg ip addresses."
  type = string
}
