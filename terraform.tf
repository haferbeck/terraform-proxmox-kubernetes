terraform {
  required_version = ">=1.9.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }

    proxmox = {
      source = "bpg/proxmox"
      # 0.100.0 introduced the short `proxmox_*` type names used here
      # (download_file, user_token, datastores).
      version = ">= 0.100.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }

  }
}
