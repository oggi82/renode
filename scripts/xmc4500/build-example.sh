#!/bin/bash
# usage: build-example.sh <Example> [<Example> ...]   (or "all" for every example)
# Builds Infineon example projects with 'make all' and prints the resulting ELF paths.
source "$(dirname "$0")/env.sh"
[ $# -ge 1 ] || { echo "usage: $0 <Example>... | all" >&2; exit 2; }
examples=("$@")
if [ "$1" = all ]; then
    examples=()
    for d in "$XMC_EXAMPLES_DIR"/*/; do [ -f "$d/Makefile" ] && examples+=("$(basename "$d")"); done
fi
rc=0
for e in "${examples[@]}"; do
    if (cd "$XMC_EXAMPLES_DIR/$e" && make all -j"$(nproc)" > "/tmp/xmc-build-$e.log" 2>&1); then
        echo "$e: $(xmc_elf_of "$e")"
    else
        echo "$e: BUILD FAILED (see /tmp/xmc-build-$e.log)" >&2; rc=1
    fi
done
exit $rc
