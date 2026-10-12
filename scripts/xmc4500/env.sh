#!/bin/bash
# Common environment for the XMC4500 helper scripts. Source it, do not execute it.
#   XMC_EXAMPLES_DIR  directory with the Infineon example projects (default: ~/mtw)
#   XMC_VENV          python venv with robotframework & co. (default: ~/.venvs/renode-xmc)
XMC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export XMC_ROOT
export XMC_EXAMPLES_DIR="${XMC_EXAMPLES_DIR:-$HOME/mtw}"
export XMC_VENV="${XMC_VENV:-$HOME/.venvs/renode-xmc}"
export XMC_TARGET="APP_KIT_XMC45_RELAX_V1"
export PATH="$XMC_VENV/bin:$PATH"

# Prints the path of the ELF a given example produces (the example must have been built)
xmc_elf_of() {
    local dir="$XMC_EXAMPLES_DIR/$1/build/$XMC_TARGET/Debug"
    ls "$dir"/*.elf 2>/dev/null | head -n 1
}
