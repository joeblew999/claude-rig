#!/usr/bin/env nu
# capture.nu — copy this machine's global Claude config into your config folder
#
# The config folder is the one `mise run config` shows (RIG_CONFIG, or the
# folder in ~/.config/claude-rig/config.toml). Safe to repeat. Builds the copy
# in a temp folder, checks it for secrets and for paths that only exist on this
# machine, and only then replaces the config's entries in the folder. Anything
# else there (a README, .git) is left alone. If a check fails, nothing changes.
#
#   nu tasks/capture.nu

use lib.nu *
use userconfig.nu [ENTRIES local-folder config-problems]

# What gets captured. Everything else in ~/.claude (projects, todos, logs,
# login state in ~/.claude.json) is machine-local and never copied.
const DIRS = [skills agents commands hooks]

# Filled in by the Claude account on each machine, so not ours to copy.
const SKIP = [synced .DS_Store]

# Settings that only make sense on this Mac (local folders, local socket paths).
const MAC_ONLY = [
  [permissions additionalDirectories]
  [sandbox network allowUnixSockets]
]

const SECRET_NAME = '(?i)TOKEN|KEY|SECRET|PASSWORD|CREDENTIAL'

# Remove a nested key if it is there.
def drop-key [keys: list<string>]: record -> record {
  let settings = $in
  let path = $keys | into cell-path
  if ($settings | get --optional $path) == null { $settings } else { $settings | reject $path }
}

def clean-settings []: record -> record {
  let settings = $in
  let settings = if "env" in $settings {
    $settings | update env {|it| $it.env | transpose name value | where name !~ $SECRET_NAME | transpose --header-row --as-record }
  } else {
    $settings
  }
  $MAC_ONLY | reduce --fold $settings {|keys, acc| $acc | drop-key $keys }
}

# The config's entries in a folder, as something that can be compared with ==.
def snapshot [folder: path]: nothing -> list {
  $ENTRIES | each {|entry|
    let item = $folder | path join $entry
    if ($item | path exists) { [$entry (contents $item)] } else { [$entry null] }
  }
}

def main [] {
  let src = claude-home
  let dest = local-folder capture
  if $dest == null { fail capture "no config folder yet. Make one: mise run config -- init <folder>" }
  if not ($src | path exists) { fail capture $"no Claude config at ($src)" }

  let tmp = mktemp --directory | path expand
  let settings = $src | path join settings.json
  if ($settings | path exists) {
    let cleaned = try { open --raw $settings | from json } catch {
      fail capture "settings.json is not valid JSON"
    }
    $cleaned | clean-settings | to json --indent 2 | $"($in)\n" | save ($tmp | path join settings.json)
  }

  let md = $src | path join CLAUDE.md
  if ($md | path exists) { cp $md ($tmp | path join CLAUDE.md) }

  for dir in $DIRS {
    let from = $src | path join $dir
    if not ($from | path exists) { continue }
    mkdir ($tmp | path join $dir)
    for entry in (ls --all $from | get name | where {|path| ($path | path basename) not-in $SKIP }) {
      cp --recursive $entry ($tmp | path join $dir ($entry | path basename))
    }
  }
  do { cd $tmp; glob "**/.DS_Store" } | each {|file| rm $file }

  let problems = config-problems $tmp
  if ($problems | is-not-empty) {
    for check in $problems {
      print --stderr $"capture: ($check.problem) these files \(($dest) was not changed):"
      $check.files | each {|file| print --stderr $"  ($src | path join $file)" }
    }
    rm --recursive --force $tmp
    exit 1
  }

  # Replace the config's entries with the checked copy (a mirror: what was
  # removed here goes there too). Nothing else in the folder is touched.
  mkdir $dest
  let before = snapshot $dest
  for entry in $ENTRIES {
    let from = $tmp | path join $entry
    let to = $dest | path join $entry
    rm --recursive --force $to
    if ($from | path exists) { cp --recursive $from $to }
  }
  rm --recursive --force $tmp

  if (snapshot $dest) == $before {
    print $"capture: ($dest) is already up to date."
  } else if ($dest | path join .git | path exists) {
    print $"capture: ($dest) updated. Changes:"
    print (^git -C $dest status --short | complete | get stdout | str trim)
    print $"Review with: git -C ($dest) diff, then commit and push it."
  } else {
    print $"capture: ($dest) updated."
  }
}
