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
#   nu tasks/fleet.nu claims <machine>         who is using a machine
#   nu tasks/fleet.nu release <machine> <id>   let go of a claim on it
#   nu tasks/fleet.nu slots <machine> [<n>]    how many jobs it takes at once

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

# A word that is safe on any remote command line once in single quotes:
# callers and job labels are cut down to plain characters.
def plain [text: string, longest: int]: nothing -> string {
  $text | str replace --all --regex '[^A-Za-z0-9@._:/+= -]' "_" | str trim | str substring 0..<($longest)
}

# The command that runs tasks/claims.nu on a machine, with `input` on its
# stdin, and its output captured. Every argument has been through `plain`.
# The input (the work) is never put on a command line, where quoting would
# mangle it: on macOS and Linux it goes in on stdin, and on Windows it rides
# inside the PowerShell script as base64.
def claims-on [machine: record, args: list<string>, input?: string]: nothing -> record {
  if $machine.target == "(this machine)" {
    let claims = $env.FILE_PWD | path join claims.nu
    if $input == null {
      return (^$nu.current-exe $claims ...$args | complete)
    }
    return ($input | ^$nu.current-exe --stdin $claims ...$args | complete)
  }
  let quoted = $args | each {|arg| $"'($arg)'" } | str join " "
  let options = ssh-options ($machine.port? | default null) ($machine.identity? | default null) ($machine.known_hosts? | default null)
  if $machine.os == "Windows" {
    let claims = '& "$env:LOCALAPPDATA\mise\shims\nu.exe" --stdin "$HOME\.claude-rig\tasks\claims.nu" ' + $quoted
    let script = [
      '$OutputEncoding = [Text.Encoding]::UTF8'
      '$env:Path = "$HOME\.local\bin;$env:LOCALAPPDATA\mise\shims;$env:Path"'
      (if $input == null {
        "'' | " + $claims
      } else {
        "[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" + ($input | encode base64) + "')) | " + $claims
      })
      'exit $LASTEXITCODE'
    ] | str join "\n"
    $script | ^ssh -o BatchMode=yes ...$options $machine.target "powershell -NoProfile -ExecutionPolicy Bypass -Command -" | complete
  } else {
    let command = $'PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH" nu --stdin "$HOME/.claude-rig/tasks/claims.nu" ($quoted)'
    if $input == null {
      ^ssh -n -o BatchMode=yes ...$options $machine.target $command | complete
    } else {
      $input | ^ssh -o BatchMode=yes ...$options $machine.target $command | complete
    }
  }
}

# Who is calling: --caller, else $env.RIG_CALLER, else user@host.
def caller-name [given: any]: nothing -> string {
  let user = $env.USER? | default ($env.USERNAME? | default "someone")
  plain ($given | default ($env.RIG_CALLER? | default $"($user)@(machine-name)")) 60
}

# Give one machine the work and wait for the answer. The machine takes a
# claim first and runs the work in that claim's own job folder.
def run-on [machine: record, work: string, caller: string, label: string, wait: bool]: nothing -> record {
  let started = date now
  let args = [job --caller $caller --label $label] ++ (if $wait { [--wait] } else { [] })
  let result = claims-on $machine $args $work
  let state = if $result.exit_code == 0 { "done" } else if $result.exit_code == 6 { "busy" } else { "failed" }
  {
    machine: $machine.target
    ok: ($result.exit_code == 0)
    state: $state
    seconds: ((date now) - $started | into int | $in / 1_000_000_000 | math round --precision 1)
    answer: (if $result.exit_code in [0 6] { $result.stdout | str trim } else { $"($result.stdout | str trim)\n($result.stderr | str trim)" | str trim })
  }
}

# Every machine: this one, then each one rigged from here.
def all-machines []: nothing -> list<record> {
  [{target: "(this machine)", os: "here"}] ++ (known-machines)
}

# One machine, by its `where` from the table, or this machine by its name.
def find-machine [wanted: string]: nothing -> record {
  let found = all-machines | where {|machine| $machine.target == $wanted or ($wanted == (machine-name) and $machine.target == "(this machine)") }
  if ($found | is-empty) { fail fleet $"no machine called ($wanted). `mise run fleet` lists them by their `where`." }
  $found.0
}

# Give a machine a piece of work: Claude runs it there, with that machine's
# settings, and the answer comes back here. The machine first takes a claim,
# so the work gets its own job folder and nobody else's job runs there at
# the same time. A busy machine says who holds it, unless --wait is given.
# With --all, every machine gets the same work at the same time, and busy
# ones are reported as busy.
#
# This is how a lead Claude spreads work over the fleet: one call per piece
# of work, each to a different machine.
def "main run" [
  ...words: string  # The machine (a name from the fleet table, or user@host), then the work. With --all, only the work
  --all             # Every machine, this one included
  --wait            # Wait for a busy machine to have a free slot (not with --all)
  --caller: string  # Who is giving the work (default: $RIG_CALLER, else user@host)
  --label: string   # What the job is, in a few words (default: the start of the work)
  --json            # Print the results as JSON
] {
  let chosen = if $all {
    all-machines
  } else {
    if ($words | length) < 2 { fail fleet "say which machine, then the work. Or use --all." }
    [(find-machine $words.0)]
  }
  let work = (if $all { $words } else { $words | skip 1 }) | str join " "
  if ($work | str trim) == "" { fail fleet "there is no work to give." }
  let who = caller-name $caller
  let what = plain ($label | default ($work | lines | get 0? | default "work")) 40
  let wait = $wait and not $all

  let results = $chosen | par-each {|machine| run-on $machine $work $who $what $wait }
  if $json {
    print ($results | to json --indent 2)
  } else {
    for result in $results {
      print $"--- ($result.machine): ($result.state | str uppercase) in ($result.seconds)s"
      print $result.answer
    }
  }
  if ($results | any {|result| $result.state == "failed" }) { exit 1 }
  if ($results | any {|result| $result.state == "busy" }) { exit 6 }
}

# Run a claims command on one machine and pass on what it said.
def claims-command [wanted: string, args: list<string>] {
  let result = claims-on (find-machine $wanted) $args
  if ($result.stdout | str trim) != "" { print ($result.stdout | str trim) }
  if ($result.stderr | str trim) != "" { print --stderr ($result.stderr | str trim) }
  if $result.exit_code != 0 { exit $result.exit_code }
}

# The claims on one machine: who is using it, for which job, until when.
def "main claims" [
  machine: string  # The machine (a name from the fleet table, or user@host)
  --json           # Print them as JSON
] {
  claims-command $machine (if $json { [list --json] } else { [list] })
}

# Let go of a claim on one machine. Someone else's live claim needs --force;
# the work it was taken for is not stopped.
def "main release" [
  machine: string   # The machine (a name from the fleet table, or user@host)
  id: string        # The claim's id, from `fleet claims`
  --force           # Release it even though it is someone else's and still live
  --caller: string  # Who is releasing it (default: $RIG_CALLER, else user@host)
] {
  claims-command $machine ([release (plain $id 40) --caller (caller-name $caller)] ++ (if $force { [--force] } else { [] }))
}

# How many jobs one machine takes at once. With a number, set it.
def "main slots" [
  machine: string  # The machine (a name from the fleet table, or user@host)
  count?: int      # The new number of slots
] {
  claims-command $machine (if $count == null { [slots] } else { [slots ($count | into string)] })
}

# Who holds a machine, for the table: "free", or who and since when.
def claims-text [report: record]: nothing -> string {
  let claims = $report.claims? | default null
  if $claims == null { return "?" }
  if ($claims | is-empty) { return "free" }
  let since = {|claim| try { $claim.since | into datetime | format date "%H:%M" } catch { "?" } }
  let held = $claims | each {|claim| $"($claim.who) since (do $since $claim)" } | str join ", "
  let slots = $report.slots? | default 1
  if $slots > 1 { $"($claims | length)/($slots): ($held)" } else { $held }
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
      claims: (claims-text $report)
      rig: ($report.rig_commit? | default "?")
      note: ($report.problem? | default "")
    }
  }
  print ($rows | table --index false --width 200)
  let off = $reports | where {|report| not ($report.session_running? | default false) } | length
  print $"fleet: ($reports | length) machine\(s), ($off) without a running session."
}
