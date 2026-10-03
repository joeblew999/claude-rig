#!/usr/bin/env nu
# apply.nu — tests for tasks/apply.nu.
#
# Each test runs the real task against a throwaway Claude folder and checks
# what it left behind. Nothing outside a temp folder is touched.
#
#   nu tests/apply.nu

const APPLY = path self ../tasks/apply.nu
# A made-up config, laid out like a user's config folder.
const RIG_CONFIG = path self fixtures/config

# Run apply against a Claude folder, with the test config named in RIG_CONFIG.
# The rig's own folder is a throwaway one next to it, so this machine's
# ~/.config/claude-rig is never read. Returns what it printed and its exit code.
def apply [home: path, ...flags: string]: nothing -> record {
  let rig_home = $home | path dirname | path join rig-home
  with-env { CLAUDE_HOME: $home, RIG_CONFIG: $RIG_CONFIG, RIG_CONFIG_HOME: $rig_home, RIG_CHANGES: "0", RIG_DRY_RUN: "0" } {
    ^$nu.current-exe $APPLY ...$flags | complete
  }
}

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# The names in a folder, sorted. Empty if the folder is not there.
def names [dir: path]: nothing -> list<string> {
  if ($dir | path exists) { ls --all $dir | get name | each {|path| $path | path basename } | sort } else { [] }
}

def test-fresh-machine [root: path] {
  print "a machine with no Claude config"
  let home = $root | path join fresh .claude

  let dry = apply $home "--dry-run"
  check "a dry run succeeds" ($dry.exit_code == 0)
  check "a dry run creates nothing" (not ($home | path exists))

  let first = apply $home
  check "the first run succeeds" ($first.exit_code == 0)
  check "settings.json is the rig's" ((open --raw ($home | path join settings.json) | from json) == (open --raw ($RIG_CONFIG | path join settings.json) | from json))
  check "the rig's skills are there" ((names ($home | path join skills)) == (names ($RIG_CONFIG | path join skills)))
  check "the commands are there" ((names ($home | path join commands)) == ["hello.md"])
  check "CLAUDE.md is the rig's" ((open --raw ($home | path join CLAUDE.md)) == (open --raw ($RIG_CONFIG | path join CLAUDE.md)))
  check "no backup is taken when nothing was there" ((names ($home | path dirname) | where {|name| $name starts-with ".claude" }) == [".claude"])

  let second = apply $home
  check "a second run changes nothing" ($second.stdout =~ "already up to date" and $second.stdout !~ '(?m)^ +change ')
}

def test-existing-config [root: path] {
  print "a machine with its own Claude config"
  let home = $root | path join existing .claude
  mkdir ($home | path join skills local-only) ($home | path join skills alpha)
  "old" | save ($home | path join skills alpha SKILL.md)
  "mine" | save ($home | path join skills local-only SKILL.md)
  {
    model: "sonnet"
    localOnly: {keep: true}
    permissions: {defaultMode: "default", allow: ["Bash(ls:*)"]}
    sandbox: {excludedCommands: ["podman", "git"]}
  } | to json | save ($home | path join settings.json)

  let first = apply $home
  check "the first run succeeds" ($first.exit_code == 0)

  let settings = open --raw ($home | path join settings.json) | from json
  let rig = open --raw ($RIG_CONFIG | path join settings.json) | from json
  check "a key that exists only here is kept" ($settings.localOnly == {keep: true})
  check "the rig's value wins where both have one" ($settings.model == $rig.model)
  check "a nested key that exists only here is kept" ($settings.permissions.allow == ["Bash(ls:*)"])
  check "a list keeps the rig's entries and adds the local ones" (
    ($rig.sandbox.excludedCommands | all {|item| $item in $settings.sandbox.excludedCommands }) and "podman" in $settings.sandbox.excludedCommands
  )
  check "a list has no duplicates" (($settings.sandbox.excludedCommands | uniq | length) == ($settings.sandbox.excludedCommands | length))

  check "a skill that exists only here is left alone" ((open --raw ($home | path join skills local-only SKILL.md)) == "mine")
  check "the rig's skill replaced the old one" ((open --raw ($home | path join skills alpha SKILL.md)) != "old")

  let backups = names ($home | path dirname) | where {|name| $name starts-with ".claude.rig-backup-" }
  check "one backup was taken" (($backups | length) == 1)
  let backup = $home | path dirname | path join $backups.0
  check "the backup holds the old skill" ((open --raw ($backup | path join skills alpha SKILL.md)) == "old")
  check "the backup holds the old settings" ((open --raw ($backup | path join settings.json) | from json | get model) == "sonnet")

  let second = apply $home
  check "a second run changes nothing" ($second.stdout =~ "already up to date")
  check "a second run takes no second backup" ((names ($home | path dirname) | where {|name| $name starts-with ".claude.rig-backup-" } | length) == 1)

  print "a skill changed on the machine"
  "tampered" | save --append ($home | path join skills alpha SKILL.md)
  let repair = apply $home
  check "the changed skill is put back" ($repair.stdout =~ "update skills/alpha" and $repair.stdout !~ "local-only")

  print "a skill the rig once installed and has since dropped"
  mkdir ($home | path join skills gone)
  (names ($RIG_CONFIG | path join skills) | each {|name| $"skills/($name)" } | append "skills/gone" | str join "\n") | save --force ($home | path join .rig-manifest)
  let drop = apply $home
  check "the dropped skill is removed" (not ($home | path join skills gone | path exists))
  check "the local skill is still there" ($home | path join skills local-only SKILL.md | path exists)
}

def test-broken-settings [root: path] {
  print "a machine whose settings.json is not valid JSON"
  let home = $root | path join broken .claude
  mkdir $home
  "{bad" | save ($home | path join settings.json)
  let run = apply $home
  check "the run stops with an error" ($run.exit_code != 0)
  check "the error names the problem" ($run.stderr =~ "not valid JSON")
  check "the broken file is left as it was" ((open --raw ($home | path join settings.json)) == "{bad")
}

def main [] {
  let root = mktemp --directory | path expand
  try {
    test-fresh-machine $root
    test-existing-config $root
    test-broken-settings $root
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "apply: every test passed."
}
