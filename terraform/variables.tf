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
  type = string
  default = "v1.9.5"
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
  default = ""
}
#Wireguard Configs

variable "controlplane_node" {
  description = "The name of the controlplane node as specified in cloud_nodes variable."
  type = string
}
variable "cloud_nodes" {
  description = "An object describing the oracle cloud nodes properties."
  default = {
    "controlplane" = {
      role = "controlplane"
      arch = "arm64"
      instance_shape = "VM.Standard.A1.Flex"
      ocpus = 4
      memory_in_gbs = 24
      config_patches = {
        "templates/example_static_pod.yaml" = {
          pod_name = "busybox"
          container_name = "busybox"
          image = "busybox"
          command = "sleep 5"
        }
      }
      tags = {
        type = "cloud"
        role = "controlplane"
      }
    }
  }
  type = map(object({
    arch = string
    role = string
    instance_shape = string
    ocpus = number
    memory_in_gbs = number
    config_patches = optional(map(map(string)),{})
    tags = optional(map(string))
  }))
}
variable "onprem_nodes" {
  description = "An object describing the locally accessible nodes properties."
  default = {
    "home" = {
      role = "worker"
      public_ip = "192.168.1.2"
      config_patches = {
        "templates/example_static_pod.yaml" = {
          pod_name = "busybox"
          container_name = "busybox"
          image = "busybox"
          command = "sleep 5"
        }
      }
    }
  }
  type = map(object({
    role = string
    public_ip = string
    config_patches = optional(map(map(string)),{})
    tags = optional(map(string))
  }))
}
variable "wg_controlplane_adderess"{
    description = "The address of the controlplane endpoint in the wireguard interface."
    default = null
}
#Oracle Controlplane Instance
variable "availability_domain" {
  default     = 1
  description = "Availability Domain of the oracle instances."
  type        = number
}
#image
variable "arch" {
  description = "The Talos vm architectures for oracle vm image creation."
  type        = list(string)
  default     = ["amd64", "arm64"]
}
variable "wg_kubelet_subnet" {
  description = "the k8s kubelet subnet used to specify the kubelet ip address, it allows the controlplane to use wg ip addresses."
  type = string
  default = "10.10.0.0/24"
}
variable "site" {
  description = "The wireguard mesh network configs."
  default = {
    "controlplane" = {
      egress_endpoint = "127.0.0.1:51820"
      endpoint = "controlpane.example-domain.com:51820" #The url where it's peers are supposed to reach it, will be modified to take ip address if null
      listen_port = 51820
      addresses = ["10.10.0.1/24"]
      allowedIPs = ["10.10.0.0/24"]
      peers = ["home"]
    }
    "home" = {
      ingress_tunnel = true
      endpoint = "192.168.1.4:51821" 
      listen_port = 51821
      addresses = ["10.10.0.101/24"]
      allowedIPs = ["10.10.0.101/32"]
      peers = ["controlplane"]
    }
  }
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
variable "bootstrap_nodes" {
  type = bool
  default = true
}