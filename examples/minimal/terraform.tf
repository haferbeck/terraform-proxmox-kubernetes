terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.89.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.11.0"
    }
  }
}
