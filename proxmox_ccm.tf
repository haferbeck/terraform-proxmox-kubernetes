# Proxmox CCM — API User, Role, Token (auto-provisioned)
resource "proxmox_virtual_environment_role" "ccm" {
  count = var.proxmox_ccm_enabled ? 1 : 0

  role_id = "${var.cluster_name}-ccm"

  privileges = [
    "Sys.Audit",
    "VM.Audit",
    "VM.Monitor",
  ]
}

resource "proxmox_virtual_environment_user" "ccm" {
  count = var.proxmox_ccm_enabled ? 1 : 0

  user_id = "${var.cluster_name}-ccm@pve"
  comment = "Kubernetes CCM for cluster ${var.cluster_name}"

  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.ccm[0].role_id
  }
}

resource "proxmox_user_token" "ccm" {
  count = var.proxmox_ccm_enabled ? 1 : 0

  comment               = "CCM token for cluster ${var.cluster_name}"
  token_name            = "ccm"
  user_id               = proxmox_virtual_environment_user.ccm[0].user_id
  privileges_separation = false
}

# Proxmox CCM Secret
locals {
  proxmox_ccm_api_url = "https://${var.proxmox_node}:8006/api2/json"

  proxmox_ccm_secret_manifest = var.proxmox_ccm_enabled ? {
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = "proxmox-cloud-controller-manager"
      namespace = "kube-system"
    }
    stringData = {
      "config.yaml" = yamlencode({
        clusters = [
          {
            url          = coalesce(var.proxmox_ccm_api_url, local.proxmox_ccm_api_url)
            insecure     = var.proxmox_ccm_api_insecure
            token_id     = proxmox_user_token.ccm[0].id
            token_secret = split("=", proxmox_user_token.ccm[0].value)[1]
            region       = var.proxmox_ccm_region
          }
        ]
      })
    }
  } : null
}

# Proxmox CCM Helm Template
data "helm_template" "proxmox_ccm" {
  count = var.proxmox_ccm_enabled ? 1 : 0

  name      = "proxmox-cloud-controller-manager"
  namespace = "kube-system"

  repository   = var.proxmox_ccm_helm_repository
  chart        = var.proxmox_ccm_helm_chart
  version      = var.proxmox_ccm_helm_version
  kube_version = var.kubernetes_version

  values = [
    yamlencode({
      enabledControllers = ["cloud-node", "cloud-node-lifecycle"]
      config = {
        clusters = []
      }
      existingConfigSecret = "proxmox-cloud-controller-manager"
      useDaemonSet         = true
      priorityClassName    = "system-cluster-critical"
      nodeSelector         = { "node-role.kubernetes.io/control-plane" = "" }
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
    yamlencode(var.proxmox_ccm_helm_values)
  ]
}

locals {
  proxmox_ccm_manifest = var.proxmox_ccm_enabled ? {
    name     = "proxmox-ccm"
    contents = <<-EOF
      ${yamlencode(local.proxmox_ccm_secret_manifest)}
      ---
      ${data.helm_template.proxmox_ccm[0].manifest}
    EOF
  } : null
}
