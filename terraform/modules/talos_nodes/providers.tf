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
  }
}