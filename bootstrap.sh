#!/bin/sh
# bootstrap.sh — macOS + Linux: install git and mise, fetch claude-rig, run it.
#
#   curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
#   curl -fsSL .../bootstrap.sh | sh -s -- --dry-run
#
# Safe to repeat. Each step checks first and acts only if something is missing.
# Arguments are passed on to tasks/rig.sh.
set -eu

RIG_REPO="${RIG_REPO:-https://github.com/joeblew999/claude-rig.git}"
RIG_REF="${RIG_REF:-main}"
RIG_DIR="${RIG_DIR:-$HOME/.claude-rig}"

say() { echo "bootstrap: $*"; }
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
else
  say "installing mise"
  curl -fsSL https://mise.run | sh
  have mise || die "mise did not install into $HOME/.local/bin"
fi

# --- 3. The rig itself -----------------------------------------------------

# Run from a checkout (bootstrap.sh sitting next to tasks/rig.sh): use it as is.
# Piped from curl: keep a clone in RIG_DIR and bring it up to date.
here="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
if [ -n "$here" ] && [ -f "$here/tasks/rig.sh" ]; then
  RIG_DIR="$here"
  say "ok       rig checkout at $RIG_DIR"
elif [ -d "$RIG_DIR/.git" ]; then
  git -C "$RIG_DIR" fetch -q origin "$RIG_REF"
  if [ "$(git -C "$RIG_DIR" rev-parse HEAD)" = "$(git -C "$RIG_DIR" rev-parse FETCH_HEAD)" ]; then
    say "ok       rig clone at $RIG_DIR"
  elif [ -n "$(git -C "$RIG_DIR" status --porcelain)" ]; then
    die "$RIG_DIR has local changes. Commit or discard them, then run again."
  else
    say "updating $RIG_DIR"
    git -C "$RIG_DIR" merge -q --ff-only FETCH_HEAD
  fi
else
  say "cloning the rig into $RIG_DIR"
  git clone -q --branch "$RIG_REF" "$RIG_REPO" "$RIG_DIR"
fi

exec bash "$RIG_DIR/tasks/rig.sh" "$@"
