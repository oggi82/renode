#!/bin/bash
# usage: merge-workspace.sh <component>   (run in the main checkout, branch xmc4500)
# Merges the branch xmc4500-<component> from ../renode-xmc-<component> into the current branch,
# first the Infrastructure submodule, then the main repo.
source "$(dirname "$0")/env.sh"
comp="$1"; [ -n "$comp" ] || { echo "usage: $0 <component>" >&2; exit 2; }
src="$(dirname "$XMC_ROOT")/renode-xmc-$comp"
br="xmc4500-$comp"
set -e
git -C "$XMC_ROOT/src/Infrastructure" fetch "$src/src/Infrastructure" "$br:$br"
git -C "$XMC_ROOT/src/Infrastructure" merge --no-edit "$br"
git -C "$XMC_ROOT" fetch "$src" "$br:$br"
git -C "$XMC_ROOT" merge --no-edit "$br" || true
echo "If the main repo merge conflicted on the Infrastructure pointer, run:"
echo "  git add src/Infrastructure && git commit --no-edit"
