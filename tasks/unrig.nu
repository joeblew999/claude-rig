#!/usr/bin/env nu
# unrig.nu — take this machine out of the fleet.
#
# Stops the always-on session and removes what starts it, so the machine no
# longer shows up in the Claude app. Everything else stays: the tools, Claude
# Code, the Claude config, the login and the work folder. Running the rig
# again puts the session back.
#
# The machine's fleet-api token stays in its file: a machine has no
# Cloudflare credentials, so it cannot revoke it. unrig prints the command
# that does, run on the owner's Mac in fleet-api.
#
#   nu tasks/unrig.nu [--dry-run]

use lib.nu *
use enroll.nu [remove-session]
use report.nu [access-file token-name]

def main [
  --dry-run  # Report what would change and change nothing
] {
  if $dry_run { $env.RIG_DRY_RUN = "1" }
  $env.PATH = [(local-bin) (mise-shims)] ++ $env.PATH

  print "Session"
  remove-session

  print "Reporting"
  if (access-file | path exists) {
    skipped $"revoking this machine's fleet-api token: only the owner can, on their Mac: mise -C <fleet-api's checkout> run access:token -- revoke (token-name)"
  } else {
    ok "no fleet-api token on this machine"
  }

  if (changes) == 0 {
    print "unrig: nothing to remove."
  } else if (dry-run) {
    print $"unrig: (changes) change\(s) to make. Nothing was changed."
  } else {
    print $"unrig: done. Run the rig again to put the session back."
  }
}
