# Convenience tasks for maintaining this fork

default:
    @just --list

# Sync fork with upstream via PR
sync-upstream:
    bash scripts/sync-upstream.sh

# Fast-forward main to upstream/main (no PR) when safe
sync-upstream-ff:
    bash scripts/sync-upstream.sh --ff

