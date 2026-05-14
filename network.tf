locals {
  # Network ranges — computed from network_ipv4_cidr if not explicitly provided
  network_ipv4_cidr             = var.network_ipv4_cidr
  network_ipv4_cidr_prefix_size = tonumber(split("/", local.network_ipv4_cidr)[1])

  network_node_ipv4_cidr = coalesce(var.network_node_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 3, 2))

  # Limit service IPs to a /12 or more specific CIDR to satisfy Kubernetes 1.33+ validation.
  network_service_ipv4_cidr_newbits = max(3, 12 - local.network_ipv4_cidr_prefix_size)
  network_service_ipv4_cidr_netnum  = 3 * pow(2, local.network_service_ipv4_cidr_newbits - 3)

  network_service_ipv4_cidr = coalesce(
    var.network_service_ipv4_cidr,
    cidrsubnet(
      local.network_ipv4_cidr,
      local.network_service_ipv4_cidr_newbits,
      local.network_service_ipv4_cidr_netnum
    )
  )

  network_pod_ipv4_cidr = coalesce(var.network_pod_ipv4_cidr, cidrsubnet(local.network_ipv4_cidr, 1, 1))

  network_native_routing_ipv4_cidr = coalesce(var.network_native_routing_ipv4_cidr, local.network_ipv4_cidr)
}
