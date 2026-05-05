# Security Policy

## Reporting a Vulnerability

Report security issues privately via [GitHub Security Advisories](https://github.com/haferbeck/terraform-proxmox-kubernetes/security/advisories/new).

Do **not** open public issues, discussions, or pull requests for security-relevant findings. Wait for an advisory to be published before disclosing details elsewhere.

When you submit an advisory please include:

- A description of the issue and its impact
- A minimal Terraform/OpenTofu configuration that reproduces it
- Affected module versions (`git rev-parse HEAD` or release tag)
- Provider versions in use (`bpg/proxmox`, `siderolabs/talos`, etc.)
- Any suggested mitigation if known

## Response Expectations

| Stage | Target |
|-------|--------|
| Acknowledgement | within 7 days |
| Triage and reproduction | within 14 days |
| Fix or mitigation plan | depending on severity, communicated in the advisory |

This module is maintained on a best-effort basis by an individual maintainer. Response times are targets, not contractual SLAs.

## Supported Versions

Only the latest minor release line receives security fixes. Older releases are not patched. Pin via the Terraform Registry (`version = "~> X.Y"`) and update regularly.

## Scope

In scope:

- Vulnerabilities in the module code itself (`*.tf`, `templates/`, `scripts/`)
- Insecure defaults that lead to exposure when the module is used as documented
- Secret-leakage paths through outputs, state, or generated artefacts

Out of scope:

- Vulnerabilities in upstream dependencies (`bpg/proxmox`, `siderolabs/talos`, Talos Linux, Kubernetes, Cilium, Longhorn, Piraeus, etc.) — please report those upstream
- Vulnerabilities in user-supplied configuration unless they result from an insecure default in this module
- Issues in the example configurations under `examples/` unless they propagate into the module itself
