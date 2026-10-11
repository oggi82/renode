#!/bin/bash
# usage: test.sh <component> [renode-test args...]   run one component's robot test
#        test.sh all                                  run every tests/platforms/xmc4500/*.robot
#        test.sh list                                 list components that have a test
# Needs a built Renode (./build.sh --net) and the python venv from env.sh.
source "$(dirname "$0")/env.sh"
cd "$XMC_ROOT"
case "${1:-}" in
    ""|-h|--help) sed -n '2,5p' "$0"; exit 2 ;;
    list) ls tests/platforms/xmc4500/*.robot 2>/dev/null | xargs -n1 basename | sed 's/\.robot$//'; exit 0 ;;
    all)  shift; exec ./renode-test tests/platforms/xmc4500/*.robot "$@" ;;
esac
comp="$1"; shift
file="tests/platforms/xmc4500/$comp.robot"
[ -f "$file" ] || { echo "no such test: $file" >&2; exit 2; }
exec ./renode-test "$file" "$@"
