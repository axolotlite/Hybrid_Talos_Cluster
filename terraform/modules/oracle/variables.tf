variable "compartment_ocid" {
  description = "Compartment ocid where to create all resources"
  type        = string
}
variable "availability_domain" {
  description = "The availability domain used in VM creation."
  type = number
  default = 1
}
variable "vcn_cidr_blocks" {
  description = "The VCN cidr blocks"
  default = ["10.1.0.0/16"]
}
variable "subnet" {
  description = "The main VCN subnet address block"
  default = "10.1.20.0/24"
}
variable "vcn_name" {
  description = "The main VCN name."
  type = string
  default = "main"
}
variable "subnet_name" {
  description = "The main VCN subnet name."
  type = string
  default = "main"
}
variable "nodes" {
  description = "The oracle nodes configuration, is restricted to always-free resources."
  type = map(object({
    arch = string
    instance_shape = string
    ocpus = number
    memory_in_gbs = number
  }))
  ## VM shape restriction
  validation {
    error_message = "Always Free Restrictions violated: instance_shape is neither \"VM.Standard.A1.Flex\" or \"VM.Standard.E2.1.Micro\""
    condition = anytrue([ for node in var.nodes: contains(["VM.Standard.A1.Flex","VM.Standard.E2.1.Micro"],node.instance_shape)])
  }
  ## VM.Standard.A1.Flex restrictions
  ### Don't exceed 4 ocpus across all created vms
  validation {
    error_message = "Always Free Restrictions violated: \"VM.Standard.A1.Flex\" ocpu count exceeded 4."
    condition = sum(
      coalescelist(
        [ for node in var.nodes: node.ocpus if node.instance_shape == "VM.Standard.A1.Flex" ],
        [0]
      )
    ) <= 4
  }
  ### Don't exceed 24 gigs of ram across all created vms
  validation {
    error_message = "Always Free Restrictions violated: \"VM.Standard.A1.Flex\" memory_in_gbs size exceeded 24 gbs."
    condition = sum(
      coalescelist(
        [ for node in var.nodes: node.memory_in_gbs if node.instance_shape == "VM.Standard.A1.Flex"],
        [0]
      )
    ) <= 24
  }
  ## VM.Standard.E2.1.Micro restrictions
  ### Don't exceed 2 vms of this type
  validation {
    error_message = "Always Free Restrictions violated: \"VM.Standard.E2.1.Micro\" nodes exceed 2."
    condition = sum(
      coalescelist(
        [
          for node in var.nodes:
            1 if node.instance_shape == "VM.Standard.E2.1.Micro"
        ],
        [0]
      )
    ) <= 2
  }
  ### Don't exceed 1 ocpu on each vm
  validation {
    error_message = "Always Free Restrictions violated: \"VM.Standard.E2.1.Micro\" ocpu count is not 1."
    condition = anytrue(
      coalescelist(
        [
          for node in var.nodes:
            false if node.instance_shape == "VM.Standard.E2.1.Micro" && node.ocpus != 1
        ],
        [true]
      )
    )
  }
  ### Don't exceed 1 gb ram on each vm
  validation {
    error_message = "Always Free Restrictions violated: \"VM.Standard.E2.1.Micro\" memory_in_gbs count is not 1."
    condition = anytrue(
      coalescelist(
        [
          for node in var.nodes:
            false if node.instance_shape == "VM.Standard.E2.1.Micro" && node.memory_in_gbs != 1
        ],
        [true]
      )
    )
  }
}
variable "images" {
  description = "A map of image architecture and location to upload it to oracle archive storage"
  type = map(string)
}
variable "talos_version" {
  description = "Talos image version"
  type = string
}