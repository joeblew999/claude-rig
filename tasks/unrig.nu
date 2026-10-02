#!/usr/bin/env nu
# unrig.nu — take this machine out of the fleet.
#
# Stops the always-on session and removes what starts it, so the machine no
# longer shows up in the Claude app. Everything else stays: the tools, Claude
# Code, the Claude config, the login and the work folder. Running the rig
# again puts the session back.
#
#   nu tasks/unrig.nu [--dry-run]

use lib.nu *
use enroll.nu [remove-session]

def main [
  --dry-run  # Report what would change and change nothing
] {
  if $dry_run { $env.RIG_DRY_RUN = "1" }
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH

  print "Session"
  remove-session

  if (changes) == 0 {
    print "unrig: nothing to remove."
  } else if (dry-run) {
    print $"unrig: (changes) change\(s) to make. Nothing was changed."
  } else {
    print $"unrig: done. Run the rig again to put the session back."
  }
}
