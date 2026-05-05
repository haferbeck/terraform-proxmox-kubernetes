output "cluster_endpoint" {
  description = "Kubernetes API endpoint, https://<cluster_vip>:6443."
  value       = module.kubernetes.cluster_endpoint
}

output "control_plane_ips" {
  description = "IPv4 addresses of the control plane nodes."
  value       = module.kubernetes.control_plane_ips
}

output "worker_ips" {
  description = "IPv4 addresses of the worker nodes."
  value       = module.kubernetes.worker_ips
}

output "kubeconfig_data" {
  description = "Kubeconfig contents (sensitive)."
  value       = module.kubernetes.kubeconfig_data
  sensitive   = true
}

output "talosconfig_data" {
  description = "Talosconfig contents (sensitive)."
  value       = module.kubernetes.talosconfig_data
  sensitive   = true
}
