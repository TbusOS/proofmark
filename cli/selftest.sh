#!/usr/bin/env bash
# selftest.sh — install into a throwaway directory and check what landed.
#
# The case worth being careful about is the third block: refusing to replace
# something that is already there. Getting that wrong once, on a machine where
# someone keeps their own design work under the same names, is the kind of thing
# a tool does not recover from.

set -uo pipefail
PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CLI="node $ROOT/cli/proofmark.mjs"
cd "$ROOT"

pass=0; fail=0
t() { if [ "$1" = "$2" ]; then echo "  ok   $3"; pass=$((pass+1));
      else echo "  FAIL $3 (expected $2, got $1)"; fail=$((fail+1)); fi; }
has() { case "$1" in *"$2"*) t y y "$3";; *) t n y "$3";; esac; }
hasnt() { case "$1" in *"$2"*) t n y "$3";; *) t y y "$3";; esac; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "cli surface"
out="$($CLI 2>&1)"; rc=$?
t "$rc" "2" "no command exits 2 and prints help"
has "$out" "npx github:TbusOS/proofmark" "help names the invocation that needs no publish"
out="$($CLI --help 2>&1)"; rc=$?
t "$rc" "0" "--help exits 0"
out="$($CLI nonsense 2>&1)"; rc=$?
t "$rc" "2" "an unknown command exits 2"
out="$($CLI install --bogus 2>&1)"; rc=$?
t "$rc" "2" "an unknown flag exits 2"

echo "install"
out="$($CLI install --dir=$T/a --dry-run 2>&1)"
t "$([ -d "$T/a/skills" ] && echo yes || echo no)" "no" "--dry-run writes nothing"
out="$($CLI install --dir=$T/a 2>&1)"
t "$(ls "$T/a/skills" 2>/dev/null | wc -l | tr -d ' ')" "12" "12 skills land"
t "$(ls "$T/a/agents" 2>/dev/null | wc -l | tr -d ' ')" "6" "6 agents land"
t "$(ls "$T/a/commands" 2>/dev/null | wc -l | tr -d ' ')" "2" "2 commands land"
t "$([ -f "$T/a/.proofmark-installed.json" ] && echo yes || echo no)" "yes" "a manifest is written"
t "$(python3 -c "import json;print(len(json.load(open('$T/a/.proofmark-installed.json'))['entries']))")" "20" \
  "the manifest lists every entry"
t "$([ -L "$T/a/skills/glass-design" ] && echo link || echo copy)" "link" \
  "a git checkout links by default, so a pull updates the skills"
out="$($CLI install --dir=$T/b --copy 2>&1)"
t "$([ -L "$T/b/skills/glass-design" ] && echo link || echo copy)" "copy" "--copy makes real directories"
t "$([ -f "$T/b/skills/glass-design/SKILL.md" ] && echo yes || echo no)" "yes" "the copy has content"

echo "install · refusing to clobber"
mkdir -p "$T/c/skills/glass-design" && echo "someone else's work" > "$T/c/skills/glass-design/SKILL.md"
out="$($CLI install --dir=$T/c 2>&1)"
has "$out" "left alone" "an unrelated directory is reported, not replaced"
has "$out" "glass-design" "the report names it"
t "$(cat "$T/c/skills/glass-design/SKILL.md")" "someone else's work" "its content is untouched"
t "$(ls "$T/c/skills" | wc -l | tr -d ' ')" "12" "the other 11 still install"
out="$($CLI install --dir=$T/c --force 2>&1)"
t "$([ -L "$T/c/skills/glass-design" ] && echo link || echo other)" "link" "--force replaces it"

echo "install · idempotent"
before="$(ls -1 "$T/a/skills" | sort | md5 2>/dev/null || ls -1 "$T/a/skills" | sort | md5sum)"
out="$($CLI install --dir=$T/a 2>&1)"
hasnt "$out" "left alone" "re-installing over our own entries reports no conflict"
after="$(ls -1 "$T/a/skills" | sort | md5 2>/dev/null || ls -1 "$T/a/skills" | sort | md5sum)"
t "$before" "$after" "re-installing changes nothing"

echo "doctor"
out="$($CLI doctor --dir=$T/a 2>&1)"; rc=$?
t "$rc" "0" "doctor exits 0"
has "$out" "20 ours" "doctor counts what it installed"
out="$($CLI doctor --dir=$T/empty 2>&1)"
has "$out" "0 ours" "doctor on an empty dir says nothing is installed"

echo "uninstall"
out="$($CLI uninstall --dir=$T/a --dry-run 2>&1)"
t "$(ls "$T/a/skills" | wc -l | tr -d ' ')" "12" "--dry-run removes nothing"
out="$($CLI uninstall --dir=$T/a 2>&1)"
t "$(ls "$T/a/skills" 2>/dev/null | wc -l | tr -d ' ')" "0" "uninstall clears the skills"
t "$([ -f "$T/a/.proofmark-installed.json" ] && echo yes || echo no)" "no" "the manifest goes too"
# The thing it must not do: remove what it did not install.
mkdir -p "$T/d/skills/mine" && echo x > "$T/d/skills/mine/SKILL.md"
out="$($CLI uninstall --dir=$T/d 2>&1)"
has "$out" "nothing to remove" "with no manifest it removes nothing"
t "$([ -f "$T/d/skills/mine/SKILL.md" ] && echo yes || echo no)" "yes" "an unrelated skill survives uninstall"

echo "package"
t "$(python3 -c "import json;print(json.load(open('$ROOT/package.json')).get('dependencies','{}') == {} or json.load(open('$ROOT/package.json')).get('dependencies') is None)")" "True" \
  "no runtime dependencies, so npx starts without downloading a browser"
t "$(python3 -c "import json;print('proofmark' in json.load(open('$ROOT/package.json'))['bin'])")" "True" \
  "the bin is called proofmark"

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
