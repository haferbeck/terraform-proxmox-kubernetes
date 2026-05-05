# Minimal Example

Smallest viable cluster: **1 control plane + 1 worker** on a single Proxmox host. Useful for kicking the tyres or for non-HA homelab setups.

> Not highly available. Loss of the control plane node means cluster downtime. For HA use 3 (or 5) control plane nodes spread across multiple Proxmox hosts.

## Prerequisites

- A Proxmox VE node (v8.0+) reachable at `var.proxmox_endpoint`
- An API token with the permissions described in the [root README](../../README.md#proxmox-user-setup)
- A free IP for the cluster VIP (`10.0.0.10` in this example)
- SSH access to the Proxmox host (the bpg/proxmox provider uses SSH for custom-disk operations)

## Usage

```sh
export TF_VAR_proxmox_endpoint='https://pve.example.com:8006'
export TF_VAR_proxmox_api_token='terraform@pve!terraform-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
export TF_VAR_proxmox_insecure='true'   # only for self-signed lab certs

tofu init
tofu apply
```

After apply:

```sh
export KUBECONFIG=$PWD/kubeconfig
export TALOSCONFIG=$PWD/talosconfig

kubectl get nodes -o wide
talosctl get member
```

## Adjusting for your environment

Edit `main.tf`:

| Setting | Change for your env |
|---------|---------------------|
| `proxmox_node` | Name of your Proxmox host (`pvecm nodes`) |
| `proxmox_disk_storage` | Storage pool for VM disks (`pvesm status`) |
| `proxmox_image_storage` | Storage pool for ISO uploads |
| `network_node_ipv4_cidr` / `network_gateway` / `cluster_vip` | Match your bridge subnet |
| `control_plane_nodepools[].ip_offset` / `worker_nodepools[].ip_offset` | Pick free IPs |

## Teardown

```sh
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.worker'
tofu state rm 'module.kubernetes.talos_machine_configuration_apply.control_plane'
tofu state rm 'module.kubernetes.talos_machine_secrets.this'
tofu destroy
```

The `state rm` calls remove resources marked `prevent_destroy` so the cluster can be torn down. See the [root README](../../README.md#teardown) for details.
