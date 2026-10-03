#!/usr/bin/env nu
# config.nu — tests for where a config comes from: none at all, `config init`,
# a config sent by push, and a config given as a git URL.
#
# Each test runs the real tasks against throwaway folders: a made-up ~/.claude
# (CLAUDE_HOME) and a made-up ~/.config/claude-rig (RIG_CONFIG_HOME). The
# sending over SSH itself is not run here (it is in CI's push-windows job);
# what is sent, the packed file, is.
#
#   nu tests/config.nu

use ../tasks/userconfig.nu [pack-config]

const APPLY = path self ../tasks/apply.nu
const CONFIG = path self ../tasks/config.nu
const USERCONFIG = path self ../tasks/userconfig.nu
const FIXTURE = path self fixtures/config

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# Run a task with a made-up Claude folder and rig folder. RIG_CONFIG is
# empty unless given.
def run-task [task: path, home: path, rig_home: path, args: list<string>, --rig-config: string = ""]: nothing -> record {
  with-env { CLAUDE_HOME: $home, RIG_CONFIG_HOME: $rig_home, RIG_CONFIG: $rig_config, RIG_CHANGES: "0", RIG_DRY_RUN: "0" } {
    ^$nu.current-exe $task ...$args | complete
  }
}

def names [dir: path]: nothing -> list<string> {
  if ($dir | path exists) { ls --all $dir | get name | each {|path| $path | path basename } | sort } else { [] }
}

# Everything under a folder, as name and text, to see that nothing changed.
def snapshot [dir: path]: nothing -> list<string> {
  cd $dir
  glob "**/*" | each {|file|
    let name = $file | path relative-to $dir
    if ($file | path type) == "dir" { $name } else { $"($name) (open --raw $file | hash sha256)" }
  } | sort
}

# A Claude folder as a machine has it before the rig.
def make-home [root: path, name: string]: nothing -> path {
  let home = $root | path join $name .claude
  mkdir ($home | path join skills mine)
  "mine" | save ($home | path join skills mine SKILL.md)
  {model: "sonnet"} | to json | save ($home | path join settings.json)
  $home
}

def test-no-config [root: path] {
  print "a machine with no config"
  let home = make-home $root none
  let before = snapshot ($home | path dirname)
  let rig_home = $root | path join none-rig
  let run = run-task $APPLY $home $rig_home []
  check "the config step succeeds" ($run.exit_code == 0)
  check "it says it skipped the config" ($run.stdout =~ '(?m)^ +skip +config: none chosen')
  check "it changes nothing" ($run.stdout !~ '(?m)^ +(change|would) ')
  check "~/.claude is left exactly as it was" ((snapshot ($home | path dirname)) == $before)
  check "the rig's folder is not made" (not ($rig_home | path exists))

  let fresh = $root | path join none-fresh .claude
  let dry = run-task $APPLY $fresh $rig_home ["--dry-run"]
  check "a dry run on a bare machine skips it too" ($dry.exit_code == 0 and $dry.stdout =~ "skip +config")
  check "and makes no ~/.claude" (not ($fresh | path exists))

  let show = run-task $CONFIG $home $rig_home []
  check "`config` says there is none and how to make one" ($show.stdout =~ "config: none" and $show.stdout =~ "config -- init")
}

def test-init [root: path] {
  print "config init with a new folder"
  let home = make-home $root init
  let rig_home = $root | path join init-rig
  let folder = $root | path join my-config
  let run = run-task $CONFIG $home $rig_home [init $folder]
  check "init succeeds" ($run.exit_code == 0)
  check "the folder is remembered in config.toml" ((open ($rig_home | path join config.toml) | get folder) == $folder)
  check "this machine's ~/.claude is captured into it" ((names ($folder | path join skills)) == ["mine"] and ($folder | path join settings.json | path exists))

  let show = run-task $CONFIG $home $rig_home []
  check "`config` shows the folder" ($show.stdout =~ "my-config" and $show.stdout =~ "config.toml")

  let again = run-task $CONFIG $home $rig_home [init $folder]
  check "init again changes nothing" ($again.exit_code == 0 and $again.stdout !~ '(?m)^ +change ')

  print "config init with a folder that holds a config already"
  let clone = $root | path join a-clone
  cp --recursive $FIXTURE $clone
  "# my config repo" | save ($clone | path join README.md)
  let before = snapshot $clone
  let other = run-task $CONFIG $home $rig_home [init $clone]
  check "init succeeds" ($other.exit_code == 0)
  check "the setting now names it" ((open ($rig_home | path join config.toml) | get folder) == $clone)
  check "its config is not replaced" ((snapshot $clone) == $before)

  print "a run on the machine that chose a folder"
  let apply = run-task $APPLY $home $rig_home []
  check "the run applies the chosen folder" ($apply.exit_code == 0 and ($home | path join skills alpha SKILL.md | path exists))
  check "it says where the config came from" ($apply.stdout =~ "set in")
}

def test-sent-by-push [root: path] {
  print "a config sent by push"
  let home = $root | path join pushed .claude
  let rig_home = $root | path join pushed-rig
  mkdir $rig_home
  pack-config $FIXTURE ($rig_home | path join config.tar)
  let first = run-task $APPLY $home $rig_home []
  check "the run succeeds" ($first.exit_code == 0)
  check "it takes in what was sent" ($first.stdout =~ "take in the config sent by push")
  check "the machine's copy is the config that was sent" ((snapshot ($rig_home | path join config)) == (snapshot $FIXTURE))
  check "the sent file is cleared away" (not ($rig_home | path join config.tar | path exists))
  check "the config is applied" ((names ($home | path join skills)) == ["alpha" "beta"])

  pack-config $FIXTURE ($rig_home | path join config.tar)
  let second = run-task $APPLY $home $rig_home []
  check "the same config sent again changes nothing" ($second.exit_code == 0 and $second.stdout =~ "already up to date")

  let later = run-task $APPLY $home $rig_home []
  check "a run with nothing sent uses the machine's copy" ($later.stdout =~ "sent by push" and $later.stdout =~ "already up to date")

  print "what push packs"
  let extra = $root | path join packed-folder
  cp --recursive $FIXTURE $extra
  mkdir ($extra | path join .git)
  "secret history" | save ($extra | path join .git HEAD)
  "# README" | save ($extra | path join README.md)
  "x" | save ($extra | path join skills alpha .DS_Store)
  let out = $root | path join packed.tar
  pack-config $extra $out
  # Read on stdin: GNU tar takes the "C:" of a Windows path for a host name.
  let listed = open --raw $out | ^tar -tf - | lines | each {|line| $line | str trim --right --char "/" }
  check "only the config's entries are packed" ($listed | all {|name| ($name | path split | first) in [settings.json CLAUDE.md skills commands] })
  check "not .git or a README" ($listed | all {|name| $name !~ '^(\.git|README)' })
  check "not .DS_Store" ($listed | all {|name| $name !~ 'DS_Store' })

  print "a config with a secret in it is not sent"
  $"token: ghp_('a' | fill --width 36 --character 'a')" | save --force ($extra | path join skills beta SKILL.md)
  let bad = $root | path join bad.tar
  let refused = ^$nu.current-exe -c $"use '($USERCONFIG)' *; pack-for-push '($extra)' '($bad)'" | complete
  check "packing for push stops" ($refused.exit_code != 0)
  check "the error names the file" ($refused.stderr =~ "possible secret" and $refused.stderr =~ "SKILL.md")
  check "no pack is left to send" (not ($bad | path exists))
}

# A git URL for a local folder, as git wants it on every OS.
def file-url [dir: path]: nothing -> string {
  let slashed = $dir | str replace --all '\' '/'
  if ($slashed starts-with "/") { $"file://($slashed)" } else { $"file:///($slashed)" }
}

def test-git-url [root: path] {
  print "a config given as a git URL"
  let source = $root | path join config-repo
  cp --recursive $FIXTURE $source
  let git = [-C $source -c user.name=test -c user.email=test@example.com]
  ^git init -q $source
  ^git ...$git add -A
  ^git ...$git commit -q -m "a config"
  let url = file-url $source

  let home = $root | path join cloned .claude
  let rig_home = $root | path join cloned-rig
  let dry = run-task $APPLY $home $rig_home ["--dry-run"] --rig-config $url
  check "a dry run says it would clone" ($dry.exit_code == 0 and $dry.stdout =~ "would +clone the config")
  check "and keeps no clone" (not ($rig_home | path join config | path exists))

  let first = run-task $APPLY $home $rig_home [] --rig-config $url
  check "the run succeeds" ($first.exit_code == 0)
  check "the config is cloned into the machine's copy" ($rig_home | path join config .git | path exists)
  check "the config is applied" ((names ($home | path join skills)) == ["alpha" "beta"])

  let second = run-task $APPLY $home $rig_home [] --rig-config $url
  check "a second run changes nothing" ($second.exit_code == 0 and $second.stdout =~ "already up to date")

  "# A changed config\n" | save --force ($source | path join CLAUDE.md)
  ^git ...$git commit -q -am "change it"
  let later = run-task $APPLY $home $rig_home []
  check "a later run without RIG_CONFIG brings the clone up to date" ($later.exit_code == 0 and $later.stdout =~ "update the config from")
  # git on Windows may check text out with CRLF line endings.
  check "and applies the change" ((open --raw ($home | path join CLAUDE.md) | str replace --all "\r" "") == "# A changed config\n")
}

def main [] {
  let root = mktemp --directory | path expand
  try {
    test-no-config $root
    test-init $root
    test-sent-by-push $root
    test-git-url $root
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "config: every test passed."
}
