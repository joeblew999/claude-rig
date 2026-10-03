#!/usr/bin/env nu
# always-on.nu — `mise run ci:windows-session`: on Windows, the always-on
# session starts at sign-in and stays up.
#
# A CI runner cannot log in to Claude, so the server itself cannot connect.
# This checks the parts around it: the sign-in entry, the session's loop, and
# the keeper beside it that holds the PC awake. Run after ci:bootstrap.
#
# This file's name must not contain the session script's name: the rig takes
# any process whose command line names it for the session, and stops it.
#
#   mise run ci:windows-session

use ../lib.nu [is-windows powershell fail]
use common.nu *

const FIXTURE = path self ../../tests/fixtures/config

# Every process, with its parent and command line.
def processes []: nothing -> table {
  powershell 'Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, CommandLine | ConvertTo-Json -Compress' | from json
}

# The session's processes and the keeper started beside them, once both are up.
def session-and-keeper []: nothing -> record {
  let all = processes
  let session = $all | where {|process| ($process.CommandLine? | default "") =~ '[\\/]tasks[\\/]session\.nu' }
  let ids = $session | get ProcessId
  let keeper = $all | where {|process|
    $process.Name == "powershell.exe" and ($process.CommandLine? | default "") =~ 'EncodedCommand' and $process.ParentProcessId in $ids
  }
  { session: $session, keeper: $keeper }
}

def main [] {
  if not (is-windows) { fail ci:windows-session "this checks the session on Windows" }
  guard ci:windows-session

  let wanted = { RIG_ASSUME_LOGGED_IN: "1", RIG_CONFIG: $FIXTURE }

  print "A run with the session"
  with-env $wanted { bootstrap | ignore }
  let startup = $env.APPDATA | path join Microsoft Windows "Start Menu" Programs Startup claude-rig.cmd
  check "the session starts at sign-in" ($startup | path exists)
  print (open --raw $startup | decode utf-8)

  # The session is started through the Task Scheduler: give it a minute.
  mut found = session-and-keeper
  for _ in 1..30 {
    if ($found.session | is-not-empty) and ($found.keeper | is-not-empty) { break }
    sleep 2sec
    $found = session-and-keeper
  }
  check "the session is running" ($found.session | is-not-empty)
  # The runner is an administrator, so powercfg can list who holds the PC awake.
  check "the keep-awake is running beside it" ($found.keeper | is-not-empty)
  print (^powercfg /requests | complete | get stdout)
  let log = $nu.home-dir | path join .claude-rig-session.log
  if ($log | path exists) { print (open --raw $log | decode utf-8 | lines | first 10 | str join "\n") }

  print "A second run with the session"
  let second = with-env $wanted { bootstrap }
  unchanged $second
}
