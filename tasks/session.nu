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
#   nu tasks/session.nu [--keep-alive]

use lib.nu *

# Where the Windows session writes what the server prints. Started fresh on
# every start, so it holds the latest run only.
def log-file []: nothing -> path {
  $nu.home-dir | path join .claude-rig-session.log
}

# Start the server and wait for it to stop.
def serve [] {
  # The first start on a machine asks "Enable Remote Control? (y/n)" once.
  # Rigging a machine is the owner saying yes, so answer it. On every later
  # start nothing is asked and the answer is ignored.
  # On macOS the session also keeps the Mac awake while it runs, on mains
  # power only (caffeinate -s): a Mac that sleeps drops out of the Claude app
  # and stops its VMs. Closing the lid still puts it to sleep.
  if $nu.os-info.name == "macos" and (have caffeinate) {
    "y\n" | ^caffeinate -i -s claude remote-control --name (machine-name)
  } else {
    "y\n" | ^claude remote-control --name (machine-name)
  }
}

def main [
  --keep-alive  # Restart the server whenever it stops, and log to a file
] {
  # Sessions started from the app need claude and every rig tool on PATH,
  # and a service starts with almost nothing on it.
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH

  cd (work-dir)

  if not $keep_alive {
    serve
    return
  }
  loop {
    try { serve out+err> (log-file) } catch { }
    sleep 15sec
  }
}
