locals {
  # Flatten nodepools into maps of individual nodes with computed IPs
  control_plane_nodes = merge([
    for np_index in range(length(local.control_plane_nodepools)) : {
      for cp_index in range(local.control_plane_nodepools[np_index].count) : "${var.cluster_name}-${local.control_plane_nodepools[np_index].name}-${cp_index + 1}" => {
        nodepool     = local.control_plane_nodepools[np_index].name
        proxmox_node = local.control_plane_nodepools[np_index].proxmox_node
        cpu          = local.control_plane_nodepools[np_index].cpu
        memory       = local.control_plane_nodepools[np_index].memory
        disk_size    = local.control_plane_nodepools[np_index].disk_size
        labels       = local.control_plane_nodepools[np_index].labels
        vm_id        = local.vm_id_base + local.control_plane_nodepools[np_index].ip_offset + cp_index
        ip = cidrhost(
          var.network_node_ipv4_cidr,
          local.control_plane_nodepools[np_index].ip_offset + cp_index
        )
      }
    }
  ]...)

  worker_nodes = merge([
    for np_index in range(length(local.worker_nodepools)) : {
      for wkr_index in range(local.worker_nodepools[np_index].count) : "${var.cluster_name}-${local.worker_nodepools[np_index].name}-${wkr_index + 1}" => {
        nodepool          = local.worker_nodepools[np_index].name
        proxmox_node      = local.worker_nodepools[np_index].proxmox_node
        cpu               = local.worker_nodepools[np_index].cpu
        memory            = local.worker_nodepools[np_index].memory
        disk_size         = local.worker_nodepools[np_index].disk_size
        storage_disk_size = local.worker_nodepools[np_index].storage_disk_size
        labels            = local.worker_nodepools[np_index].labels
        vm_id             = local.vm_id_base + local.worker_nodepools[np_index].ip_offset + wkr_index
        ip                = cidrhost(var.network_node_ipv4_cidr, local.worker_nodepools[np_index].ip_offset + wkr_index)
      }
    }
  ]...)

  # IP lists
  control_plane_ips = [for name, node in local.control_plane_nodes : node.ip]
  worker_ips        = [for name, node in local.worker_nodes : node.ip]

  # Network
  network_prefix_length = tonumber(split("/", var.network_node_ipv4_cidr)[1])

  # VM ID base: explicit or derived from the third octet of the node CIDR (e.g. 192.168.10.0/24 → 100)
  vm_id_base = coalesce(var.proxmox_vm_id_base, tonumber(split(".", var.network_node_ipv4_cidr)[2]) * 10)
}

###############################################################################
# Control Plane Nodes
###############################################################################

resource "proxmox_virtual_environment_vm" "control_plane" {
  for_each = local.control_plane_nodes

  vm_id     = each.value.vm_id
  name      = each.key
  node_name = each.value.proxmox_node
  tags      = sort(["kubernetes", "control-plane", "managed-by-tofu"])

  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  keyboard_layout = var.proxmox_keyboard_layout
  tablet_device   = false
  started         = true
  stop_on_destroy = true

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  efi_disk {
    datastore_id      = var.proxmox_disk_storage
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    interface    = "scsi0"
    file_id      = proxmox_download_file.talos_image.id
    size         = each.value.disk_size
    datastore_id = var.proxmox_disk_storage
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${local.network_prefix_length}"
        gateway = var.network_gateway
      }
    }
  }

  network_device {
    bridge  = var.proxmox_network_bridge
    model   = "virtio"
    vlan_id = var.proxmox_network_vlan_id
  }

  agent {
    enabled = true
    trim    = true
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      initialization,
    ]
  }
}

###############################################################################
# Worker Nodes
###############################################################################

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = local.worker_nodes

  vm_id     = each.value.vm_id
  name      = each.key
  node_name = each.value.proxmox_node
  tags      = sort(["kubernetes", "worker", "managed-by-tofu"])

  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"
  keyboard_layout = var.proxmox_keyboard_layout
  tablet_device   = false
  started         = true
  stop_on_destroy = true

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  efi_disk {
    datastore_id      = var.proxmox_disk_storage
    type              = "4m"
    pre_enrolled_keys = false
  }

  disk {
    interface    = "scsi0"
    file_id      = proxmox_download_file.talos_image.id
    size         = each.value.disk_size
    datastore_id = var.proxmox_disk_storage
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  # Dedicated storage disk
  dynamic "disk" {
    for_each = each.value.storage_disk_size > 0 ? [1] : []
    content {
      interface    = "scsi1"
      size         = each.value.storage_disk_size
      datastore_id = var.proxmox_disk_storage
      discard      = "on"
      iothread     = true
      ssd          = true
      file_format  = "raw"
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${local.network_prefix_length}"
        gateway = var.network_gateway
      }
    }
  }

  network_device {
    bridge  = var.proxmox_network_bridge
    model   = "virtio"
    vlan_id = var.proxmox_network_vlan_id
  }

  agent {
    enabled = true
    trim    = true
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      initialization,
    ]
  }
}
