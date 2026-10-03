#!/usr/bin/env nu
# session.nu — the always-on Claude session for this machine.
#
# It starts Claude's Remote Control server in the work folder, so the machine
# shows up in the Claude app and can be given work from a phone or a browser.
#
# On macOS and Linux, pitchfork runs this and restarts it if it stops.
# On Windows, where pitchfork cannot start at boot, it is started at sign-in
# with --keep-alive and restarts the server itself.
#
# While it runs it keeps the machine awake (awake.nu) and reports to
# fleet-api (report.nu): `start` when it starts, `interval` every 5 minutes,
# `stop` when the server ends (or, when pitchfork stops it, pitchfork's
# on_stop hook does). A report that fails never stops the session.
#
#   nu tasks/session.nu [--keep-alive]

use lib.nu *
use awake.nu [awake-plan run-windows-keeper]
use report.nu [report-now EVERY_S]

# Where the Windows session writes what the server prints. Started fresh on
# every start, so it holds the latest run only.
def log-file []: nothing -> path {
  $nu.home-dir | path join .claude-rig-session.log
}

# Start the server and wait for it to stop. `prefix` keeps the machine awake
# while it runs (awake-plan).
def serve [prefix: list<string>] {
  # The first start on a machine asks "Enable Remote Control? (y/n)" once.
  # Rigging a machine is the owner saying yes, so answer it. On every later
  # start nothing is asked and the answer is ignored.
  let command = $prefix ++ [claude remote-control --name (machine-name)]
  "y\n" | run-external ...$command
}

# Post a report and say what came of it. Never fails.
def report [reason: string] {
  print $"report: ($reason) ((report-now $reason))"
}

# Report `start`, then `interval` every EVERY_S seconds, until killed. Run
# in a job, beside the server. `start` waits a little, so that on a restart
# the `stop` from pitchfork's hook is the older of the two.
def reporter [] {
  sleep 10sec
  report start
  loop {
    sleep ($EVERY_S * 1sec)
    report interval
  }
}

def main [
  --keep-alive  # Restart the server whenever it stops, and log to a file
] {
  # Sessions started from the app need claude and every rig tool on PATH,
  # and a service starts with almost nothing on it.
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH

  cd (work-dir)

  let awake = awake-plan
  if $awake.note != "" { print $"session: ($awake.note)" }
  let reporting = job spawn { reporter }

  if not $keep_alive {
    # When pitchfork stops the session, this process ends with it, and
    # pitchfork's on_stop hook reports `stop` (enroll.nu). When the server
    # ends by itself, the session reports it here.
    let failed = try { serve $awake.prefix; false } catch { true }
    try { job kill $reporting }
    report stop
    # A server that failed must still look failed, so pitchfork restarts it.
    if $failed { exit 1 }
    return
  }
  # Windows: the keeper holds sleep off for as long as this process lives.
  # The session is ended by stopping the process, so no `stop` is sent.
  if (is-windows) { job spawn { try { run-windows-keeper } catch { } } | ignore }
  loop {
    try { serve $awake.prefix out+err> (log-file) } catch { }
    sleep 15sec
  }
}
