#!/usr/bin/env bash
# rig.sh — the main run: tools, Claude Code, Claude config.
#
# bootstrap.sh gets git and mise onto the machine and then runs this.
# Safe to repeat. Each step checks first and acts only if something is
# missing or out of date.
#
#   bash tasks/rig.sh [--dry-run]
set -euo pipefail

TASK=rig
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tasks/lib.sh
. "$REPO/tasks/lib.sh"
parse_flags "$@"

MISE_CONF_DIR="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"
MISE_SHIMS="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"
export PATH="$HOME/.local/bin:$MISE_SHIMS:$PATH"

if ! have mise; then
  [ "$DRY_RUN" = 1 ] || die "mise is missing. Run bootstrap.sh first."
fi

# --- Tools -----------------------------------------------------------------

echo "Tools"

TOOLS_SRC="$REPO/mise/claude-rig.toml"
TOOLS_DEST="$MISE_CONF_DIR/conf.d/claude-rig.toml"

install_tool_list() {
  mkdir -p "$(dirname "$TOOLS_DEST")"
  cp "$TOOLS_SRC" "$TOOLS_DEST"
}

# Run from the home folder so only the machine-wide tool list is in play.
install_tools() { (cd "$HOME" && mise install --yes); }

if cmp -s "$TOOLS_SRC" "$TOOLS_DEST" 2>/dev/null && have mise; then
  ok "tool list ($TOOLS_DEST)"
  if [ -z "$(cd "$HOME" && mise ls --current --missing 2>/dev/null)" ]; then
    ok "tools installed"
  else
    change "install the missing tools" install_tools
  fi
else
  change "install the tool list to $TOOLS_DEST" install_tool_list
  change "install the tools" install_tools
fi

# --- Shell PATH ------------------------------------------------------------

# New shells need ~/.local/bin (claude, mise) and the mise shims (every tool).
# A machine whose shell already sets up mise is left alone.

echo "Shell"

path_block() {
  cat >> "$1" <<'EOF'

# >>> claude-rig >>>
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
# <<< claude-rig <<<
EOF
}

case "$(basename "${SHELL:-sh}")" in
  zsh) rc_files=("$HOME/.zshrc") ;;
  bash) rc_files=("$HOME/.bashrc" "$HOME/.profile") ;;
  *) rc_files=("$HOME/.profile") ;;
esac

for rc in "${rc_files[@]}"; do
  if grep -qE 'claude-rig|mise activate|mise/shims' "$rc" 2>/dev/null; then
    ok "PATH in $rc"
  else
    change "add the tools to PATH in $rc" path_block "$rc"
  fi
done

# --- Claude Code -----------------------------------------------------------

echo "Claude Code"

install_claude() { curl -fsSL https://claude.ai/install.sh | bash; }

if have claude; then
  ok "claude ($(command -v claude))"
else
  change "install Claude Code with the native installer" install_claude
fi

# --- Claude config ---------------------------------------------------------

echo "Claude config"

if have jq; then
  bash "$REPO/tasks/apply.sh" "$@"
elif [ "$DRY_RUN" = 1 ]; then
  CHANGES=$((CHANGES + 1))
  echo "  would   apply claude/ to ~/.claude (details once the tools are installed)"
else
  die "jq is missing after the tools step. Run: mise doctor"
fi

if [ "$DRY_RUN" = 1 ]; then
  echo "rig: dry run finished. Nothing was changed."
else
  echo "rig: done."
fi
