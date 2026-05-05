#!/usr/bin/env bash
# Pull a GitHub pull request branch into the local clone for integration via GitLab.
#
# Usage: ./scripts/integrate-github-pr.sh <pr-number> [target-branch]
#
# Result: a local branch `gh-pr-<num>` rebased on <target-branch> (default: main),
# ready to push to the GitLab origin and open as a merge request there.

set -euo pipefail

PR="${1:-}"
TARGET="${2:-main}"
GITHUB_REMOTE="github"
GITHUB_URL="https://github.com/haferbeck/terraform-proxmox-kubernetes.git"

if [[ -z "${PR}" ]]; then
  echo "[FAIL] missing pr number" >&2
  echo "usage: $0 <pr-number> [target-branch]" >&2
  exit 2
fi

if ! [[ "${PR}" =~ ^[0-9]+$ ]]; then
  echo "[FAIL] pr number must be numeric: ${PR}" >&2
  exit 2
fi

if ! git remote get-url "${GITHUB_REMOTE}" >/dev/null 2>&1; then
  echo "[INFO] adding remote '${GITHUB_REMOTE}' -> ${GITHUB_URL}"
  git remote add "${GITHUB_REMOTE}" "${GITHUB_URL}"
fi

LOCAL_BRANCH="gh-pr-${PR}"

echo "[INFO] fetching pull/${PR}/head from ${GITHUB_REMOTE}"
git fetch "${GITHUB_REMOTE}" "pull/${PR}/head:${LOCAL_BRANCH}"

echo "[INFO] switching to ${LOCAL_BRANCH}"
git switch "${LOCAL_BRANCH}"

echo "[INFO] rebasing onto ${TARGET}"
if ! git rebase "${TARGET}"; then
  cat >&2 <<EOF

[WARN] rebase hit conflicts. Resolve them, then:
       git add <files>
       git rebase --continue
       git push -u origin ${LOCAL_BRANCH}
EOF
  exit 1
fi

cat <<EOF

[OK] branch ${LOCAL_BRANCH} ready.

Next steps:
  git push -u origin ${LOCAL_BRANCH}
  open a GitLab merge request from ${LOCAL_BRANCH} -> ${TARGET}
  reference the GitHub PR in the MR description (Closes https://github.com/haferbeck/terraform-proxmox-kubernetes/pull/${PR})

After the GitLab MR is merged the GitHub mirror will replay the merge commit;
close the GitHub PR with a link to the merged commit.
EOF
