#!/usr/bin/env nu
# fleet.nu — every rigged machine in one table.
#
# Asks this machine and each machine rigged from here (with `push`) for its
# doctor report, over SSH, and shows them side by side. Changes nothing on
# any of them.
#
#   nu tasks/fleet.nu                 the table
#   nu tasks/fleet.nu --json          the same, as JSON
#   nu tasks/fleet.nu add user@host   add a machine that was rigged by hand
#   nu tasks/fleet.nu forget user@host

use lib.nu *
use remote.nu *

# The command that prints a machine's doctor report, for its OS.
# On Windows the script goes to PowerShell on stdin: quoting it through
# cmd.exe goes wrong.
def doctor-on [os: string]: nothing -> record {
  if $os == "Windows" {
    {
      command: "powershell -NoProfile -ExecutionPolicy Bypass -Command -"
      input: '& "$env:LOCALAPPDATA\mise\shims\nu.exe" "$HOME\.claude-rig\tasks\doctor.nu" --json'
    }
  } else {
    {
      command: 'PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" nu "$HOME/.claude-rig/tasks/doctor.nu" --json'
      input: null
    }
  }
}

# One machine's report, or why there is none.
def ask [machine: record]: nothing -> record {
  let options = ssh-options ($machine.port? | default null) ($machine.identity? | default null) ($machine.known_hosts? | default null)
  let how = doctor-on $machine.os
  let result = if $how.input == null {
    ^ssh -n -o BatchMode=yes ...$options $machine.target $how.command | complete
  } else {
    $how.input | ^ssh -o BatchMode=yes ...$options $machine.target $how.command | complete
  }
  let facts = try { $result.stdout | from json } catch { null }
  if $result.exit_code == 0 and $facts != null {
    $facts | insert target $machine.target | insert reachable true
  } else if $result.exit_code == 255 {
    {target: $machine.target, os: ($machine.os | str lowercase), reachable: false, problem: "cannot reach it over SSH"}
  } else {
    {target: $machine.target, os: ($machine.os | str lowercase), reachable: true, problem: "reached it, but the rig's doctor did not answer"}
  }
}

# This machine's own report.
def ask-here []: nothing -> record {
  let result = ^$nu.current-exe ($env.FILE_PWD | path join doctor.nu) --json | complete
  $result.stdout | from json | insert target "(this machine)" | insert reachable true
}

def yes-no [value: any]: nothing -> string {
  if $value == null { "?" } else if $value { "yes" } else { "no" }
}

# Add a machine that was rigged by hand, so the table includes it.
def "main add" [
  target: string         # The machine, as user@host
  --port: int            # The SSH port, if it is not 22
  --identity: path       # The SSH private key to log in with
  --windows              # The machine runs Windows (otherwise macOS or Linux)
] {
  remember-machine {target: $target, os: (if $windows { "Windows" } else { "Unix" }), port: $port, identity: $identity, known_hosts: null}
  print $"fleet: added ($target)."
}

# Take a machine off the list. Nothing on the machine itself changes.
def "main forget" [target: string] {
  if (forget-machine $target) {
    print $"fleet: forgot ($target). To stop its session, run `mise run unrig` on it."
  } else {
    print $"fleet: ($target) is not on the list."
  }
}

def main [
  --json  # Print the reports as JSON
] {
  let reports = [(ask-here)] ++ (known-machines | each {|machine| ask $machine })
  if $json {
    print ($reports | to json --indent 2)
    return
  }
  let rows = $reports | each {|report|
    {
      machine: ($report.name? | default "?")
      where: $report.target
      os: $report.os
      tools: (yes-no ($report.tools_installed? | default null))
      "logged in": (yes-no ($report.logged_in? | default null))
      session: (yes-no ($report.session_running? | default null))
      rig: ($report.rig_commit? | default "?")
      note: ($report.problem? | default "")
    }
  }
  print ($rows | table --index false --width 200)
  let off = $reports | where {|report| not ($report.session_running? | default false) } | length
  print $"fleet: ($reports | length) machine\(s), ($off) without a running session."
}
