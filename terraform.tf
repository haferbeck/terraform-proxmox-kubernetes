terraform {
  required_version = ">=1.9.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.11.0"
    }

    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.89.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.0"
    }

    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }

  }
}
