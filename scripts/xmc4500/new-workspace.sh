#!/bin/bash
# usage: new-workspace.sh <component>
# Creates an isolated clone of this checkout (including build outputs, so builds stay incremental)
# at ../renode-xmc-<component> with branches xmc4500-<component> in the repo and in src/Infrastructure.
# Use it so that several people/agents can build and commit in parallel; merge back with merge-workspace.sh.
source "$(dirname "$0")/env.sh"
comp="$1"; [ -n "$comp" ] || { echo "usage: $0 <component>" >&2; exit 2; }
dest="$(dirname "$XMC_ROOT")/renode-xmc-$comp"
[ -e "$dest" ] && { echo "$dest exists" >&2; exit 1; }
base="$(git -C "$XMC_ROOT" rev-parse --abbrev-ref HEAD)"
cp -a "$XMC_ROOT" "$dest"
git -C "$dest" checkout -q -b "xmc4500-$comp" "$base"
git -C "$dest/src/Infrastructure" checkout -q -b "xmc4500-$comp"
echo "$dest (branch xmc4500-$comp, based on $base)"
