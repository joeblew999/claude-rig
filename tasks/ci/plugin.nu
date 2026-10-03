#!/usr/bin/env nu
# plugin.nu — `mise run ci:plugin`: `plugin:check` with Claude Code in place.
#
# In CI, Claude Code is installed first with its native installer, the one the
# rig uses; elsewhere it must already be there.
#
#   mise run ci:plugin

use ../lib.nu [is-windows local-bin have fail]
use common.nu *

def main [] {
  $env.PATH = [(local-bin)] ++ $env.PATH
  if not (have claude) {
    if ($env.CI? | default "") != "true" { fail ci:plugin "needs Claude Code (claude) on PATH" }
    if (is-windows) {
      ^powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex"
    } else {
      ^bash -c "curl -fsSL https://claude.ai/install.sh | bash"
    }
  }
  let claude = ^claude --version | complete
  check $"claude runs: ($claude.stdout | str trim)" ($claude.exit_code == 0)
  cd $REPO
  ^mise run plugin:check
}
