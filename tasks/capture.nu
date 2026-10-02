#!/usr/bin/env nu
# capture.nu — copy this Mac's global Claude config into claude/
#
# Safe to repeat. Builds the copy in a temp folder, checks it for secrets and
# for paths that only exist on this Mac, and only then replaces claude/.
# If a check fails, claude/ is untouched.
#
#   nu tasks/capture.nu

use lib.nu *

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
const SECRET_VALUE = 'sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}'

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

# The files under a folder whose text matches a pattern. Binary files are skipped.
def files-matching [root: path, pattern: string]: nothing -> list<string> {
  glob ($root | path join "**" "*") --no-dir | where {|file|
    let text = try { open --raw $file | decode utf-8 } catch { "" }
    $text =~ $pattern
  }
}

def main [] {
  let src = claude-home
  let dest = repo-dir | path join claude
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
  glob ($tmp | path join "**" ".DS_Store") | each {|file| rm $file }

  let home = $nu.home-dir | str replace --all '\' '\\' | str replace --all '.' '\.'
  for check in [
    {found: (files-matching $tmp $SECRET_VALUE), problem: "possible secret in"}
    {found: (files-matching $tmp $home), problem: $"a path under ($nu.home-dir) in"}
  ] {
    if ($check.found | is-not-empty) {
      print --stderr $"capture: ($check.problem) these files \(claude/ was not changed):"
      $check.found | each {|file| print --stderr $"  ($file | str replace $tmp $src)" }
      rm --recursive --force $tmp
      exit 1
    }
  }

  # Replace claude/ with the checked copy (mirror: things removed on the Mac go too)
  rm --recursive --force $dest
  cp --recursive $tmp $dest
  rm --recursive --force $tmp

  let status = ^git -C (repo-dir) status --short -- claude | str trim
  if $status == "" {
    print "capture: already up to date."
  } else {
    print "capture: claude/ updated. Changes:"
    print $status
    print "Review with: git diff -- claude"
  }
}
