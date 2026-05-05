<!--
This repository is a read-only mirror of a private GitLab source of truth.

Pull requests opened on GitHub are accepted but are integrated by the maintainer
into GitLab and merged there. The merged commits are then mirrored back to
GitHub. Your authorship and any `Co-Authored-By:` headers are preserved.

See CONTRIBUTING.md for the full flow.
-->

## Summary

<!-- One short paragraph: what does this change and why? -->

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing usage to break)
- [ ] Documentation only

## Upstream parity

<!-- This module is a port of terraform-hcloud-kubernetes. -->

- [ ] This change has an upstream equivalent (link if possible)
- [ ] This change is Proxmox-specific (justification below)
- [ ] N/A (documentation, examples, CI)

## Test plan

<!-- How did you verify this change? -->

- [ ] `tofu fmt -check -recursive` passes
- [ ] `tofu init -backend=false && tofu validate` passes
- [ ] `terraform-docs .` produces no diff
- [ ] Tested against a real Proxmox node (describe hardware / VE version)
- [ ] No new homelab-specific or private values introduced (IPs, hostnames, secrets)

## Conventional Commit subject

<!-- Examples: feat(server): ..., fix(talos): ..., chore(deps): ..., docs: ... -->

```
<type>(<scope>): <subject>
```
