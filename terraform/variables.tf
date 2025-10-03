#Hetzner Cloud
variable "hcloud_token" {
  description = "The hetzner cloud api token"
  sensitive = true
}
#Talos Configs
variable "talos_version" {
  description = "The version of the talos image"
  type = string
  default = "v1.10.5"
}

#Cloud Cluster Configs
variable "cluster_name" {
  description = "The name of the cluster"
  type = string
  default = "terraform-provisioned-cluster"
}
variable "cluster_url" {
  description = "The URL of the created k8s controlplane endpoint"
  type = string
}
#hetzner Controlplane Instance
variable "vm_name" {
  description = "name of the hetzner vm."
  type        = string
}
#image
variable "arch" {
  description = "The Talos vm architectures for oracle vm image creation."
  type        = list(string)
  default     = ["amd64", "arm64"]
}
variable "bootstrap_nodes" {
  type = bool
  default = true
}

#wg controlplane url
variable "wg_controlplane_address" {
  description = "The wg ip address of the main controlplane node"
  type = string
}

variable "server_type" {
  description = "the hetzner vm server type"
  type = string
  default = "cx22"
}

variable "wg_listen_port" {
  description = "The port used for wiregaurd"
  type = string
  default = "51820"
}

variable "wstunnel_secret" {
  description = "The secret used by wstunnel to authenticate"
  type = string
}