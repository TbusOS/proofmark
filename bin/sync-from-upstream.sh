#!/usr/bin/env bash
# sync-from-upstream.sh — keep this repo's copy of the design skills in step
# with sky-skills, which is where they are edited.
#
# Two copies of the same files drift. The only thing that stops it is a check
# that fails, so this script is meant to be run, not remembered. `--check` is
# the default and exits non-zero the moment the two sides disagree.
#
#   bin/sync-from-upstream.sh                 # report drift, exit 1 if any
#   bin/sync-from-upstream.sh --pull          # overwrite this side from upstream
#   bin/sync-from-upstream.sh --check -v      # also list the differing lines
#
# Upstream is located in this order:
#   1. --upstream <path>
#   2. $PROOFMARK_UPSTREAM
#   3. ../sky-skills next to this repo
#   4. a shallow clone cached in .sync-cache/ (network needed)

set -euo pipefail
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_URL="https://github.com/TbusOS/sky-skills.git"

MODE=check
VERBOSE=0
UPSTREAM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check ;;
    --pull)  MODE=pull ;;
    -v|--verbose) VERBOSE=1 ;;
    --upstream) shift; UPSTREAM="${1:-}" ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# Paths carried from upstream, relative to both repo roots.
SYNCED=(
  skills/anthropic-design skills/apple-design skills/atelier-design
  skills/eclat-design skills/ember-design skills/glass-design
  skills/lectern-design skills/primer-design skills/sage-design
  skills/design-review skills/design-planner skills/design-evolve
  corpus
  hooks/design-gate
  bin/design-review
  .claude/agents/design-critic.md
  .claude/agents/design-brand-critic.md
  .claude/agents/design-composition-critic.md
  .claude/agents/design-copy-critic.md
  .claude/agents/design-illustration-critic.md
  .claude/agents/design-learner.md
  .claude/commands/design-distill.md
  .claude/commands/design-loop.md
)

# Files this repo deliberately diverges on. Each needs a reason, and each is
# re-listed after --pull so the edit is re-applied rather than silently lost.
declare -a DIVERGED_PATH=(
  "skills/design-review/scripts/facts.mjs"
  ".claude/agents/design-copy-critic.md"
)
declare -a DIVERGED_WHY=(
  "ROSTER and CORE_SURFACES describe this repo's 12 skills and 3 pages, not upstream's 22 and 13"
  "the prose-style file is read from \$DESIGN_LANGUAGE_RULES or \$HOME, not one author's absolute path"
)

# Files that must NOT exist here, though they exist upstream. rsync --delete
# brings them straight back on every --pull, and a printed reminder to remove
# them again is the kind of instruction that gets followed twice and then
# forgotten, so --pull deletes them itself.
declare -a DELETED_PATH=(
  "skills/design-review/baselines/demos__atelier-design__diagrams--as-authored.png"
  "skills/design-review/baselines/demos__atelier-design__index--as-authored.png"
)
declare -a DELETED_WHY=(
  "pixel baseline for a demo page this repo does not carry (upstream's repo-story index)"
  "same"
)

if [ -z "$UPSTREAM" ]; then
  if [ -n "${PROOFMARK_UPSTREAM:-}" ]; then
    UPSTREAM="$PROOFMARK_UPSTREAM"
  elif [ -d "$REPO/../sky-skills/skills" ]; then
    UPSTREAM="$(cd "$REPO/../sky-skills" && pwd)"
  else
    UPSTREAM="$REPO/.sync-cache/sky-skills"
    if [ ! -d "$UPSTREAM/skills" ]; then
      echo "cloning upstream into .sync-cache/ (one time) …"
      mkdir -p "$REPO/.sync-cache"
      git clone --depth 1 -q "$UPSTREAM_URL" "$UPSTREAM"
    else
      git -C "$UPSTREAM" pull -q --ff-only || true
    fi
  fi
fi

[ -d "$UPSTREAM/skills" ] || { echo "upstream not found at: $UPSTREAM" >&2; exit 2; }
echo "upstream: $UPSTREAM"
echo "repo:     $REPO"
echo

is_diverged() {
  local p="$1" d
  for d in "${DIVERGED_PATH[@]}"; do [ "$p" = "$d" ] && return 0; done
  for d in "${DELETED_PATH[@]}"; do [ "$p" = "$d" ] && return 0; done
  return 1
}

# This repo carries its own name where upstream carries its. That rename is a
# systematic transform, not a divergence, so it is undone on the upstream side
# before comparing — otherwise every renamed file would report as drift forever
# and the check would be ignored within a week.
rename_upstream() {
  sed -e 's/sky-skills/proofmark/g' -e 's/Sky Skills/proofmark/g' "$1"
}

same_content() {
  local up="$1" here="$2"
  if LC_ALL=C grep -qI . "$up" 2>/dev/null; then      # text
    rename_upstream "$up" | cmp -s - "$here"
  else                                                # binary: compare as-is
    cmp -s "$up" "$here"
  fi
}

drift=0
missing=0
for rel in "${SYNCED[@]}"; do
  src="$UPSTREAM/$rel"
  dst="$REPO/$rel"
  if [ ! -e "$src" ]; then
    echo "✗ gone upstream: $rel"
    missing=$((missing + 1)); continue
  fi
  # Compare file-by-file so a deliberately diverged file can be excluded.
  while IFS= read -r f; do
    sub="${f#"$UPSTREAM"/}"
    is_diverged "$sub" && continue
    other="$REPO/$sub"
    if [ ! -e "$other" ]; then
      echo "✗ missing here:  $sub"
      drift=$((drift + 1))
    elif ! same_content "$f" "$other"; then
      echo "✗ differs:       $sub"
      [ "$VERBOSE" = 1 ] && diff -u "$other" <(rename_upstream "$f") | sed -n '3,12p' | sed 's/^/      /'
      drift=$((drift + 1))
    fi
  done < <(find "$src" -type f ! -name '.DS_Store' 2>/dev/null)
done

if [ "$MODE" = pull ]; then
  echo
  for rel in "${SYNCED[@]}"; do
    [ -e "$UPSTREAM/$rel" ] || continue
    mkdir -p "$(dirname "$REPO/$rel")"
    rsync -a --delete --exclude '.DS_Store' "$UPSTREAM/$rel" "$(dirname "$REPO/$rel")/"
  done
  # Re-apply the rename on everything just pulled.
  while IFS= read -r f; do
    LC_ALL=C grep -qI . "$f" 2>/dev/null || continue
    # Write back through the existing file rather than moving a new one over
    # it: `mv` replaces the inode and with it the mode, so every executable in
    # the synced tree would silently lose its +x on each pull. Redirecting into
    # the original truncates in place and keeps the mode.
    rename_upstream "$f" > "$f.renamed" && cat "$f.renamed" > "$f" && rm -f "$f.renamed"
  done < <(for rel in "${SYNCED[@]}"; do [ -e "$REPO/$rel" ] && find "$REPO/$rel" -type f; done)
  for i in "${!DELETED_PATH[@]}"; do
    if [ -e "$REPO/${DELETED_PATH[$i]}" ]; then
      rm -f "$REPO/${DELETED_PATH[$i]}"
      echo "removed again: ${DELETED_PATH[$i]}  (${DELETED_WHY[$i]})"
    fi
  done
  echo "pulled $(( ${#SYNCED[@]} )) path(s) from upstream, upstream name rewritten to this repo's."
  echo
  echo "Re-apply these deliberate divergences before committing — they are content"
  echo "edits, so no script can restore them for you:"
  for i in "${!DIVERGED_PATH[@]}"; do
    echo "  · ${DIVERGED_PATH[$i]}"
    echo "      ${DIVERGED_WHY[$i]}"
  done
  exit 0
fi

echo
if [ "$drift" -eq 0 ] && [ "$missing" -eq 0 ]; then
  echo "✓ in step with upstream ($(( ${#SYNCED[@]} )) path(s); ${#DIVERGED_PATH[@]} deliberate divergence(s) and ${#DELETED_PATH[@]} deliberate deletion(s) skipped)"
  exit 0
fi
echo "✗ $drift file(s) drifted, $missing path(s) gone upstream"
echo "  bin/sync-from-upstream.sh --pull   overwrites this side from upstream"
exit 1
