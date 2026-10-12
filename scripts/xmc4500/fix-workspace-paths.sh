#!/bin/bash
# usage: fix-workspace-paths.sh [old-root]
# After cloning a checkout with its build outputs (new-workspace.sh) the CMake caches of the cores still
# point to the original directory, and ./build.sh fails in the CMake step. This rewrites those paths.
source "$(dirname "$0")/env.sh"
cores="$XMC_ROOT/src/Infrastructure/src/Emulator/Cores/obj"
[ -d "$cores" ] || { echo "nothing to fix ($cores missing)"; exit 0; }
old="${1:-}"
if [ -z "$old" ]; then
    old="$(grep -h '^CMAKE_HOME_DIRECTORY' "$cores"/Release/*/le/CMakeCache.txt "$cores"/Release/*/CMakeCache.txt 2>/dev/null | head -n 1 | sed 's#.*=##; s#/src/Infrastructure/.*##')"
fi
[ -n "$old" ] && [ "$old" != "$XMC_ROOT" ] || { echo "paths already correct"; exit 0; }
grep -rIl -- "$old" "$cores" | xargs -r sed -i "s#${old}\([/ \"':;]\|\$\)#${XMC_ROOT}\1#g"
echo "rewrote $old -> $XMC_ROOT"
