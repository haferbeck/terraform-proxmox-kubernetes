# Talos CCM — handles cloud-node (providerID, node init) and CSR approval.
# Always runs with the same controllers regardless of Proxmox CCM state.

data "helm_template" "talos_ccm" {
  count = var.talos_ccm_enabled ? 1 : 0

  name      = "talos-cloud-controller-manager"
  namespace = "kube-system"

  repository   = var.talos_ccm_helm_repository
  chart        = var.talos_ccm_helm_chart
  version      = var.talos_ccm_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      enabledControllers = [
        "node-csr-approval"
      ]
      useDaemonSet      = true
      priorityClassName = "system-cluster-critical"
      nodeSelector      = { "node-role.kubernetes.io/control-plane" = "" }
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          effect   = "NoSchedule"
          operator = "Exists"
        },
        {
          key    = "node.cloudprovider.kubernetes.io/uninitialized"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
    }),
    yamlencode(var.talos_ccm_helm_values)
  ]
}

locals {
  talos_ccm_manifest = var.talos_ccm_enabled ? {
    name     = "talos-ccm"
    contents = data.helm_template.talos_ccm[0].manifest
  } : null
}
