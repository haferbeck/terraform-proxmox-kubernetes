# Cluster Configuration
variable "cluster_name" {
  type        = string
  description = "Specifies the name of the cluster. This name is used to identify the cluster within the infrastructure and should be unique across all deployments."

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$", var.cluster_name))
    error_message = "The cluster name must start and end with a lowercase letter or number, can contain hyphens, and must be no longer than 32 characters."
  }
}

variable "cluster_domain" {
  type        = string
  default     = "cluster.local"
  description = "Specifies the domain name used by the cluster. This domain name is integral for internal networking and service discovery within the cluster. The default is 'cluster.local', which is commonly used for local Kubernetes clusters."

  validation {
    condition     = can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)$", var.cluster_domain))
    error_message = "The cluster domain must be a valid domain: each segment must start and end with a letter or number, can contain hyphens, and each segment must be no longer than 63 characters."
  }
}

variable "cluster_vip" {
  type        = string
  description = "The virtual IP address used for the Kubernetes API server endpoint. This IP is managed via Talos VIP and should be an unused IP within the node network."

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.cluster_vip))
    error_message = "The cluster VIP must be a valid IPv4 address."
  }
}

variable "cluster_kubeconfig_path" {
  type        = string
  default     = null
  description = "If not null, the kubeconfig will be written to a file speficified."
}

variable "cluster_talosconfig_path" {
  type        = string
  default     = null
  description = "If not null, the talosconfig will be written to a file speficified."
}

variable "cluster_healthcheck_enabled" {
  type        = bool
  default     = true
  description = "Determines whether are executed during cluster deployment and upgrade."
}

variable "cluster_allow_scheduling_on_control_planes" {
  type        = bool
  default     = null
  description = "Allow scheduling on control plane nodes. If this is false, scheduling on control plane nodes is explicitly disabled. Defaults to true if there are no workers present."
}


# Client Tools
variable "client_prerequisites_check_enabled" {
  type        = bool
  default     = true
  description = "Controls whether a preflight check verifies that required client tools are installed before provisioning."
}

variable "talosctl_version_check_enabled" {
  type        = bool
  default     = true
  description = "Controls whether a preflight check verifies the local talosctl client version before provisioning."
}

variable "talosctl_retries" {
  type        = number
  default     = 100
  description = "Specifies how many times talosctl operations should retry before failing. This setting helps improve resilience against transient network issues or temporary API unavailability."

  validation {
    condition     = var.talosctl_retries >= 0
    error_message = "The talosctl retries value must be at least 0."
  }
}


# Proxmox Configuration
variable "proxmox_node" {
  type        = string
  description = "The name of the Proxmox node on which to create VMs."
}

variable "proxmox_disk_storage" {
  type        = string
  description = "The Proxmox storage pool used for VM disks (e.g. 'local-lvm')."
}

variable "proxmox_image_storage" {
  type        = string
  description = "The Proxmox storage pool used for storing downloaded images (e.g. 'local')."
}

variable "proxmox_network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "The Proxmox network bridge to attach VM network interfaces to."
}

variable "proxmox_network_vlan_id" {
  type        = number
  default     = null
  description = "The VLAN ID to assign to VM network interfaces. Set to null for untagged traffic."
}

variable "proxmox_keyboard_layout" {
  type        = string
  default     = "en-us"
  description = "The keyboard layout for the VM console."
}

variable "proxmox_vm_id_base" {
  type        = number
  default     = null
  description = "Base VM ID for cluster nodes. Node VM IDs are calculated as vm_id_base + ip_offset + node_index. If not set, derived from the third octet of network_node_ipv4_cidr (e.g. 192.168.10.0/24 → 100). Proxmox requires VM IDs >= 100."

  validation {
    condition     = var.proxmox_vm_id_base == null || var.proxmox_vm_id_base >= 100
    error_message = "The proxmox_vm_id_base must be at least 100 (Proxmox minimum VM ID). Use a value derived from the network CIDR's third octet (>= 10) or set explicitly."
  }
}


# Network Configuration
variable "network_ipv4_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Specifies the main IPv4 CIDR block for the network. This CIDR block is used to allocate IP addresses within the network."
}

variable "network_node_ipv4_cidr" {
  type        = string
  default     = null # 10.0.64.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Node IPv4 CIDR used for allocating IP addresses to both Control Plane and Worker nodes within the cluster. If not explicitly provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_service_ipv4_cidr" {
  type        = string
  default     = null # 10.0.96.0/19 when network_ipv4_cidr is 10.0.0.0/16
  description = "Specifies the Service IPv4 CIDR block used for allocating ClusterIPs to services within the cluster. If not provided, a default subnet is dynamically calculated from the specified network_ipv4_cidr."
}

variable "network_pod_ipv4_cidr" {
  type        = string
  default     = null # 10.0.128.0/17 when network_ipv4_cidr is 10.0.0.0/16
  description = "Defines the Pod IPv4 CIDR block allocated for use by pods within the cluster. This CIDR block is essential for internal pod communications. If a specific subnet is not provided, a default is dynamically calculated from the network_ipv4_cidr."
}

variable "network_native_routing_ipv4_cidr" {
  type        = string
  default     = null
  description = "Specifies the IPv4 CIDR block that the CNI assumes will be routed natively by the underlying network infrastructure without the need for SNAT."
}

variable "network_gateway" {
  type        = string
  description = "The default gateway IP address for the node network."

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.network_gateway))
    error_message = "The network gateway must be a valid IPv4 address."
  }
}


# Control Plane
variable "kube_api_admission_control" {
  type        = list(any)
  default     = []
  description = "List of admission control settings for the Kube API. If set, this overrides the default admission control."
}

variable "control_plane_nodepools" {
  type = list(object({
    name         = string
    cpu          = number
    memory       = number
    disk_size    = number
    ip_offset    = number
    proxmox_node = optional(string)
    labels       = optional(map(string), {})
    annotations  = optional(map(string), {})
    taints       = optional(list(string), [])
    count        = optional(number, 1)
  }))
  description = "Configures the number and attributes of Control Plane nodes. Set proxmox_node per nodepool to place VMs on a specific Proxmox host (multi-host clusters); falls back to var.proxmox_node when null."

  validation {
    condition     = length(var.control_plane_nodepools) == length(distinct([for np in var.control_plane_nodepools : np.name]))
    error_message = "Control Plane nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) <= 9
    error_message = "The total count of all nodes in Control Plane nodepools must not exceed 9."
  }

  validation {
    condition     = sum([for np in var.control_plane_nodepools : np.count]) % 2 == 1
    error_message = "The sum of all Control Plane nodes must be odd to ensure high availability."
  }

  validation {
    condition = alltrue([
      for np in var.control_plane_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Control Plane nodepool name must not exceed 56 characters."
  }
}

variable "control_plane_config_patches" {
  type        = any
  default     = []
  description = "List of configuration patches applied to the Control Plane nodes."
}


# Worker
variable "worker_nodepools" {
  type = list(object({
    name              = string
    cpu               = number
    memory            = number
    disk_size         = number
    ip_offset         = number
    proxmox_node      = optional(string)
    storage_disk_size = optional(number, 0)
    labels            = optional(map(string), {})
    annotations       = optional(map(string), {})
    taints            = optional(list(string), [])
    count             = optional(number, 1)
  }))
  default     = []
  description = "Defines configuration settings for Worker node pools within the cluster. Set proxmox_node per nodepool to place VMs on a specific Proxmox host (multi-host clusters); falls back to var.proxmox_node when null."

  validation {
    condition     = length(var.worker_nodepools) == length(distinct([for np in var.worker_nodepools : np.name]))
    error_message = "Worker nodepool names must be unique to avoid configuration conflicts."
  }

  validation {
    condition = sum(concat(
      [for worker_nodepool in var.worker_nodepools : coalesce(worker_nodepool.count, 1)],
      [for control_nodepool in var.control_plane_nodepools : coalesce(control_nodepool.count, 1)]
    )) <= 100
    error_message = "The total count of nodes in both worker and Control Plane nodepools must not exceed 100 to ensure manageable cluster size."
  }

  validation {
    condition = alltrue([
      for np in var.worker_nodepools : length(var.cluster_name) + length(np.name) <= 56
    ])
    error_message = "The combined length of the cluster name and any Worker nodepool name must not exceed 56 characters."
  }
}

variable "worker_config_patches" {
  type        = any
  default     = []
  description = "List of configuration patches applied to the Worker nodes."
}


# Talos
variable "talos_version" {
  type        = string
  default     = "v1.12.7" # https://github.com/siderolabs/talos
  description = "Specifies the version of Talos to be used in generated machine configurations."
}

variable "talos_schematic_id" {
  type        = string
  default     = null
  description = "Specifies the Talos schematic ID used for selecting the specific Image and Installer versions in deployments. This has precedence over `talos_image_extensions`"
}

variable "talos_image_extensions" {
  type        = list(string)
  default     = []
  description = "Specifies Talos image extensions for additional functionality on top of the default Talos Linux capabilities. See: https://github.com/siderolabs/extensions"
}

variable "talos_iso_checksum" {
  type        = string
  default     = null
  description = "Optional SHA256 checksum (64 lowercase hex chars) for the downloaded Talos ISO. When set, the bpg/proxmox provider verifies the file matches after download. Leave null to skip verification (default; matches existing clusters)."

  validation {
    condition     = var.talos_iso_checksum == null || can(regex("^[a-f0-9]{64}$", var.talos_iso_checksum))
    error_message = "The talos_iso_checksum must be 64 lowercase hexadecimal characters (SHA256)."
  }
}

variable "talos_upgrade_debug" {
  type        = bool
  default     = false
  description = "Enable debug operation from kernel logs during Talos upgrades. When true, --wait is set to true by talosctl."
}

variable "talos_upgrade_force" {
  type        = bool
  default     = false
  description = "Force the Talos upgrade by skipping etcd health and member checks."
}

variable "talos_upgrade_insecure" {
  type        = bool
  default     = false
  description = "Upgrade using the insecure (no auth) maintenance service."
}

variable "talos_upgrade_reboot_mode" {
  type        = string
  default     = null
  description = "Select the reboot mode during upgrade. Mode \"powercycle\" bypasses kexec. Valid values: \"default\" or \"powercycle\"."

  validation {
    condition     = var.talos_upgrade_reboot_mode == null || contains(["default", "powercycle"], var.talos_upgrade_reboot_mode)
    error_message = "The talos_upgrade_reboot_mode must be \"default\" or \"powercycle\"."
  }
}

variable "talos_reboot_debug" {
  type        = bool
  default     = false
  description = "Enable debug operation from kernel logs during Talos reboots. When true, --wait is set to true by talosctl."
}

variable "talos_reboot_mode" {
  type        = string
  default     = null
  description = "Select the reboot mode. Mode \"powercycle\" bypasses kexec, and mode \"force\" skips graceful teardown. Valid values: \"default\", \"powercycle\", or \"force\"."

  validation {
    condition     = var.talos_reboot_mode == null || contains(["default", "powercycle", "force"], var.talos_reboot_mode)
    error_message = "The talos_reboot_mode must be \"default\", \"powercycle\", or \"force\"."
  }
}

variable "talos_upgrade_stage" {
  type        = bool
  default     = false
  description = "Stage the Talos upgrade to perform it after a reboot."
}

variable "talos_discovery_kubernetes_enabled" {
  type        = bool
  default     = false
  description = "Enable or disable Kubernetes-based Talos discovery service. Deprecated as of Kubernetes v1.32, where the AuthorizeNodeWithSelectors feature gate is enabled by default."
}

variable "talos_discovery_service_enabled" {
  type        = bool
  default     = true
  description = "Enable or disable Sidero Labs public Talos discovery service."
}

variable "talos_kubelet_extra_mounts" {
  type = list(object({
    source      = string
    destination = optional(string)
    type        = optional(string, "bind")
    options     = optional(list(string), ["bind", "rshared", "rw"])
  }))
  default     = []
  description = "Defines extra kubelet mounts for Talos with configurable 'source', 'destination' (defaults to 'source' if unset), 'type' (defaults to 'bind'), and 'options' (defaults to ['bind', 'rshared', 'rw'])"

  validation {
    condition = (
      length(var.talos_kubelet_extra_mounts) ==
      length(toset([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)])) &&
      (!var.longhorn_enabled || !contains([for mount in var.talos_kubelet_extra_mounts : coalesce(mount.destination, mount.source)], "/var/lib/longhorn"))
    )
    error_message = "Each destination in talos_kubelet_extra_mounts must be unique and cannot include the Longhorn default data path if Longhorn is enabled."
  }
}

variable "talos_extra_kernel_args" {
  type        = list(string)
  default     = []
  description = "Defines a list of extra kernel commandline parameters."
}

variable "talos_kernel_modules" {
  type = list(object({
    name       = string
    parameters = optional(list(string))
  }))
  default     = null
  description = "Defines a list of kernel modules to be loaded during system boot, along with optional parameters for each module. This allows for customized kernel behavior in the Talos environment."
}

variable "talos_machine_configuration_apply_mode" {
  type        = string
  default     = "auto"
  description = "Determines how changes to Talos machine configurations are applied. 'auto' (default) applies changes immediately and reboots if necessary. 'reboot' applies changes and then reboots the node. 'no_reboot' applies changes immediately without a reboot, failing if a reboot is required. 'staged' stages changes to apply on the next reboot. 'staged_if_needing_reboot' performs a dry-run and uses 'staged' mode if reboot is needed, 'auto' otherwise."

  validation {
    condition     = contains(["auto", "reboot", "no_reboot", "staged", "staged_if_needing_reboot"], var.talos_machine_configuration_apply_mode)
    error_message = "The talos_machine_configuration_apply_mode must be 'auto', 'reboot', 'no_reboot', 'staged', or 'staged_if_needing_reboot'."
  }
}

variable "talos_staged_configuration_automatic_reboot_enabled" {
  type        = bool
  default     = true
  description = "Determines whether nodes are rebooted automatically after Talos machine configuration changes are applied in 'staged' mode, or when 'staged_if_needing_reboot' resolves to 'staged' mode."
}

variable "talos_sysctls_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies a map of sysctl key-value pairs for configuring additional kernel parameters. These settings allow for detailed customization of the operating system's behavior at runtime."
}

variable "talos_state_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the state (`/system/state`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ephemeral_partition_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables or disables encryption for the ephemeral (`/var`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster."
}

variable "talos_ipv6_enabled" {
  type        = bool
  default     = false
  description = "Determines whether IPv6 is enabled for the Talos operating system. Enabling this setting configures the Talos OS to support IPv6 networking capabilities."
}

variable "talos_coredns_enabled" {
  type        = bool
  default     = true
  description = "Determines whether CoreDNS is enabled in the Talos cluster. When enabled, CoreDNS serves as the primary DNS service provider in Kubernetes."
}

variable "talos_nameservers" {
  type        = list(string)
  default     = []
  description = "Specifies a list of nameserver addresses used for DNS resolution by nodes and CoreDNS within the cluster. Falls back to the network gateway if empty."
}

variable "talos_certificates" {
  type        = any
  default     = {}
  description = <<-EOF
    Additional trusted CA certificates to be added to the Talos configuration.
    Map keys are used as names for the TrustedRootsConfig documents.
    Values can be either a single PEM-encoded string containing one or more certificates (inline or from file), or a list of PEM-encoded strings.

    Example:
    ```hcl
    talos_certificates = {
      # Inline string (single certificate)
      "inline-ca" = "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"

      # Single certificate from file
      "file-ca" = [file("ca.crt")]

      # Multiple certificates from files (chain)
      "corporate-chain" = [file("root.crt"), file("intermediate.crt")]

      # Multiple inline certificates in a single string (backward compatible)
      "legacy-ca" = <<-EOT
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
      EOT
    }
    ```
  EOF

  validation {
    condition     = var.talos_certificates == null ? true : can(keys(var.talos_certificates))
    error_message = "The 'talos_certificates' variable must be a map."
  }

  validation {
    condition = var.talos_certificates == null ? true : alltrue([
      for name, chain in var.talos_certificates :
      can(regex("^[a-z0-9-]+$", name))
    ])
    error_message = "Trusted root certificates config names must be lowercase alphanumeric and may contain hyphens."
  }

  validation {
    condition = var.talos_certificates == null ? true : alltrue([
      for chain in values(var.talos_certificates) :
      length(can(tolist(chain)) ? tolist(chain) : [tostring(chain)]) > 0
    ])
    error_message = "Each certificate group in 'talos_certificates' must contain at least one certificate."
  }

  validation {
    condition = var.talos_certificates == null ? true : alltrue([
      for chain in values(var.talos_certificates) :
      alltrue([
        for cert in(can(tolist(chain)) ? tolist(chain) : [tostring(chain)]) :
        can(regex("(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", cert))
      ])
    ])
    error_message = "All certificates must be valid PEM-encoded strings containing BEGIN/END CERTIFICATE markers."
  }
}

variable "talos_static_hosts" {
  type = list(object({
    ip        = string
    hostnames = list(string)
  }))
  default     = []
  description = "Specifies static host mappings to be added on each node. Each entry must include an IP address and a list of hostnames associated with that IP."
}

variable "talos_ntp_servers" {
  type = list(string)
  default = [
    "0.pool.ntp.org",
    "1.pool.ntp.org",
    "2.pool.ntp.org"
  ]
  description = "Specifies a list of time server addresses used for network time synchronization across the cluster. These servers ensure that all cluster nodes maintain accurate and synchronized time."
}

variable "talos_registries" {
  type        = any
  default     = null
  description = <<-EOF
    Specifies a list of registry mirrors to be used for container image retrieval. This configuration helps in specifying alternate sources or local mirrors for image registries, enhancing reliability and speed of image downloads.
    Example configuration:
    ```
    registries = {
      mirrors = {
        "docker.io" = {
          endpoints = [
            "http://localhost:5000",
            "https://docker.io"
          ]
        }
      }
    }
    ```
  EOF
}

variable "talos_logging_destinations" {
  description = "List of objects defining remote destinations for Talos service logs."
  type = list(object({
    endpoint  = string
    format    = optional(string, "json_lines")
    extraTags = optional(map(string), {})
  }))
  default = []
}

variable "talos_extra_inline_manifests" {
  type = list(object({
    name     = string
    contents = string
  }))
  description = "List of additional inline Kubernetes manifests to append to the Talos machine configuration during bootstrap."
  default     = null
}

variable "talos_extra_remote_manifests" {
  type        = list(string)
  description = "List of remote URLs pointing to Kubernetes manifests to be appended to the Talos machine configuration during bootstrap."
  default     = null
}


# Talos Backup
variable "talos_backup_version" {
  type        = string
  default     = "v0.1.0-beta.3-3-g38dad7c"
  description = "Specifies the version of Talos Backup to be used in generated machine configurations."
}

variable "talos_backup_s3_enabled" {
  type        = bool
  default     = true
  description = "Enable Talos etcd S3 backup cronjob."
}

variable "talos_backup_s3_region" {
  type        = string
  default     = null
  description = "S3 region for Talos Backup."
}

variable "talos_backup_s3_endpoint" {
  type        = string
  default     = null
  description = "S3 endpoint for Talos Backup."
}

variable "talos_backup_s3_bucket" {
  type        = string
  default     = null
  description = "S3 bucket name for Talos Backup."
}

variable "talos_backup_s3_prefix" {
  type        = string
  default     = null
  description = "S3 prefix for Talos Backup."
}

variable "talos_backup_s3_path_style" {
  type        = bool
  default     = false
  description = "Use path style S3 for Talos Backup. Set this to false if you have another s3 like endpoint such as minio."
}

variable "talos_backup_s3_access_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "S3 Access Key for Talos Backup."
}

variable "talos_backup_s3_secret_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "S3 Secret Access Key for Talos Backup."
}

variable "talos_backup_age_x25519_public_key" {
  type        = string
  default     = null
  description = "AGE X25519 Public Key for client side Talos Backup encryption."
}

variable "talos_backup_enable_compression" {
  type        = bool
  default     = false
  description = "Enable ETCD snapshot compression with zstd algorithm."
}

variable "talos_backup_schedule" {
  type        = string
  default     = "0 * * * *"
  description = "The schedule for Talos Backup"
}


# Kubernetes
variable "kubernetes_version" {
  type        = string
  default     = "v1.33.10" # https://github.com/kubernetes/kubernetes
  description = "Specifies the Kubernetes version to deploy."
}


variable "kubernetes_kubelet_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to pass to the kubelet service. These arguments can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}

variable "kubernetes_kubelet_extra_config" {
  type        = any
  default     = {}
  description = "Specifies additional configuration settings for the kubelet service. These settings can customize or override default kubelet configurations, allowing for tailored cluster behavior."
}

variable "kubernetes_apiserver_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-apiserver (e.g., 'my-registry.io/kube-apiserver'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_apiserver_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_apiserver_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-apiserver'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_controller_manager_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-controller-manager (e.g., 'my-registry.io/kube-controller-manager'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_controller_manager_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_controller_manager_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-controller-manager'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_scheduler_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-scheduler (e.g., 'my-registry.io/kube-scheduler'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_scheduler_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_scheduler_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-scheduler'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_proxy_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for kube-proxy (e.g., 'my-registry.io/kube-proxy'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_proxy_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_proxy_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kube-proxy'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_kubelet_image" {
  type        = string
  default     = null
  description = "Specifies a custom image repository for the kubelet (e.g., 'my-registry.io/kubelet'). The version tag is appended automatically from kubernetes_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults."

  validation {
    condition     = var.kubernetes_kubelet_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+$", var.kubernetes_kubelet_image))
    error_message = "The image must be a valid container image reference without a tag (e.g., 'my-registry.io/kubelet'). The version tag is appended automatically from kubernetes_version."
  }
}

variable "kubernetes_etcd_image" {
  type        = string
  default     = null
  description = "Specifies a custom container image for etcd including the tag and/or digest (e.g., 'my-registry.io/etcd:v3.6.8', 'my-registry.io/etcd:v3.6.8@sha256:...', or 'my-registry.io/etcd@sha256:...'). This change will only take effect after a manual reboot of your cluster nodes!"

  validation {
    condition     = var.kubernetes_etcd_image == null || can(regex("^[a-z0-9]([a-z0-9._-]*[a-z0-9])?(:[0-9]+)?(/[a-z0-9]([a-z0-9._-]*[a-z0-9])?)+((:[a-zA-Z0-9][a-zA-Z0-9._-]*)(@[a-z0-9]+:[a-f0-9]+)?|@[a-z0-9]+:[a-f0-9]+)$", var.kubernetes_etcd_image))
    error_message = "The image must be a valid container image reference with a tag and/or digest (e.g., 'my-registry.io/etcd:v3.6.8' or 'my-registry.io/etcd:v3.6.8@sha256:...')."
  }
}


# Kubernetes API
variable "kube_api_hostname" {
  type        = string
  default     = null
  description = "Specifies the hostname for external access to the Kubernetes API server. This must be a valid domain name, set to the API's public IP address."
}

variable "kube_api_extra_args" {
  type        = map(string)
  default     = {}
  description = "Specifies additional command-line arguments to be passed to the kube-apiserver. This allows for customization of the API server's behavior according to specific cluster requirements."
}


# Talos CCM
variable "talos_ccm_enabled" {
  type        = bool
  default     = true
  description = "Enables the Talos Cloud Controller Manager (CCM) deployment. Handles kubelet CSR approval. When Proxmox CCM is also active, only CSR approval runs."
}

variable "talos_ccm_helm_repository" {
  type        = string
  default     = "oci://ghcr.io/siderolabs/charts"
  description = "Helm repository for the Talos CCM chart."
}

variable "talos_ccm_helm_chart" {
  type        = string
  default     = "talos-cloud-controller-manager"
  description = "Helm chart name for the Talos CCM."
}

variable "talos_ccm_helm_version" {
  type        = string
  default     = "0.5.4"
  description = "Helm chart version for the Talos CCM."
}

variable "talos_ccm_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Talos CCM chart."
}


# Proxmox CCM
variable "proxmox_ccm_enabled" {
  type        = bool
  default     = true
  description = "Enables the Proxmox Cloud Controller Manager. Manages node lifecycle (automatic cleanup of deleted nodes) and sets provider-specific labels. A dedicated Proxmox API user and token are automatically provisioned."
}

variable "proxmox_ccm_api_url" {
  type        = string
  default     = null
  description = "Proxmox API URL for the CCM. If not set, derived from proxmox_node (https://<proxmox_node>:8006/api2/json)."
}

variable "proxmox_ccm_api_insecure" {
  type        = bool
  default     = true
  description = "Allow insecure TLS connections to the Proxmox API."
}

variable "proxmox_ccm_region" {
  type        = string
  default     = "default"
  description = "Region identifier for this Proxmox cluster. Used as topology.kubernetes.io/region label."
}

variable "proxmox_ccm_helm_repository" {
  type        = string
  default     = "oci://ghcr.io/sergelogvinov/charts"
  description = "Helm repository for the Proxmox CCM chart."
}

variable "proxmox_ccm_helm_chart" {
  type        = string
  default     = "proxmox-cloud-controller-manager"
  description = "Helm chart name for the Proxmox CCM."
}

variable "proxmox_ccm_helm_version" {
  type        = string
  default     = "0.2.27"
  description = "Helm chart version for the Proxmox CCM."
}

variable "proxmox_ccm_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Proxmox CCM chart."
}


# Kubernetes OIDC Configuration
variable "oidc_enabled" {
  description = "Enable OIDC authentication for Kubernetes API server"
  type        = bool
  default     = false
}

variable "oidc_issuer_url" {
  description = "URL of the OIDC provider (e.g., https://your-oidc-provider.com). Required when oidc_enabled is true"
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_enabled == false || (var.oidc_enabled == true && var.oidc_issuer_url != "")
    error_message = "oidc_issuer_url is required when oidc_enabled is true."
  }
}

variable "oidc_client_id" {
  description = "OIDC client ID that all tokens must be issued for. Required when oidc_enabled is true"
  type        = string
  default     = ""

  validation {
    condition     = var.oidc_enabled == false || (var.oidc_enabled == true && var.oidc_client_id != "")
    error_message = "oidc_client_id is required when oidc_enabled is true."
  }
}

variable "oidc_username_claim" {
  description = "JWT claim to use as the username"
  type        = string
  default     = "sub"
}

variable "oidc_groups_claim" {
  description = "JWT claim to use as the user's groups"
  type        = string
  default     = "groups"
}

variable "oidc_groups_prefix" {
  description = "Prefix prepended to group claims to prevent clashes with existing names"
  type        = string
  default     = "oidc:"
}

variable "oidc_group_mappings" {
  description = "List of OIDC groups mapped to Kubernetes roles and cluster roles"
  type = list(object({
    group         = string
    cluster_roles = optional(list(string), [])
    roles = optional(list(object({
      name      = string
      namespace = string
    })), [])
  }))
  default = []

  validation {
    condition = length(var.oidc_group_mappings) == length(distinct([
      for mapping in var.oidc_group_mappings : mapping.group
    ]))
    error_message = "OIDC group names must be unique. Duplicate group names found."
  }
}

# Kubernetes RBAC
variable "rbac_roles" {
  description = "List of custom Kubernetes roles to create"
  type = list(object({
    name      = string
    namespace = string
    rules = list(object({
      api_groups = list(string)
      resources  = list(string)
      verbs      = list(string)
    }))
  }))
  default = []

  validation {
    condition = length(var.rbac_roles) == length(distinct([
      for role in var.rbac_roles : role.name
    ]))
    error_message = "RBAC role names must be unique. Duplicate role names found."
  }
}

variable "rbac_cluster_roles" {
  description = "List of custom Kubernetes cluster roles to create"
  type = list(object({
    name = string
    rules = list(object({
      api_groups = list(string)
      resources  = list(string)
      verbs      = list(string)
    }))
  }))
  default = []

  validation {
    condition = length(var.rbac_cluster_roles) == length(distinct([
      for role in var.rbac_cluster_roles : role.name
    ]))
    error_message = "RBAC cluster role names must be unique. Duplicate cluster role names found."
  }
}


# Longhorn
variable "longhorn_helm_repository" {
  type        = string
  default     = "https://charts.longhorn.io"
  description = "URL of the Helm repository where the Longhorn chart is located."
}

variable "longhorn_helm_chart" {
  type        = string
  default     = "longhorn"
  description = "Name of the Helm chart used for deploying Longhorn."
}

variable "longhorn_helm_version" {
  type        = string
  default     = "1.11.1"
  description = "Version of the Longhorn Helm chart to deploy."
}

variable "longhorn_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Longhorn chart deployment. These values will merge with and will override the default values provided by the Longhorn Helm chart."
}

variable "longhorn_enabled" {
  type        = bool
  default     = false
  description = "Enable or disable Longhorn integration"

  validation {
    condition = !var.longhorn_enabled || alltrue([
      for np in var.worker_nodepools : np.storage_disk_size > 0
    ])
    error_message = "Longhorn is enabled but one or more worker nodepools have no storage_disk_size configured. Set storage_disk_size > 0 on all worker nodepools to provide dedicated Longhorn storage."
  }
}

variable "longhorn_default_storage_class" {
  type        = bool
  default     = false
  description = "Set Longhorn as the default storage class."
}


# Piraeus / LINSTOR
variable "piraeus_enabled" {
  type        = bool
  default     = false
  description = "Prepares the cluster for Piraeus/LINSTOR storage: adds DRBD extension to the Talos image, loads DRBD kernel modules, and provisions a dedicated storage disk on worker nodes. The actual Piraeus Operator must be installed separately (e.g. via ArgoCD)."

  validation {
    condition = !var.piraeus_enabled || alltrue([
      for np in var.worker_nodepools : np.storage_disk_size > 0
    ])
    error_message = "Piraeus is enabled but one or more worker nodepools have no storage_disk_size configured. Set storage_disk_size > 0 on all worker nodepools to provide dedicated LINSTOR storage."
  }

  validation {
    condition     = !(var.piraeus_enabled && var.longhorn_enabled)
    error_message = "Piraeus and Longhorn cannot both be enabled — they share the same storage disk (scsi1)."
  }
}


# Cilium
variable "cilium_enabled" {
  type        = bool
  default     = true
  description = "Enables the Cilium CNI deployment."
}

variable "cilium_helm_repository" {
  type        = string
  default     = "https://helm.cilium.io"
  description = "URL of the Helm repository where the Cilium chart is located."
}

variable "cilium_helm_chart" {
  type        = string
  default     = "cilium"
  description = "Name of the Helm chart used for deploying Cilium."
}

variable "cilium_helm_version" {
  type        = string
  default     = "1.18.7"
  description = "Version of the Cilium Helm chart to deploy."
}

variable "cilium_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Cilium chart deployment. These values will merge with and will override the default values provided by the Cilium Helm chart."
}

variable "cilium_policy_cidr_match_mode" {
  type        = string
  default     = ""
  description = "Allows setting policy-cidr-match-mode to \"nodes\", which means that cluster nodes can be selected by CIDR network policies. Normally nodes are only accessible via remote-node entity selectors. This is required if you want to target the kube-api server with a k8s NetworkPolicy."

  validation {
    condition     = var.cilium_policy_cidr_match_mode == "" || var.cilium_policy_cidr_match_mode == "nodes"
    error_message = "cilium_policy_cidr_match_mode must be either \"nodes\" or an empty string."
  }
}

variable "cilium_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables transparent network encryption using Cilium within the Kubernetes cluster. When enabled, this feature provides added security for network traffic."
}

variable "cilium_encryption_type" {
  type        = string
  default     = "wireguard"
  description = "Type of encryption to use for Cilium network encryption. Options: 'wireguard' or 'ipsec'."

  validation {
    condition     = contains(["wireguard", "ipsec"], var.cilium_encryption_type)
    error_message = "Encryption type must be either 'wireguard' or 'ipsec'."
  }
}

variable "cilium_ipsec_algorithm" {
  type        = string
  default     = "rfc4106(gcm(aes))"
  description = "Cilium IPSec key algorithm."
}

variable "cilium_ipsec_key_size" {
  type        = number
  default     = 256
  description = "AES key size in bits for IPSec encryption (128, 192, or 256). Only used when cilium_encryption_type is 'ipsec'."

  validation {
    condition     = contains([128, 192, 256], var.cilium_ipsec_key_size)
    error_message = "IPSec key size must be 128, 192 or 256 bits."
  }
}

variable "cilium_ipsec_key_id" {
  type        = number
  default     = 1
  description = "IPSec key ID (1-15, increment manually for rotation). Only used when cilium_encryption_type is 'ipsec'."

  validation {
    condition     = var.cilium_ipsec_key_id >= 1 && var.cilium_ipsec_key_id <= 15 && floor(var.cilium_ipsec_key_id) == var.cilium_ipsec_key_id
    error_message = "The IPSec key_id must be between 1 and 15."
  }
}

variable "cilium_kube_proxy_replacement_enabled" {
  type        = bool
  default     = true
  description = "Enables Cilium's eBPF kube-proxy replacement."
}

variable "cilium_socket_lb_host_namespace_only_enabled" {
  type        = bool
  default     = false
  description = "Limit Cilium's socket-level load-balancing to the host namespace only."
}

variable "cilium_load_balancer_acceleration" {
  type        = string
  default     = "disabled"
  description = "Cilium XDP Acceleration mode. Note: 'native' requires NIC driver support (not available with virtio). Use PCI passthrough for native XDP."

  validation {
    condition     = contains(["disabled", "native", "best-effort"], var.cilium_load_balancer_acceleration)
    error_message = "cilium_load_balancer_acceleration must be one of: disabled, native or best-effort"
  }
}

variable "cilium_routing_mode" {
  type        = string
  description = "Cilium routing mode. Use 'tunnel' (VXLAN) for environments without external route management (e.g. Proxmox). Use 'native' only with a route controller or SDN."
  default     = "tunnel"

  validation {
    condition     = contains(["", "native", "tunnel"], var.cilium_routing_mode)
    error_message = "cilium_routing_mode must be one of: empty string, native, or tunnel."
  }
}

variable "cilium_bpf_datapath_mode" {
  type        = string
  default     = "veth"
  description = "Mode for Pod devices for the core datapath. Allowed values: veth, netkit, netkit-l2. Warning: Netkit is still in beta and should not be used together with IPsec encryption!"

  validation {
    condition     = contains(["veth", "netkit", "netkit-l2"], var.cilium_bpf_datapath_mode)
    error_message = "cilium_bpf_datapath_mode must be one of: veth, netkit, netkit-l2."
  }
}

variable "cilium_l2_announcements_enabled" {
  type        = bool
  default     = true
  description = "Enables Cilium L2 Announcements for LoadBalancer service IPs. This allows services to be reachable on the local network without an external load balancer."
}

variable "cilium_gateway_api_enabled" {
  type        = bool
  default     = false
  description = "Enables Cilium Gateway API."
}

variable "cilium_gateway_api_proxy_protocol_enabled" {
  type        = bool
  default     = true
  description = "Enable PROXY Protocol on Cilium Gateway API for external load balancer traffic."
}

variable "cilium_gateway_api_external_traffic_policy" {
  type        = string
  default     = "Cluster"
  description = "Denotes if this Service desires to route external traffic to node-local or cluster-wide endpoints."

  validation {
    condition     = contains(["Cluster", "Local"], var.cilium_gateway_api_external_traffic_policy)
    error_message = "Invalid value for external traffic policy. Allowed values are 'Cluster' or 'Local'."
  }
}

variable "cilium_egress_gateway_enabled" {
  type        = bool
  default     = false
  description = "Enables egress gateway to redirect and SNAT the traffic that leaves the cluster."

  validation {
    condition     = !var.cilium_egress_gateway_enabled || var.cilium_kube_proxy_replacement_enabled
    error_message = "cilium_egress_gateway_enabled can only be true when cilium_kube_proxy_replacement_enabled is true, because Cilium Egress Gateway requires kubeProxyReplacement=true and BPF masquerading."
  }
}

variable "cilium_service_monitor_enabled" {
  type        = bool
  default     = false
  description = "Enables service monitors for Prometheus if set to true."
}

variable "cilium_hubble_enabled" {
  type        = bool
  default     = false
  description = "Enables Hubble observability within Cilium, which may impact performance with an overhead of 1-15% depending on network traffic patterns and settings."
}

variable "cilium_hubble_relay_enabled" {
  type        = bool
  default     = false
  description = "Enables Hubble Relay, which requires Hubble to be enabled."

  validation {
    condition     = var.cilium_hubble_relay_enabled ? var.cilium_hubble_enabled : true
    error_message = "Hubble Relay cannot be enabled unless Hubble is also enabled."
  }
}

variable "cilium_hubble_ui_enabled" {
  type        = bool
  default     = false
  description = "Enables the Hubble UI, which requires Hubble Relay to be enabled."

  validation {
    condition     = var.cilium_hubble_ui_enabled ? var.cilium_hubble_relay_enabled : true
    error_message = "Hubble UI cannot be enabled unless Hubble Relay is also enabled."
  }
}


# Metrics Server
variable "metrics_server_helm_repository" {
  type        = string
  default     = "https://kubernetes-sigs.github.io/metrics-server"
  description = "URL of the Helm repository where the Metrics Server chart is located."
}

variable "metrics_server_helm_chart" {
  type        = string
  default     = "metrics-server"
  description = "Name of the Helm chart used for deploying Metrics Server."
}

variable "metrics_server_helm_version" {
  type        = string
  default     = "3.13.0"
  description = "Version of the Metrics Server Helm chart to deploy."
}

variable "metrics_server_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Metrics Server chart deployment. These values will merge with and will override the default values provided by the Metrics Server Helm chart."
}

variable "metrics_server_enabled" {
  type        = bool
  default     = true
  description = "Enables the the Kubernetes Metrics Server."
}

variable "metrics_server_schedule_on_control_plane" {
  type        = bool
  default     = null
  description = "Determines whether to schedule the Metrics Server on control plane nodes. Defaults to 'true' if there are no configured worker nodes."
}

variable "metrics_server_replicas" {
  type        = number
  default     = null
  description = "Specifies the number of replicas for the Metrics Server. Depending on the node pool size, a default of 1 or 2 is used if not explicitly set."
}


# Cert Manager
variable "cert_manager_helm_repository" {
  type        = string
  default     = "https://charts.jetstack.io"
  description = "URL of the Helm repository where the Cert Manager chart is located."
}

variable "cert_manager_helm_chart" {
  type        = string
  default     = "cert-manager"
  description = "Name of the Helm chart used for deploying Cert Manager."
}

variable "cert_manager_helm_version" {
  type        = string
  default     = "v1.20.2"
  description = "Version of the Cert Manager Helm chart to deploy."
}

variable "cert_manager_helm_values" {
  type        = any
  default     = {}
  description = "Custom Helm values for the Cert Manager chart deployment. These values will merge with and will override the default values provided by the Cert Manager Helm chart."
}

variable "cert_manager_enabled" {
  type        = bool
  default     = false
  description = "Enables the deployment of cert-manager for managing TLS certificates."
}


# Gateway API CRDs
variable "gateway_api_crds_enabled" {
  type        = bool
  default     = true
  description = "Enables the Gateway API Custom Resource Definitions (CRDs) deployment."
}

variable "gateway_api_crds_version" {
  type        = string
  default     = "v1.4.1" # https://github.com/kubernetes-sigs/gateway-api
  description = "Specifies the version of the Gateway API Custom Resource Definitions (CRDs) to deploy."
}

variable "gateway_api_crds_release_channel" {
  type        = string
  default     = "standard"
  description = "Specifies the release channel for the Gateway API CRDs. Valid options are 'standard' or 'experimental'."

  validation {
    condition     = contains(["standard", "experimental"], var.gateway_api_crds_release_channel)
    error_message = "Invalid value for 'gateway_api_crds_release_channel'. Valid options are 'standard' or 'experimental'."
  }
}


# Prometheus Operator CRDs
variable "prometheus_operator_crds_enabled" {
  type        = bool
  default     = true
  description = "Enables the Prometheus Operator Custom Resource Definitions (CRDs) deployment."
}

variable "prometheus_operator_crds_version" {
  type        = string
  default     = "v0.91.0" # https://github.com/prometheus-operator/prometheus-operator
  description = "Specifies the version of the Prometheus Operator Custom Resource Definitions (CRDs) to deploy."
}
