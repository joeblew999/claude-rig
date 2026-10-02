#!/usr/bin/env nu
# session.nu — the always-on Claude session for this machine.
#
# The service manager (pitchfork) runs this and restarts it if it stops.
# It starts Claude's Remote Control server in the work folder, so the machine
# shows up in the Claude app and can be given work from a phone or a browser.
#
#   nu tasks/session.nu

use lib.nu *

def main [] {
  # Sessions started from the app need claude and every rig tool on PATH,
  # and a service starts with almost nothing on it.
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH

  cd (work-dir)

  # The first start on a machine asks "Enable Remote Control? (y/n)" once.
  # Rigging a machine is the owner saying yes, so answer it. On every later
  # start nothing is asked and the answer is ignored.
  "y\n" | ^claude remote-control --name (machine-name)
}
