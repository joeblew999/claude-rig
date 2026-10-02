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
#   nu tasks/fleet.nu run <machine> "<work>"   give one machine a piece of work
#   nu tasks/fleet.nu run --all "<work>"       give every machine the same work

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

# The command that runs one piece of work with Claude on a machine, in its
# work folder, and prints Claude's answer. The work itself is never put on a
# command line, where quoting would mangle it: on macOS and Linux it goes in
# on stdin, and on Windows it rides inside the script as base64.
def work-on [os: string, work: string]: nothing -> record {
  if $os == "Windows" {
    let encoded = $work | encode base64
    {
      command: "powershell -NoProfile -ExecutionPolicy Bypass -Command -"
      input: ([
        $"$work = [Text.Encoding]::UTF8.GetString\([Convert]::FromBase64String\('($encoded)'))"
        '$env:Path = "$HOME\.local\bin;$env:LOCALAPPDATA\mise\shims;$env:Path"'
        'New-Item -ItemType Directory -Force "$HOME\work" | Out-Null; Set-Location "$HOME\work"'
        '$work | claude -p'
      ] | str join "\n")
    }
  } else {
    {
      command: 'mkdir -p "$HOME/work" && cd "$HOME/work" && PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" claude -p'
      input: $work
    }
  }
}

# Give one machine the work and wait for the answer.
def run-on [machine: record, work: string]: nothing -> record {
  let started = date now
  let result = if $machine.target == "(this machine)" {
    cd (work-dir)
    $work | ^claude -p | complete
  } else {
    let options = ssh-options ($machine.port? | default null) ($machine.identity? | default null) ($machine.known_hosts? | default null)
    let how = work-on $machine.os $work
    $how.input | ^ssh -o BatchMode=yes ...$options $machine.target $how.command | complete
  }
  {
    machine: $machine.target
    ok: ($result.exit_code == 0)
    seconds: ((date now) - $started | into int | $in / 1_000_000_000 | math round --precision 1)
    answer: (if $result.exit_code == 0 { $result.stdout | str trim } else { $"($result.stdout | str trim)\n($result.stderr | str trim)" | str trim })
  }
}

# Give a machine a piece of work: Claude runs it there, in the machine's work
# folder, with that machine's settings, and the answer comes back here. With
# --all, every machine gets the same work at the same time.
#
# This is how a lead Claude spreads work over the fleet: one call per piece
# of work, each to a different machine.
def "main run" [
  ...words: string  # The machine (a name from the fleet table, or user@host), then the work. With --all, only the work
  --all             # Every machine, this one included
  --json            # Print the results as JSON
] {
  let here = {target: "(this machine)", os: "here"}
  let machines = [$here] ++ (known-machines)
  let chosen = if $all {
    $machines
  } else {
    if ($words | length) < 2 { fail fleet "say which machine, then the work. Or use --all." }
    let wanted = $words.0
    let found = $machines | where {|machine| $machine.target == $wanted or ($wanted == (machine-name) and $machine.target == "(this machine)") }
    if ($found | is-empty) { fail fleet $"no machine called ($wanted). `mise run fleet` lists them by their `where`." }
    $found
  }
  let work = (if $all { $words } else { $words | skip 1 }) | str join " "
  if ($work | str trim) == "" { fail fleet "there is no work to give." }

  let results = $chosen | par-each {|machine| run-on $machine $work }
  if $json {
    print ($results | to json --indent 2)
  } else {
    for result in $results {
      let state = if $result.ok { "done" } else { "FAILED" }
      print $"--- ($result.machine): ($state) in ($result.seconds)s"
      print $result.answer
    }
  }
  if ($results | any {|result| not $result.ok }) { exit 1 }
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
