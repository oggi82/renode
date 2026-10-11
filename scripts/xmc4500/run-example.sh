#!/bin/bash
# usage: run-example.sh <Example|path/to.elf> [virtual-seconds=1] ["extra;monitor;commands"]
# Quick headless run of an example on the XMC4500 Relax Lite Kit platform. UART output of
# usic0ch0 appears in the log as '[INFO] usic0ch0: ... <text>'. Extra monitor commands run
# after the platform is loaded and before the emulation is started, e.g.
#   run-example.sh GPIO_Toggle 3 "logLevel -1 sysbus.nvic"
# To inspect state over time use a sequence of RunFor/read commands in the extra commands
# and pass 0 as the time, e.g. "emulation RunFor '1'; sysbus.port1.led1 State".
source "$(dirname "$0")/env.sh"
target="$1"; secs="${2:-1}"; extra="${3:-}"
[ -n "$target" ] || { echo "usage: $0 <Example|elf> [seconds] [commands]" >&2; exit 2; }
elf="$target"
if [ ! -f "$elf" ]; then
    "$XMC_ROOT/scripts/xmc4500/build-example.sh" "$target" > /dev/null || exit 1
    elf="$(xmc_elf_of "$target")"
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '$bin=@%s\ninclude @%s/scripts/single-node/xmc4500_relax_lite_kit.resc\n' "$elf" "$XMC_ROOT" > "$tmp/run.resc"
cd "$XMC_ROOT"
cmds="include @$tmp/run.resc"
[ -n "$extra" ] && cmds="$cmds; $extra"
[ "$secs" != 0 ] && cmds="$cmds; emulation RunFor '$secs'"
timeout 300 ./renode --disable-xwt --console --plain -e "$cmds; quit" 2>&1 \
  | grep -v "INFO\] \(sysbus: Loading\|XMC4500_Relax_Lite_Kit: Machine\|System bus\|Including\|Loaded\|cpu: Setting\)" \
  | grep -v '^$\|monitor) include\|^Renode, version\|Renode is quitting\|Disposed'
