# Contributing

Thanks for your interest in improving this module. This document explains how the project is developed and how external contributions flow through it.

## Repository topology

This module is developed on GitLab and mirrored to GitHub:

| Forge | Role | URL |
|-------|------|-----|
| GitLab | Source of truth. Primary CI/CD. Releases are cut here. Project is publicly readable; sign-up is invite-only. | https://git.lab.haferbeck.it/devops/terraform-modules/proxmox-kubernetes |
| GitHub | Public mirror. Terraform Registry source. Issue tracker and contributor inbox. | https://github.com/haferbeck/terraform-proxmox-kubernetes |

Tags and `main` are pushed one-way GitLab → GitHub. Direct commits to `main` on GitHub are overwritten by the next mirror cycle.

**For external contributors GitHub is the contribution channel.** The GitLab instance does not allow self-registration, so only invited collaborators can fork and open merge requests there. Anyone can read the GitLab project (browse code, view CI runs, read MRs) without an account.

## Filing issues

Use [GitHub Issues](https://github.com/haferbeck/terraform-proxmox-kubernetes/issues). Pick the appropriate template (Bug Report / Feature Request). For general questions, use [Discussions](https://github.com/haferbeck/terraform-proxmox-kubernetes/discussions).

## Submitting changes

### Default path — GitHub pull request

1. Fork https://github.com/haferbeck/terraform-proxmox-kubernetes on GitHub.
2. Push your branch and open a pull request against `main`.
3. The maintainer pulls the PR branch into GitLab using the helper script (see below).
4. Re-base on `main`, run the full GitLab CI/CD pipeline (lint, IaC SAST, validate, tests).
5. Open and merge a corresponding GitLab merge request, preserving your authorship via `Co-Authored-By:`.
6. The mirror replays the merge commit back to GitHub. The GitHub PR is closed with a link to the merged commit.

Your authorship is preserved end-to-end. Commit author and `Co-Authored-By:` headers travel with the commits, so you remain the credited author of your changes.

### Invited collaborators — direct GitLab merge request

If you have a collaborator account on https://git.lab.haferbeck.it (invite-only), you can:

1. Fork the GitLab project.
2. Push your branch and open a merge request against `main` directly.
3. CI runs automatically. The maintainer reviews and merges.
4. The mirror replays the merge commit to GitHub.

This path is reserved for trusted contributors who maintain the module regularly.

## Maintainer workflow — integrating a GitHub PR

```sh
./scripts/integrate-github-pr.sh <pr-number>
```

This fetches `pull/<n>/head` from GitHub, rebases onto `main`, and leaves a local branch ready to push to GitLab as a merge request.

## Conventional Commits

This repository follows [Conventional Commits](https://www.conventionalcommits.org/). Examples:

```
feat(server): add per-nodepool placement override
fix(talos): correct dm-thin-pool kernel module name
chore(deps): bump bpg/proxmox to 0.100.0
docs(readme): clarify storage_disk_size requirement
```

The CI commit-message check enforces the format on all branches.

## Upstream parity

This module is a Proxmox VE port of [terraform-hcloud-kubernetes](https://github.com/hcloud-k8s/terraform-hcloud-kubernetes) by VantaLabs. Upstream-merge-ability is a hard project goal. Please:

- Match upstream variable names, output schemas, and file layout where applicable.
- Limit divergence to Proxmox-only files (`preflight.tf`, `proxmox_ccm.tf`, `talos_ccm.tf`) and Proxmox-required resource swaps.
- Do not add features the upstream module lacks unless they have an explicit Proxmox justification.

If unsure, open a Discussion before opening a PR.

## Local checks before opening a PR

```sh
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
terraform-docs .
```

The pipeline runs the same checks plus IaC SAST (KICS + Trivy config) and tflint. Pre-commit hooks are recommended once they are committed to this repository.

## Code of Conduct

This project follows the [Contributor Covenant 3.0](CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
