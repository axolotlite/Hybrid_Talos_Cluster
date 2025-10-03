terraform {
  required_providers {
    talos = {
      source = "registry.terraform.io/siderolabs/talos"
      # source = "local/talos"
      version = "0.8.1"
    }
    wireguard = {
      source = "OJFord/wireguard"
      version = "0.4.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}