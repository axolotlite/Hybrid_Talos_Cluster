# variable "fingerprint" {
#   description = "Fingerprint of oci api private key"
#   type        = string
# }
# variable "private_key_path" {
#   description = "Path to oci api private key used"
#   type        = string
# }
# variable "region" {
#   description = "The oci region where resources will be created"
#   type        = string
# }
# variable "tenancy_ocid" {
#   description = "Tenancy ocid where to create the sources"
#   type        = string
# }
# variable "user_ocid" {
#   description = "Ocid of user that terraform will use to create the resources"
#   type        = string
# }
variable "compartment_ocid" {
  description = "Compartment ocid where to create all resources"
  type        = string
}
variable "availability_domain" {
  default = 1
}
variable "vcn_cidr_blocks" {
  default = ["10.1.0.0/16"]
}
variable "subnet" {
  default = "10.1.20.0/24"
}
variable "subnet_name" {
  default = "main"
}
variable "vcn_name" {
  default = "main"
}

variable "nodes" {
  
}
variable "images" {
  
}
variable "talos_version" {
  
}