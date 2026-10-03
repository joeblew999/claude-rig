# common.nu — what the CI checks in tasks/ci/ share: how a check passes or
# fails, how the bootstrap is run from this checkout, and the PATH a new shell
# on the machine has.

use ../lib.nu [is-windows local-bin mise-shims fail]

# The top folder of this repo.
export const REPO = path self ../..

# Say a check passed, or stop with what failed.
export def check [what: string, passed: bool] {
  if not $passed { error make --unspanned { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# These checks rig the machine they run on. Run them only in CI, or with the
# home folder (HOME, and USERPROFILE on Windows) set to a throwaway folder
# under the temp folder.
export def guard [task: string] {
  let ci = ($env.CI? | default "") == "true"
  let throwaway = $nu.home-dir | path expand | str starts-with ($nu.temp-dir | path expand)
  if not ($ci or $throwaway) {
    fail $task $"this rigs the machine it runs on: run it in CI, or with HOME set to a throwaway folder under ($nu.temp-dir)"
  }
}

# Run the bootstrap from this checkout, the way a user runs it, and return
# what it printed. Stops if it fails.
export def bootstrap [--dry-run]: nothing -> string {
  cd $REPO
  let result = if (is-windows) {
    let flags = if $dry_run { ["-DryRun"] } else { [] }
    ^powershell -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1 ...$flags | complete
  } else {
    let flags = if $dry_run { ["--dry-run"] } else { [] }
    ^sh bootstrap.sh ...$flags | complete
  }
  let output = $result.stdout + $result.stderr
  print $output
  check $"the bootstrap finished \(exit code ($result.exit_code))" ($result.exit_code == 0)
  $output
}

# Check that a run's output has no line saying it changed, or would change, something.
export def unchanged [output: string] {
  let changed = $output | lines | where {|line| $line =~ '^ +(change|would) ' }
  check $"it changed nothing(if ($changed | is-empty) { '' } else { ': ' + ($changed | str join '; ') })" ($changed | is-empty)
}

# A log kept by `Tee-Object` in Windows PowerShell is UTF-16; one kept by
# `tee` is UTF-8.
export def read-log [file: path]: nothing -> string {
  let bytes = open --raw $file | into binary
  if ($bytes | bytes starts-with 0x[FFFE]) {
    $bytes | bytes at 2.. | decode utf-16le
  } else {
    $bytes | decode utf-8
  }
}

# PATH as a new shell on this machine has it: the folders the rig puts on PATH
# first, and without the tools this repo's own mise.toml adds for a task, which
# would hide a tool the rig failed to install.
export def machine-path []: nothing -> list<string> {
  let installs = mise-shims | path dirname | path join installs | str lowercase
  let rest = $env.PATH | where {|dir| not ($dir | str lowercase | str starts-with $installs) }
  [(local-bin) (mise-shims)] ++ $rest
}

# The user PATH Windows keeps for new windows, then this one.
export def user-path []: nothing -> list<string> {
  let user = ^powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'User')" | str trim | split row ";" | where {|dir| $dir != "" }
  $user ++ $env.PATH
}
