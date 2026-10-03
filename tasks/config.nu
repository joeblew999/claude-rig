#!/usr/bin/env nu
# config.nu — your config folder: where it is, and making one.
#
#   nu tasks/config.nu               where this machine's config comes from
#   nu tasks/config.nu init <folder> use this folder as the config; if it holds
#                                    no config yet, make it and capture into it
#
# The folder's location is kept in ~/.config/claude-rig/config.toml.

use lib.nu *
use userconfig.nu [ENTRIES chosen-folder choose-folder describe-config settings-file]

# Where this machine's config comes from.
def main [] {
  let where = describe-config
  if $where == null {
    print "config: none. Make one from this machine's ~/.claude: mise run config -- init <folder>"
  } else {
    print $"config: ($where)"
  }
}

# Use a folder as the config. A folder that holds no config yet is made, and
# this machine's ~/.claude is captured into it.
def "main init" [
  folder: string  # The config folder: a new one, or a clone of your config repo
] {
  let folder = $folder | path expand
  let holds_config = $ENTRIES | any {|entry| $folder | path join $entry | path exists }

  if (chosen-folder) == $folder {
    ok $"config folder is ($folder) \(in (settings-file))"
  } else {
    change $"remember ($folder) as the config folder, in (settings-file)" { choose-folder $folder }
  }

  if $holds_config {
    ok $"($folder) holds a config already. `mise run capture` replaces it with this machine's ~/.claude"
    return
  }
  if not ((claude-home) | path exists) {
    change $"make an empty config folder ($folder) \(there is no (claude-home) to capture)" { mkdir $folder }
    return
  }
  change $"capture (claude-home) into ($folder)" {
    let capture = $env.FILE_PWD | path join capture.nu
    # RIG_CONFIG would name a different folder to capture into.
    with-env { RIG_CONFIG: "" } { ^$nu.current-exe $capture }
  }
}
