locals {
  controlplane_node_address = module.hetzner_vm.ipv4_address
  cluster_url = coalesce(var.cluster_url,local.controlplane_node_address)
  cluster_endpoint = "https://${local.cluster_url}:6443"
  wg_cluster_endpoint = "https://${var.wg_controlplane_address}:6443"

  control_plane_scheduling = yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    })
  firewall_rules = [
    {
        description = "HTTP for use in ingress"
        direction = "in"
        protocol = "tcp"
        port = "80"
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
    },
    {
        description = "HTTPS for use in ingress"
        direction = "in"
        protocol = "tcp"
        port = "443"
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
    },
    {
        description = "Wireguard ports"
        direction = "in"
        protocol = "udp"
        port = var.wg_listen_port
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
    },
    {
        description = "controlplane wstunnel port"
        direction = "in"
        protocol = "tcp"
        port = var.wg_listen_port
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
    },
    # {
    #     description = "additional wstunnel ports"
    #     direction = "in"
    #     protocol = "tcp"
    #     port = "51920-51930"
    #     source_ips = [
    #       "0.0.0.0/0",
    #       "::/0"
    #     ]
    # }
  ]
}

# #Used to create an image, no longer needed since any image can be used to install any version
# module "images" {
#   source = "./modules/image"
#   talos_version = var.talos_version
# }

# Hetzner
## Image created and pushed using packer
data "hcloud_image" "amd64" {
  with_selector     = "os=talos"
  with_architecture = "x86"
  most_recent       = true
}
module "hetzner_vm" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/hetzner/hetzner_vm/"
  vm_name = var.vm_name
  location = "hel1"
  server_type = var.server_type
  image_id = data.hcloud_image.amd64.id
  firewall_rules = local.firewall_rules
}

## Main talos secret
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

## Nodes Configuration

module "hetzner_controlplane" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/talos_node"
  #Talos configs
  node_is_controlplane = true
  node_address = var.wg_controlplane_address # module.hetzner_vm.ipv4_address ##This is only used during initial install
  cluster_name = var.cluster_name
  talos_version = var.talos_version
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_secrets = talos_machine_secrets.this.machine_secrets
  is_image_secureboot = true
  ## Additional talos configs
  talos_extra_kernel_args = ["talos.platform=nocloud"]
  # talos_kernel_modules = ["nvme_tcp", "vfio_pci", "uio_pci_generic"]
  # talos_extensions = [
  #   # longhorn
  #   "iscsi-tools",
  #   "util-linux-tools"
  # ]
  config_templates = {
    "templates/wstunnel.yaml" = {
      command = "exec /home/app/wstunnel server --restrict-http-upgrade-path-prefix '${var.wstunnel_secret}' --restrict-to 127.0.0.1:${var.wg_listen_port} wss://0.0.0.0:${var.wg_listen_port}"
    }
    "templates/certsans.yaml" = {
      dns_name = local.cluster_url
      node_ip = local.wg_cluster_endpoint
    }
    # "templates/allow_controlplane_scheduling.yaml" = {}
    # "templates/longhorn.yaml" = {}
  }
  #Kubernetes configs
  cluster_endpoint = local.wg_cluster_endpoint
  node_labels = {
    # "node.longhorn.io/create-default-disk"=true
    type= "cloud"
    role= "controlplane"
  }

  #Networking and Wireguard
  use_wireguard = true
  #The endpoint used by other nodes to access the controlplane through wstunnel
  wg_override_endpoint = "127.0.0.1:51820"
  wg_listen_port = var.wg_listen_port
  wg_addresses = [ "${var.wg_controlplane_address}/24" ]
  wg_allowed_ips = [ "10.10.0.0/24" ]
  wg_peers = [
    module.home_worker_a.wg_peer,
    module.home_worker_b.wg_peer,
    module.home_worker_c.wg_peer,
    module.home_worker_gpu.wg_peer,
    module.wg_admin.wg_peer
  ]
}
module "home_worker_a" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/talos_node"
  #Talos configs
  node_is_controlplane = false
  node_address = "10.10.0.2"
  cluster_name = var.cluster_name
  talos_version = var.talos_version
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_secrets = talos_machine_secrets.this.machine_secrets
  is_image_secureboot = true
  ## Additional talos configs
  talos_kernel_modules = [
    "nvme_tcp",
    "vfio_pci",
    "uio_pci_generic"
  ]
  talos_extensions = [
    "intel-ucode",
    "iscsi-tools",
    "util-linux-tools"
  ]
  config_templates = {
    "templates/install_disk.yaml" = {
      disk_name = "/dev/nvme0n1"
    }
    "templates/longhorn.yaml" = {}
    "templates/wstunnel.yaml" = {
      command = "exec /home/app/wstunnel client --http-upgrade-path-prefix '${var.wstunnel_secret}' -L 'udp://${var.wg_listen_port}:127.0.0.1:${var.wg_listen_port}?timeout_sec=0' wss://${local.cluster_url}:${var.wg_listen_port}"
    }
  }
  #Kubernetes configs
  cluster_endpoint = local.wg_cluster_endpoint
  node_labels = {
    "node.longhorn.io/create-default-disk"=true
    storage = true
    type= "prem"
  }
  #Networking and Wireguard
  use_wireguard = true
  wg_override_endpoint = "192.168.1.5:51821"
  wg_listen_port = 51821
  wg_addresses = [ "10.10.0.2/24" ]
  wg_allowed_ips = [ "10.10.0.2/32" ]
  wg_peers = [
    module.hetzner_controlplane.wg_peer,
    module.home_worker_b.wg_peer,
    module.home_worker_gpu.wg_peer
  ]
}

module "home_worker_b" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/talos_node"
  #Talos configs
  node_is_controlplane = false
  node_address = "10.10.0.3"
  cluster_name = var.cluster_name
  talos_version = var.talos_version
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_secrets = talos_machine_secrets.this.machine_secrets
  is_image_secureboot = true
  ## Additional talos configs
  talos_kernel_modules = [
    "nvme_tcp",
    "vfio_pci",
    "uio_pci_generic"
  ]
  talos_extensions = [
    "amd-ucode",
    "iscsi-tools",
    "util-linux-tools"
  ]
  config_templates = {
    "templates/install_disk.yaml" = {
      disk_name = "/dev/sdb"
    }
    "templates/wstunnel.yaml" = {
        command = "exec /home/app/wstunnel client --http-upgrade-path-prefix '${var.wstunnel_secret}' -L 'udp://${var.wg_listen_port}:127.0.0.1:${var.wg_listen_port}?timeout_sec=0' wss://${local.cluster_url}:${var.wg_listen_port}"
    }
    "templates/longhorn.yaml" = {}
    "templates/volumes.yaml" = {
      volumes = {
        "longhorn-volume" = {
          match = "disk.size >= 400u * GB"
          max_size = "500GB"
        }
      }
    }
  }
  #Kubernetes configs
  cluster_endpoint = local.wg_cluster_endpoint
  node_labels = {
    "node.longhorn.io/create-default-disk"=true
    storage = true
    type= "prem"
  }
  # node_taints = {
  #   node="storage:NoSchedule"
  # }

  #Networking and Wireguard
  use_wireguard = true
  wg_override_endpoint = "192.168.1.11:51821"
  wg_listen_port = 51821
  wg_addresses = [ "10.10.0.3/24" ]
  wg_allowed_ips = [ "10.10.0.3/32" ]
  wg_peers = [
    module.hetzner_controlplane.wg_peer,
    module.home_worker_a.wg_peer,
    module.home_worker_gpu.wg_peer
  ]
}

module "home_worker_c" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/talos_node"
  #Talos configs
  node_is_controlplane = false
  node_address = "10.10.0.4"
  cluster_name = var.cluster_name
  talos_version = var.talos_version
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_secrets = talos_machine_secrets.this.machine_secrets
  is_image_secureboot = true
  ## Additional talos configs
  talos_kernel_modules = [
    "nvme_tcp",
    "vfio_pci",
    "uio_pci_generic"
  ]
  talos_extensions = [
    "amd-ucode",
    "iscsi-tools",
    "util-linux-tools"
  ]
  config_templates = {
    "templates/install_disk.yaml" = {
      disk_name = "/dev/sdb"
    }
    "templates/wstunnel.yaml" = {
        command = "exec /home/app/wstunnel client --http-upgrade-path-prefix '${var.wstunnel_secret}' -L 'udp://${var.wg_listen_port}:127.0.0.1:${var.wg_listen_port}?timeout_sec=0' wss://${local.cluster_url}:${var.wg_listen_port}"
    }
    "templates/longhorn.yaml" = {}
    "templates/volumes.yaml" = {
      volumes = {
        "longhorn-volume" = {
          match = "disk.size >= 400u * GB"
          max_size = "500GB"
        }
      }
    }
  }
  #Kubernetes configs
  cluster_endpoint = local.wg_cluster_endpoint
  node_labels = {
    "node.longhorn.io/create-default-disk"=true
    storage = true
    type= "prem"
  }  
  #Networking and Wireguard
  use_wireguard = true
  ## This node is in another zone
  # wg_override_endpoint = "192.168.1.12:51821"
  wg_listen_port = 51821
  wg_addresses = [ "10.10.0.4/24" ]
  wg_allowed_ips = [ "10.10.0.4/32" ]
  wg_peers = [
    module.hetzner_controlplane.wg_peer,
    # module.home_worker_a.wg_peer,
    # module.home_worker_b.wg_peer,
    # module.home_worker_gpu.wg_peer
  ]
  
}
module "home_worker_gpu" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/talos_node"
  #Talos configs
  node_is_controlplane = false
  node_address = "10.10.0.5"
  cluster_name = var.cluster_name
  talos_version = var.talos_version
  client_configuration = talos_machine_secrets.this.client_configuration
  machine_secrets = talos_machine_secrets.this.machine_secrets
  is_image_secureboot = true
  ## Additional talos configs
  talos_kernel_modules = [
    "nvme_tcp",
    "vfio_pci",
    "uio_pci_generic",
    "uinput",
    "amdgpu"
  ]
  talos_extensions = [
    "amd-ucode",
    "iscsi-tools",
    "util-linux-tools",
    "fuse",
    "uinput",
    "amdgpu"
  ]
  config_templates = {
    # "templates/install_disk.yaml" = {
    #   disk_name = "/dev/sda"
    # }
    "templates/wstunnel.yaml" = {
        command = "exec /home/app/wstunnel client --http-upgrade-path-prefix '${var.wstunnel_secret}' -L 'udp://${var.wg_listen_port}:127.0.0.1:${var.wg_listen_port}?timeout_sec=0' wss://${local.cluster_url}:${var.wg_listen_port}"
    }
    "templates/longhorn.yaml" = {}
    "templates/volumes.yaml" = {
      volumes = {
        "nvme-volume" = {
          match = "disk.transport == 'nvme'"
          max_size = "500GB"
        }
        "ssd-volume" = {
          match = "disk.size >= 470u * GB && disk.size <= 490u * GB"
          max_size = "480GB"
        }
      }
    }
  }
  #Kubernetes configs
  cluster_endpoint = local.wg_cluster_endpoint
  node_labels = {
    # "node.longhorn.io/create-default-disk"=true
    storage = true
    gpu = true
    gaming = true
    type= "prem"
  }
  #Networking and Wireguard
  use_wireguard = true
  wg_override_endpoint = "192.168.1.24:51821"
  wg_listen_port = 51821
  wg_addresses = [ "10.10.0.5/24" ]
  wg_allowed_ips = [ "10.10.0.5/32" ]
  wg_peers = [
    module.hetzner_controlplane.wg_peer,
    module.home_worker_a.wg_peer,
    module.home_worker_b.wg_peer
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [ module.hetzner_controlplane ]
  node                 = local.controlplane_node_address
  client_configuration = talos_machine_secrets.this.client_configuration
}

#Write Configuration Files
## Wireguard for cluster adminstration
module "wg_admin" {
  source = "git::https://github.com/axolotlite/terraform-modules.git//modules/misc/wg_user"
  wg_listen_port = var.wg_listen_port
  wg_addresses = [ "10.10.0.100/24" ]
  wg_allowed_ips = [ "10.10.0.100/32" ]
  wg_peers = [
    module.hetzner_controlplane.wg_peer
  ]
}
## Talos configs
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [var.cluster_url, var.wg_controlplane_address] #need to set this up once I'm done setting the terraform vars

}
resource"local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}
## Kube configs
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint                 = var.wg_controlplane_address
  node = var.wg_controlplane_address
}
resource"local_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}