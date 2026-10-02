#!/usr/bin/env bash
# capture.sh — copy this Mac's global Claude config into claude/
#
# Safe to repeat. Builds the copy in a temp folder, checks it for secrets,
# and only then replaces claude/. If a secret is found, claude/ is untouched.
set -euo pipefail

SRC="${CLAUDE_HOME:-$HOME/.claude}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/claude"

# What gets captured. Everything else in ~/.claude (projects, todos, logs,
# login state in ~/.claude.json) is machine-local and never copied.
FILES=(CLAUDE.md settings.json)
DIRS=(skills agents commands hooks)

die() { echo "capture: $*" >&2; exit 1; }

[ -d "$SRC" ] || die "no Claude config at $SRC"
command -v jq >/dev/null || die "jq is missing. Run: mise install"
command -v rsync >/dev/null || die "rsync is missing"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# settings.json: drop env entries whose names look like secrets
if [ -f "$SRC/settings.json" ]; then
  jq 'if has("env") then
        .env |= with_entries(select(.key | test("TOKEN|KEY|SECRET|PASSWORD|CREDENTIAL"; "i") | not))
      else . end' "$SRC/settings.json" > "$TMP/settings.json" \
    || die "settings.json is not valid JSON"
fi

[ -f "$SRC/CLAUDE.md" ] && cp "$SRC/CLAUDE.md" "$TMP/CLAUDE.md"

for d in "${DIRS[@]}"; do
  if [ -d "$SRC/$d" ]; then
    mkdir -p "$TMP/$d"
    rsync -a --exclude '.DS_Store' "$SRC/$d/" "$TMP/$d/"
  fi
done

# Secret check: stop if anything token-shaped got through
PATTERNS='sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}'
if grep -rEIl "$PATTERNS" "$TMP" >/dev/null 2>&1; then
  echo "capture: possible secret in these files (claude/ was not changed):" >&2
  grep -rEIl "$PATTERNS" "$TMP" | sed "s|^$TMP|  $SRC|" >&2
  exit 1
fi

# Replace claude/ with the checked copy (mirror: things removed on the Mac go too)
mkdir -p "$DEST"
rsync -a --delete "$TMP/" "$DEST/"

if [ -n "$(git -C "$REPO" status --porcelain -- claude 2>/dev/null)" ]; then
  echo "capture: claude/ updated. Changes:"
  git -C "$REPO" status --short -- claude
  echo "Review with: git diff -- claude"
else
  echo "capture: already up to date."
fi
