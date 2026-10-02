# shellcheck shell=bash
# lib.sh — shared by the rig tasks. Source it, do not run it.
#
# Every change goes through `change`, so a run can report what it did and
# --dry-run can report what it would do without doing it.

DRY_RUN="${DRY_RUN:-0}"
CHANGES=0

die() { echo "$TASK: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ok <what> — the thing is already as it should be
ok() { printf '  ok      %s\n' "$1"; }

# skip <what> — nothing to do here, and why
skip() { printf '  skip    %s\n' "$1"; }

# change <what> <command...> — make a change, or only announce it on --dry-run
change() {
  local what="$1"
  shift
  CHANGES=$((CHANGES + 1))
  if [ "$DRY_RUN" = 1 ]; then
    printf '  would   %s\n' "$what"
  else
    printf '  change  %s\n' "$what"
    "$@"
  fi
}

parse_flags() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=1 ;;
      *) die "unknown option: $arg" ;;
    esac
  done
  export DRY_RUN
}
