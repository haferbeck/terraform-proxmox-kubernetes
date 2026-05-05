locals {
  talos_allow_scheduling_on_control_planes = coalesce(var.cluster_allow_scheduling_on_control_planes, local.worker_sum == 0)

  kube_api_oidc_configuration = var.oidc_enabled ? {
    "oidc-issuer-url"     = var.oidc_issuer_url
    "oidc-client-id"      = var.oidc_client_id
    "oidc-username-claim" = var.oidc_username_claim
    "oidc-groups-claim"   = var.oidc_groups_claim
    "oidc-groups-prefix"  = var.oidc_groups_prefix
  } : {}

  # Kubernetes Manifests for Talos
  talos_inline_manifests = concat(
    local.proxmox_ccm_manifest != null ? [local.proxmox_ccm_manifest] : [],
    local.talos_ccm_manifest != null ? [local.talos_ccm_manifest] : [],
    local.cilium_manifest != null ? [local.cilium_manifest] : [],
    local.talos_backup_manifest != null ? [local.talos_backup_manifest] : [],
    local.longhorn_manifest != null ? [local.longhorn_manifest] : [],
    local.metrics_server_manifest != null ? [local.metrics_server_manifest] : [],
    local.cert_manager_manifest != null ? [local.cert_manager_manifest] : [],
    var.talos_extra_inline_manifests != null ? var.talos_extra_inline_manifests : [],
    local.rbac_manifest != null ? [local.rbac_manifest] : [],
    local.oidc_manifest != null ? [local.oidc_manifest] : []
  )
  talos_manifests = concat(
    var.prometheus_operator_crds_enabled ? [
      "https://github.com/prometheus-operator/prometheus-operator/releases/download/${var.prometheus_operator_crds_version}/stripped-down-crds.yaml"
    ] : [],
    var.gateway_api_crds_enabled ? [
      "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crds_version}/${var.gateway_api_crds_release_channel}-install.yaml"
    ] : [],
    var.talos_extra_remote_manifests != null ? var.talos_extra_remote_manifests : []
  )

  # Control Plane Config
  control_plane_talos_config_patches = {
    for name, node in local.control_plane_nodes : name => concat(
      [
        {
          machine = {
            nodeLabels = merge(
              local.talos_allow_scheduling_on_control_planes ? { "node.kubernetes.io/exclude-from-external-load-balancers" = { "$patch" = "delete" } } : {},
              local.control_plane_nodepools_map[node.nodepool].labels,
            )
            nodeAnnotations = local.control_plane_nodepools_map[node.nodepool].annotations
            nodeTaints = {
              for taint in local.control_plane_nodepools_map[node.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
            }
            kubelet = {
              extraArgs = var.proxmox_ccm_enabled ? {
                "provider-id" = "proxmox://${var.proxmox_ccm_region}/${node.vm_id}"
              } : {}
              extraConfig = merge(
                {
                  registerWithTaints = local.control_plane_nodepools_map[node.nodepool].taints
                  systemReserved = {
                    cpu               = "250m"
                    memory            = "300Mi"
                    ephemeral-storage = "1Gi"
                  }
                  kubeReserved = {
                    cpu               = "250m"
                    memory            = "350Mi"
                    ephemeral-storage = "1Gi"
                  }
                },
                var.kubernetes_kubelet_extra_config
              )
            }
            features = {
              kubernetesTalosAPIAccess = {
                enabled = true
                allowedRoles = [
                  "os:reader",
                  "os:etcd:backup"
                ]
                allowedKubernetesNamespaces = ["kube-system"]
              }
            }
          }
          cluster = {
            allowSchedulingOnControlPlanes = local.talos_allow_scheduling_on_control_planes
            coreDNS = {
              disabled = !var.talos_coredns_enabled
            }
            apiServer = merge(
              {
                admissionControl = var.kube_api_admission_control
                certSANs         = local.talos_certificate_san
                extraArgs = merge(
                  { "enable-aggregator-routing" = true },
                  local.kube_api_oidc_configuration,
                  var.kube_api_extra_args
                )
              },
              var.kubernetes_apiserver_image != null ? {
                image = "${var.kubernetes_apiserver_image}:${var.kubernetes_version}"
              } : {}
            )
            controllerManager = merge(
              {
                extraArgs = {
                  "cloud-provider" = "external"
                  "bind-address"   = "0.0.0.0"
                }
              },
              var.kubernetes_controller_manager_image != null ? {
                image = "${var.kubernetes_controller_manager_image}:${var.kubernetes_version}"
              } : {}
            )
            etcd = merge(
              {
                advertisedSubnets = [var.network_node_ipv4_cidr]
                extraArgs = {
                  "listen-metrics-urls" = "http://0.0.0.0:2381"
                }
              },
              var.kubernetes_etcd_image != null ? {
                image = var.kubernetes_etcd_image
              } : {}
            )
            scheduler = merge(
              {
                extraArgs = {
                  "bind-address" = "0.0.0.0"
                }
              },
              var.kubernetes_scheduler_image != null ? {
                image = "${var.kubernetes_scheduler_image}:${var.kubernetes_version}"
              } : {}
            )
            adminKubeconfig = {
              certLifetime = "87600h"
            }
            inlineManifests = local.talos_inline_manifests
            externalCloudProvider = {
              enabled   = true
              manifests = local.talos_manifests
            }
          }
        },
        {
          apiVersion = "v1alpha1"
          kind       = "HostnameConfig"
          hostname   = name
          auto       = "off"
        },
        {
          apiVersion = "v1alpha1"
          kind       = "Layer2VIPConfig"
          link       = "eth0"
          name       = var.cluster_vip
        },
      ]
    )
  }
}

data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.kube_api_url
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  docs               = false
  examples           = false

  config_patches = concat(
    [for patch in local.talos_base_config_patches : yamlencode(patch)],
    [for patch in local.control_plane_talos_config_patches[each.key] : yamlencode(patch)],
    [for patch in var.control_plane_config_patches : yamlencode(patch)]
  )
}
