#!/usr/bin/env nu
# apply.nu — apply claude/ from this repo to this machine's ~/.claude
#
# Safe to repeat. Merges rather than overwrites:
#   - settings.json: rig keys are set, keys that exist only here are kept
#   - skills, agents, commands, hooks: rig entries are added or updated,
#     entries that exist only here are left alone
#   - CLAUDE.md: replaced, only if it differs
# The first run backs up everything it could touch. ~/.claude.json is never touched.
#
#   nu tasks/apply.nu [--dry-run]

use lib.nu *

const DIRS = [skills agents commands hooks]

# Merge the rig's settings into this machine's. Records are merged key by key.
# Lists keep the rig's entries and add any that exist only here. For anything
# else the rig's value wins.
def merge-settings [local: any, rig: any] {
  let kinds = [($local | describe --detailed | get type) ($rig | describe --detailed | get type)]
  if $kinds == [record record] {
    $rig | columns | reduce --fold $local {|key, merged|
      let value = if $key in $merged {
        merge-settings ($merged | get $key) ($rig | get $key)
      } else {
        $rig | get $key
      }
      $merged | upsert $key $value
    }
  } else if ($kinds | all {|kind| $kind in [list table] }) {
    $rig ++ ($local | where {|item| $item not-in $rig })
  } else {
    $rig
  }
}

def backup [dest: path, to: path] {
  mkdir $to
  for name in ([settings.json CLAUDE.md] ++ $DIRS) {
    let item = $dest | path join $name
    if ($item | path exists) { cp --recursive $item ($to | path join $name) }
  }
}

def replace-entry [from: path, to: path] {
  mkdir ($to | path dirname)
  rm --recursive --force $to
  cp --recursive $from $to
}

def main [
  --dry-run  # Report what would change and change nothing
] {
  if $dry_run { $env.RIG_DRY_RUN = "1" }

  let src = repo-dir | path join claude
  let dest = claude-home
  let manifest = $dest | path join ".rig-manifest"

  if not ($src | path exists) { fail apply $"no captured config at ($src)" }

  # --- Backup, once ---------------------------------------------------------

  # The manifest is written at the end of the first run, so once it exists
  # whatever is in ~/.claude has already been through the rig.
  let backups = glob $"($dest | path expand --no-symlink).rig-backup-*"
  if ($backups | is-not-empty) {
    ok "backup (taken on the first run)"
  } else if ($manifest | path exists) {
    ok "backup (nothing was here before the first run)"
  } else if ($dest | path exists) {
    let to = $"($dest).rig-backup-(date now | format date '%Y%m%d-%H%M%S')"
    change $"back up the current config to ($to)" { backup $dest $to }
  } else {
    skip $"backup \(no ($dest) yet)"
  }

  if not (dry-run) { mkdir $dest }

  # --- settings.json: merge -------------------------------------------------

  let rig_settings = $src | path join settings.json
  let settings = $dest | path join settings.json
  if ($rig_settings | path exists) {
    let rig = open --raw $rig_settings | from json
    if ($settings | path exists) {
      let local = try { open --raw $settings | from json } catch {
        fail apply $"($settings) is not valid JSON. Fix it, then run again."
      }
      let merged = merge-settings $local $rig
      if $merged == $local {
        ok "settings.json"
      } else {
        change "merge the rig's settings into settings.json" {
          $merged | to json --indent 2 | save --force $settings
        }
      }
    } else {
      change "create settings.json" { cp $rig_settings $settings }
    }
  }

  # --- CLAUDE.md: replace if different --------------------------------------

  let rig_md = $src | path join CLAUDE.md
  let md = $dest | path join CLAUDE.md
  if ($rig_md | path exists) {
    if (read-text $rig_md) == (read-text $md) {
      ok "CLAUDE.md"
    } else {
      change "replace CLAUDE.md" { cp $rig_md $md }
    }
  }

  # --- skills, agents, commands, hooks: sync entry by entry -----------------

  # Entries are named with forward slashes on every OS, like skills/mise-tasks.
  let entries = $DIRS
    | where {|dir| $src | path join $dir | path exists }
    | each {|dir| ls ($src | path join $dir) | get name | each {|path| $"($dir)/($path | path basename)" } }
    | flatten
    | sort

  for entry in $entries {
    let from = $src | path join $entry
    let to = $dest | path join $entry
    if not ($to | path exists) {
      change $"add ($entry)" { replace-entry $from $to }
    } else if (contents $from) == (contents $to) {
      ok $entry
    } else {
      change $"update ($entry)" { replace-entry $from $to }
    }
  }

  # Entries the rig put here on an earlier run and has since dropped are removed.
  # Anything the rig never installed is not in the manifest, so it is left alone.
  let installed = read-text $manifest | default "" | lines | where {|line| $line != "" }
  for entry in $installed {
    let old = $dest | path join $entry
    if $entry not-in $entries and ($old | path exists) {
      change $"remove ($entry) \(no longer in the rig)" { rm --recursive --force $old }
    }
  }

  if $installed != $entries {
    change $"record what the rig installed in ($manifest)" {
      $entries | str join "\n" | save --force $manifest
    }
  }

  if (changes) == 0 {
    print "apply: already up to date."
  } else if (dry-run) {
    print $"apply: (changes) change\(s) to make. Nothing was changed."
  } else {
    print $"apply: (changes) change\(s) made."
  }
}
