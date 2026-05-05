locals {
  # Talos Version
  talos_version_parts = regex("^v?(?P<major>[0-9]+)\\.(?P<minor>[0-9]+)\\.(?P<patch>[0-9]+)", var.talos_version)
  talos_version_major = local.talos_version_parts.major
  talos_version_minor = local.talos_version_parts.minor
  talos_version_patch = local.talos_version_parts.patch

  # Talos Nodes
  talos_primary_node_name = sort(keys(proxmox_virtual_environment_vm.control_plane))[0]
  talos_primary_node_ip   = local.control_plane_nodes[local.talos_primary_node_name].ip

  # Talos API
  talos_api_port         = 50000
  talos_primary_endpoint = local.talos_primary_node_ip
  talos_endpoints        = local.control_plane_ips

  # Kubernetes API
  kube_api_port = 6443
  kube_api_host = var.cluster_vip
  kube_api_url  = "https://${local.kube_api_host}:${local.kube_api_port}"

  # KubePrism
  kube_prism_host = "127.0.0.1"
  kube_prism_port = 7445

  # Talos Control
  talosctl_commands = templatefile("${path.module}/templates/talosctl_commands.sh.tftpl", {
    talos_upgrade_debug                 = var.talos_upgrade_debug
    talos_upgrade_force                 = var.talos_upgrade_force
    talos_upgrade_insecure              = var.talos_upgrade_insecure
    talos_upgrade_stage                 = var.talos_upgrade_stage
    talos_upgrade_reboot_mode           = var.talos_upgrade_reboot_mode
    talos_reboot_debug                  = var.talos_reboot_debug
    talos_reboot_mode                   = var.talos_reboot_mode
    talos_installer_image_url           = local.talos_installer_image_url
    talosctl_retries                    = var.talosctl_retries
    healthcheck_enabled                 = var.cluster_healthcheck_enabled
    talos_primary_node                  = local.talos_primary_node_ip
    kube_api_url                        = local.kube_api_url
    kubernetes_version                  = var.kubernetes_version
    kubernetes_apiserver_image          = var.kubernetes_apiserver_image
    kubernetes_controller_manager_image = var.kubernetes_controller_manager_image
    kubernetes_scheduler_image          = var.kubernetes_scheduler_image
    kubernetes_proxy_image              = var.kubernetes_proxy_image
    kubernetes_kubelet_image            = var.kubernetes_kubelet_image
    control_plane_nodes                 = local.control_plane_ips
    worker_nodes                        = local.worker_ips
  })

  # Cluster Status (evaluated at plan time, no resource dependencies — breaks cycle)
  cluster_initialized = data.external.cluster_state.result.initialized == "true"

  talos_staged_configuration_automatic_reboot_enabled = (
    var.talos_staged_configuration_automatic_reboot_enabled &&
    contains(["staged", "staged_if_needing_reboot"], var.talos_machine_configuration_apply_mode)
  )
}

###############################################################################
# Machine Secrets
###############################################################################

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version

  lifecycle {
    prevent_destroy = true
  }
}

###############################################################################
# Upgrades
###############################################################################

resource "terraform_data" "upgrade_control_plane" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Control Plane Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.control_plane_ips
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Control Plane Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Control Plane Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.control_plane,
    data.talos_client_configuration.this
  ]
}

resource "terraform_data" "upgrade_worker" {
  triggers_replace = [
    var.talos_version,
    local.talos_schematic_id
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = local.cluster_initialized ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      "printf '%s\\n' \"Start upgrading Worker Nodes\"",
      templatefile("${path.module}/templates/talos_upgrade.sh.tftpl", {
        upgrade_nodes      = local.worker_ips
        talos_version      = var.talos_version
        talos_schematic_id = local.talos_schematic_id
      }),
      "printf '%s\\n' \"Worker Nodes upgraded successfully\"",
    ]) : "printf '%s\\n' \"Cluster not initialized, skipping Worker Node upgrade\""

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    data.talos_machine_configuration.worker,
    terraform_data.upgrade_control_plane
  ]
}

resource "terraform_data" "upgrade_kubernetes" {
  triggers_replace = [
    var.kubernetes_version,
    var.kubernetes_apiserver_image,
    var.kubernetes_controller_manager_image,
    var.kubernetes_scheduler_image,
    var.kubernetes_proxy_image,
    var.kubernetes_kubelet_image,
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n",
      [
        "set -eu",
        local.cluster_initialized ? join("\n",
          [
            local.talosctl_commands,
            "printf '%s\\n' \"Start upgrading Kubernetes\"",
            templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
            "printf '%s\\n' \"Kubernetes upgraded successfully\"",
          ]
        ) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes upgrade\"",
    ])

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    terraform_data.upgrade_control_plane,
    terraform_data.upgrade_worker,
  ]
}

###############################################################################
# Apply Machine Configuration
###############################################################################

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.control_plane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  depends_on = [
    proxmox_virtual_environment_vm.control_plane,
    terraform_data.upgrade_kubernetes
  ]
}

resource "terraform_data" "talos_staged_configuration_reboot_control_plane" {
  count = local.talos_staged_configuration_automatic_reboot_enabled ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(jsonencode({
      for k, v in data.talos_machine_configuration.control_plane :
      k => v.machine_configuration
    })))
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = anytrue([for _, v in talos_machine_configuration_apply.control_plane : v.resolved_apply_mode == "staged"]) ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      templatefile("${path.module}/templates/talos_reboot.sh.tftpl", {
        target_nodes        = local.control_plane_ips
        healthcheck_enabled = local.cluster_initialized
      })
    ]) : "printf '%s\\n' \"No control plane configuration changes were applied in staged mode. Skipping reboot.\""

    environment = merge(
      { TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config) },
      {
        for _, apply in talos_machine_configuration_apply.control_plane :
        "TALOS_APPLY_MODE_${replace(apply.node, ".", "_")}" => apply.resolved_apply_mode
      }
    )
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_configuration_apply.control_plane
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip
  apply_mode                  = var.talos_machine_configuration_apply_mode

  depends_on = [
    proxmox_virtual_environment_vm.worker,
    terraform_data.upgrade_kubernetes,
    talos_machine_configuration_apply.control_plane,
    terraform_data.talos_staged_configuration_reboot_control_plane
  ]
}

resource "terraform_data" "talos_staged_configuration_reboot_worker" {
  count = local.talos_staged_configuration_automatic_reboot_enabled ? 1 : 0

  triggers_replace = [
    nonsensitive(sha1(jsonencode({
      for k, v in data.talos_machine_configuration.worker :
      k => v.machine_configuration
    })))
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = anytrue([for _, v in talos_machine_configuration_apply.worker : v.resolved_apply_mode == "staged"]) ? join("\n", [
      "set -eu",
      local.talosctl_commands,
      templatefile("${path.module}/templates/talos_reboot.sh.tftpl", {
        target_nodes        = local.worker_ips
        healthcheck_enabled = local.cluster_initialized
      })
    ]) : "printf '%s\\n' \"No worker configuration changes were applied in staged mode. Skipping reboot.\""

    environment = merge(
      { TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config) },
      {
        for _, apply in talos_machine_configuration_apply.worker :
        "TALOS_APPLY_MODE_${replace(apply.node, ".", "_")}" => apply.resolved_apply_mode
      }
    )
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_configuration_apply.worker
  ]
}

###############################################################################
# Bootstrap
###############################################################################

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.talos_primary_endpoint
  node                 = local.talos_primary_node_ip

  depends_on = [
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
    terraform_data.talos_staged_configuration_reboot_control_plane,
    terraform_data.talos_staged_configuration_reboot_worker,
  ]
}

###############################################################################
# Manifest Synchronization
###############################################################################

resource "terraform_data" "synchronize_manifests" {
  triggers_replace = [
    nonsensitive(sha1(jsonencode(local.talos_inline_manifests))),
    nonsensitive(sha1(jsonencode(local.talos_manifests))),
  ]

  provisioner "local-exec" {
    when  = create
    quiet = true
    command = join("\n",
      [
        "set -eu",
        local.cluster_initialized ? join("\n",
          [
            local.talosctl_commands,
            "printf '%s\\n' \"Start synchronizing Kubernetes manifests\"",
            templatefile("${path.module}/templates/talos_upgrade_k8s.sh.tftpl", {}),
            "printf '%s\\n' \"Kubernetes manifests synchronized successfully\"",
          ]
        ) : "printf '%s\\n' \"Cluster not initialized, skipping Kubernetes manifest synchronization\"",
      ]
    )

    environment = {
      TALOSCONFIG = nonsensitive(data.talos_client_configuration.this.talos_config)
    }
  }

  depends_on = [
    data.external.talosctl_version_check,
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.control_plane,
    talos_machine_configuration_apply.worker,
    terraform_data.talos_staged_configuration_reboot_control_plane,
    terraform_data.talos_staged_configuration_reboot_worker,
  ]
}

###############################################################################
# Cluster State (plan-time probe, no resource dependencies)
###############################################################################

data "external" "cluster_state" {
  program = [
    "sh", "-c", <<-EOT
      if curl -sk --connect-timeout 5 "https://${var.cluster_vip}:${local.kube_api_port}/version" >/dev/null 2>&1; then
        printf '{"initialized": "true"}'
      else
        printf '{"initialized": "false"}'
      fi
    EOT
  ]
}

###############################################################################
# Access Data (buffered in state — health check uses previous apply's values,
# preventing checks against nodes that don't exist yet)
###############################################################################

resource "terraform_data" "talos_access_data" {
  input = {
    talos_primary_node  = local.talos_primary_node_ip
    endpoints           = local.talos_endpoints
    control_plane_nodes = local.control_plane_ips
    worker_nodes        = local.worker_ips
    kube_api_url        = local.kube_api_url
  }
}

###############################################################################
# Health Check
###############################################################################

data "talos_cluster_health" "this" {
  count = var.cluster_healthcheck_enabled ? 1 : 0

  client_configuration   = talos_machine_secrets.this.client_configuration
  endpoints              = terraform_data.talos_access_data.output.endpoints
  control_plane_nodes    = terraform_data.talos_access_data.output.control_plane_nodes
  worker_nodes           = terraform_data.talos_access_data.output.worker_nodes
  skip_kubernetes_checks = false

  timeouts = {
    read = "10m"
  }

  depends_on = [
    terraform_data.synchronize_manifests,
    talos_machine_bootstrap.this,
  ]
}
