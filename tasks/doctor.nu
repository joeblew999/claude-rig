#!/usr/bin/env nu
# doctor.nu — what is set up on this machine and what is missing.
#
# Changes nothing. Prints a short report, then what a real run would change.
# With --json it prints only the report, as one JSON object: the shape a
# control plane takes in when a machine checks in.
#
#   nu tasks/doctor.nu [--json]

use lib.nu *
use enroll.nu [logged-in session-running]
use userconfig.nu [describe-config]

# The first line a program prints, or null if it is missing or fails.
def first-line [program: string, args: list<string>] {
  if not (have $program) { return null }
  let result = ^$program ...$args | complete
  if $result.exit_code != 0 { return null }
  $result.stdout | lines | get 0? | default "" | str trim
}

# The commit of the rig this machine last ran.
def rig-commit [] {
  first-line git ["-C" (repo-dir) rev-parse "--short" HEAD]
}

# The facts about this machine, as one record.
def report []: nothing -> record {
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH
  let tools_ok = (have mise) and (missing-tools) == ""
  {
    name: (machine-name)
    os: $nu.os-info.name
    arch: $nu.os-info.arch
    rig_commit: (rig-commit)
    tools_installed: $tools_ok
    claude_version: (first-line claude ["--version"])
    config: (describe-config)
    config_applied: (claude-home | path join .rig-manifest | path exists)
    logged_in: (logged-in)
    session_running: (session-running)
    work_dir: (work-dir)
    checked_at: (date now | format date "%Y-%m-%dT%H:%M:%S%:z")
  }
}

def main [
  --json  # Print only the report, as JSON
] {
  let facts = report
  if $json {
    print ($facts | to json --indent 2)
    return
  }
  print "This machine"
  $facts | transpose key value | each {|row|
    print $"  ($row.key | fill --width 16) ($row.value)"
  }
  print ""
  print "What a run would change"
  ^$nu.current-exe ($env.FILE_PWD | path join rig.nu) --dry-run
}
