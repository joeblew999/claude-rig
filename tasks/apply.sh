#!/usr/bin/env bash
# apply.sh — apply claude/ from this repo to this machine's ~/.claude
#
# Safe to repeat. Merges rather than overwrites:
#   - settings.json: rig keys are set, keys that exist only here are kept
#   - skills, agents, commands, hooks: rig entries are added or updated,
#     entries that exist only here are left alone
#   - CLAUDE.md: replaced, only if it differs
# The first run backs up everything it could touch. ~/.claude.json is never touched.
#
#   bash tasks/apply.sh [--dry-run]
set -euo pipefail

TASK=apply
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tasks/lib.sh
. "$REPO/tasks/lib.sh"
parse_flags "$@"

SRC="$REPO/claude"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
MANIFEST="$DEST/.rig-manifest"
DIRS=(skills agents commands hooks)

[ -d "$SRC" ] || die "no captured config at $SRC"
have jq || die "jq is missing. Run: mise install"

# --- Backup, once ----------------------------------------------------------

backup() {
  local to="$1" d
  mkdir -p "$to"
  [ -f "$DEST/settings.json" ] && cp -p "$DEST/settings.json" "$to/"
  [ -f "$DEST/CLAUDE.md" ] && cp -p "$DEST/CLAUDE.md" "$to/"
  for d in "${DIRS[@]}"; do
    [ -d "$DEST/$d" ] && cp -Rp "$DEST/$d" "$to/$d"
  done
  return 0
}

# The manifest is written at the end of the first run, so once it exists
# whatever is in ~/.claude has already been through the rig.
if compgen -G "$DEST.rig-backup-*" >/dev/null; then
  ok "backup (taken on the first run)"
elif [ -f "$MANIFEST" ]; then
  ok "backup (nothing was here before the first run)"
elif [ -d "$DEST" ]; then
  to="$DEST.rig-backup-$(date +%Y%m%d-%H%M%S)"
  change "back up the current config to $to" backup "$to"
else
  skip "backup (no $DEST yet)"
fi

[ "$DRY_RUN" = 1 ] || mkdir -p "$DEST"

# --- settings.json: merge ---------------------------------------------------

# Objects are merged key by key. Lists keep the rig's entries and add any
# that exist only here. For anything else the rig's value wins.
# shellcheck disable=SC2016
MERGE='
def rmerge($l; $r):
  if ($l | type) == "object" and ($r | type) == "object" then
    reduce ($r | keys_unsorted[]) as $k
      ($l; .[$k] = (if has($k) then rmerge($l[$k]; $r[$k]) else $r[$k] end))
  elif ($l | type) == "array" and ($r | type) == "array" then $r + ($l - $r)
  else $r end;
rmerge(.[0]; .[1])'

write_settings() { printf '%s\n' "$1" > "$DEST/settings.json"; }

if [ -f "$SRC/settings.json" ]; then
  if [ -f "$DEST/settings.json" ]; then
    jq -e . "$DEST/settings.json" >/dev/null 2>&1 \
      || die "$DEST/settings.json is not valid JSON. Fix it, then run again."
    merged="$(jq -s "$MERGE" "$DEST/settings.json" "$SRC/settings.json")"
    if [ "$(jq -S . <<<"$merged")" = "$(jq -S . "$DEST/settings.json")" ]; then
      ok "settings.json"
    else
      change "merge the rig's settings into settings.json" write_settings "$merged"
    fi
  else
    change "create settings.json" cp "$SRC/settings.json" "$DEST/settings.json"
  fi
fi

# --- CLAUDE.md: replace if different ---------------------------------------

if [ -f "$SRC/CLAUDE.md" ]; then
  if cmp -s "$SRC/CLAUDE.md" "$DEST/CLAUDE.md" 2>/dev/null; then
    ok "CLAUDE.md"
  else
    change "replace CLAUDE.md" cp "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
  fi
fi

# --- skills, agents, commands, hooks: sync entry by entry -------------------

replace_entry() {
  mkdir -p "$(dirname "$2")"
  rm -rf "$2"
  cp -R "$1" "$2"
}

entries=""
for d in "${DIRS[@]}"; do
  [ -d "$SRC/$d" ] || continue
  for path in "$SRC/$d"/*; do
    [ -e "$path" ] || continue
    entry="$d/$(basename "$path")"
    entries="$entries$entry"$'\n'
    if [ ! -e "$DEST/$entry" ]; then
      change "add $entry" replace_entry "$path" "$DEST/$entry"
    elif diff -rq -x .DS_Store "$path" "$DEST/$entry" >/dev/null 2>&1; then
      ok "$entry"
    else
      change "update $entry" replace_entry "$path" "$DEST/$entry"
    fi
  done
done

# Entries the rig put here on an earlier run and has since dropped are removed.
# Anything the rig never installed is not in the manifest, so it is left alone.
if [ -f "$MANIFEST" ]; then
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    if ! grep -qxF "$entry" <<<"$entries" && [ -e "$DEST/$entry" ]; then
      change "remove $entry (no longer in the rig)" rm -rf "${DEST:?}/$entry"
    fi
  done < "$MANIFEST"
fi

write_manifest() { printf '%s' "$entries" > "$MANIFEST"; }
if [ "$(cat "$MANIFEST" 2>/dev/null)" != "$(printf '%s' "$entries")" ]; then
  change "record what the rig installed in $MANIFEST" write_manifest
fi

if [ "$CHANGES" -eq 0 ]; then
  echo "apply: already up to date."
elif [ "$DRY_RUN" = 1 ]; then
  echo "apply: $CHANGES change(s) to make. Nothing was changed."
else
  echo "apply: $CHANGES change(s) made."
fi
