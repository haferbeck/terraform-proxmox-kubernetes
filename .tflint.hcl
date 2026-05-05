plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Rules disabled below flag patterns that exist verbatim in the upstream
# `terraform-hcloud-kubernetes` module. Fixing them only here would create
# port-vs-upstream divergence and break the documented upstream-merge-ability
# goal. Re-enable individual rules when upstream addresses them.

# upstream image.tf uses legacy splat syntax `data.X.Y.this[0].info.*.name`
# (image factory extensions array)
rule "terraform_deprecated_index" {
  enabled = false
}

# upstream talos_config_base.tf uses interpolation-only expressions in the
# IPv6 sysctl values: "${var.talos_ipv6_enabled ? 0 : 1}"
rule "terraform_deprecated_interpolation" {
  enabled = false
}

# upstream declares `local.talos_api_port` (consumed by firewall.tf which
# is removed in the Proxmox port), `local.network_node_ipv4_cidr` (used by
# multiple files including ingress_nginx.tf which is also removed), and
# `data.talos_cluster_health.this` (read for side-effect health checks).
rule "terraform_unused_declarations" {
  enabled = false
}
