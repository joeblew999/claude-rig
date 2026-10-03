#!/usr/bin/env nu
# report.nu — tests for what a machine reports to fleet-api, and how.
#
# Each test runs the real task against a throwaway rig folder
# (RIG_CONFIG_HOME): the report built from a made-up `doctor --json` holds
# to fleet-api's schema, the machine id stays the same, a report that cannot
# be delivered is spooled, and with no token nothing is posted. Nothing here
# reaches fleet-api: the one URL used is a closed port on this machine.
#
#   nu tests/report.nu

use ../tasks/report.nu [TOKEN_UNIX_COMMAND auth-from]
use ../tasks/awake.nu [awake-plan run-windows-keeper keeper-state]

const REPORT = path self ../tasks/report.nu
const ENROLL = path self ../tasks/enroll.nu
const FIXTURE = path self fixtures/doctor.json
const CREDENTIALS = path self fixtures/credentials.json
# Nothing listens here, so every post fails at once.
const CLOSED = "http://127.0.0.1:9"

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# Run report.nu with a throwaway rig folder, and no token unless given.
def run-report [rig_home: path, args: list<string>, --token: string = "", --url: string = $CLOSED]: nothing -> record {
  with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_WRITE_TOKEN: $token, FLEET_API_READ_TOKEN: "", FLEET_API_URL: $url } {
    ^$nu.current-exe $REPORT ...$args | complete
  }
}

# --- fleet-api's rules, as api/device.go in fleet-api says them -----------

def is-int [value: any]: nothing -> bool { ($value | describe) == "int" }

# Every rule a report breaks, as "where: what". Empty when it holds.
export def schema-errors [report: record]: nothing -> list<string> {
  mut bad = []
  let watching = $report.reason? in [start change interval]
  if $report.schema? != 1 { $bad = $bad | append "schema: not 1" }
  if ($report.id? | default "") !~ '^[0-9a-f]{16}$' { $bad = $bad | append "id: not 16 hex digits" }
  if not (is-int $report.ts?) or ($report.ts? | default 0) < 1 { $bad = $bad | append "ts: not Unix milliseconds" }
  if $report.reason? not-in [start change interval stop once] { $bad = $bad | append "reason: unknown" }
  let next = $report.next_s? | default (-1)
  if not (is-int $next) or $next < 0 or $next > 86400 { $bad = $bad | append "next_s: out of range" }
  if $watching and $next == 0 { $bad = $bad | append "next_s: a watcher promises its next report" }
  if not $watching and $next != 0 { $bad = $bad | append "next_s: stop and once promise nothing" }
  for field in [version command] {
    if ($report.tool? | default {} | get --optional $field | default "") == "" { $bad = $bad | append $"tool.($field): missing" }
  }
  let host = $report.host? | default {}
  if ($host.name? | default "") == "" { $bad = $bad | append "host.name: missing" }
  if $host.os? not-in [darwin linux windows] { $bad = $bad | append "host.os: not darwin, linux or windows" }
  if ($host.arch? | default "") == "" { $bad = $bad | append "host.arch: missing" }
  if "boot" in $host and not (is-int $host.boot) { $bad = $bad | append "host.boot: not an integer" }

  # A section: its status, why only when unknown, and the values it must
  # (need) or may (only) carry when ok and must not carry otherwise.
  let section = {|path, value, statuses, need, only, ints|
    mut errors = []
    let status = $value.status? | default ""
    if $status not-in $statuses { $errors = $errors | append $"($path).status: ($status) is not one of ($statuses | str join ', ')" }
    if $status == "unknown" and ($value.why? | default "") == "" { $errors = $errors | append $"($path).why: unknown needs a reason" }
    if $status == "ok" and ($value.why? | default "") != "" { $errors = $errors | append $"($path).why: ok has no reason" }
    for field in $need {
      let present = ($value | get --optional $field) != null
      if $status == "ok" and not $present { $errors = $errors | append $"($path).($field): missing though ok" }
      if $status != "ok" and $present { $errors = $errors | append $"($path).($field): present though not ok" }
    }
    for field in $only {
      if $status != "ok" and ($value | get --optional $field) != null { $errors = $errors | append $"($path).($field): present though not ok" }
    }
    for field in $ints {
      let found = $value | get --optional $field
      if $found != null and not (is-int $found) { $errors = $errors | append $"($path).($field): not an integer" }
      if $found != null and (is-int $found) and $found < 0 { $errors = $errors | append $"($path).($field): negative" }
    }
    $errors
  }

  $bad = $bad ++ (do $section cpu ($report.cpu? | default {}) [ok unknown] [count] [load1] [count])
  let memory = $report.memory? | default {}
  $bad = $bad ++ (do $section memory $memory [ok unknown] [total available] [] [total available])
  if ($memory.available? | default 0) > ($memory.total? | default 0) { $bad = $bad | append "memory.available: more than total" }

  let disks = $report.disks? | default []
  if ($disks | is-empty) or ($disks | length) > 8 { $bad = $bad | append "disks: 1 to 8 entries" }
  let roles = $disks | each {|disk| $disk.roles? | default [] } | flatten
  if ($roles | sort) != ([system data] | sort) { $bad = $bad | append $"disks: roles are ($roles | str join ', '), not system and data once each" }
  for disk in ($disks | enumerate) {
    let path = $"disks[($disk.index)]"
    $bad = $bad ++ (do $section $path $disk.item [ok unknown] [total free] [fs] [total free])
    if ($disk.item.path? | default "") == "" { $bad = $bad | append $"($path).path: missing" }
    if ($disk.item.free? | default 0) > ($disk.item.total? | default 0) { $bad = $bad | append $"($path).free: more than total" }
  }

  let power = $report.power? | default {}
  $bad = $bad ++ (do $section power $power [ok unknown] [source] [] [])
  if "source" in $power and $power.source not-in [ac battery ups] { $bad = $bad | append "power.source: unknown" }

  let battery = $report.battery? | default {}
  $bad = $bad ++ (do $section battery $battery [ok none unknown] [count percent state] [health remaining_s] [count remaining_s])
  if "percent" in $battery and ($battery.percent < 0 or $battery.percent > 100) { $bad = $bad | append "battery.percent: outside 0 to 100" }
  if "state" in $battery and $battery.state not-in [charging discharging full idle] { $bad = $bad | append "battery.state: unknown" }
  if $battery.status? == "none" and $power.source? == "battery" { $bad = $bad | append "power.source: battery, with no battery" }

  let lid = $report.lid? | default {}
  $bad = $bad ++ (do $section lid $lid [ok none unknown] [closed] [] [])

  let sleep = $report.sleep? | default {}
  $bad = $bad ++ (do $section sleep $sleep [ok none unknown] [idle_s inhibited] [display_s lid_action inhibitors] [idle_s display_s])
  if $sleep.status? == "ok" and $lid.status? == "ok" and ($sleep.lid_action? | default "") == "" { $bad = $bad | append "sleep.lid_action: missing though there is a lid" }
  if "lid_action" in $sleep and $sleep.lid_action not-in [sleep hibernate shutdown lock nothing] { $bad = $bad | append "sleep.lid_action: unknown" }
  if ($sleep.inhibited? == false) and ($sleep.inhibitors? | default [] | is-not-empty) { $bad = $bad | append "sleep.inhibitors: listed though nothing inhibits" }
  if ($sleep.inhibitors? | default [] | length) > 8 { $bad = $bad | append "sleep.inhibitors: more than 8" }

  let keeper = $report.keeper? | default {}
  $bad = $bad ++ (do $section keeper $keeper [ok none unknown] [running idle lid] [] [])
  if $keeper.running? == false and ($keeper.idle? == true or $keeper.lid? == true) { $bad = $bad | append "keeper: holding something though it is not running" }

  if "rig" in $report {
    $bad = $bad ++ (do $section rig $report.rig [ok none unknown] [tools_installed config_applied logged_in session_running] [commit claude_version work_dir] [])
  }
  if "claims" in $report {
    let claims = $report.claims
    $bad = $bad ++ (do $section claims $claims [ok none unknown] [slots] [held] [slots])
    let held = $claims.held? | default []
    if ($claims.slots? | default 64) < ($held | length) { $bad = $bad | append "claims.held: more claims than slots" }
    for claim in ($held | enumerate) {
      let path = $"claims.held[($claim.index)]"
      if ($claim.item.id? | default "") !~ '^[A-Za-z0-9._-]{1,64}$' { $bad = $bad | append $"($path).id: not a claim id" }
      if ($claim.item.caller? | default "") == "" or ($claim.item.job? | default "") == "" { $bad = $bad | append $"($path): caller and job are needed" }
      if not (is-int $claim.item.since?) { $bad = $bad | append $"($path).since: not Unix milliseconds" }
      if "until" in $claim.item and ($claim.item.until < $claim.item.since) { $bad = $bad | append $"($path).until: before since" }
    }
  }

  # Nothing that names a person or a network, and no string over 200 bytes.
  let strings = $report | to json --raw | parse --regex '"(?<text>(?:[^"\\]|\\.)*)"' | get text
  for text in $strings {
    if ($text | str contains "@") { $bad = $bad | append $"a string has an @: ($text)" }
    if $text =~ '(^|[^0-9.])\d{1,3}(\.\d{1,3}){3}($|[^0-9.])' { $bad = $bad | append $"a string has an IP address: ($text)" }
    if $text =~ '(?i)^([a-z]:)?[/\\]+(users|home)[/\\]+[^/\\]+' and $text !~ '(?i)^([a-z]:)?[/\\]+users[/\\]+shared' { $bad = $bad | append $"a string names a home folder: ($text)" }
    if $text =~ '([0-9a-f]{2}[:-]){5}[0-9a-f]{2}' { $bad = $bad | append $"a string has a MAC address: ($text)" }
    if ($text | str length) > 200 { $bad = $bad | append "a string is over 200 bytes" }
  }
  if ($report | to json --raw | str length) > 16384 { $bad = $bad | append "over 16 KiB" }
  $bad
}

# --- The tests ----------------------------------------------------------------

def test-shape [root: path] {
  print "the report from a doctor --json fixture"
  let rig_home = $root | path join shape
  let run = run-report $rig_home [--print --doctor $FIXTURE]
  check "report --print succeeds" ($run.exit_code == 0)
  let report = $run.stdout | from json
  let errors = schema-errors $report
  if ($errors | is-not-empty) { print ($errors | each {|error| $"        ($error)" } | str join "\n") }
  check "it holds to fleet-api's schema" ($errors | is-empty)
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
  check "a start report holds to the schema and promises the next in 300 s" ((schema-errors $started | is-empty) and $started.next_s == 300)

  let broken = $report | upsert next_s 300 | upsert rig.work_dir "/home/dev/work"
  check "the checks catch a report that breaks the rules" ((schema-errors $broken | length) >= 2)
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
  let run = run-report $rig_home [--doctor $FIXTURE] --token "test-token"
  check "the run still succeeds" ($run.exit_code == 0)
  check "it says the report is spooled" ($run.stdout =~ 'report: once spooled: could not reach')
  check "the report waits in the spool" ((ls $spool | length) == 1)
  let again = run-report $rig_home [--doctor $FIXTURE --reason interval] --token "test-token"
  check "the next one is spooled beside it" ($again.stdout =~ 'spooled' and (ls $spool | length) == 2)
  let kept = ls $spool | get name | sort | each {|file| open --raw $file | decode utf-8 | from json }
  check "both are whole reports, oldest first" ($kept.0.reason == "once" and $kept.1.reason == "interval" and ($kept | all {|report| schema-errors $report | is-empty }))
  check "the token is in none of them" ($kept | all {|report| not ($report | to json | str contains "test-token") })
}

def test-no-token [root: path] {
  print "no token"
  let rig_home = $root | path join no-token
  let run = run-report $rig_home [--doctor $FIXTURE]
  check "the run still succeeds" ($run.exit_code == 0)
  check "reporting says skipped and why" ($run.stdout =~ 'skipped: no write token')
  check "nothing is spooled" (not ($rig_home | path join report-spool | path exists))

  let step = with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_WRITE_TOKEN: "", RIG_CHANGES: "0", RIG_DRY_RUN: "0" } {
    ^$nu.current-exe --commands $"use '($ENROLL)' [token-step]; token-step" | complete
  }
  check "the rig's token step skips, saying how to give one" ($step.exit_code == 0 and $step.stdout =~ 'skip +reporting to fleet-api: no write token')
}

def test-token-file [root: path] {
  print "the token on a machine"
  let rig_home = $root | path join token
  let file = $rig_home | path join fleet-api.token
  let step = {|token|
    with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_WRITE_TOKEN: $token, RIG_CHANGES: "0", RIG_DRY_RUN: "0" } {
      ^$nu.current-exe --commands $"use '($ENROLL)' [token-step]; token-step" | complete
    }
  }
  let first = do $step "test-token-1"
  check "the rig keeps a token from the environment" ($first.exit_code == 0 and $first.stdout =~ 'change +keep the fleet-api write token' and (open --raw $file | decode utf-8) == "test-token-1")
  check "and never prints it" (not ($first.stdout | str contains "test-token-1"))
  if $nu.os-info.name == "windows" {
    let acl = ^icacls $file | complete | get stdout
    print ($acl | lines | where {|line| $line =~ ':' } | str join "\n")
    check "the file is closed to everyone but the user" ($acl =~ $env.USERNAME and $acl !~ '(?i)(Everyone|BUILTIN\\|Authenticated Users|NT AUTHORITY)')
  } else {
    check "the file is readable by the user only" ((ls -l $file | get 0.mode) == "rw-------")
  }
  check "a second run changes nothing" ((do $step "test-token-1").stdout =~ 'ok +fleet-api write token')
  check "a run with no token in its environment keeps the file" ((do $step "").stdout =~ 'ok +fleet-api write token')
  let run = with-env { RIG_CONFIG_HOME: $rig_home, FLEET_API_WRITE_TOKEN: "", FLEET_API_URL: $CLOSED } {
    ^$nu.current-exe $REPORT --doctor $FIXTURE | complete
  }
  check "a report uses the token in the file" ($run.stdout =~ 'spooled')

  if $nu.os-info.name != "windows" {
    # What push runs on a macOS or Linux machine, run here in a made-up home.
    let home = $root | path join remote-home
    mkdir $home
    let sent = do { cd $home; "test-token-2" | ^sh -c ($TOKEN_UNIX_COMMAND | str replace --regex "^sh -c '(.*)'$" '$1') | complete }
    let remote = $home | path join .config claude-rig fleet-api.token
    check "push's command keeps the token it is sent" ($sent.exit_code == 0 and (open --raw $remote | decode utf-8) == "test-token-2")
    check "readable by that user only" ((ls -l $remote | get 0.mode) == "rw-------")
  }
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
    with-env { RIG_CONFIG_HOME: ($root | path join login-rig), CLAUDE_HOME: $home, PATH: ([$bin] ++ $env.PATH), FLEET_API_WRITE_TOKEN: "" } {
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
  check "the report still holds to the schema" (schema-errors ($result.stdout | from json) | is-empty)

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

def main [] {
  let root = mktemp --directory | path expand
  try {
    test-shape $root
    test-device-id $root
    test-spool $root
    test-no-token $root
    test-token-file $root
    test-login $root
    test-awake
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "report: every test passed."
}
