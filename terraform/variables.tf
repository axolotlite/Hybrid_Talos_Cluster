#Oracle Configs
variable "fingerprint" {
  description = "Fingerprint of oci api private key"
  type        = string
}
variable "private_key_path" {
  description = "Path to oci api private key used"
  type        = string
}
variable "region" {
  description = "The oci region where resources will be created"
  type        = string
}
variable "tenancy_ocid" {
  description = "Tenancy ocid where to create the sources"
  type        = string
}
variable "user_ocid" {
  description = "Ocid of user that terraform will use to create the resources"
  type        = string
}
variable "compartment_ocid" {
  description = "Compartment ocid where to create all resources"
  type        = string
}

#Talos Configs
variable "talos_version" {
  description = "The version of the talos image"
  default = "1.9.4"
}

variable "worker_ips" {
  description = "value"
  default = []
}

#Cloud Cluster Configs
variable "cluster_name" {
  description = "The name of the cluster"
  default = "terraform-provisioned-cluster"
}
variable "cluster_endpoint" {
  description = "The URL or IP of the k8s controlplane endpoint"
}
variable "cluster_url" {
  description = "The URL of the k8s controlplane endpoint"
  default = ""
}
#Wireguard Configs
variable "wg_cidr"{
    description = "value"
    default = "10.10.0.0/24"
}
variable "listen_port"{
    description = "value"
    default = "51820"
}
variable "control_node_ip"{
    description = "value"
    default = "10.10.0.1"
}
variable "wg_subnet"{
    description = "value"
    default = "24"
}
variable "worker_node_ips"{
    description = "value"
    default = ["10.10.0.100/32", "10.10.0.101/32"]
}

#Tunnel Configs
variable "ws_secret" {
    description = "value"
}
variable "ws_port" {
    description = "value"
    default="12345"
}

#Oracle Controlplane Instance
variable "instance_name" {
  description = "Name of the instance."
  type        = string
}

variable "instance_ad_number" {
  description = "The availability domain number of the instance. If none is provided, it will start with AD-1 and continue in round-robin."
  default     = 1
  type        = number
}

variable "instance_state" {
  default     = "RUNNING"
  description = "(Updatable) The target state for the instance. Could be set to RUNNING or STOPPED."
  type        = string

  validation {
    condition     = contains(["RUNNING", "STOPPED"], var.instance_state)
    error_message = "Accepted values are RUNNING or STOPPED."
  }
}

variable "assign_public_ip" {
  default     = false
  description = "Whether the VNIC should be assigned a public IP address."
  type        = bool
}

variable "availability_domain" {
  default     = 3
  description = "Availability Domain of the instance"
  type        = number
}

variable "instance_shape" {
  default     = "VM.Standard.A1.Flex"
  description = "The shape of an instance."
  type        = string
}

variable "instance_ocpus" {
  default     = 1
  description = "Number of OCPUs"
  type        = number
}

variable "instance_shape_config_memory_in_gbs" {
  default     = 6
  description = "Amount of Memory (GB)"
  type        = number
}

variable "instance_source_type" {
  default     = "image"
  description = "The source type for the instance."
  type        = string
}

variable "boot_volume_size_in_gbs" {
  default     = "50"
  description = "Boot volume size in GBs"
  type        = number
}
#image
variable "arch" {
  description = "The Talos architecture list"
  type        = list(string)
  default     = ["amd64", "arm64"]
}