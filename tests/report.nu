#!/usr/bin/env nu
# report.nu — tests for what a machine reports to fleet-api, and how.
#
# Each test runs the real task against a throwaway rig folder
# (RIG_CONFIG_HOME): the report built from a made-up `doctor --json` holds
# to fleet-api's schema, as fleet-api's generated SDK checks it (through
# tasks/fleet-api.ts, so bun and the SDK the tool list installs are needed),
# names no person or network, the machine id stays the same, a report that
# cannot be delivered is spooled, with no token nothing is posted, the
# machine's token is kept readable by its user only, push makes a token with
# fleet-api's task (here a stand-in for it), and the VM keeper's list is taken
# while fresh. Nothing here reaches fleet-api: the one URL used is a closed
# port on this machine.
#
#   nu tests/report.nu

use ../tasks/report.nu [ACCESS_UNIX_COMMAND auth-from fleet-api]
use ../tasks/awake.nu [awake-plan run-windows-keeper keeper-state]

const REPORT = path self ../tasks/report.nu
const ENROLL = path self ../tasks/enroll.nu
const PUSH = path self ../tasks/push.nu
const FIXTURE = path self fixtures/doctor.json
const CREDENTIALS = path self fixtures/credentials.json
# Nothing listens here, so every post fails at once.
const CLOSED = "http://127.0.0.1:9"

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# A made-up Access service token.
const ID = "made-up-id.access"
const HIDDEN = "made-up-for-tests"

# Run report.nu with a throwaway rig folder, and no token unless given.
def run-report [rig_home: path, args: list<string>, --token, --url: string = $CLOSED]: nothing -> record {
  let id = if $token { $ID } else { "" }
  let secret = if $token { $HIDDEN } else { "" }
  with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_ACCESS_CLIENT_ID: $id, FLEET_API_ACCESS_CLIENT_SECRET: $secret, FLEET_API_URL: $url } {
    ^$nu.current-exe $REPORT ...$args | complete
  }
}

def is-int [value: any]: nothing -> bool { ($value | describe) == "int" }

# Why fleet-api's schema refuses a report, as its generated SDK checks it; ""
# when it holds.
def refused [report: record]: nothing -> string {
  let answer = fleet-api check --input ($report | to json --raw)
  if $answer.ok { "" } else { $answer.why }
}

# Everything in a report that names a person or a network. Empty when it
# names none.
export def privacy-errors [report: record]: nothing -> list<string> {
  let strings = $report | to json --raw | parse --regex '"(?<text>(?:[^"\\]|\\.)*)"' | get text
  mut bad = []
  for text in $strings {
    if ($text | str contains "@") { $bad = $bad | append $"a string has an @: ($text)" }
    if $text =~ '(^|[^0-9.])\d{1,3}(\.\d{1,3}){3}($|[^0-9.])' { $bad = $bad | append $"a string has an IP address: ($text)" }
    if $text =~ '(?i)^([a-z]:)?[/\\]+(users|home)[/\\]+[^/\\]+' and $text !~ '(?i)^([a-z]:)?[/\\]+users[/\\]+shared' { $bad = $bad | append $"a string names a home folder: ($text)" }
    if $text =~ '([0-9a-f]{2}[:-]){5}[0-9a-f]{2}' { $bad = $bad | append $"a string has a MAC address: ($text)" }
  }
  $bad
}

# --- The tests ----------------------------------------------------------------

def test-shape [root: path] {
  print "the report from a doctor --json fixture"
  let rig_home = $root | path join shape
  let run = run-report $rig_home [--print --doctor $FIXTURE]
  check "report --print succeeds" ($run.exit_code == 0)
  let report = $run.stdout | from json
  let why = refused $report
  if $why != "" { print $"        ($why)" }
  check "it holds to fleet-api's schema, as its SDK checks it" ($why == "")
  let named = privacy-errors $report
  if ($named | is-not-empty) { print ($named | each {|error| $"        ($error)" } | str join "\n") }
  check "it names no person or network" ($named | is-empty)
  check "reason once promises no next report" ($report.reason == "once" and $report.next_s == 0)
  check "the rig section is doctor's" ($report.rig.status == "ok" and $report.rig.logged_in and not $report.rig.session_running and $report.rig.commit == "4fd9d8e")
  check "the work folder is written with ~" ($report.rig.work_dir == "~/work")
  check "the claims are there, slots and all" ($report.claims.slots == 2 and ($report.claims.held | length) == 2)
  check "a caller written user@host keeps only the host" ($report.claims.held.0.caller == "a person on studio-1")
  check "claim times are Unix milliseconds" ($report.claims.held.0.since == 1790997753120 and "until" not-in $report.claims.held.1)
  check "memory and disks are bytes" ((is-int $report.memory.total?) and (is-int ($report.disks.0.total? | default 1)))

  # This machine's own report too, whatever it runs on.
  let start = run-report $rig_home [--print --doctor $FIXTURE --reason start]
  let started = $start.stdout | from json
  check "a start report holds to the schema and promises the next in 300 s" ((refused $started) == "" and $started.next_s == 300)
  let checked = run-report $rig_home [--check --doctor $FIXTURE]
  check "report --check says it holds" ($checked.exit_code == 0 and $checked.stdout =~ "holds to fleet-api's schema")

  check "the SDK refuses a report that breaks the schema" ((refused ($report | upsert reason "whenever" | reject host)) =~ 'reason.*host')
  check "the privacy check catches a home folder and an address" ((privacy-errors ($report | upsert rig.work_dir "/home/dev/work" | upsert host.name "dev@box") | length) == 2)
}

def test-device-id [root: path] {
  print "the machine id"
  let rig_home = $root | path join id
  let first = run-report $rig_home [--print --doctor $FIXTURE] | get stdout | from json | get id
  let second = run-report $rig_home [--print --doctor $FIXTURE] | get stdout | from json | get id
  check "it is 16 hex digits" ($first =~ '^[0-9a-f]{16}$')
  check "it is the same on the next run" ($first == $second)
  check "it is kept in the rig folder" ((open --raw ($rig_home | path join device-id) | decode utf-8 | str trim) == $first)
  let other = run-report ($root | path join id-other) [--print --doctor $FIXTURE] | get stdout | from json | get id
  check "another machine gets another" ($other != $first)
}

def test-spool [root: path] {
  print "a report that cannot be delivered"
  let rig_home = $root | path join spool
  let spool = $rig_home | path join report-spool
  let run = run-report $rig_home [--doctor $FIXTURE] --token
  check "the run still succeeds" ($run.exit_code == 0)
  check "it says the report is spooled" ($run.stdout =~ 'report: once spooled: could not reach')
  check "the report waits in the spool" ((ls $spool | length) == 1)
  let again = run-report $rig_home [--doctor $FIXTURE --reason interval] --token
  check "the next one is spooled beside it" ($again.stdout =~ 'spooled' and (ls $spool | length) == 2)
  let kept = ls $spool | get name | sort | each {|file| open --raw $file | decode utf-8 | from json }
  check "both are whole reports, oldest first" ($kept.0.reason == "once" and $kept.1.reason == "interval" and ($kept | all {|report| (refused $report) == "" }))
  check "the token is in none of them" ($kept | all {|report| not ($report | to json | str contains $HIDDEN) and not ($report | to json | str contains $ID) })
}

def test-no-token [root: path] {
  print "no token"
  let rig_home = $root | path join no-token
  let run = run-report $rig_home [--doctor $FIXTURE]
  check "the run still succeeds" ($run.exit_code == 0)
  check "reporting says skipped and why" ($run.stdout =~ 'skipped: no fleet-api token')
  check "nothing is spooled" (not ($rig_home | path join report-spool | path exists))

  let step = access-step $rig_home "" ""
  check "the rig's token step skips, saying how to give one" ($step.exit_code == 0 and $step.stdout =~ 'skip +reporting to fleet-api: no token')
  let half = access-step $rig_home $ID ""
  check "half a token stops the rig, saying so" ($half.exit_code != 0 and $half.stderr =~ 'both')
}

# The rig's token step, in a throwaway rig folder, with this token in its environment.
def access-step [rig_home: path, id: string, secret: string]: nothing -> record {
  with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_ACCESS_CLIENT_ID: $id, FLEET_API_ACCESS_CLIENT_SECRET: $secret, RIG_CHANGES: "0", RIG_DRY_RUN: "0" } {
    ^$nu.current-exe --commands $"use '($ENROLL)' [access-step]; access-step" | complete
  }
}

def test-token-file [root: path] {
  print "the token on a machine"
  let rig_home = $root | path join token
  let file = $rig_home | path join fleet-api-access.json
  mkdir $rig_home
  "old-shared-token" | save ($rig_home | path join fleet-api.token)
  let first = access-step $rig_home $ID $HIDDEN
  check "the rig keeps a token from the environment" ($first.exit_code == 0 and $first.stdout =~ 'change +keep the fleet-api token' and (open --raw $file | decode utf-8 | from json) == {client_id: $ID, client_secret: $HIDDEN})
  check "and never prints it" (not ($first.stdout | str contains $HIDDEN))
  check "the old shared write token is removed" ($first.stdout =~ 'no longer takes' and not ($rig_home | path join fleet-api.token | path exists))
  if $nu.os-info.name == "windows" {
    let acl = ^icacls $file | complete | get stdout
    print ($acl | lines | where {|line| $line =~ ':' } | str join "\n")
    check "the file is closed to everyone but the user" ($acl =~ $env.USERNAME and $acl !~ '(?i)(Everyone|BUILTIN\\|Authenticated Users|NT AUTHORITY)')
  } else {
    check "the file is readable by the user only" ((ls -l $file | get 0.mode) == "rw-------")
  }
  check "a second run changes nothing" ((access-step $rig_home $ID $HIDDEN).stdout =~ 'ok +fleet-api token')
  check "a run with no token in its environment keeps the file" ((access-step $rig_home "" "").stdout =~ 'ok +fleet-api token')
  let run = with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_ACCESS_CLIENT_ID: "", FLEET_API_ACCESS_CLIENT_SECRET: "", FLEET_API_URL: $CLOSED } {
    ^$nu.current-exe $REPORT --doctor $FIXTURE | complete
  }
  check "a report uses the token in the file" ($run.stdout =~ 'spooled: could not reach')
  let who = with-env { RIG_CONFIG_HOME: $rig_home, RIG_NAME: "Studio_2.local" } { ^$nu.current-exe $REPORT --whoami | complete | get stdout | from json }
  check "--whoami gives the machine id, the token's name, and that it has one" ($who.id =~ '^[0-9a-f]{16}$' and $who.token_name == "studio-2" and $who.has_token)

  if $nu.os-info.name != "windows" {
    # What push runs on a macOS or Linux machine, run here in a made-up home.
    let home = $root | path join remote-home
    mkdir $home
    let text = {client_id: $ID, client_secret: $HIDDEN} | to json --raw
    let sent = do { cd $home; $text | ^sh -c ($ACCESS_UNIX_COMMAND | str replace --regex "^sh -c '(.*)'$" '$1') | complete }
    let remote = $home | path join .config claude-rig fleet-api-access.json
    check "push's command keeps the token it is sent" ($sent.exit_code == 0 and (open --raw $remote | decode utf-8) == $text)
    check "readable by that user only" ((ls -l $remote | get 0.mode) == "rw-------")
  }
}

# A stand-in for fleet-api's checkout: its access:token task, with the same
# commands and answers as fleet-api's scripts/access.mjs, keeping its tokens
# in a file instead of at Cloudflare. ci:push uses it too. mise must trust the
# folder: MISE_TRUSTED_CONFIG_PATHS.
export def fake-fleet-api [dir: path] {
  mkdir $dir
  let script = $dir | path join access.nu
  [
    "def main [command: string, ...args: string] {"
    "  let state = $env.FILE_PWD | path join tokens.json"
    "  let tokens = if ($state | path exists) { open $state } else { [] }"
    "  match $command {"
    "    create => {"
    "      let name = $'fleet-api-($args.0)'"
    "      if ($tokens | any {|t| $t.name == $name }) { print $'FAIL  ($name) exists: revoke it first, or pick another name'; exit 1 }"
    "      let count = $env.FILE_PWD | path join made"
    "      let n = (if ($count | path exists) { open --raw $count | into int } else { 0 }) + 1"
    "      $n | into string | save --force $count"
    "      $tokens | append {name: $name, device: $args.1} | to json | save --force $state"
    "      {client_id: $'stub-($n).access', client_secret: $'stub-secret-($n)'} | to json --raw | save --force $args.2"
    "      print $'PASS  ($name): posts for ($args.1) only'"
    "    }"
    "    list => { $tokens | each {|t| print $'($t.name)\tdevice ($t.device)\texpires 2027-10-03' } | ignore }"
    "    revoke => { $tokens | where name != $'fleet-api-($args.0)' | to json | save --force $state; print 'PASS  revoked' }"
    "  }"
    "}"
  ] | str join "\n" | save --force $script
  $"[tasks.\"access:token\"]\nrun = '\"($nu.current-exe)\" \"($script)\"'\n" | save --force ($dir | path join mise.toml)
}

def test-make-token [root: path] {
  print "push makes a machine's token with fleet-api's task"
  let fleet_api = $root | path join fleet-api
  fake-fleet-api $fleet_api
  let make = {|name, id|
    let folder = mktemp --directory | path expand
    let result = with-env { MISE_TRUSTED_CONFIG_PATHS: $fleet_api } {
      ^$nu.current-exe --commands $"use '($PUSH)' [make-token]; make-token '($fleet_api)' ($name) ($id) '($folder)' | to json --raw" | complete
    }
    let made = try { $result.stdout | lines | last | from json } catch { null }
    let token = if $made != null { open --raw $made.file | decode utf-8 | from json } else { null }
    rm --recursive --force $folder
    {exit_code: $result.exit_code, made: $made, token: $token, said: $"($result.stdout)($result.stderr)"}
  }
  let first = do $make "box" "00000000000000aa"
  if $first.exit_code != 0 { print $first.said }
  check "a new machine gets a new token" ($first.exit_code == 0 and not $first.made.rotated and $first.token.client_id == "stub-1.access")
  let again = do $make "box" "00000000000000aa"
  check "the same machine again: the token is revoked and made again" ($again.exit_code == 0 and $again.made.rotated and $again.token.client_secret == "stub-secret-2")
  let other = do $make "box" "00000000000000bb"
  check "another machine of the same name is refused, and the token left alone" ($other.exit_code != 0 and $other.said =~ 'for another machine' and (open ($fleet_api | path join tokens.json) | get device) == ["00000000000000aa"])
}

# The session's keep-awake holds sleep off while what it wraps runs.
# What `claude auth status` says, email and organisation included, so the
# test can see they are left out.
const AUTH_STATUS = '{"loggedIn":true,"authMethod":"claude.ai","apiProvider":"firstParty","email":"someone@example.com","orgId":"0b9c1d2e","orgName":"Someone Example Org"}'

# A stand-in for `claude` that answers `claude auth status` with it. Not on
# Windows, where a script does not stand in for claude.exe.
def fake-claude [dir: path] {
  mkdir $dir
  $"#!/bin/sh\necho '($AUTH_STATUS)'\n" | save --force ($dir | path join claude)
  ^chmod +x ($dir | path join claude)
}

def test-login [root: path] {
  print "the login, with a made-up stored login"
  let claude_home = $root | path join login-claude
  mkdir $claude_home
  cp $CREDENTIALS ($claude_home | path join .credentials.json)
  let auth = auth-from $AUTH_STATUS
  check "from claude auth status: logged in, and how, only" ($auth == {status: "ok", logged_in: true, auth_method: "claude.ai"})
  check "a status that is not JSON says why" ((auth-from "not logged in").status == "unknown")
  let bin = $root | path join login-bin
  let faked = $nu.os-info.name != "windows"
  if $faked { fake-claude $bin }
  let run = {|home|
    with-env { RIG_CONFIG_HOME: ($root | path join login-rig), CLAUDE_HOME: $home, PATH: ([$bin] ++ $env.PATH), FLEET_API_ACCESS_CLIENT_ID: "", FLEET_API_ACCESS_CLIENT_SECRET: "" } {
      ^$nu.current-exe $REPORT --print --doctor $FIXTURE | complete
    }
  }
  let result = do $run $claude_home
  check "report --print succeeds" ($result.exit_code == 0)
  let login = $result.stdout | from json | get rig.login
  if $faked {
    check "it says logged in, and how" ($login.status == "ok" and $login.logged_in and $login.auth_method == "claude.ai")
  } else {
    print $"    --  this machine's own claude says: ($login | reject --optional refresh_expires refresh_expires_why | to json --raw)"
  }
  let stored = open --raw $CREDENTIALS | decode utf-8 | from json | get claudeAiOauth
  let leaked = [$stored.accessToken $stored.refreshToken accessToken refreshToken sk-ant] | where {|secret| $result.stdout | str contains $secret }
  if ($leaked | is-not-empty) { print $"        in the report: ($leaked | str join ', ')" }
  check "no token, or its name, is in the report" ($leaked | is-empty)
  check "it has the refresh token's expiry, in Unix milliseconds" ($login.refresh_expires? == 1792989310012)
  check "nor the email or the organisation" (not ($result.stdout =~ '(?i)someone@example|0b9c1d2e|Example Org|"email"|"org'))
  check "the report still holds to the schema" ((refused ($result.stdout | from json)) == "")

  let bare = $root | path join login-bare
  mkdir $bare
  {claudeAiOauth: {accessToken: "x"}} | to json | save ($bare | path join .credentials.json)
  let without = do $run $bare | get stdout | from json | get rig.login
  check "a stored login with no expiry says why, and gives none" ("refresh_expires" not-in $without and ($without.refresh_expires_why? | default "") != "")
}

def test-awake [] {
  print "keeping the machine awake"
  let os = $nu.os-info.name
  if $os == "windows" {
    let keeper = job spawn { run-windows-keeper }
    mut running = false
    for attempt in 1..20 {
      if (keeper-state).running { $running = true; break }
      sleep 1sec
    }
    check "the keeper runs and the report sees it" $running
    # The keeper compiles its call first, so give it a few seconds to make it.
    mut requests = ^powercfg /requests | complete
    for attempt in 1..30 {
      if $requests.exit_code != 0 or $requests.stdout =~ '(?i)powershell' { break }
      sleep 1sec
      $requests = ^powercfg /requests | complete
    }
    if $requests.exit_code == 0 {
      print ($requests.stdout | lines | where {|line| $line =~ '(?i)SYSTEM|powershell' } | str join "\n")
      check "Windows lists it as holding the system awake" ($requests.stdout =~ '(?i)powershell')
    } else {
      print "    --  powercfg /requests needs administrator rights here, not checked"
    }
    try { job kill $keeper }
    return
  }
  let plan = awake-plan
  print $"    --  ($plan.note)"
  # Every Mac has caffeinate; a Linux machine may rightly have nothing to hold.
  if $os == "macos" { check "the session holds sleep off on macOS" ($plan.prefix | is-not-empty) }
  if ($plan.prefix | is-empty) { return }
  let held = job spawn { run-external ...$plan.prefix sleep "4" }
  sleep 1500ms
  if $os == "macos" {
    let assertions = ^pmset -g assertions | complete | get stdout
    check "caffeinate holds sleep off for what it runs" ($assertions =~ "caffeinate asserting on behalf of 'sleep'")
  } else {
    let list = ^systemd-inhibit --list | complete | get stdout
    check "systemd-inhibit holds idle and sleep off" ($list =~ 'claude-rig' and $list =~ 'idle:sleep' and $list =~ 'block')
  }
  try { job kill $held }
}

def test-vms [root: path] {
  print "the VMs, as the VM keeper writes them"
  let rig_home = $root | path join vms
  let report = {|| run-report $rig_home [--print --doctor $FIXTURE] | get stdout | from json }
  check "with no keeper's file there is no vms section" ("vms" not-in (do $report))
  mkdir $rig_home
  let now = (date now | into int) // 1_000_000
  let vms = {status: "ok", manager: "utm", manager_running: true, list: [{name: "claude-rig-linux", state: "started", os: "linux", owner: "claude-rig", keep_running: true, keeper_starts: 1}]}
  {ts: $now, vms: $vms} | to json | save --force ($rig_home | path join vms.json)
  let fresh = do $report
  check "a fresh list is the vms section, as written" ($fresh.vms == $vms)
  check "and the report holds to the schema" ((refused $fresh) == "")
  {ts: ($now - 600_000), vms: $vms} | to json | save --force ($rig_home | path join vms.json)
  let stale = do $report | get vms
  check "a stale list is unknown, and says how old" ($stale.status == "unknown" and $stale.why =~ '10 min ago' and "list" not-in $stale)
  "not json" | save --force ($rig_home | path join vms.json)
  check "a broken file is unknown, and says why" ((do $report | get vms.status) == "unknown")
}

def main [] {
  let root = mktemp --directory | path expand
  try {
    test-shape $root
    test-device-id $root
    test-spool $root
    test-no-token $root
    test-token-file $root
    test-make-token $root
    test-login $root
    test-vms $root
    test-awake
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "report: every test passed."
}
