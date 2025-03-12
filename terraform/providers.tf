terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
      version = "0.7.1"
    }
    wireguard = {
      source = "OJFord/wireguard"
      version = "0.3.2"
    }
    oci = {
      source  = "oracle/oci"
      version = ">= 4.108.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}