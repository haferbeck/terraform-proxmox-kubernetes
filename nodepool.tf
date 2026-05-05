locals {
  control_plane_nodepools = [
    for np in var.control_plane_nodepools : {
      name         = np.name,
      cpu          = np.cpu,
      memory       = np.memory,
      disk_size    = np.disk_size,
      ip_offset    = np.ip_offset,
      proxmox_node = coalesce(np.proxmox_node, var.proxmox_node),
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = concat(
        [for taint in np.taints : regex(
          "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
          taint
        )],
        local.talos_allow_scheduling_on_control_planes ? [] : [
          { key = "node-role.kubernetes.io/control-plane", value = "", effect = "NoSchedule" }
        ]
      ),
      count = np.count,
    }
  ]

  worker_nodepools = [
    for np in var.worker_nodepools : {
      name              = np.name,
      cpu               = np.cpu,
      memory            = np.memory,
      disk_size         = np.disk_size,
      ip_offset         = np.ip_offset,
      proxmox_node      = coalesce(np.proxmox_node, var.proxmox_node),
      storage_disk_size = np.storage_disk_size,
      labels = merge(
        np.labels,
        { nodepool = np.name }
      ),
      annotations = np.annotations,
      taints = [for taint in np.taints : regex(
        "^(?P<key>[^=:]+)=?(?P<value>[^=:]*?):(?P<effect>.+)$",
        taint
      )],
      count = np.count,
    }
  ]

  control_plane_nodepools_map = { for np in local.control_plane_nodepools : np.name => np }
  worker_nodepools_map        = { for np in local.worker_nodepools : np.name => np }

  control_plane_sum = sum(concat(
    [for np in local.control_plane_nodepools : np.count], [0]
  ))
  worker_sum = sum(concat(
    [for np in local.worker_nodepools : np.count if length(np.taints) == 0], [0]
  ))

  # Distinct Proxmox hosts referenced across all nodepools (for preflight checks).
  proxmox_target_nodes = distinct(concat(
    [var.proxmox_node],
    [for np in local.control_plane_nodepools : np.proxmox_node],
    [for np in local.worker_nodepools : np.proxmox_node],
  ))
}
