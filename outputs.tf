output "talosconfig" {
  description = "Raw Talos OS configuration file used for cluster access and management."
  value       = local.talosconfig
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig file for authenticating with the Kubernetes cluster."
  value       = local.kubeconfig
  sensitive   = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data, suitable for use with other Terraform providers or tools."
  value       = local.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Structured Talos configuration data, suitable for use with other Terraform providers or tools."
  value       = local.talosconfig_data
  sensitive   = true
}

output "talos_client_configuration" {
  description = "Detailed configuration data for the Talos client."
  value       = data.talos_client_configuration.this
}

output "talos_machine_secrets" {
  description = "Talos machine secret, suitable for use with other Terraform providers or tools."
  value       = talos_machine_secrets.this.machine_secrets
  sensitive   = true
}

output "talos_machine_configurations_control_plane" {
  description = "Talos machine configurations for all control plane nodes."
  value       = data.talos_machine_configuration.control_plane
  sensitive   = true
}

output "talos_machine_configurations_worker" {
  description = "Talos machine configurations for all worker nodes."
  value       = data.talos_machine_configuration.worker
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint URL."
  value       = local.kube_api_url
}

output "cluster_vip" {
  description = "Control plane virtual IP."
  value       = var.cluster_vip
}

output "control_plane_ips" {
  description = "List of IPv4 addresses assigned to control plane nodes."
  value       = local.control_plane_ips
}

output "worker_ips" {
  description = "List of IPv4 addresses assigned to worker nodes."
  value       = local.worker_ips
}

output "control_plane_vm_ids" {
  description = "Map of control plane node names to their assigned Proxmox VM IDs."
  value       = { for name, node in local.control_plane_nodes : name => node.vm_id }
}

output "worker_vm_ids" {
  description = "Map of worker node names to their assigned Proxmox VM IDs."
  value       = { for name, node in local.worker_nodes : name => node.vm_id }
}

output "proxmox_ccm_token_id" {
  description = "Token ID of the auto-provisioned Proxmox CCM API user. Empty when proxmox_ccm_enabled is false."
  value       = var.proxmox_ccm_enabled ? proxmox_user_token.ccm[0].id : ""
}

output "cilium_encryption_info" {
  description = "Cilium traffic encryption settings, including current state and IPsec details if enabled."
  value = {
    encryption_enabled = var.cilium_encryption_enabled
    encryption_type    = var.cilium_encryption_type

    ipsec = local.cilium_ipsec_enabled ? {
      current_key_id = var.cilium_ipsec_key_id
      next_key_id    = local.cilium_ipsec_key_config["next_id"]
      algorithm      = var.cilium_ipsec_algorithm
      key_size_bits  = var.cilium_ipsec_key_size
      secret_name    = local.cilium_ipsec_keys_manifest.metadata["name"]
      namespace      = local.cilium_ipsec_keys_manifest.metadata["namespace"]
    } : {}
  }
}
