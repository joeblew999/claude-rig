#!/bin/sh
# bootstrap.sh — macOS + Linux: install git and mise, fetch claude-rig, run it.
# The run itself is tasks/rig.nu, the same nushell code on every OS.
#
#   curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
#   curl -fsSL .../bootstrap.sh | sh -s -- --dry-run
#
# Safe to repeat. Each step checks first and acts only if something is missing.
# With --dry-run it changes nothing and reports what a real run would do.
# Arguments are passed on to tasks/rig.nu.
set -eu

DRY_RUN=0
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then DRY_RUN=1; fi
done

RIG_REPO="${RIG_REPO:-https://github.com/joeblew999/claude-rig.git}"
RIG_REF="${RIG_REF:-main}"
RIG_DIR="${RIG_DIR:-$HOME/.claude-rig}"

say() { echo "bootstrap: $*"; }
would() { say "would    $*"; }
die() { echo "bootstrap: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command as root: directly if we are root, through sudo otherwise.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    die "need root to run: $*  (no sudo on this machine)"
  fi
}

# --- 1. Base tools: git and curl ------------------------------------------

install_packages() {
  if have apt-get; then
    as_root apt-get update -qq
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
  elif have dnf; then
    as_root dnf install -y -q "$@"
  elif have pacman; then
    as_root pacman -Sy --noconfirm --needed "$@"
  elif have zypper; then
    as_root zypper --non-interactive install "$@"
  else
    die "no supported package manager (apt, dnf, pacman, zypper). Install by hand: $*"
  fi
}

# macOS ships a git stub that only works once the Command Line Tools are in.
install_macos_clt() {
  say "installing the Xcode Command Line Tools (needs sudo)"
  flag=/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  touch "$flag"
  label="$(softwareupdate -l 2>/dev/null |
    sed -n 's/^.*Label: \(Command Line Tools.*\)$/\1/p' | sort | tail -n 1)"
  [ -n "$label" ] || { rm -f "$flag"; die "could not find the Command Line Tools. Run: xcode-select --install"; }
  as_root softwareupdate -i "$label"
  rm -f "$flag"
}

case "$(uname -s)" in
  Darwin)
    if xcode-select -p >/dev/null 2>&1; then
      say "ok       git (Command Line Tools)"
    elif [ "$DRY_RUN" = 1 ]; then
      would "install the Xcode Command Line Tools (git)"
    else
      install_macos_clt
    fi
    ;;
  Linux)
    missing=""
    have git || missing="$missing git"
    have curl || missing="$missing curl ca-certificates"
    have bash || missing="$missing bash"
    if [ -z "$missing" ]; then
      say "ok       git, curl, bash"
    elif [ "$DRY_RUN" = 1 ]; then
      would "install$missing"
    else
      say "installing$missing"
      # shellcheck disable=SC2086
      install_packages $missing
    fi
    ;;
  *)
    die "unsupported OS: $(uname -s). On Windows use bootstrap.ps1"
    ;;
esac

# --- 2. mise ---------------------------------------------------------------

PATH="$HOME/.local/bin:$PATH"
export PATH
if have mise; then
  say "ok       mise"
elif [ "$DRY_RUN" = 1 ]; then
  would "install mise"
else
  say "installing mise"
  curl -fsSL https://mise.run | sh
  have mise || die "mise did not install into $HOME/.local/bin"
fi

# --- 3. The rig itself -----------------------------------------------------

# mise fetches the nushell version the tool list names, then nushell runs the rig.
run_rig() {
  dir="$1"
  shift
  nu_version="$(sed -n 's/^nu = "\(.*\)"$/\1/p' "$dir/mise/claude-rig.toml")"
  [ -n "$nu_version" ] || die "no nu version in $dir/mise/claude-rig.toml"
  if [ "$DRY_RUN" = 1 ]; then
    if ! have mise || ! mise where "nu@$nu_version" >/dev/null 2>&1; then
      would "install nushell $nu_version, then the tools, Claude Code and the Claude config"
      say "dry run finished. Nothing was changed."
      return 0
    fi
  fi
  # Piped from curl, stdin is this script. Hand the rig the terminal instead,
  # so the login step can ask its one question.
  if [ ! -t 0 ] && (: </dev/tty) 2>/dev/null; then
    MISE_YES=1 mise exec "nu@$nu_version" -- nu "$dir/tasks/rig.nu" "$@" </dev/tty
  else
    MISE_YES=1 mise exec "nu@$nu_version" -- nu "$dir/tasks/rig.nu" "$@"
  fi
}

# Run from a checkout (bootstrap.sh sitting next to tasks/rig.nu): use it as is.
# Piped from curl: keep a clone in RIG_DIR and bring it up to date.
here="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || here=""
if [ -n "$here" ] && [ -f "$here/tasks/rig.nu" ]; then
  RIG_DIR="$here"
  say "ok       rig checkout at $RIG_DIR"
elif [ "$DRY_RUN" = 1 ]; then
  # Look at the rig without leaving a clone behind.
  if [ -d "$RIG_DIR/.git" ]; then
    say "ok       rig clone at $RIG_DIR (a real run brings it up to date)"
  else
    would "keep a clone of the rig in $RIG_DIR"
  fi
  if ! have git; then
    would "then install nushell, the tools, Claude Code and the Claude config"
    say "dry run finished. Nothing was changed."
    exit 0
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone -q --depth 1 --branch "$RIG_REF" "$RIG_REPO" "$tmp/rig"
  run_rig "$tmp/rig" "$@"
  exit 0
elif [ -d "$RIG_DIR/.git" ]; then
  git -C "$RIG_DIR" fetch -q origin "$RIG_REF"
  if [ "$(git -C "$RIG_DIR" rev-parse HEAD)" = "$(git -C "$RIG_DIR" rev-parse FETCH_HEAD)" ]; then
    say "ok       rig clone at $RIG_DIR"
  elif [ -n "$(git -C "$RIG_DIR" status --porcelain)" ]; then
    die "$RIG_DIR has local changes. Commit or discard them, then run again."
  else
    say "updating $RIG_DIR"
    # Move to exactly what was fetched. This also works when the branch was
    # rewritten, or when RIG_REF names a different branch than last time.
    git -C "$RIG_DIR" checkout -q --detach FETCH_HEAD
  fi
else
  say "cloning the rig into $RIG_DIR"
  git clone -q --branch "$RIG_REF" "$RIG_REPO" "$RIG_DIR"
fi

run_rig "$RIG_DIR" "$@"
