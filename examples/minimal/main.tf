provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  ssh {
    agent = true
  }
}

# Smallest viable cluster: 1 control plane + 1 worker, single Proxmox host.
# Not highly available. For HA use 3 (or 5) control plane nodes across multiple hosts.
module "kubernetes" {
  source = "../.."

  cluster_name = "minimal"
  cluster_vip  = "10.0.0.10"

  proxmox_node          = "pve01"
  proxmox_disk_storage  = "local-lvm"
  proxmox_image_storage = "local"

  network_node_ipv4_cidr = "10.0.0.0/24"
  network_gateway        = "10.0.0.1"

  cluster_kubeconfig_path  = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  control_plane_nodepools = [
    {
      name      = "control"
      cpu       = 2
      memory    = 4096
      disk_size = 20
      ip_offset = 11
      count     = 1
    }
  ]

  worker_nodepools = [
    {
      name      = "worker"
      cpu       = 2
      memory    = 4096
      disk_size = 20
      ip_offset = 21
      count     = 1
    }
  ]
}
