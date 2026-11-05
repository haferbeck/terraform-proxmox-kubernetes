locals {
  talos_allow_scheduling_on_control_planes = coalesce(var.cluster_allow_scheduling_on_control_planes, local.worker_sum == 0)

  talos_kube_authentication_config_patches = length(var.kube_api_oidc_providers) > 0 ? [
    {
      apiVersion = "v1alpha1"
      kind       = "KubeAuthenticationConfig"
      configuration = {
        anonymous = {
          enabled = true
          conditions = [
            { path = "/livez" },
            { path = "/readyz" },
            { path = "/healthz" }
          ]
        }
        jwt = [
          for provider in var.kube_api_oidc_providers : {
            issuer = merge(
              {
                url       = provider.issuer_url
                audiences = provider.audiences
              },
              length(provider.audiences) > 1 ? {
                audienceMatchPolicy = "MatchAny"
              } : {},
              provider.discovery_url != null ? {
                discoveryURL = provider.discovery_url
              } : {},
              provider.certificate_authority != null ? {
                certificateAuthority = provider.certificate_authority
              } : {}
            )
            claimMappings = {
              username = {
                claim = provider.username_claim
                prefix = provider.username_prefix != null ? provider.username_prefix : (
                  provider.username_claim == "email" ? "" : "${provider.issuer_url}#"
                )
              }
              groups = {
                claim  = provider.groups_claim
                prefix = provider.groups_prefix
              }
            }
          }
        ]
      }
    }
  ] : []

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

  talos_kube_admission_control_config_patches = [
    for plugin in var.kube_api_admission_control : {
      apiVersion    = "v1alpha1"
      kind          = "KubeAdmissionControlConfig"
      name          = plugin.name
      configuration = plugin.configuration
    }
  ]

  talos_kube_inline_manifest_config_patches = [
    for manifest in local.talos_inline_manifests : {
      apiVersion = "v1alpha1"
      kind       = "KubeInlineManifestConfig"
      name       = manifest.name
      manifest   = manifest.contents
    }
  ]

  talos_kube_external_manifest_config_patches = [
    for index, url in local.talos_manifests : {
      apiVersion = "v1alpha1"
      kind       = "KubeExternalManifestConfig"
      name       = "external-manifest-${index + 1}"
      url        = url
    }
  ]

  # Proxmox CCM provider ID, set by kubelet (proxmox-port-only)
  control_plane_kubelet_provider_id_args = {
    for name, node in local.control_plane_nodes : name => var.proxmox_ccm_enabled ? {
      "provider-id" = "proxmox://${var.proxmox_ccm_region}/${node.vm_id}"
    } : {}
  }

  # Control Plane Config
  control_plane_talos_config_patches = {
    for name, node in local.control_plane_nodes : name => concat(
      [
        {

          cluster = {
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
            adminKubeconfig = {
              certLifetime = "87600h"
            }
            externalCloudProvider = {
              enabled = true
            }
          }
        },
        {
          apiVersion = "v1alpha1"
          kind       = "KubeNodeConfig"
          labels = merge(
            local.talos_allow_scheduling_on_control_planes ? {
              "node.kubernetes.io/exclude-from-external-load-balancers" = { "$patch" = "delete" }
            } : {},
            local.control_plane_nodepools_map[node.nodepool].labels
          )
          annotations = local.control_plane_nodepools_map[node.nodepool].annotations
          taints = merge(
            local.talos_allow_scheduling_on_control_planes ? {
              "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" }
            } : {},
            {
              for taint in local.control_plane_nodepools_map[node.nodepool].taints : taint.key => "${taint.value}:${taint.effect}"
            }
          )
        }
      ],
      local.talos_legacy_kubelet_config_enabled ? [{
        machine = {
          kubelet = {
            extraArgs = local.control_plane_kubelet_provider_id_args[name]
            extraConfig = merge(
              {
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
        }
      }] : [],
      local.talos_legacy_kubelet_config_enabled ? [] : [{
        apiVersion = "v1alpha1"
        kind       = "KubeletConfig"
        extraArgs  = local.control_plane_kubelet_provider_id_args[name]
        config = merge(
          {
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
      }],
      [
        merge(
          {
            apiVersion    = "v1alpha1"
            kind          = "KubeAPIServerConfig"
            certExtraSANs = local.talos_certificate_san
            extraArgs = merge(
              { "enable-aggregator-routing" = "true" },
              var.kube_api_extra_args
            )
          },
          var.kubernetes_apiserver_image != null ? {
            image = "${var.kubernetes_apiserver_image}:${var.kubernetes_version}"
          } : {}
        ),
        merge(
          {
            apiVersion = "v1alpha1"
            kind       = "KubeControllerManagerConfig"
            extraArgs = {
              "cloud-provider" = "external"
              "bind-address"   = "0.0.0.0"
            }
          },
          var.kubernetes_controller_manager_image != null ? {
            image = "${var.kubernetes_controller_manager_image}:${var.kubernetes_version}"
          } : {}
        ),
        merge(
          {
            apiVersion = "v1alpha1"
            kind       = "KubeSchedulerConfig"
            extraArgs = {
              "bind-address" = "0.0.0.0"
            }
          },
          var.kubernetes_scheduler_image != null ? {
            image = "${var.kubernetes_scheduler_image}:${var.kubernetes_version}"
          } : {}
        ),
        {
          apiVersion = "v1alpha1"
          kind       = "KubeCoreDNSConfig"
          enabled    = var.talos_coredns_enabled
        },
        local.talos_kube_proxy_config_patch,
        {
          apiVersion = "v1alpha1"
          kind       = "KubeTalosAPIAccessConfig"
          allowedRoles = [
            "os:reader",
            "os:etcd:backup"
          ]
          allowedKubernetesNamespaces = ["kube-system"]
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
        }
      ],
      local.talos_kube_admission_control_config_patches,
      local.talos_kube_authentication_config_patches,
      local.talos_kube_inline_manifest_config_patches,
      local.talos_kube_external_manifest_config_patches
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
    [for patch in local.talos_cloud_config_patches : yamlencode(patch)],
    [for patch in local.control_plane_talos_config_patches[each.key] : yamlencode(patch)],
    [for patch in var.control_plane_config_patches : yamlencode(patch)]
  )
}
