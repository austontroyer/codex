#!/usr/bin/env bash

set -euo pipefail

# Sync this fork with upstream/openai/codex and create a PR.
# Usage:
#   scripts/sync-upstream.sh            # create a PR merging upstream/main into fork main
#   scripts/sync-upstream.sh --ff       # fast-forward local + origin main when safe

MODE="pr"
if [[ "${1:-}" == "--ff" ]]; then
  MODE="ff"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

current_branch=$(git rev-parse --abbrev-ref HEAD)

# Ensure remotes
if ! git remote get-url upstream >/dev/null 2>&1; then
  git remote add upstream https://github.com/openai/codex.git
fi

echo "Fetching remotes…"
git fetch origin --prune
git fetch upstream --prune

# Optionally stash local changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Stashing local changes…"
  git stash push -u -m "codex upstream sync WIP" >/dev/null
  STASHED=1
else
  STASHED=0
fi

if [[ "$MODE" == "ff" ]]; then
  # Fast-forward local main to upstream/main when possible, then push to origin
  echo "Attempting fast-forward of main to upstream/main…"
  git checkout main
  # Use upstream/main as the source of truth; error if diverged
  if git merge-base --is-ancestor main upstream/main; then
    git merge --ff-only upstream/main
    git push origin main
    echo "Fast-forwarded main to upstream/main and pushed to origin."
  else
    echo "Cannot fast-forward: main has local commits. Use PR mode instead." >&2
    exit 1
  fi
else
  # Create a dedicated sync branch from origin/main and merge upstream/main
  ts=$(date +%Y%m%d-%H%M%S)
  branch="sync-upstream-${ts}"
  echo "Creating sync branch $branch from origin/main…"
  git checkout -B "$branch" origin/main
  set +e
  git merge --no-edit upstream/main
  status=$?
  set -e
  if [[ $status -ne 0 ]]; then
    echo "Merge has conflicts. Resolve then run: git add -A && git commit && git push -u origin $branch" >&2
    exit $status
  fi

  git push -u origin "$branch"

  if command -v gh >/dev/null 2>&1; then
    echo "Opening PR from $branch to main…"
    gh pr create --title "Sync fork with upstream/main" \
      --body "Automated sync: merge latest changes from openai/codex upstream into this fork's main." \
      --base main --head "$branch" || true
  else
    echo "gh CLI not found. Open a PR manually for branch $branch → main." >&2
  fi
fi

# Restore stashed changes if any
if [[ ${STASHED:-0} -eq 1 ]]; then
  echo "Reapplying stashed local changes…"
  git checkout "$current_branch" || true
  git stash apply || true
fi

echo "Done."

