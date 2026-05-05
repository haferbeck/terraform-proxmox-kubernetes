# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This module is a port of [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes). The **Upstream** field on each release records which upstream tag the port is aligned with at that point. Where the port intentionally diverges from upstream, the rationale is noted under **Notes**.

## [4.0.0] - 2026-05-05

Phase C completion of the upstream 4.0.0 alignment. The Talos machine configuration is split across three files mirroring upstream and migrated to Talos multi-document config format. With this release the port reaches structural parity with [terraform-hcloud-kubernetes 4.0.0](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/tag/4.0.0); only Hetzner-specific resources and proxmox-equivalent swaps differ.

### Changed
- **Talos machine configuration migrated to multi-document format.** `machine.systemDiskEncryption`, `machine.network.nameservers`, `machine.network.extraHostEntries`, and `machine.time.servers` are no longer set under the legacy `machine` keys. Each is emitted as a separate Talos document:
  - `VolumeConfig` STATE / EPHEMERAL (system volume encryption)
  - `ResolverConfig` (DNS nameservers)
  - `StaticHostConfig` (static `/etc/hosts` mappings — the Phase B compatibility shim is gone)
  - `TimeSyncConfig` (NTP)
  - `TrustedRootsConfig` (already in Phase B)
  - `Layer2VIPConfig` (control plane only)
  - `HostnameConfig` (per node)

  Requires Talos OS ≥ 1.10. The default `talos_version` is well above that.

- `talos_config.tf` (single file, ~459 LOC) split into:
  - `talos_config_base.tf` — base machine + cluster patch and all multi-document patches shared by every node
  - `talos_config_control_plane.tf` — control-plane-specific patches (apiServer, etcd, scheduler, controllerManager, inlineManifests, externalCloudProvider, Layer2VIPConfig, HostnameConfig per node)
  - `talos_config_worker.tf` — worker-specific patches (Longhorn dedicated disk, smaller kubelet reserved, HostnameConfig per node)

- `talos_machine_configuration_apply.control_plane` and `.worker` no longer carry inline `config_patches`. `HostnameConfig` and `Layer2VIPConfig` were moved to the new `talos_config_control_plane.tf` / `talos_config_worker.tf` files where they belong (matching upstream's structure). The apply blocks now only set `endpoint`, `node`, and `apply_mode`.

### Removed
- The Phase B compatibility shim `local.talos_extra_host_entries` (the field-rename `aliases` → `hostnames` mapper) is gone — multi-document `StaticHostConfig` uses `hostnames` natively.
- `machine.network.extraHostEntries`, `machine.network.nameservers`, `machine.systemDiskEncryption`, `machine.time.servers` no longer appear in any single-document machine patch — replaced by their multi-document equivalents.

### Notes
- This is a large machine_configuration change. Every node's machine_configuration hash will change on first apply. Combined with `talos_machine_configuration_apply_mode = "staged"` (and `talos_staged_configuration_automatic_reboot_enabled = true` by default), this triggers a staged rolling reboot of every node.
- Functional behavior is unchanged — the multi-document documents produce the same effective Talos machine state as the legacy single-document fields.
- Port-specific divergences from upstream are preserved as before: single network interface (no public/private/DHCP `LinkConfig` patches), `Layer2VIPConfig` instead of `HCloudVIPConfig`, Piraeus kernel modules and Longhorn machine disk on workers, no autoscaler / load-balancer / firewall logic.

### Upstream
- **Aligned with [terraform-hcloud-kubernetes 4.0.0](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/tag/4.0.0).** All shared files (`terraform.tf`, `outputs.tf`, `talos.tf`, `talos_config_*.tf`, `templates/*.tftpl`, common variable schemas) are byte-identical or differ only where Proxmox replaces a Hetzner-specific construct (e.g. `proxmox_virtual_environment_vm` for `hcloud_server`, `Layer2VIPConfig` for `HCloudVIPConfig`, single-network for public/private split, `data.external.cluster_state` curl probe for `data.hcloud_certificates.state`).

## [4.0.0-pre.3] - 2026-05-04

Phase B remainder of the upstream 4.0.0 alignment. User-facing variable renames and the new `talos_certificates` variable for TrustedRootsConfig support. No Talos OS upgrade, no machine_secrets touch — but the machine_configuration hash changes for every node, so a staged rolling reboot is triggered if `talos_machine_configuration_apply_mode` is `staged` (default `auto` reboots immediately).

### Added
- `talos_certificates` variable — accepts a map of TrustedRootsConfig documents. Each entry becomes a separate Talos config document appended to `config_patches`. Useful for adding corporate / internal CA bundles to node trust stores. Schema and validation match upstream 4.0.0.

### Renamed (BREAKING)
- `talos_extra_host_entries` → `talos_static_hosts`. Field `aliases` → `hostnames`. Update any `terraform.tfvars` using the old name.
- `talos_time_servers` → `talos_ntp_servers`. Update any `terraform.tfvars` using the old name.

### Notes
- The port still emits the legacy `machine.network.extraHostEntries` Talos field internally — `talos_static_hosts` is mapped to it via a compatibility shim until Phase C migrates the whole Talos config to multi-document and switches to the `StaticHostConfig` document type.
- `talos_certificates` patches are added as additional YAML documents in the existing `config_patches` list. The Talos provider already accepts multi-document `config_patches`; no full multi-document refactor was needed for this variable.

### Upstream
- Aligned with [terraform-hcloud-kubernetes 4.0.0](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/tag/4.0.0) — partial. Multi-document Talos config refactor (LinkConfig, VolumeConfig, ResolverConfig, TimeSyncConfig, StaticHostConfig) remains in Phase C.

## [4.0.0-pre.2] - 2026-05-04

Phase A of the upstream 4.0.0 alignment, revised. Pulls in the `siderolabs/talos` provider bump together with the coupled `on_destroy` / `cluster_graceful_destroy` removal, after `4.0.0-pre.1` apply failed at `talos_machine_configuration_apply` with HTTP 422 — root cause traced to a known issue in provider `0.10.1` ("empty resolved_apply_mode when reusing state") fixed in `0.11.0`.

### Added
- `talos_machine_secrets` output — exposes raw machine secrets for use with other Terraform providers or external tooling.

### Changed
- Default `talos_version` bumped from `v1.12.6` to `v1.12.7`.
- Default `cert_manager_helm_version` bumped from `v1.19.4` to `v1.20.2`.
- `siderolabs/talos` provider bumped from `0.10.1` to `0.11.0`.

### Removed (BREAKING)
- `cluster_graceful_destroy` variable. Upstream removed it in 4.0.0; the variable is no longer accepted. Set graceful destroy via Talos client tooling outside the module if needed.
- `on_destroy { graceful, reset, reboot }` blocks on `talos_machine_configuration_apply` resources. Required by provider `0.11.0`, which no longer accepts these fields with computed values.

### Notes
- Talos CCM Helm chart `0.5.4` already pulls appVersion `v1.12.0`; no chart bump needed despite upstream bumping its raw daemonset URL to `v1.12.0`.
- Curl prerequisite check was already aligned in 3.30.x and is unchanged.
- Provider bump and `on_destroy` removal are coupled: provider `0.11.0` rejects the `on_destroy.graceful` field when its value is computed at plan time. Both changes ship together.
- This release stays compatible with existing clusters that did **not** set `cluster_graceful_destroy` explicitly — its previous default (`true`) had no on-cluster effect because the matching `on_destroy` block also went away. Users who relied on explicit destroy-time draining must orchestrate that step themselves.

### Upstream
- Aligned with [terraform-hcloud-kubernetes 4.0.0](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/tag/4.0.0) — partial. Variable renames, `talos_certificates` and the multi-document Talos config refactor remain in Phases B and C.

## [4.0.0-pre.1] - 2026-05-04 [YANKED]

First Phase A attempt. Apply against an existing cluster failed at `talos_machine_configuration_apply` with HTTP 422; do not use. See `4.0.0-pre.2` for the working version.

### Added
- `talos_machine_secrets` output — exposes raw machine secrets for use with other Terraform providers or external tooling.

### Changed
- Default `talos_version` bumped from `v1.12.6` to `v1.12.7`.
- Default `cert_manager_helm_version` bumped from `v1.19.4` to `v1.20.2`.

### Notes
- The `siderolabs/talos` provider was kept at `0.10.1` to avoid the (apparent) coupling between provider `0.11.0` and the `on_destroy` block. This was the wrong call: provider `0.10.1` has a known bug where `talos_machine_configuration_apply.resolved_apply_mode` becomes empty when reusing state, which the Talos API rejects with HTTP 422. Resolved in `4.0.0-pre.2`.

## [3.30.2] - 2026-04-09

First tagged release of the Proxmox port, based on upstream `terraform-hcloud-kubernetes` `3.30.2`.

### Added
- Proxmox-specific module structure: `proxmox_virtual_environment_vm` instead of `hcloud_server`, Talos Layer2 VIP instead of Hetzner LB / floating IPs, Proxmox CCM auto-provisioning (user, role, token, secret) alongside Talos CCM for CSR approval.
- ISO download via `proxmox_download_file` instead of Packer image builds.
- Optional dedicated storage disk per worker (`storage_disk_size`) for Longhorn / Piraeus.
- Piraeus / LINSTOR preparation (DRBD extension, kernel modules) when `piraeus_enabled = true`.
- Optional per-nodepool `proxmox_node` for multi-host clusters; falls back to `var.proxmox_node` when null.
- `talos_iso_checksum` variable for optional SHA256 verification of the downloaded ISO.
- Preflight checks (`preflight.tf`): VM ID base ≥ 100 and Proxmox storage pool existence per target host.
- Outputs: `control_plane_vm_ids`, `worker_vm_ids`, `proxmox_ccm_token_id`, `cilium_encryption_info`.

### Removed
- Hetzner-only features that have no Proxmox equivalent: `autoscaler.tf`, `firewall.tf`, `floating_ip.tf`, `hcloud.tf`, `ingress_nginx.tf`, `load_balancer.tf`, `placement_group.tf`, `rdns.tf`, `ssh_key.tf`, `packer/`.
- Fixed: removed `dm-crypt` from Piraeus kernel modules (built-in to the Talos kernel).

### Upstream
- Aligned with [terraform-hcloud-kubernetes 3.30.2](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes/releases/tag/3.30.2).

---

## Alignment Plan

The port tracks upstream `terraform-hcloud-kubernetes` and ports each upstream release in phases when changes are large.

| Phase | Scope | Risk | Status |
|---|---|---|---|
| A | Provider bumps, default-version bumps, additive output, `cluster_graceful_destroy` + `on_destroy` removal (coupled with provider 0.11.0) | low | **Released as 4.0.0-pre.2** |
| B | Variable renames (`talos_extra_host_entries` → `talos_static_hosts`, `talos_time_servers` → `talos_ntp_servers`), `talos_certificates` variable | breaking for users of the renamed variables | **Released as 4.0.0-pre.3** |
| C | Talos config refactor: split `talos_config.tf` into `talos_config_base.tf` / `talos_config_control_plane.tf` / `talos_config_worker.tf`; migrate to multi-document Talos config (VolumeConfig, ResolverConfig, TimeSyncConfig, StaticHostConfig, TrustedRootsConfig, Layer2VIPConfig, HostnameConfig) | high (machine_configuration hash changes for every node, triggers staged rolling reboot) | **Released as 4.0.0** |
| D | Polish, README updates, upgrade notes | low | planned |

[4.0.0]: https://git.lab.haferbeck.it/devops/proxmox-kubernetes/-/compare/4.0.0-pre.3...4.0.0
[4.0.0-pre.3]: https://git.lab.haferbeck.it/devops/proxmox-kubernetes/-/compare/4.0.0-pre.2...4.0.0-pre.3
[4.0.0-pre.2]: https://git.lab.haferbeck.it/devops/proxmox-kubernetes/-/compare/3.30.2...4.0.0-pre.2
[4.0.0-pre.1]: https://git.lab.haferbeck.it/devops/proxmox-kubernetes/-/compare/3.30.2...4.0.0-pre.1
[3.30.2]: https://git.lab.haferbeck.it/devops/proxmox-kubernetes/-/tags/3.30.2
