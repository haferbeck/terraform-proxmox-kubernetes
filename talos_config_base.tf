locals {
  # Talos and Kubernetes Certificates
  talos_certificate_san = sort(
    distinct(
      compact(
        concat(
          # Virtual IP
          [var.cluster_vip],
          # Control Plane Node IPs
          local.control_plane_ips,
          # Other Addresses
          [var.kube_api_hostname],
          ["127.0.0.1", "::1", "localhost"],
        )
      )
    )
  )

  # DNS Configuration
  talos_host_dns = {
    enabled              = true
    forwardKubeDNSToHost = false
    resolveMemberNames   = true
  }

  # Kubelet extra mounts
  talos_kubelet_extra_mounts = concat(
    var.longhorn_enabled ? [
      {
        source      = "/var/lib/longhorn"
        destination = "/var/lib/longhorn"
        type        = "bind"
        options     = ["bind", "rshared", "rw"]
      }
    ] : [],
    [
      for mount in var.talos_kubelet_extra_mounts : {
        source      = mount.source
        destination = coalesce(mount.destination, mount.source)
        type        = mount.type
        options     = mount.options
      }
    ]
  )

  # Talos Discovery
  talos_discovery_enabled = var.talos_discovery_kubernetes_enabled || var.talos_discovery_service_enabled

  talos_discovery = {
    enabled = local.talos_discovery_enabled
    registries = {
      kubernetes = { disabled = !var.talos_discovery_kubernetes_enabled }
      service    = { disabled = !var.talos_discovery_service_enabled }
    }
  }

  # System Volume Config
  talos_system_volume_encryption = {
    provider = "luks2"
    options  = ["no_read_workqueue", "no_write_workqueue"]
    keys = [{
      nodeID = {}
      slot   = 0
    }]
  }

  talos_system_volume_config_patches = concat(
    var.talos_state_partition_encryption_enabled ? [
      {
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "STATE"
        encryption = local.talos_system_volume_encryption
      }
    ] : [],
    var.talos_ephemeral_partition_encryption_enabled ? [
      {
        apiVersion = "v1alpha1"
        kind       = "VolumeConfig"
        name       = "EPHEMERAL"
        encryption = local.talos_system_volume_encryption
      }
    ] : []
  )

  # Nameservers (port falls back to network_gateway when empty)
  talos_nameservers = length(var.talos_nameservers) > 0 ? var.talos_nameservers : [var.network_gateway]

  talos_resolver_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "ResolverConfig"
    nameservers = [
      for ns in local.talos_nameservers : {
        address = ns
      }
    ]
  }

  # Static Hosts (/etc/hosts)
  talos_static_hosts = concat(
    var.kube_api_hostname != null ? [
      {
        ip        = var.cluster_vip
        hostnames = [var.kube_api_hostname]
      }
    ] : [],
    var.talos_static_hosts
  )

  talos_static_host_config_patches = [
    for ip in distinct([for entry in local.talos_static_hosts : entry.ip]) : {
      apiVersion = "v1alpha1"
      kind       = "StaticHostConfig"
      name       = ip
      hostnames = sort(distinct(flatten([
        for entry in local.talos_static_hosts :
        entry.ip == ip ? entry.hostnames : []
      ])))
    }
  ]

  # NTP
  talos_time_sync_config_patch = {
    apiVersion = "v1alpha1"
    kind       = "TimeSyncConfig"
    ntp = {
      servers = var.talos_ntp_servers
    }
  }

  # Additional trusted CA certificates
  talos_trusted_certs_config_patches = var.talos_certificates != null ? [
    for name, chain in var.talos_certificates : {
      apiVersion = "v1alpha1"
      kind       = "TrustedRootsConfig"
      name       = name
      certificates = join("\n", [
        for cert in(can(tolist(chain)) ? tolist(chain) : [tostring(chain)]) :
        trimspace(cert) if trimspace(cert) != ""
      ])
    }
  ] : []

  # DRBD kernel modules for Piraeus/LINSTOR (proxmox-port-only)
  talos_piraeus_kernel_modules = var.piraeus_enabled ? tolist([
    {
      name       = "drbd"
      parameters = ["usermode_helper=disabled"]
    },
    {
      name       = "dm-thin-pool"
      parameters = []
    },
  ]) : tolist([])

  # Talos Base Config
  talos_base_config_patches = concat(
    [{
      machine = {
        install = {
          image           = local.talos_installer_image_url
          extraKernelArgs = var.talos_extra_kernel_args
        }
        certSANs = local.talos_certificate_san
        kubelet = merge(
          {
            extraArgs = merge(
              {
                "cloud-provider"             = "external"
                "rotate-server-certificates" = true
              },
              var.kubernetes_kubelet_extra_args
            )
            extraConfig = {
              shutdownGracePeriod             = "90s"
              shutdownGracePeriodCriticalPods = "15s"
            }
            extraMounts = local.talos_kubelet_extra_mounts
            nodeIP = {
              validSubnets = [var.network_node_ipv4_cidr]
            }
          },
          var.kubernetes_kubelet_image != null ? {
            image = "${var.kubernetes_kubelet_image}:${var.kubernetes_version}"
          } : {}
        )
        kernel = {
          modules = concat(
            coalesce(var.talos_kernel_modules, []),
            local.talos_piraeus_kernel_modules
          )
        }
        sysctls = merge(
          {
            "net.core.somaxconn"                 = "65535"
            "net.core.netdev_max_backlog"        = "4096"
            "net.ipv6.conf.default.disable_ipv6" = "${var.talos_ipv6_enabled ? 0 : 1}"
            "net.ipv6.conf.all.disable_ipv6"     = "${var.talos_ipv6_enabled ? 0 : 1}"
          },
          var.talos_sysctls_extra_args
        )
        registries = var.talos_registries
        features = {
          hostDNS = local.talos_host_dns
        }
        logging = {
          destinations = var.talos_logging_destinations
        }
      }
      cluster = {
        network = {
          dnsDomain      = var.cluster_domain
          podSubnets     = [local.network_pod_ipv4_cidr]
          serviceSubnets = [local.network_service_ipv4_cidr]
          cni            = { name = "none" }
        }
        proxy = merge(
          {
            disabled = var.cilium_kube_proxy_replacement_enabled
          },
          var.kubernetes_proxy_image != null ? {
            image = "${var.kubernetes_proxy_image}:${var.kubernetes_version}"
          } : {}
        )
        discovery = local.talos_discovery
      }
    }],
    local.talos_system_volume_config_patches,
    [local.talos_resolver_config_patch],
    [local.talos_time_sync_config_patch],
    local.talos_static_host_config_patches,
    local.talos_trusted_certs_config_patches
  )
}
