#!/bin/bash
# usage: resolve-repl-conflict.sh <test-name-for-tests.yaml|->
# After merge-workspace.sh left conflicts only in platforms/cpus/xmc4500.repl (two components appended blocks)
# and in the src/Infrastructure pointer: keep both sides of the repl, take the merged submodule HEAD, commit.
source "$(dirname "$0")/env.sh"
cd "$XMC_ROOT"
python3 - <<'PY'
p='platforms/cpus/xmc4500.repl'
out=[]
for l in open(p).read().split('\n'):
    if l.startswith('<<<<<<< ') or l.startswith('>>>>>>> '): continue
    out.append('' if l=='=======' else l)
open(p,'w').write('\n'.join(out))
PY
grep -c '^<<<<<<<\|^>>>>>>>' platforms/cpus/xmc4500.repl
git add platforms/cpus/xmc4500.repl src/Infrastructure
git commit -q --no-edit
if [ "$1" != "-" ] && [ -n "$1" ]; then
    grep -q "xmc4500/$1.robot" tests/tests.yaml || { python3 - "$1" <<'PY'
import sys
p='tests/tests.yaml'
lines=open(p).read().rstrip('\n').split('\n')
i=max(k for k,l in enumerate(lines) if 'tests/platforms/xmc4500/' in l)
lines.insert(i+1,'- tests/platforms/xmc4500/%s.robot' % sys.argv[1])
open(p,'w').write('\n'.join(lines)+'\n')
PY
git add tests/tests.yaml; git commit -q -m "XMC4500: Register $1 test

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"; }
fi
