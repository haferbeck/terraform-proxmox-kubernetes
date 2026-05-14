<div align="center">

  <img src="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/proxmox-light.svg" alt="logo" width="150" height="auto" />
  <h1>Proxmox Kubernetes</h1>

  <p>
    OpenTofu / Terraform Module to deploy Kubernetes on Proxmox VE with Talos Linux
  </p>

  <p>
    <a href="https://registry.terraform.io/modules/haferbeck/kubernetes/proxmox">
      <img src="https://img.shields.io/badge/registry.terraform.io-haferbeck%2Fkubernetes%2Fproxmox-blueviolet?logo=terraform" alt="Terraform Registry" />
    </a>
    <a href="https://github.com/haferbeck/terraform-proxmox-kubernetes/releases">
      <img src="https://img.shields.io/github/v/release/haferbeck/terraform-proxmox-kubernetes" alt="GitHub Release" />
    </a>
    <a href="LICENSE">
      <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT" />
    </a>
  </p>

</div>

<br />

## Overview
- [About the Project](#about-the-project)
- [Getting Started](#getting-started)
- [Advanced Configuration](#advanced-configuration)
- [Lifecycle](#lifecycle)
- [Known Issues](#known-issues)
- [Reference](#reference)
- [Contributing](#contributing)
- [Security](#security)
- [Credits](#credits)

## About the Project

Proxmox Kubernetes is a Terraform module for deploying a fully declarative Kubernetes cluster on Proxmox VE. It uses [Talos Linux](https://talos.dev), a secure, immutable, and minimal operating system designed specifically for Kubernetes.

This module is a port of [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes) by VantaLabs, adapted for Proxmox VE environments. It retains the upstream module structure to simplify merging future improvements.

### Differences from the Upstream Module

This module removes Hetzner Cloud-specific features and replaces them with Proxmox equivalents where applicable:

**Removed (Hetzner-specific, no Proxmox equivalent):**
- **Ingress NGINX** — Uses Hetzner LB annotations. Use Cilium Gateway API or deploy your own ingress controller.
- **Cluster Autoscaler** — Proxmox does not support dynamic VM provisioning.
- **Firewall** — Use Proxmox host firewall instead.
- **Placement Groups** — No multi-zone spreading on single Proxmox node.
- **Reverse DNS** — Manage externally.
- **SSH Key Management** — Talos does not use SSH.

**Replaced (mechanism swap):**

| Hetzner Mechanism | Proxmox Equivalent | File |
|---|---|---|
| `hcloud_server` | `proxmox_virtual_environment_vm` | server.tf |
| `hcloud_floating_ip` / `hcloud_load_balancer` (API) | Talos Layer2 VIP (`cluster_vip`) | talos.tf |
| Hcloud CCM (node init + lifecycle + LB) | Proxmox CCM (node init + lifecycle) + Talos CCM (CSR approval) | proxmox_ccm.tf, talos_ccm.tf |
| Hcloud CSI (cloud volumes) | Longhorn or Piraeus/LINSTOR (local disks) | longhorn.tf |
| `hcloud_network` + subnets | Pre-configured bridge network | network.tf |
| Packer image builds (dual-arch) | Direct ISO download from Talos Factory | image.tf |
| `hcloud_uploaded_certificate` (state tracking) | `data.external` curl probe | talos.tf |
| `server_type` (e.g. cx41) | `cpu` + `memory` + `disk_size` per nodepool | nodepool.tf |
| Public/private cluster access | Always private (Talos VIP) | talos.tf |

**Added (Proxmox-specific):**
- **Proxmox CCM** — Auto-provisions API user/role/token. Initializes nodes and automatically cleans up Node objects on VM deletion.
- **Piraeus/LINSTOR** — DRBD-based storage option with kernel modules and dedicated disks.
- **Cilium L2 Announcements** — LoadBalancer services reachable on local network.
- **Dedicated storage disk** — Optional second disk on workers for storage backends.
- **VM ID calculation** — Deterministic IDs from network CIDR offset.

### Features

* **Immutable Infrastructure:** Uses Talos Linux for a fully declarative, immutable Kubernetes cluster.
* **High Availability:** Supports multi-node control planes with Talos Layer2 VIP for API server failover.
* **Upgrade Orchestration:** Rolling Talos and Kubernetes upgrades with health checks between nodes.
* **Quick Start:** Optional Cilium Gateway API, Cert Manager, Longhorn, and Piraeus/LINSTOR integrations.
* **L2 Load Balancing:** Cilium L2 Announcements for LoadBalancer services without an external load balancer.
* **Security:** Disk encryption (LUKS2), transparent network encryption (WireGuard/IPSec), and Talos mTLS API.
* **Storage Options:** Longhorn or Piraeus/LINSTOR with dedicated storage disks on worker nodes.
* **Node Lifecycle:** Proxmox CCM initializes nodes and automatically cleans up Kubernetes Node objects when VMs are deleted.

### Components

This module bundles essential Kubernetes components, preconfigured for Proxmox environments:

- **[Proxmox Cloud Controller Manager](https://github.com/sergelogvinov/proxmox-cloud-controller-manager)** — Initializes nodes (taint removal), monitors Proxmox API, and automatically removes Kubernetes Node objects when VMs are deleted.
- **[Talos Cloud Controller Manager](https://github.com/siderolabs/talos-cloud-controller-manager)** — Approves kubelet CSRs for certificate rotation.
- **[Talos Backup](https://github.com/siderolabs/talos-backup)** — Automates etcd snapshots and S3 storage for backup.
- **[Cilium CNI](https://cilium.io)** — High performance CNI with eBPF, kube-proxy replacement, and L2 announcements.
- **[Cilium Gateway API](https://cilium.io/use-cases/gateway-api/)** — Kubernetes Gateway API implementation using eBPF and Envoy.
- **[Longhorn](https://longhorn.io)** — Distributed block storage with snapshots and automatic replica rebuilding.
- **[Cert Manager](https://cert-manager.io)** — Automated TLS certificate management.
- **[Metrics Server](https://kubernetes-sigs.github.io/metrics-server/)** — Container resource metrics for autoscaling.

### Security

Talos Linux removes SSH and shell access, managed exclusively through a secure mTLS API. It follows [NIST](https://www.nist.gov/publications/application-container-security-guide) and [CIS](https://www.cisecurity.org/benchmark/kubernetes) hardening standards.

**Network Policy:** Internal cluster traffic governed by Kubernetes Network Policies using [Cilium CNI](https://docs.cilium.io/en/stable/network/kubernetes/policy/).

**Encryption in Transit:** Pod network traffic encrypted by Cilium using [WireGuard](https://docs.cilium.io/en/latest/security/network/encryption-wireguard/) by default, with optional [IPsec](https://docs.cilium.io/en/latest/security/network/encryption-ipsec/).

**Encryption at Rest:** STATE and EPHEMERAL partitions encrypted by default using [Talos Disk Encryption](https://www.talos.dev/latest/talos-guides/configuration/disk-encryption/) with LUKS2.

## Getting Started

### Prerequisites

- [terraform](https://developer.hashicorp.com/terraform/install) or [tofu](https://opentofu.org/docs/intro/install/) to deploy the cluster
- [curl](https://curl.se) and [jq](https://jqlang.org/download/) for API communication
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl) to manage the Talos cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) to manage Kubernetes (optional)

> **Important:** Keep CLI tools up to date. Ensure `talosctl` matches your Talos version, especially before upgrades. Minimum Talos version: **v1.12.0**.

### Infrastructure Prerequisites

- A Proxmox VE node (v8.0+) with API access
- A network bridge (e.g. `vmbr0`) with an available IP range for cluster nodes
- A free IP address for the cluster VIP (Kubernetes API endpoint)
- SSH access to the Proxmox host (required by the bpg/proxmox provider to create custom disks)

#### Network / Firewall Requirements

This module does **not** configure the Proxmox host firewall. If you operate a firewall (host, perimeter, or VLAN ACL), the following ports must be reachable across the node network and from the workstation/CI runner that performs `terraform apply`:

| Source | Destination | Port | Protocol | Purpose |
|---|---|---|---|---|
| Workstation / CI | All node IPs + cluster VIP | 50000 | TCP | Talos API (`talosctl`) |
| All node IPs | All node IPs | 50000–50001 | TCP | Talos apid / trustd intra-cluster |
| Workstation / CI | Cluster VIP | 6443 | TCP | Kubernetes API (`kubectl`, plan-time probe) |
| Control plane → control plane | (same) | 2379–2380 | TCP | etcd peer + client |
| All nodes | All nodes | 10250 | TCP | kubelet |
| All nodes | All nodes | 51871 | UDP | Cilium WireGuard (when `cilium_encryption_type = "wireguard"`) |
| All nodes | All nodes | 4789 | UDP | Cilium VXLAN (when `cilium_routing_mode = "tunnel"`, default) |
| All nodes | All nodes | (any) | ESP/AH | Cilium IPSec (when `cilium_encryption_type = "ipsec"`) |
| All nodes | NTP servers | 123 | UDP | Time sync |
| All nodes | Container registries | 443 | TCP | Image pulls |
| All nodes | Cluster VIP | 6443 | TCP | API access for kubelet/CCM/Cilium |

> **Plan-time note:** The `data.external.cluster_state` probe runs `curl` against `https://<cluster_vip>:6443` from the workstation that runs `terraform plan`/`apply`. If the workstation cannot reach the VIP (e.g. CI runner outside the network) the probe always returns `false`, which is harmless on a fresh deploy but skips upgrade and manifest synchronization on existing clusters. Keep VIP:6443 reachable from wherever Terraform runs.

#### Proxmox User Setup

Create a dedicated Terraform user and role on the Proxmox host:

```sh
# Create role with required permissions
pveum role add TerraformRole -privs "\
  Datastore.Allocate \
  Datastore.AllocateSpace \
  Datastore.AllocateTemplate \
  Datastore.Audit \
  Permissions.Modify \
  Realm.AllocateUser \
  SDN.Use \
  Sys.Audit \
  Sys.Modify \
  User.Modify \
  VM.Allocate \
  VM.Audit \
  VM.Clone \
  VM.Config.CDROM \
  VM.Config.Cloudinit \
  VM.Config.CPU \
  VM.Config.Disk \
  VM.Config.HWType \
  VM.Config.Memory \
  VM.Config.Network \
  VM.Config.Options \
  VM.Migrate \
  VM.Monitor \
  VM.PowerMgmt"

# Create user and assign role
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role TerraformRole

# Create API token (save the output!)
pveum user token add terraform@pve terraform-token --privsep=0
```

> **Note:** `Permissions.Modify`, `Realm.AllocateUser`, and `User.Modify` are required for the automatic Proxmox CCM user/token provisioning. If you disable the Proxmox CCM (`proxmox_ccm_enabled = false`), these permissions are not needed.

#### Provider Configuration

Configure the bpg/proxmox provider in your root module:

```hcl
provider "proxmox" {
  endpoint  = "https://your-proxmox-host:8006"
  api_token = "terraform@pve!terraform-token=<token-value>"
  insecure  = true  # Set to false if using valid TLS certificates

  ssh {
    agent = true  # Uses ssh-agent for SSH key authentication
  }
}
```

The provider requires **both** API access and SSH access to the Proxmox host:

- **API access** — Used for all standard VM operations (create, modify, delete)
- **SSH access** — Required when creating custom disks (e.g. dedicated storage disks for Longhorn/Piraeus on worker nodes). The provider runs `qm set` via SSH because the Proxmox API cannot create empty disks.

Ensure your SSH key is loaded in the agent:
```sh
ssh-add    # Add default key
ssh-add -L # Verify loaded keys
```

> **Note for CI/CD:** When running in a pipeline, the runner needs SSH access to the Proxmox host. Add the SSH private key as a CI/CD variable and load it in the job's `before_script`.

### Installation

Create a `main.tf` file with the module configuration:

```hcl
module "kubernetes" {
  # Terraform Registry (recommended)
  source  = "haferbeck/proxmox-kubernetes/proxmox"
  version = "~> 4.0"

  # Or pull directly from GitHub:
  # source = "github.com/haferbeck/terraform-proxmox-kubernetes"

  # Cluster
  cluster_name = "k8s"
  cluster_vip  = "10.0.0.10"

  # Proxmox
  proxmox_node          = "pve01"
  proxmox_disk_storage  = "local-lvm"
  proxmox_image_storage = "local"

  # Network
  network_node_ipv4_cidr = "10.0.0.0/24"
  network_gateway        = "10.0.0.1"

  # Export configs (optional)
  cluster_kubeconfig_path  = "kubeconfig"
  cluster_talosconfig_path = "talosconfig"

  control_plane_nodepools = [
    {
      name      = "control"
      cpu       = 4
      memory    = 8192
      disk_size = 20
      ip_offset = 11
      count     = 3
    }
  ]

  worker_nodepools = [
    {
      name      = "worker"
      cpu       = 4
      memory    = 8192
      disk_size = 20
      ip_offset = 14
      count     = 3
    }
  ]
}
```

The Proxmox CCM is enabled by default. It handles node initialization (taint removal) and monitors the Proxmox API to automatically remove Kubernetes Node objects when their VMs are deleted (scale-down cleanup). Each node gets a `providerID` in the format `proxmox://<region>/<vmid>` which links the Kubernetes Node to its Proxmox VM.

A dedicated Proxmox API user (`<cluster_name>-ccm@pve`), role, and token are automatically provisioned with minimal read-only permissions. CSR approval for kubelet certificate rotation is handled by the Talos CCM, which always runs alongside.

To customize the API endpoint (e.g. if Proxmox is reachable on a different address than `proxmox_node`):
```hcl
proxmox_ccm_api_url = "https://10.0.0.1:8006/api2/json"
```

> **Note:** Each Control Plane node requires at least 4GB of memory. For High-Availability (HA), at least 3 Control Plane nodes are required. The total count of Control Plane nodes must be odd.

Initialize and deploy:

**OpenTofu:**
```sh
tofu init -upgrade
tofu apply
```

**Terraform:**
```sh
terraform init -upgrade
terraform apply
```

### Cluster Access

Set config file locations:
```sh
export TALOSCONFIG=talosconfig
export KUBECONFIG=kubeconfig
```

Display cluster nodes:
```sh
talosctl get member
kubectl get nodes -o wide
```

### Teardown

To destroy the cluster, first remove resources that have `prevent_destroy` enabled:

**OpenTofu:**
```sh
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.worker'
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.control_plane'
tofu state rm 'module.kubernetes.talos_machine_secrets.this'
tofu destroy
```

**Terraform:**
```sh
terraform state rm 'module.kubernetes.talos_machine_configuration_apply.worker'
terraform state rm 'module.kubernetes.talos_machine_configuration_apply.control_plane'
terraform state rm 'module.kubernetes.talos_machine_secrets.this'
terraform destroy
```

## Advanced Configuration

<details>
<summary><b>Proxmox Configuration</b></summary>

Configure Proxmox-specific settings:

```hcl
proxmox_node            = "pve01"          # Proxmox node name
proxmox_disk_storage    = "local-lvm"      # Storage for VM disks
proxmox_image_storage   = "local"          # Storage for Talos ISO
proxmox_network_bridge  = "vmbr0"          # Network bridge (default)
proxmox_network_vlan_id = 30               # Optional VLAN ID
proxmox_keyboard_layout = "de"             # Console keyboard layout (default: en-us)
proxmox_vm_id_base      = 300              # Base VM ID (default: derived from 3rd octet of node CIDR)
```

#### VM ID Calculation

VM IDs are calculated as `vm_id_base + ip_offset + node_index`. By default, `vm_id_base` is derived from the third octet of `network_node_ipv4_cidr` multiplied by 10 (e.g. `10.0.30.0/24` -> `300`). Override with `proxmox_vm_id_base` if needed.

Proxmox requires VM IDs >= 100. The module fails plan with a clear error if the derived `vm_id_base` is < 100 (e.g. CIDR third octet < 10). Either pick a CIDR with a higher octet or set `proxmox_vm_id_base` explicitly.

#### Multi-Host Placement (opt-in)

For Proxmox clusters with multiple hosts, place individual nodepools on different hosts via the optional `proxmox_node` field per nodepool. When unset, the nodepool falls back to `var.proxmox_node`.

```hcl
proxmox_node = "pve01"  # default for nodepools without explicit override

control_plane_nodepools = [
  { name = "cp-pve01", proxmox_node = "pve01", cpu = 4, memory = 8192, disk_size = 20, ip_offset = 11, count = 1 },
  { name = "cp-pve02", proxmox_node = "pve02", cpu = 4, memory = 8192, disk_size = 20, ip_offset = 12, count = 1 },
  { name = "cp-pve03", proxmox_node = "pve03", cpu = 4, memory = 8192, disk_size = 20, ip_offset = 13, count = 1 },
]
```

Constraints:
- `var.proxmox_disk_storage` and `var.proxmox_image_storage` must exist on **every** host referenced by any nodepool. Plan-time preflight checks each host and fails with a clear error if a pool is missing.
- Storage pool names must be identical across hosts. Per-host storage overrides are not yet supported — use shared storage (Ceph, NFS) or align local pool naming.
- VMs are not auto-migrated when you change `proxmox_node` on an existing nodepool. Use `qm migrate` first, then update Terraform with `lifecycle { ignore_changes = [node_name] }` if needed.

#### ISO Checksum Verification (optional)

Enable end-to-end integrity verification of the downloaded Talos ISO by setting an explicit SHA256:

```hcl
talos_iso_checksum = "abcdef0123456789..."  # 64 lowercase hex chars
```

When set, the bpg/proxmox provider verifies the file content matches after download. Default `null` (no verification, matches existing clusters). Obtain the checksum from the Talos Image Factory response or by hashing a trusted local copy.

</details>

<details>
<summary><b>Network Configuration</b></summary>

The cluster VIP is a virtual IP managed by Talos Layer2 VIP. It floats between control plane nodes and serves as the Kubernetes API endpoint.

```hcl
cluster_vip            = "10.0.0.10"    # Must be unused in the network
network_node_ipv4_cidr = "10.0.0.0/24"  # Node IP range
network_gateway        = "10.0.0.1"     # Default gateway
talos_nameservers      = ["10.0.0.2"]   # DNS servers (defaults to gateway)
```

#### Network Segmentation

By default, optimal subnets are calculated from `network_ipv4_cidr` (default `10.0.0.0/16`):

| Subnet | Default CIDR | Purpose |
|--------|-------------|---------|
| Node IPs | `10.0.64.0/19` | Control Plane and Worker node IPs |
| Service IPs | `10.0.96.0/19` | Kubernetes ClusterIPs |
| Pod IPs | `10.0.128.0/17` | Pod network |

Override individually with `network_node_ipv4_cidr`, `network_service_ipv4_cidr`, and `network_pod_ipv4_cidr`.

#### Kubernetes API Hostname

Optionally configure a hostname for the API endpoint:
```hcl
kube_api_hostname = "kube-api.example.com"
```
This adds the hostname to certificate SANs and creates a host entry pointing to the cluster VIP.

</details>

<details>
<summary><b>Nodepool Configuration</b></summary>

#### Control Plane Nodepools

```hcl
control_plane_nodepools = [
  {
    name        = "control"
    cpu         = 4              # CPU cores
    memory      = 8192           # Memory in MB
    disk_size   = 20             # OS disk in GB
    ip_offset   = 11             # First IP = network + offset (.11)
    count       = 3              # Number of nodes (must be odd)
    labels      = {}             # Optional Kubernetes labels
    annotations = {}             # Optional Kubernetes annotations
    taints      = []             # Optional Kubernetes taints
  }
]
```

#### Worker Nodepools

```hcl
worker_nodepools = [
  {
    name              = "worker"
    cpu               = 4
    memory            = 8192
    disk_size         = 20
    ip_offset         = 14           # First IP = network + offset (.14)
    count             = 3
    storage_disk_size = 60           # Optional: dedicated storage disk in GB (for Longhorn/Piraeus)
    labels            = {}
    annotations       = {}
    taints            = []
  }
]
```

Node IPs are calculated sequentially: with `ip_offset = 14` and `count = 3`, nodes get `.14`, `.15`, `.16`.

</details>

<details>
<summary><b>Storage Configuration</b></summary>

#### Longhorn

Longhorn provides distributed block storage with replication and snapshots.

```hcl
longhorn_enabled               = true
longhorn_default_storage_class = true
```

Requires `storage_disk_size > 0` on all worker nodepools. A dedicated disk (`scsi1`) is provisioned, formatted, and mounted at `/var/lib/longhorn`.

#### Piraeus / LINSTOR

Piraeus provides DRBD-based replicated storage via the LINSTOR operator. This module prepares the infrastructure; install the Piraeus Operator separately (e.g. via ArgoCD).

```hcl
piraeus_enabled = true
```

This will:
- Add `siderolabs/drbd` and `siderolabs/util-linux-tools` extensions to the Talos image
- Load `drbd` and `drbd_transport_tcp` kernel modules
- Provision a dedicated raw storage disk (`scsi1`) on worker nodes

Requires `storage_disk_size > 0` on all worker nodepools. Piraeus and Longhorn cannot both be enabled.

#### Custom Helm Values

Override default Helm values for any bundled component:

```hcl
longhorn_helm_values       = {}
cilium_helm_values         = {}
metrics_server_helm_values = {}
cert_manager_helm_values   = {}
```

</details>

<details>
<summary><b>Cilium Configuration</b></summary>

#### L2 Announcements

Enabled by default for Proxmox environments. Allows LoadBalancer services to be reachable on the local network:

```hcl
cilium_l2_announcements_enabled = true
```

#### Transparent Encryption

Network encryption is enabled by default using WireGuard:

```hcl
cilium_encryption_enabled = true          # Default: true
cilium_encryption_type    = "wireguard"   # wireguard (default) | ipsec
```

For IPSec:
```hcl
cilium_encryption_type = "ipsec"
cilium_ipsec_algorithm = "rfc4106(gcm(aes))"  # Default
cilium_ipsec_key_size  = 256                   # Default
cilium_ipsec_key_id    = 1                     # Increment for key rotation (1-15)
```

#### Gateway API

```hcl
cilium_gateway_api_enabled = true
cert_manager_enabled       = true
```

#### Egress Gateway

```hcl
cilium_egress_gateway_enabled = true
```

Requires `cilium_kube_proxy_replacement_enabled = true` (default).

</details>

<details>
<summary><b>Talos Backup</b></summary>

Configure etcd backups to S3-compatible storage:

```hcl
talos_backup_s3_region     = "<region>"
talos_backup_s3_endpoint   = "<endpoint>"
talos_backup_s3_bucket     = "<bucket>"
talos_backup_s3_prefix     = "<prefix>"
talos_backup_s3_access_key = "<access-key>"
talos_backup_s3_secret_key = "<secret-key>"

# Optional
talos_backup_s3_path_style         = true
talos_backup_age_x25519_public_key = "<age-public-key>"
talos_backup_schedule              = "0 * * * *"
```

To recover from a snapshot, refer to the [Talos Disaster Recovery documentation](https://www.talos.dev/latest/advanced/disaster-recovery/#recovery).

</details>

<details>
<summary><b>Bootstrap Manifests</b></summary>

### Component Deployment Control

Enable or disable component deployment:

```hcl
# Core Components (enabled by default)
cilium_enabled                   = true
proxmox_ccm_enabled              = true
talos_backup_s3_enabled          = true
talos_ccm_enabled                = true
talos_coredns_enabled            = true
metrics_server_enabled           = true
prometheus_operator_crds_enabled = true
gateway_api_crds_enabled         = true

# Additional Components (disabled by default)
cert_manager_enabled = true
longhorn_enabled     = true
piraeus_enabled      = true
```

> **Note:** Disabling a component does not delete its existing resources. You must remove deployed resources manually after disabling.

### Adding Extra Manifests

```hcl
# Remote manifests (URLs fetched at bootstrap)
talos_extra_remote_manifests = [
  "https://example.com/manifest.yaml"
]

# Inline manifests
talos_extra_inline_manifests = [
  {
    name     = "my-manifest"
    contents = <<-EOF
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: example
      data:
        key: value
    EOF
  }
]
```

</details>

<details>
<summary><b>OIDC Authentication</b></summary>

Integrate with external identity providers (Keycloak, Auth0, Authentik, etc.):

```hcl
oidc_enabled        = true
oidc_issuer_url     = "https://your-oidc-provider.com"
oidc_client_id      = "your-client-id"
oidc_username_claim = "preferred_username"
oidc_groups_claim   = "groups"
oidc_groups_prefix  = "oidc:"

oidc_group_mappings = [
  {
    group         = "cluster-admins"
    cluster_roles = ["cluster-admin"]
  },
  {
    group         = "developers"
    cluster_roles = ["view"]
    roles = [
      { name = "developer", namespace = "development" }
    ]
  }
]
```

</details>

<details>
<summary><b>Kubernetes RBAC</b></summary>

Create custom roles and cluster roles:

```hcl
rbac_cluster_roles = [
  {
    name  = "my-cluster-role"
    rules = [
      {
        api_groups = [""]
        resources  = ["nodes"]
        verbs      = ["get", "list", "watch"]
      }
    ]
  }
]

rbac_roles = [
  {
    name      = "my-role"
    namespace = "my-namespace"
    rules = [
      {
        api_groups = [""]
        resources  = ["pods", "services"]
        verbs      = ["get", "list", "watch"]
      }
    ]
  }
]
```

</details>

<details>
<summary><b>Module Outputs</b></summary>

| Output | Description |
|---|---|
| `talosconfig` / `talosconfig_data` | Talos client configuration (sensitive). |
| `kubeconfig` / `kubeconfig_data` | Kubernetes client configuration (sensitive). |
| `cluster_endpoint` | Kubernetes API URL (`https://<cluster_vip>:6443`). |
| `cluster_vip` | Layer2 VIP IP. |
| `control_plane_ips` / `worker_ips` | Lists of node IPv4 addresses. |
| `control_plane_vm_ids` / `worker_vm_ids` | Maps of node-name → Proxmox VM ID. |
| `proxmox_ccm_token_id` | Token ID of the auto-provisioned Proxmox CCM API user (non-secret). |
| `cilium_encryption_info` | Encryption type, algorithm, key id, key size. Useful for IPSec key rotation audits. |

</details>

## Lifecycle

### Upgrades

Talos and Kubernetes versions are managed by this module. Do not upgrade Talos or Kubernetes manually — changes to the version variables trigger automated rolling upgrades with health checks:

1. **Talos Upgrade:** Control plane nodes are upgraded sequentially, then worker nodes. Health checks run between each node.
2. **Kubernetes Upgrade:** API server, controller manager, scheduler, kubelet, and kube-proxy are upgraded via `talosctl upgrade-k8s`.
3. **Manifest Sync:** Changed manifests are re-synchronized after upgrades.

### Configuration Apply Modes

Control how machine configuration changes are applied:

```hcl
talos_machine_configuration_apply_mode = "auto"  # auto | reboot | no_reboot | staged | staged_if_needing_reboot
```

> **Warning:** The default mode `auto` applies changes immediately and reboots nodes if required. For changes that trigger a reboot (e.g. CPU/memory changes), all affected nodes may reboot simultaneously, causing downtime. For production clusters, use `staged` mode to perform rolling reboots with health checks:

```hcl
talos_machine_configuration_apply_mode              = "staged"
talos_staged_configuration_automatic_reboot_enabled = true
```

This stages the configuration and reboots nodes one at a time, waiting for the cluster to be healthy between each reboot.

### Scaling

- **Add nodes:** Increase `count` in a nodepool and apply.
- **Remove nodes:** Decrease `count`. Nodes are gracefully drained and removed from etcd. The Proxmox CCM automatically cleans up the Kubernetes Node objects when it detects the VM no longer exists.

> **Warning:** Do not scale control plane nodes from 3 to 1 in a single apply. This removes two etcd members simultaneously and may cause quorum loss. Scale down one step at a time (e.g. 5 to 3, then 3 to 1) and wait for the cluster to stabilize between each step.

## Known Issues

### Talos Image Extensions should be set at first deploy

Settings that affect the Talos base image (e.g. `talos_image_extensions`, `piraeus_enabled`, `longhorn_enabled`) result in a different ISO being downloaded. It is recommended to decide on these before the initial cluster deployment. Changing them later requires re-downloading the ISO and may require node reprovisioning.

### Manifest changes may require manual sync

Inline manifests (Cilium, CCMs, Metrics Server, etc.) are deployed via Talos bootstrap manifests. When Terraform detects a manifest content change, it triggers a sync automatically via `synchronize_manifests`. However, if the sync does not trigger (e.g. after a token rotation or manual resource deletion), you can force it:

```sh
tofu taint 'module.kubernetes.terraform_data.synchronize_manifests'
tofu apply
```

After syncing, restart affected pods to pick up the new configuration:

```sh
# Example: restart Proxmox CCM after token change
kubectl delete pod -n kube-system -l app.kubernetes.io/name=proxmox-cloud-controller-manager
```

## Reference

Full input/output reference is auto-generated from the module sources via [terraform-docs](https://terraform-docs.io). Re-generate locally with `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.9.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.1.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | >= 0.89.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.8.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_external"></a> [external](#provider\_external) | ~> 2.3.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 3.1.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | >= 0.89.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.8.0 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.11.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_download_file.talos_image](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/download_file) | resource |
| [proxmox_user_token.ccm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
| [proxmox_virtual_environment_role.ccm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
| [proxmox_virtual_environment_user.ccm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
| [proxmox_virtual_environment_vm.control_plane](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [proxmox_virtual_environment_vm.worker](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [random_bytes.cilium_ipsec_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/bytes) | resource |
| [talos_cluster_kubeconfig.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/cluster_kubeconfig) | resource |
| [talos_image_factory_schematic.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/image_factory_schematic) | resource |
| [talos_machine_bootstrap.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_configuration_apply.worker](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/resources/machine_secrets) | resource |
| [terraform_data.create_kubeconfig](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.create_talosconfig](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.preflight](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.synchronize_manifests](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.talos_access_data](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.talos_staged_configuration_reboot_control_plane](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.talos_staged_configuration_reboot_worker](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.upgrade_control_plane](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.upgrade_kubernetes](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.upgrade_worker](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.client_prerequisites_check](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.cluster_state](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.talosctl_version_check](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [helm_template.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.cilium](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.longhorn](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.metrics_server](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.proxmox_ccm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [helm_template.talos_ccm](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [proxmox_virtual_environment_datastores.preflight](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_datastores) | data source |
| [talos_client_configuration.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/client_configuration) | data source |
| [talos_cluster_health.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/cluster_health) | data source |
| [talos_image_factory_extensions_versions.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/image_factory_extensions_versions) | data source |
| [talos_image_factory_urls.this](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/image_factory_urls) | data source |
| [talos_machine_configuration.control_plane](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/machine_configuration) | data source |
| [talos_machine_configuration.worker](https://registry.terraform.io/providers/siderolabs/talos/0.11.0/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Specifies the name of the cluster. This name is used to identify the cluster within the infrastructure and should be unique across all deployments. | `string` | n/a | yes |
| <a name="input_cluster_vip"></a> [cluster\_vip](#input\_cluster\_vip) | The virtual IP address used for the Kubernetes API server endpoint. This IP is managed via Talos VIP and should be an unused IP within the node network. | `string` | n/a | yes |
| <a name="input_control_plane_nodepools"></a> [control\_plane\_nodepools](#input\_control\_plane\_nodepools) | Configures the number and attributes of Control Plane nodes. Set proxmox\_node per nodepool to place VMs on a specific Proxmox host (multi-host clusters); falls back to var.proxmox\_node when null. | <pre>list(object({<br/>    name         = string<br/>    cpu          = number<br/>    memory       = number<br/>    disk_size    = number<br/>    ip_offset    = number<br/>    proxmox_node = optional(string)<br/>    labels       = optional(map(string), {})<br/>    annotations  = optional(map(string), {})<br/>    taints       = optional(list(string), [])<br/>    count        = optional(number, 1)<br/>  }))</pre> | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | The default gateway IP address for the node network. | `string` | n/a | yes |
| <a name="input_proxmox_disk_storage"></a> [proxmox\_disk\_storage](#input\_proxmox\_disk\_storage) | The Proxmox storage pool used for VM disks (e.g. 'local-lvm'). | `string` | n/a | yes |
| <a name="input_proxmox_image_storage"></a> [proxmox\_image\_storage](#input\_proxmox\_image\_storage) | The Proxmox storage pool used for storing downloaded images (e.g. 'local'). | `string` | n/a | yes |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | The name of the Proxmox node on which to create VMs. | `string` | n/a | yes |
| <a name="input_cert_manager_enabled"></a> [cert\_manager\_enabled](#input\_cert\_manager\_enabled) | Enables the deployment of cert-manager for managing TLS certificates. | `bool` | `false` | no |
| <a name="input_cert_manager_helm_chart"></a> [cert\_manager\_helm\_chart](#input\_cert\_manager\_helm\_chart) | Name of the Helm chart used for deploying Cert Manager. | `string` | `"cert-manager"` | no |
| <a name="input_cert_manager_helm_repository"></a> [cert\_manager\_helm\_repository](#input\_cert\_manager\_helm\_repository) | URL of the Helm repository where the Cert Manager chart is located. | `string` | `"https://charts.jetstack.io"` | no |
| <a name="input_cert_manager_helm_values"></a> [cert\_manager\_helm\_values](#input\_cert\_manager\_helm\_values) | Custom Helm values for the Cert Manager chart deployment. These values will merge with and will override the default values provided by the Cert Manager Helm chart. | `any` | `{}` | no |
| <a name="input_cert_manager_helm_version"></a> [cert\_manager\_helm\_version](#input\_cert\_manager\_helm\_version) | Version of the Cert Manager Helm chart to deploy. | `string` | `"v1.20.2"` | no |
| <a name="input_cilium_bpf_datapath_mode"></a> [cilium\_bpf\_datapath\_mode](#input\_cilium\_bpf\_datapath\_mode) | Mode for Pod devices for the core datapath. Allowed values: veth, netkit, netkit-l2. Warning: Netkit is still in beta and should not be used together with IPsec encryption! | `string` | `"veth"` | no |
| <a name="input_cilium_egress_gateway_enabled"></a> [cilium\_egress\_gateway\_enabled](#input\_cilium\_egress\_gateway\_enabled) | Enables egress gateway to redirect and SNAT the traffic that leaves the cluster. | `bool` | `false` | no |
| <a name="input_cilium_enabled"></a> [cilium\_enabled](#input\_cilium\_enabled) | Enables the Cilium CNI deployment. | `bool` | `true` | no |
| <a name="input_cilium_encryption_enabled"></a> [cilium\_encryption\_enabled](#input\_cilium\_encryption\_enabled) | Enables transparent network encryption using Cilium within the Kubernetes cluster. When enabled, this feature provides added security for network traffic. | `bool` | `true` | no |
| <a name="input_cilium_encryption_type"></a> [cilium\_encryption\_type](#input\_cilium\_encryption\_type) | Type of encryption to use for Cilium network encryption. Options: 'wireguard' or 'ipsec'. | `string` | `"wireguard"` | no |
| <a name="input_cilium_gateway_api_enabled"></a> [cilium\_gateway\_api\_enabled](#input\_cilium\_gateway\_api\_enabled) | Enables Cilium Gateway API. | `bool` | `false` | no |
| <a name="input_cilium_gateway_api_external_traffic_policy"></a> [cilium\_gateway\_api\_external\_traffic\_policy](#input\_cilium\_gateway\_api\_external\_traffic\_policy) | Denotes if this Service desires to route external traffic to node-local or cluster-wide endpoints. | `string` | `"Cluster"` | no |
| <a name="input_cilium_gateway_api_proxy_protocol_enabled"></a> [cilium\_gateway\_api\_proxy\_protocol\_enabled](#input\_cilium\_gateway\_api\_proxy\_protocol\_enabled) | Enable PROXY Protocol on Cilium Gateway API for external load balancer traffic. | `bool` | `true` | no |
| <a name="input_cilium_helm_chart"></a> [cilium\_helm\_chart](#input\_cilium\_helm\_chart) | Name of the Helm chart used for deploying Cilium. | `string` | `"cilium"` | no |
| <a name="input_cilium_helm_repository"></a> [cilium\_helm\_repository](#input\_cilium\_helm\_repository) | URL of the Helm repository where the Cilium chart is located. | `string` | `"https://helm.cilium.io"` | no |
| <a name="input_cilium_helm_values"></a> [cilium\_helm\_values](#input\_cilium\_helm\_values) | Custom Helm values for the Cilium chart deployment. These values will merge with and will override the default values provided by the Cilium Helm chart. | `any` | `{}` | no |
| <a name="input_cilium_helm_version"></a> [cilium\_helm\_version](#input\_cilium\_helm\_version) | Version of the Cilium Helm chart to deploy. | `string` | `"1.18.9"` | no |
| <a name="input_cilium_hubble_enabled"></a> [cilium\_hubble\_enabled](#input\_cilium\_hubble\_enabled) | Enables Hubble observability within Cilium, which may impact performance with an overhead of 1-15% depending on network traffic patterns and settings. | `bool` | `false` | no |
| <a name="input_cilium_hubble_relay_enabled"></a> [cilium\_hubble\_relay\_enabled](#input\_cilium\_hubble\_relay\_enabled) | Enables Hubble Relay, which requires Hubble to be enabled. | `bool` | `false` | no |
| <a name="input_cilium_hubble_ui_enabled"></a> [cilium\_hubble\_ui\_enabled](#input\_cilium\_hubble\_ui\_enabled) | Enables the Hubble UI, which requires Hubble Relay to be enabled. | `bool` | `false` | no |
| <a name="input_cilium_ipsec_algorithm"></a> [cilium\_ipsec\_algorithm](#input\_cilium\_ipsec\_algorithm) | Cilium IPSec key algorithm. | `string` | `"rfc4106(gcm(aes))"` | no |
| <a name="input_cilium_ipsec_key_id"></a> [cilium\_ipsec\_key\_id](#input\_cilium\_ipsec\_key\_id) | IPSec key ID (1-15, increment manually for rotation). Only used when cilium\_encryption\_type is 'ipsec'. | `number` | `1` | no |
| <a name="input_cilium_ipsec_key_size"></a> [cilium\_ipsec\_key\_size](#input\_cilium\_ipsec\_key\_size) | AES key size in bits for IPSec encryption (128, 192, or 256). Only used when cilium\_encryption\_type is 'ipsec'. | `number` | `256` | no |
| <a name="input_cilium_kube_proxy_replacement_enabled"></a> [cilium\_kube\_proxy\_replacement\_enabled](#input\_cilium\_kube\_proxy\_replacement\_enabled) | Enables Cilium's eBPF kube-proxy replacement. | `bool` | `true` | no |
| <a name="input_cilium_l2_announcements_enabled"></a> [cilium\_l2\_announcements\_enabled](#input\_cilium\_l2\_announcements\_enabled) | Enables Cilium L2 Announcements for LoadBalancer service IPs. This allows services to be reachable on the local network without an external load balancer. | `bool` | `true` | no |
| <a name="input_cilium_load_balancer_acceleration"></a> [cilium\_load\_balancer\_acceleration](#input\_cilium\_load\_balancer\_acceleration) | Cilium XDP Acceleration mode. Note: 'native' requires NIC driver support (not available with virtio). Use PCI passthrough for native XDP. | `string` | `"disabled"` | no |
| <a name="input_cilium_policy_cidr_match_mode"></a> [cilium\_policy\_cidr\_match\_mode](#input\_cilium\_policy\_cidr\_match\_mode) | Allows setting policy-cidr-match-mode to "nodes", which means that cluster nodes can be selected by CIDR network policies. Normally nodes are only accessible via remote-node entity selectors. This is required if you want to target the kube-api server with a k8s NetworkPolicy. | `string` | `""` | no |
| <a name="input_cilium_routing_mode"></a> [cilium\_routing\_mode](#input\_cilium\_routing\_mode) | Cilium routing mode. Use 'tunnel' (VXLAN) for environments without external route management (e.g. Proxmox). Use 'native' only with a route controller or SDN. | `string` | `"tunnel"` | no |
| <a name="input_cilium_service_monitor_enabled"></a> [cilium\_service\_monitor\_enabled](#input\_cilium\_service\_monitor\_enabled) | Enables service monitors for Prometheus if set to true. | `bool` | `false` | no |
| <a name="input_cilium_socket_lb_host_namespace_only_enabled"></a> [cilium\_socket\_lb\_host\_namespace\_only\_enabled](#input\_cilium\_socket\_lb\_host\_namespace\_only\_enabled) | Limit Cilium's socket-level load-balancing to the host namespace only. | `bool` | `false` | no |
| <a name="input_client_prerequisites_check_enabled"></a> [client\_prerequisites\_check\_enabled](#input\_client\_prerequisites\_check\_enabled) | Controls whether a preflight check verifies that required client tools are installed before provisioning. | `bool` | `true` | no |
| <a name="input_cluster_allow_scheduling_on_control_planes"></a> [cluster\_allow\_scheduling\_on\_control\_planes](#input\_cluster\_allow\_scheduling\_on\_control\_planes) | Allow scheduling on control plane nodes. If this is false, scheduling on control plane nodes is explicitly disabled. Defaults to true if there are no workers present. | `bool` | `null` | no |
| <a name="input_cluster_domain"></a> [cluster\_domain](#input\_cluster\_domain) | Specifies the domain name used by the cluster. This domain name is integral for internal networking and service discovery within the cluster. The default is 'cluster.local', which is commonly used for local Kubernetes clusters. | `string` | `"cluster.local"` | no |
| <a name="input_cluster_healthcheck_enabled"></a> [cluster\_healthcheck\_enabled](#input\_cluster\_healthcheck\_enabled) | Determines whether are executed during cluster deployment and upgrade. | `bool` | `true` | no |
| <a name="input_cluster_kubeconfig_path"></a> [cluster\_kubeconfig\_path](#input\_cluster\_kubeconfig\_path) | If not null, the kubeconfig will be written to a file speficified. | `string` | `null` | no |
| <a name="input_cluster_talosconfig_path"></a> [cluster\_talosconfig\_path](#input\_cluster\_talosconfig\_path) | If not null, the talosconfig will be written to a file speficified. | `string` | `null` | no |
| <a name="input_control_plane_config_patches"></a> [control\_plane\_config\_patches](#input\_control\_plane\_config\_patches) | List of configuration patches applied to the Control Plane nodes. | `any` | `[]` | no |
| <a name="input_gateway_api_crds_enabled"></a> [gateway\_api\_crds\_enabled](#input\_gateway\_api\_crds\_enabled) | Enables the Gateway API Custom Resource Definitions (CRDs) deployment. | `bool` | `true` | no |
| <a name="input_gateway_api_crds_release_channel"></a> [gateway\_api\_crds\_release\_channel](#input\_gateway\_api\_crds\_release\_channel) | Specifies the release channel for the Gateway API CRDs. Valid options are 'standard' or 'experimental'. | `string` | `"standard"` | no |
| <a name="input_gateway_api_crds_version"></a> [gateway\_api\_crds\_version](#input\_gateway\_api\_crds\_version) | Specifies the version of the Gateway API Custom Resource Definitions (CRDs) to deploy. | `string` | `"v1.4.1"` | no |
| <a name="input_kube_api_admission_control"></a> [kube\_api\_admission\_control](#input\_kube\_api\_admission\_control) | List of admission control settings for the Kube API. If set, this overrides the default admission control. | `list(any)` | `[]` | no |
| <a name="input_kube_api_extra_args"></a> [kube\_api\_extra\_args](#input\_kube\_api\_extra\_args) | Specifies additional command-line arguments to be passed to the kube-apiserver. This allows for customization of the API server's behavior according to specific cluster requirements. | `map(string)` | `{}` | no |
| <a name="input_kube_api_hostname"></a> [kube\_api\_hostname](#input\_kube\_api\_hostname) | Specifies the hostname for external access to the Kubernetes API server. This must be a valid domain name, set to the API's public IP address. | `string` | `null` | no |
| <a name="input_kubernetes_apiserver_image"></a> [kubernetes\_apiserver\_image](#input\_kubernetes\_apiserver\_image) | Specifies a custom image repository for kube-apiserver (e.g., 'my-registry.io/kube-apiserver'). The version tag is appended automatically from kubernetes\_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults. | `string` | `null` | no |
| <a name="input_kubernetes_controller_manager_image"></a> [kubernetes\_controller\_manager\_image](#input\_kubernetes\_controller\_manager\_image) | Specifies a custom image repository for kube-controller-manager (e.g., 'my-registry.io/kube-controller-manager'). The version tag is appended automatically from kubernetes\_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults. | `string` | `null` | no |
| <a name="input_kubernetes_etcd_image"></a> [kubernetes\_etcd\_image](#input\_kubernetes\_etcd\_image) | Specifies a custom container image for etcd including the tag and/or digest (e.g., 'my-registry.io/etcd:v3.6.8', 'my-registry.io/etcd:v3.6.8@sha256:...', or 'my-registry.io/etcd@sha256:...'). This change will only take effect after a manual reboot of your cluster nodes! | `string` | `null` | no |
| <a name="input_kubernetes_kubelet_extra_args"></a> [kubernetes\_kubelet\_extra\_args](#input\_kubernetes\_kubelet\_extra\_args) | Specifies additional command-line arguments to pass to the kubelet service. These arguments can customize or override default kubelet configurations, allowing for tailored cluster behavior. | `map(string)` | `{}` | no |
| <a name="input_kubernetes_kubelet_extra_config"></a> [kubernetes\_kubelet\_extra\_config](#input\_kubernetes\_kubelet\_extra\_config) | Specifies additional configuration settings for the kubelet service. These settings can customize or override default kubelet configurations, allowing for tailored cluster behavior. | `any` | `{}` | no |
| <a name="input_kubernetes_kubelet_image"></a> [kubernetes\_kubelet\_image](#input\_kubernetes\_kubelet\_image) | Specifies a custom image repository for the kubelet (e.g., 'my-registry.io/kubelet'). The version tag is appended automatically from kubernetes\_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults. | `string` | `null` | no |
| <a name="input_kubernetes_proxy_image"></a> [kubernetes\_proxy\_image](#input\_kubernetes\_proxy\_image) | Specifies a custom image repository for kube-proxy (e.g., 'my-registry.io/kube-proxy'). The version tag is appended automatically from kubernetes\_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults. | `string` | `null` | no |
| <a name="input_kubernetes_scheduler_image"></a> [kubernetes\_scheduler\_image](#input\_kubernetes\_scheduler\_image) | Specifies a custom image repository for kube-scheduler (e.g., 'my-registry.io/kube-scheduler'). The version tag is appended automatically from kubernetes\_version. When set, this image is used during both machine configuration and Kubernetes upgrades, preventing custom images from being reset to upstream defaults. | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Specifies the Kubernetes version to deploy. | `string` | `"v1.33.10"` | no |
| <a name="input_longhorn_default_storage_class"></a> [longhorn\_default\_storage\_class](#input\_longhorn\_default\_storage\_class) | Set Longhorn as the default storage class. | `bool` | `false` | no |
| <a name="input_longhorn_enabled"></a> [longhorn\_enabled](#input\_longhorn\_enabled) | Enable or disable Longhorn integration | `bool` | `false` | no |
| <a name="input_longhorn_helm_chart"></a> [longhorn\_helm\_chart](#input\_longhorn\_helm\_chart) | Name of the Helm chart used for deploying Longhorn. | `string` | `"longhorn"` | no |
| <a name="input_longhorn_helm_repository"></a> [longhorn\_helm\_repository](#input\_longhorn\_helm\_repository) | URL of the Helm repository where the Longhorn chart is located. | `string` | `"https://charts.longhorn.io"` | no |
| <a name="input_longhorn_helm_values"></a> [longhorn\_helm\_values](#input\_longhorn\_helm\_values) | Custom Helm values for the Longhorn chart deployment. These values will merge with and will override the default values provided by the Longhorn Helm chart. | `any` | `{}` | no |
| <a name="input_longhorn_helm_version"></a> [longhorn\_helm\_version](#input\_longhorn\_helm\_version) | Version of the Longhorn Helm chart to deploy. | `string` | `"1.11.1"` | no |
| <a name="input_metrics_server_enabled"></a> [metrics\_server\_enabled](#input\_metrics\_server\_enabled) | Enables the the Kubernetes Metrics Server. | `bool` | `true` | no |
| <a name="input_metrics_server_helm_chart"></a> [metrics\_server\_helm\_chart](#input\_metrics\_server\_helm\_chart) | Name of the Helm chart used for deploying Metrics Server. | `string` | `"metrics-server"` | no |
| <a name="input_metrics_server_helm_repository"></a> [metrics\_server\_helm\_repository](#input\_metrics\_server\_helm\_repository) | URL of the Helm repository where the Metrics Server chart is located. | `string` | `"https://kubernetes-sigs.github.io/metrics-server"` | no |
| <a name="input_metrics_server_helm_values"></a> [metrics\_server\_helm\_values](#input\_metrics\_server\_helm\_values) | Custom Helm values for the Metrics Server chart deployment. These values will merge with and will override the default values provided by the Metrics Server Helm chart. | `any` | `{}` | no |
| <a name="input_metrics_server_helm_version"></a> [metrics\_server\_helm\_version](#input\_metrics\_server\_helm\_version) | Version of the Metrics Server Helm chart to deploy. | `string` | `"3.13.0"` | no |
| <a name="input_metrics_server_replicas"></a> [metrics\_server\_replicas](#input\_metrics\_server\_replicas) | Specifies the number of replicas for the Metrics Server. Depending on the node pool size, a default of 1 or 2 is used if not explicitly set. | `number` | `null` | no |
| <a name="input_metrics_server_schedule_on_control_plane"></a> [metrics\_server\_schedule\_on\_control\_plane](#input\_metrics\_server\_schedule\_on\_control\_plane) | Determines whether to schedule the Metrics Server on control plane nodes. Defaults to 'true' if there are no configured worker nodes. | `bool` | `null` | no |
| <a name="input_network_ipv4_cidr"></a> [network\_ipv4\_cidr](#input\_network\_ipv4\_cidr) | Specifies the main IPv4 CIDR block for the network. This CIDR block is used to allocate IP addresses within the network. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_network_native_routing_ipv4_cidr"></a> [network\_native\_routing\_ipv4\_cidr](#input\_network\_native\_routing\_ipv4\_cidr) | Specifies the IPv4 CIDR block that the CNI assumes will be routed natively by the underlying network infrastructure without the need for SNAT. | `string` | `null` | no |
| <a name="input_network_node_ipv4_cidr"></a> [network\_node\_ipv4\_cidr](#input\_network\_node\_ipv4\_cidr) | Specifies the Node IPv4 CIDR used for allocating IP addresses to both Control Plane and Worker nodes within the cluster. If not explicitly provided, a default subnet is dynamically calculated from the specified network\_ipv4\_cidr. | `string` | `null` | no |
| <a name="input_network_pod_ipv4_cidr"></a> [network\_pod\_ipv4\_cidr](#input\_network\_pod\_ipv4\_cidr) | Defines the Pod IPv4 CIDR block allocated for use by pods within the cluster. This CIDR block is essential for internal pod communications. If a specific subnet is not provided, a default is dynamically calculated from the network\_ipv4\_cidr. | `string` | `null` | no |
| <a name="input_network_service_ipv4_cidr"></a> [network\_service\_ipv4\_cidr](#input\_network\_service\_ipv4\_cidr) | Specifies the Service IPv4 CIDR block used for allocating ClusterIPs to services within the cluster. If not provided, a default subnet is dynamically calculated from the specified network\_ipv4\_cidr. | `string` | `null` | no |
| <a name="input_oidc_client_id"></a> [oidc\_client\_id](#input\_oidc\_client\_id) | OIDC client ID that all tokens must be issued for. Required when oidc\_enabled is true | `string` | `""` | no |
| <a name="input_oidc_enabled"></a> [oidc\_enabled](#input\_oidc\_enabled) | Enable OIDC authentication for Kubernetes API server | `bool` | `false` | no |
| <a name="input_oidc_group_mappings"></a> [oidc\_group\_mappings](#input\_oidc\_group\_mappings) | List of OIDC groups mapped to Kubernetes roles and cluster roles | <pre>list(object({<br/>    group         = string<br/>    cluster_roles = optional(list(string), [])<br/>    roles = optional(list(object({<br/>      name      = string<br/>      namespace = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_oidc_groups_claim"></a> [oidc\_groups\_claim](#input\_oidc\_groups\_claim) | JWT claim to use as the user's groups | `string` | `"groups"` | no |
| <a name="input_oidc_groups_prefix"></a> [oidc\_groups\_prefix](#input\_oidc\_groups\_prefix) | Prefix prepended to group claims to prevent clashes with existing names | `string` | `"oidc:"` | no |
| <a name="input_oidc_issuer_url"></a> [oidc\_issuer\_url](#input\_oidc\_issuer\_url) | URL of the OIDC provider (e.g., https://your-oidc-provider.com). Required when oidc\_enabled is true | `string` | `""` | no |
| <a name="input_oidc_username_claim"></a> [oidc\_username\_claim](#input\_oidc\_username\_claim) | JWT claim to use as the username | `string` | `"sub"` | no |
| <a name="input_piraeus_enabled"></a> [piraeus\_enabled](#input\_piraeus\_enabled) | Prepares the cluster for Piraeus/LINSTOR storage: adds DRBD extension to the Talos image, loads DRBD kernel modules, and provisions a dedicated storage disk on worker nodes. The actual Piraeus Operator must be installed separately (e.g. via ArgoCD). | `bool` | `false` | no |
| <a name="input_prometheus_operator_crds_enabled"></a> [prometheus\_operator\_crds\_enabled](#input\_prometheus\_operator\_crds\_enabled) | Enables the Prometheus Operator Custom Resource Definitions (CRDs) deployment. | `bool` | `true` | no |
| <a name="input_prometheus_operator_crds_version"></a> [prometheus\_operator\_crds\_version](#input\_prometheus\_operator\_crds\_version) | Specifies the version of the Prometheus Operator Custom Resource Definitions (CRDs) to deploy. | `string` | `"v0.90.1"` | no |
| <a name="input_proxmox_ccm_api_insecure"></a> [proxmox\_ccm\_api\_insecure](#input\_proxmox\_ccm\_api\_insecure) | Allow insecure TLS connections to the Proxmox API. | `bool` | `true` | no |
| <a name="input_proxmox_ccm_api_url"></a> [proxmox\_ccm\_api\_url](#input\_proxmox\_ccm\_api\_url) | Proxmox API URL for the CCM. If not set, derived from proxmox\_node (https://<proxmox\_node>:8006/api2/json). | `string` | `null` | no |
| <a name="input_proxmox_ccm_enabled"></a> [proxmox\_ccm\_enabled](#input\_proxmox\_ccm\_enabled) | Enables the Proxmox Cloud Controller Manager. Manages node lifecycle (automatic cleanup of deleted nodes) and sets provider-specific labels. A dedicated Proxmox API user and token are automatically provisioned. | `bool` | `true` | no |
| <a name="input_proxmox_ccm_helm_chart"></a> [proxmox\_ccm\_helm\_chart](#input\_proxmox\_ccm\_helm\_chart) | Helm chart name for the Proxmox CCM. | `string` | `"proxmox-cloud-controller-manager"` | no |
| <a name="input_proxmox_ccm_helm_repository"></a> [proxmox\_ccm\_helm\_repository](#input\_proxmox\_ccm\_helm\_repository) | Helm repository for the Proxmox CCM chart. | `string` | `"oci://ghcr.io/sergelogvinov/charts"` | no |
| <a name="input_proxmox_ccm_helm_values"></a> [proxmox\_ccm\_helm\_values](#input\_proxmox\_ccm\_helm\_values) | Custom Helm values for the Proxmox CCM chart. | `any` | `{}` | no |
| <a name="input_proxmox_ccm_helm_version"></a> [proxmox\_ccm\_helm\_version](#input\_proxmox\_ccm\_helm\_version) | Helm chart version for the Proxmox CCM. | `string` | `"0.2.27"` | no |
| <a name="input_proxmox_ccm_region"></a> [proxmox\_ccm\_region](#input\_proxmox\_ccm\_region) | Region identifier for this Proxmox cluster. Used as topology.kubernetes.io/region label. | `string` | `"default"` | no |
| <a name="input_proxmox_keyboard_layout"></a> [proxmox\_keyboard\_layout](#input\_proxmox\_keyboard\_layout) | The keyboard layout for the VM console. | `string` | `"en-us"` | no |
| <a name="input_proxmox_network_bridge"></a> [proxmox\_network\_bridge](#input\_proxmox\_network\_bridge) | The Proxmox network bridge to attach VM network interfaces to. | `string` | `"vmbr0"` | no |
| <a name="input_proxmox_network_vlan_id"></a> [proxmox\_network\_vlan\_id](#input\_proxmox\_network\_vlan\_id) | The VLAN ID to assign to VM network interfaces. Set to null for untagged traffic. | `number` | `null` | no |
| <a name="input_proxmox_vm_id_base"></a> [proxmox\_vm\_id\_base](#input\_proxmox\_vm\_id\_base) | Base VM ID for cluster nodes. Node VM IDs are calculated as vm\_id\_base + ip\_offset + node\_index. If not set, derived from the third octet of network\_node\_ipv4\_cidr (e.g. 192.168.10.0/24 → 100). Proxmox requires VM IDs >= 100. | `number` | `null` | no |
| <a name="input_rbac_cluster_roles"></a> [rbac\_cluster\_roles](#input\_rbac\_cluster\_roles) | List of custom Kubernetes cluster roles to create | <pre>list(object({<br/>    name = string<br/>    rules = list(object({<br/>      api_groups = list(string)<br/>      resources  = list(string)<br/>      verbs      = list(string)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_rbac_roles"></a> [rbac\_roles](#input\_rbac\_roles) | List of custom Kubernetes roles to create | <pre>list(object({<br/>    name      = string<br/>    namespace = string<br/>    rules = list(object({<br/>      api_groups = list(string)<br/>      resources  = list(string)<br/>      verbs      = list(string)<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_talos_backup_age_x25519_public_key"></a> [talos\_backup\_age\_x25519\_public\_key](#input\_talos\_backup\_age\_x25519\_public\_key) | AGE X25519 Public Key for client side Talos Backup encryption. | `string` | `null` | no |
| <a name="input_talos_backup_enable_compression"></a> [talos\_backup\_enable\_compression](#input\_talos\_backup\_enable\_compression) | Enable ETCD snapshot compression with zstd algorithm. | `bool` | `false` | no |
| <a name="input_talos_backup_s3_access_key"></a> [talos\_backup\_s3\_access\_key](#input\_talos\_backup\_s3\_access\_key) | S3 Access Key for Talos Backup. | `string` | `""` | no |
| <a name="input_talos_backup_s3_bucket"></a> [talos\_backup\_s3\_bucket](#input\_talos\_backup\_s3\_bucket) | S3 bucket name for Talos Backup. | `string` | `null` | no |
| <a name="input_talos_backup_s3_enabled"></a> [talos\_backup\_s3\_enabled](#input\_talos\_backup\_s3\_enabled) | Enable Talos etcd S3 backup cronjob. | `bool` | `true` | no |
| <a name="input_talos_backup_s3_endpoint"></a> [talos\_backup\_s3\_endpoint](#input\_talos\_backup\_s3\_endpoint) | S3 endpoint for Talos Backup. | `string` | `null` | no |
| <a name="input_talos_backup_s3_path_style"></a> [talos\_backup\_s3\_path\_style](#input\_talos\_backup\_s3\_path\_style) | Use path style S3 for Talos Backup. Set this to false if you have another s3 like endpoint such as minio. | `bool` | `false` | no |
| <a name="input_talos_backup_s3_prefix"></a> [talos\_backup\_s3\_prefix](#input\_talos\_backup\_s3\_prefix) | S3 prefix for Talos Backup. | `string` | `null` | no |
| <a name="input_talos_backup_s3_region"></a> [talos\_backup\_s3\_region](#input\_talos\_backup\_s3\_region) | S3 region for Talos Backup. | `string` | `null` | no |
| <a name="input_talos_backup_s3_secret_key"></a> [talos\_backup\_s3\_secret\_key](#input\_talos\_backup\_s3\_secret\_key) | S3 Secret Access Key for Talos Backup. | `string` | `""` | no |
| <a name="input_talos_backup_schedule"></a> [talos\_backup\_schedule](#input\_talos\_backup\_schedule) | The schedule for Talos Backup | `string` | `"0 * * * *"` | no |
| <a name="input_talos_backup_version"></a> [talos\_backup\_version](#input\_talos\_backup\_version) | Specifies the version of Talos Backup to be used in generated machine configurations. | `string` | `"v0.1.0-beta.3-3-g38dad7c"` | no |
| <a name="input_talos_ccm_enabled"></a> [talos\_ccm\_enabled](#input\_talos\_ccm\_enabled) | Enables the Talos Cloud Controller Manager (CCM) deployment. Handles kubelet CSR approval. When Proxmox CCM is also active, only CSR approval runs. | `bool` | `true` | no |
| <a name="input_talos_ccm_helm_chart"></a> [talos\_ccm\_helm\_chart](#input\_talos\_ccm\_helm\_chart) | Helm chart name for the Talos CCM. | `string` | `"talos-cloud-controller-manager"` | no |
| <a name="input_talos_ccm_helm_repository"></a> [talos\_ccm\_helm\_repository](#input\_talos\_ccm\_helm\_repository) | Helm repository for the Talos CCM chart. | `string` | `"oci://ghcr.io/siderolabs/charts"` | no |
| <a name="input_talos_ccm_helm_values"></a> [talos\_ccm\_helm\_values](#input\_talos\_ccm\_helm\_values) | Custom Helm values for the Talos CCM chart. | `any` | `{}` | no |
| <a name="input_talos_ccm_helm_version"></a> [talos\_ccm\_helm\_version](#input\_talos\_ccm\_helm\_version) | Helm chart version for the Talos CCM. | `string` | `"0.5.4"` | no |
| <a name="input_talos_certificates"></a> [talos\_certificates](#input\_talos\_certificates) | Additional trusted CA certificates to be added to the Talos configuration.<br/>Map keys are used as names for the TrustedRootsConfig documents.<br/>Values can be either a single PEM-encoded string containing one or more certificates (inline or from file), or a list of PEM-encoded strings.<br/><br/>Example:<pre>hcl<br/>talos_certificates = {<br/>  # Inline string (single certificate)<br/>  "inline-ca" = "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"<br/><br/>  # Single certificate from file<br/>  "file-ca" = [file("ca.crt")]<br/><br/>  # Multiple certificates from files (chain)<br/>  "corporate-chain" = [file("root.crt"), file("intermediate.crt")]<br/><br/>  # Multiple inline certificates in a single string (backward compatible)<br/>  "legacy-ca" = <<-EOT<br/>    -----BEGIN CERTIFICATE-----<br/>    ...<br/>    -----END CERTIFICATE-----<br/>    -----BEGIN CERTIFICATE-----<br/>    ...<br/>    -----END CERTIFICATE-----<br/>  EOT<br/>}</pre> | `any` | `{}` | no |
| <a name="input_talos_coredns_enabled"></a> [talos\_coredns\_enabled](#input\_talos\_coredns\_enabled) | Determines whether CoreDNS is enabled in the Talos cluster. When enabled, CoreDNS serves as the primary DNS service provider in Kubernetes. | `bool` | `true` | no |
| <a name="input_talos_discovery_kubernetes_enabled"></a> [talos\_discovery\_kubernetes\_enabled](#input\_talos\_discovery\_kubernetes\_enabled) | Enable or disable Kubernetes-based Talos discovery service. Deprecated as of Kubernetes v1.32, where the AuthorizeNodeWithSelectors feature gate is enabled by default. | `bool` | `false` | no |
| <a name="input_talos_discovery_service_enabled"></a> [talos\_discovery\_service\_enabled](#input\_talos\_discovery\_service\_enabled) | Enable or disable Sidero Labs public Talos discovery service. | `bool` | `true` | no |
| <a name="input_talos_ephemeral_partition_encryption_enabled"></a> [talos\_ephemeral\_partition\_encryption\_enabled](#input\_talos\_ephemeral\_partition\_encryption\_enabled) | Enables or disables encryption for the ephemeral (`/var`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster. | `bool` | `true` | no |
| <a name="input_talos_extra_inline_manifests"></a> [talos\_extra\_inline\_manifests](#input\_talos\_extra\_inline\_manifests) | List of additional inline Kubernetes manifests to append to the Talos machine configuration during bootstrap. | <pre>list(object({<br/>    name     = string<br/>    contents = string<br/>  }))</pre> | `null` | no |
| <a name="input_talos_extra_kernel_args"></a> [talos\_extra\_kernel\_args](#input\_talos\_extra\_kernel\_args) | Defines a list of extra kernel commandline parameters. | `list(string)` | `[]` | no |
| <a name="input_talos_extra_remote_manifests"></a> [talos\_extra\_remote\_manifests](#input\_talos\_extra\_remote\_manifests) | List of remote URLs pointing to Kubernetes manifests to be appended to the Talos machine configuration during bootstrap. | `list(string)` | `null` | no |
| <a name="input_talos_image_extensions"></a> [talos\_image\_extensions](#input\_talos\_image\_extensions) | Specifies Talos image extensions for additional functionality on top of the default Talos Linux capabilities. See: https://github.com/siderolabs/extensions | `list(string)` | `[]` | no |
| <a name="input_talos_ipv6_enabled"></a> [talos\_ipv6\_enabled](#input\_talos\_ipv6\_enabled) | Determines whether IPv6 is enabled for the Talos operating system. Enabling this setting configures the Talos OS to support IPv6 networking capabilities. | `bool` | `false` | no |
| <a name="input_talos_iso_checksum"></a> [talos\_iso\_checksum](#input\_talos\_iso\_checksum) | Optional SHA256 checksum (64 lowercase hex chars) for the downloaded Talos ISO. When set, the bpg/proxmox provider verifies the file matches after download. Leave null to skip verification (default; matches existing clusters). | `string` | `null` | no |
| <a name="input_talos_kernel_modules"></a> [talos\_kernel\_modules](#input\_talos\_kernel\_modules) | Defines a list of kernel modules to be loaded during system boot, along with optional parameters for each module. This allows for customized kernel behavior in the Talos environment. | <pre>list(object({<br/>    name       = string<br/>    parameters = optional(list(string))<br/>  }))</pre> | `null` | no |
| <a name="input_talos_kubelet_extra_mounts"></a> [talos\_kubelet\_extra\_mounts](#input\_talos\_kubelet\_extra\_mounts) | Defines extra kubelet mounts for Talos with configurable 'source', 'destination' (defaults to 'source' if unset), 'type' (defaults to 'bind'), and 'options' (defaults to ['bind', 'rshared', 'rw']) | <pre>list(object({<br/>    source      = string<br/>    destination = optional(string)<br/>    type        = optional(string, "bind")<br/>    options     = optional(list(string), ["bind", "rshared", "rw"])<br/>  }))</pre> | `[]` | no |
| <a name="input_talos_logging_destinations"></a> [talos\_logging\_destinations](#input\_talos\_logging\_destinations) | List of objects defining remote destinations for Talos service logs. | <pre>list(object({<br/>    endpoint  = string<br/>    format    = optional(string, "json_lines")<br/>    extraTags = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_talos_machine_configuration_apply_mode"></a> [talos\_machine\_configuration\_apply\_mode](#input\_talos\_machine\_configuration\_apply\_mode) | Determines how changes to Talos machine configurations are applied. 'auto' (default) applies changes immediately and reboots if necessary. 'reboot' applies changes and then reboots the node. 'no\_reboot' applies changes immediately without a reboot, failing if a reboot is required. 'staged' stages changes to apply on the next reboot. 'staged\_if\_needing\_reboot' performs a dry-run and uses 'staged' mode if reboot is needed, 'auto' otherwise. | `string` | `"auto"` | no |
| <a name="input_talos_nameservers"></a> [talos\_nameservers](#input\_talos\_nameservers) | Specifies a list of nameserver addresses used for DNS resolution by nodes and CoreDNS within the cluster. Falls back to the network gateway if empty. | `list(string)` | `[]` | no |
| <a name="input_talos_ntp_servers"></a> [talos\_ntp\_servers](#input\_talos\_ntp\_servers) | Specifies a list of time server addresses used for network time synchronization across the cluster. These servers ensure that all cluster nodes maintain accurate and synchronized time. | `list(string)` | <pre>[<br/>  "0.pool.ntp.org",<br/>  "1.pool.ntp.org",<br/>  "2.pool.ntp.org"<br/>]</pre> | no |
| <a name="input_talos_reboot_debug"></a> [talos\_reboot\_debug](#input\_talos\_reboot\_debug) | Enable debug operation from kernel logs during Talos reboots. When true, --wait is set to true by talosctl. | `bool` | `false` | no |
| <a name="input_talos_reboot_mode"></a> [talos\_reboot\_mode](#input\_talos\_reboot\_mode) | Select the reboot mode. Mode "powercycle" bypasses kexec, and mode "force" skips graceful teardown. Valid values: "default", "powercycle", or "force". | `string` | `null` | no |
| <a name="input_talos_registries"></a> [talos\_registries](#input\_talos\_registries) | Specifies a list of registry mirrors to be used for container image retrieval. This configuration helps in specifying alternate sources or local mirrors for image registries, enhancing reliability and speed of image downloads.<br/>Example configuration:<pre>registries = {<br/>  mirrors = {<br/>    "docker.io" = {<br/>      endpoints = [<br/>        "http://localhost:5000",<br/>        "https://docker.io"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | `any` | `null` | no |
| <a name="input_talos_schematic_id"></a> [talos\_schematic\_id](#input\_talos\_schematic\_id) | Specifies the Talos schematic ID used for selecting the specific Image and Installer versions in deployments. This has precedence over `talos_image_extensions` | `string` | `null` | no |
| <a name="input_talos_staged_configuration_automatic_reboot_enabled"></a> [talos\_staged\_configuration\_automatic\_reboot\_enabled](#input\_talos\_staged\_configuration\_automatic\_reboot\_enabled) | Determines whether nodes are rebooted automatically after Talos machine configuration changes are applied in 'staged' mode, or when 'staged\_if\_needing\_reboot' resolves to 'staged' mode. | `bool` | `true` | no |
| <a name="input_talos_state_partition_encryption_enabled"></a> [talos\_state\_partition\_encryption\_enabled](#input\_talos\_state\_partition\_encryption\_enabled) | Enables or disables encryption for the state (`/system/state`) partition. Attention: Changing this value for an existing cluster requires manual actions as per Talos documentation (https://www.talos.dev/latest/talos-guides/configuration/disk-encryption). Ignoring this may break your cluster. | `bool` | `true` | no |
| <a name="input_talos_static_hosts"></a> [talos\_static\_hosts](#input\_talos\_static\_hosts) | Specifies static host mappings to be added on each node. Each entry must include an IP address and a list of hostnames associated with that IP. | <pre>list(object({<br/>    ip        = string<br/>    hostnames = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_talos_sysctls_extra_args"></a> [talos\_sysctls\_extra\_args](#input\_talos\_sysctls\_extra\_args) | Specifies a map of sysctl key-value pairs for configuring additional kernel parameters. These settings allow for detailed customization of the operating system's behavior at runtime. | `map(string)` | `{}` | no |
| <a name="input_talos_upgrade_debug"></a> [talos\_upgrade\_debug](#input\_talos\_upgrade\_debug) | Enable debug operation from kernel logs during Talos upgrades. When true, --wait is set to true by talosctl. | `bool` | `false` | no |
| <a name="input_talos_upgrade_force"></a> [talos\_upgrade\_force](#input\_talos\_upgrade\_force) | Force the Talos upgrade by skipping etcd health and member checks. | `bool` | `false` | no |
| <a name="input_talos_upgrade_insecure"></a> [talos\_upgrade\_insecure](#input\_talos\_upgrade\_insecure) | Upgrade using the insecure (no auth) maintenance service. | `bool` | `false` | no |
| <a name="input_talos_upgrade_reboot_mode"></a> [talos\_upgrade\_reboot\_mode](#input\_talos\_upgrade\_reboot\_mode) | Select the reboot mode during upgrade. Mode "powercycle" bypasses kexec. Valid values: "default" or "powercycle". | `string` | `null` | no |
| <a name="input_talos_upgrade_stage"></a> [talos\_upgrade\_stage](#input\_talos\_upgrade\_stage) | Stage the Talos upgrade to perform it after a reboot. | `bool` | `false` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Specifies the version of Talos to be used in generated machine configurations. | `string` | `"v1.12.7"` | no |
| <a name="input_talosctl_retries"></a> [talosctl\_retries](#input\_talosctl\_retries) | Specifies how many times talosctl operations should retry before failing. This setting helps improve resilience against transient network issues or temporary API unavailability. | `number` | `100` | no |
| <a name="input_talosctl_version_check_enabled"></a> [talosctl\_version\_check\_enabled](#input\_talosctl\_version\_check\_enabled) | Controls whether a preflight check verifies the local talosctl client version before provisioning. | `bool` | `true` | no |
| <a name="input_worker_config_patches"></a> [worker\_config\_patches](#input\_worker\_config\_patches) | List of configuration patches applied to the Worker nodes. | `any` | `[]` | no |
| <a name="input_worker_nodepools"></a> [worker\_nodepools](#input\_worker\_nodepools) | Defines configuration settings for Worker node pools within the cluster. Set proxmox\_node per nodepool to place VMs on a specific Proxmox host (multi-host clusters); falls back to var.proxmox\_node when null. | <pre>list(object({<br/>    name              = string<br/>    cpu               = number<br/>    memory            = number<br/>    disk_size         = number<br/>    ip_offset         = number<br/>    proxmox_node      = optional(string)<br/>    storage_disk_size = optional(number, 0)<br/>    labels            = optional(map(string), {})<br/>    annotations       = optional(map(string), {})<br/>    taints            = optional(list(string), [])<br/>    count             = optional(number, 1)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cilium_encryption_info"></a> [cilium\_encryption\_info](#output\_cilium\_encryption\_info) | Cilium traffic encryption settings, including current state and IPsec details if enabled. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint URL. |
| <a name="output_cluster_vip"></a> [cluster\_vip](#output\_cluster\_vip) | Control plane virtual IP. |
| <a name="output_control_plane_ips"></a> [control\_plane\_ips](#output\_control\_plane\_ips) | List of IPv4 addresses assigned to control plane nodes. |
| <a name="output_control_plane_vm_ids"></a> [control\_plane\_vm\_ids](#output\_control\_plane\_vm\_ids) | Map of control plane node names to their assigned Proxmox VM IDs. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Raw kubeconfig file for authenticating with the Kubernetes cluster. |
| <a name="output_kubeconfig_data"></a> [kubeconfig\_data](#output\_kubeconfig\_data) | Structured kubeconfig data, suitable for use with other Terraform providers or tools. |
| <a name="output_proxmox_ccm_token_id"></a> [proxmox\_ccm\_token\_id](#output\_proxmox\_ccm\_token\_id) | Token ID of the auto-provisioned Proxmox CCM API user. Empty when proxmox\_ccm\_enabled is false. |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Detailed configuration data for the Talos client. |
| <a name="output_talos_machine_configurations_control_plane"></a> [talos\_machine\_configurations\_control\_plane](#output\_talos\_machine\_configurations\_control\_plane) | Talos machine configurations for all control plane nodes. |
| <a name="output_talos_machine_configurations_worker"></a> [talos\_machine\_configurations\_worker](#output\_talos\_machine\_configurations\_worker) | Talos machine configurations for all worker nodes. |
| <a name="output_talos_machine_secrets"></a> [talos\_machine\_secrets](#output\_talos\_machine\_secrets) | Talos machine secret, suitable for use with other Terraform providers or tools. |
| <a name="output_talosconfig"></a> [talosconfig](#output\_talosconfig) | Raw Talos OS configuration file used for cluster access and management. |
| <a name="output_talosconfig_data"></a> [talosconfig\_data](#output\_talosconfig\_data) | Structured Talos configuration data, suitable for use with other Terraform providers or tools. |
| <a name="output_worker_ips"></a> [worker\_ips](#output\_worker\_ips) | List of IPv4 addresses assigned to worker nodes. |
| <a name="output_worker_vm_ids"></a> [worker\_vm\_ids](#output\_worker\_vm\_ids) | Map of worker node names to their assigned Proxmox VM IDs. |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution flow.

GitLab is the source of truth and runs the primary CI/CD pipeline; GitHub is a one-way mirror used for the Terraform Registry, Issues, and external pull requests. Both projects are publicly readable, but the GitLab instance is invite-only for sign-up — external contributors should open pull requests on GitHub.

| Forge | URL |
|-------|-----|
| GitLab (source of truth) | https://git.lab.haferbeck.it/devops/terraform-modules/proxmox-kubernetes |
| GitHub (public mirror) | https://github.com/haferbeck/terraform-proxmox-kubernetes |

## Security

Report vulnerabilities privately via [GitHub Security Advisories](https://github.com/haferbeck/terraform-proxmox-kubernetes/security/advisories/new). See [SECURITY.md](SECURITY.md) for details.

## Credits

This module is a Proxmox VE port of [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes) by [VantaLabs](https://github.com/VantaLabs). Licensed under [MIT](LICENSE).
