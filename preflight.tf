###############################################################################
# Preflight Checks
###############################################################################
# Validate prerequisites before any resource is touched. Fails plan with a
# helpful message instead of letting the Proxmox API reject mid-apply.

# Datastores per Proxmox host referenced by any nodepool (or var.proxmox_node).
data "proxmox_virtual_environment_datastores" "preflight" {
  for_each  = toset(local.proxmox_target_nodes)
  node_name = each.value
}

resource "terraform_data" "preflight" {
  input = {
    vm_id_base           = local.vm_id_base
    proxmox_target_nodes = local.proxmox_target_nodes
  }

  lifecycle {
    precondition {
      condition     = local.vm_id_base >= 100
      error_message = "Computed proxmox_vm_id_base is ${local.vm_id_base}, but Proxmox requires VM IDs >= 100. Either set var.proxmox_vm_id_base explicitly (>= 100) or use a network_node_ipv4_cidr whose third octet is >= 10 (e.g. 10.0.30.0/24 → 300)."
    }

    precondition {
      condition = alltrue([
        for n in local.proxmox_target_nodes :
        contains(data.proxmox_virtual_environment_datastores.preflight[n].datastores[*].id, var.proxmox_disk_storage)
      ])
      error_message = "var.proxmox_disk_storage = '${var.proxmox_disk_storage}' was not found on one or more target Proxmox hosts (${join(", ", local.proxmox_target_nodes)}). Verify the storage pool exists on every host that hosts a nodepool."
    }

    precondition {
      condition = alltrue([
        for n in local.proxmox_target_nodes :
        contains(data.proxmox_virtual_environment_datastores.preflight[n].datastores[*].id, var.proxmox_image_storage)
      ])
      error_message = "var.proxmox_image_storage = '${var.proxmox_image_storage}' was not found on one or more target Proxmox hosts (${join(", ", local.proxmox_target_nodes)}). Verify the storage pool exists on every host that hosts a nodepool."
    }
  }
}
