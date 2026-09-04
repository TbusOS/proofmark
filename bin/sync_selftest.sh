#!/usr/bin/env bash
# sync_selftest.sh — break the drift check on purpose and require it to notice.
#
# bin/sync-from-upstream.sh reporting "in step" is worthless until it has been
# seen to fail. This breaks it three ways and restores each time.

set -uo pipefail
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO"

pass=0; fail=0
t() { if [ "$1" = "$2" ]; then echo "  ok   $3"; pass=$((pass+1));
      else echo "  FAIL $3 (expected $2, got $1)"; fail=$((fail+1)); fi; }

echo "baseline"
out=$(bin/sync-from-upstream.sh 2>&1); rc=$?
t "$rc" "0" "clean tree reports in step"
if [ "$rc" -ne 0 ]; then
  echo "$out" | tail -5
  echo "  (tree already drifted; run --pull first, self-test cannot proceed)"
  exit 1
fi

PROBE=skills/glass-design/SKILL.md
echo "mutation 1 · one appended byte"
cp "$PROBE" "$PROBE.selftest-bak"
printf '\n<!-- drift probe -->\n' >> "$PROBE"
out=$(bin/sync-from-upstream.sh 2>&1); rc=$?
t "$rc" "1" "modified file exits 1"
case "$out" in *"differs:"*"glass-design/SKILL.md"*) t y y "modified file is named" ;;
                *) t n y "modified file is named" ;; esac
mv "$PROBE.selftest-bak" "$PROBE"

PROBE2=skills/eclat-design/SKILL.md
echo "mutation 2 · file removed here"
mv "$PROBE2" "$PROBE2.selftest-bak"
out=$(bin/sync-from-upstream.sh 2>&1); rc=$?
t "$rc" "1" "missing file exits 1"
case "$out" in *"missing here:"*"eclat-design/SKILL.md"*) t y y "missing file is named" ;;
                *) t n y "missing file is named" ;; esac
mv "$PROBE2.selftest-bak" "$PROBE2"

echo "mutation 3 · a pull must not strip the executable bit"
# The rename pass used to write a new file and mv it over the original, which
# replaced the inode and its mode. Every executable in the synced tree lost +x
# on each pull, silently, and the drift check cannot see a mode change.
before_mode="$(ls -l bin/design-review | cut -c1-10)"
case "$before_mode" in
  -rwx*) t "y" "y" "bin/design-review is executable before the pull" ;;
  *)     t "n" "y" "bin/design-review is executable before the pull" ;;
esac

echo "mutation 4 · the deliberate divergence stays quiet"
out=$(bin/sync-from-upstream.sh 2>&1); rc=$?
t "$rc" "0" "restored tree is back in step"
case "$out" in *"facts.mjs"*) t y n "facts.mjs is not reported" ;;
                *) t n n "facts.mjs is not reported" ;; esac

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
