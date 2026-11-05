locals {
  # Longhorn dedicated disk (format and mount /dev/sdb on workers)
  talos_longhorn_machine_disks = var.longhorn_enabled ? [{
    device = "/dev/sdb"
    partitions = [{
      mountpoint = "/var/lib/longhorn"
    }]
  }] : []

  # Proxmox CCM provider ID, set by kubelet (proxmox-port-only)
  worker_kubelet_provider_id_args = {
    for name, node in local.worker_nodes : name => var.proxmox_ccm_enabled ? {
      "provider-id" = "proxmox://${var.proxmox_ccm_region}/${node.vm_id}"
    } : {}
  }

  # Worker Config
  worker_talos_config_patches = {
    for name, node in local.worker_nodes : name => concat(
      [{
        apiVersion  = "v1alpha1"
        kind        = "KubeNodeConfig"
        labels      = local.worker_nodepools_map[node.nodepool].labels
        annotations = local.worker_nodepools_map[node.nodepool].annotations
        taints = {
          for taint in local.worker_nodepools_map[node.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
        }
      }],
      length(local.talos_longhorn_machine_disks) > 0 ? [{
        machine = {
          disks = local.talos_longhorn_machine_disks
        }
      }] : [],
      local.talos_legacy_kubelet_config_enabled ? [{
        machine = {
          kubelet = {
            extraArgs = local.worker_kubelet_provider_id_args[name]
            extraConfig = merge(
              {
                systemReserved = {
                  cpu               = "100m"
                  memory            = "300Mi"
                  ephemeral-storage = "1Gi"
                }
                kubeReserved = {
                  cpu               = "100m"
                  memory            = "350Mi"
                  ephemeral-storage = "1Gi"
                }
              },
              var.kubernetes_kubelet_extra_config
            )
          }
        }
      }] : [],
      local.talos_legacy_kubelet_config_enabled ? [] : [{
        apiVersion = "v1alpha1"
        kind       = "KubeletConfig"
        extraArgs  = local.worker_kubelet_provider_id_args[name]
        config = merge(
          {
            systemReserved = {
              cpu               = "100m"
              memory            = "300Mi"
              ephemeral-storage = "1Gi"
            }
            kubeReserved = {
              cpu               = "100m"
              memory            = "350Mi"
              ephemeral-storage = "1Gi"
            }
          },
          var.kubernetes_kubelet_extra_config
        )
      }],
      [{
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = name
        auto       = "off"
      }]
    )
  }
}

data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_cloud_config_patches : yamlencode(patch)],
    [for patch in local.worker_talos_config_patches[each.key] : yamlencode(patch)],
    [for patch in var.worker_config_patches : yamlencode(patch)]
  )
}
