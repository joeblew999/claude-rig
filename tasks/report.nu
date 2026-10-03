#!/usr/bin/env nu
# report.nu — tell fleet-api what this machine is and how it is doing.
#
# Builds one device report (fleet-api's DeviceReport, schema 1) from
# `doctor --json`, what nushell reads about the machine and, where the VM
# tool's keeper runs, the VMs it last wrote down; then posts it with the
# machine's own Cloudflare Access service token through fleet-api.ts, which is
# fleet-api's generated TypeScript SDK
# (it checks the report against fleet-api's schema first). The session posts
# `start`, `interval` every 5 minutes and `stop`; run by hand it posts `once`.
#
# A report is put in the spool folder first and taken out when fleet-api has
# it, so one that could not be delivered is sent with the next. With no token
# nothing is posted, and nothing else is affected.
#
# Nothing in a report names a person or a network: no user names, IP or MAC
# addresses, serial numbers; the home folder is written as ~.
#
#   nu tasks/report.nu                   post a report now (reason once)
#   nu tasks/report.nu --print           print the report, post nothing
#   nu tasks/report.nu --doctor <file>   use this doctor --json output
#   nu tasks/report.nu --check           build the report, check it against fleet-api's schema, post nothing
#   nu tasks/report.nu --list [--json]   the fleet, as fleet-api has it
#   nu tasks/report.nu --whoami          {id, token_name, has_token}: the machine id (made if missing), for push

use lib.nu *
use userconfig.nu [rig-home]
use awake.nu [keeper-state linux-can-sleep]

const HERE = path self .
const SCHEMA = 1
# fleet-api's generated TypeScript SDK, as the tool list (mise/claude-rig.toml)
# installs it from fleet-api's release; the version is pinned there.
const SDK_TOOL = "github:joeblew999/fleet-api"
# The session reports this often, and promises it in next_s.
export const EVERY_S = 300
# At most this many reports wait in the spool: a day of them.
const SPOOL_MAX = 288

# A VM keeper's list is taken while it is this fresh: the keeper writes it
# every 15 s.
const VMS_FRESH_S = 120

# --- Where things are kept --------------------------------------------------

# The machine id: 16 random hex digits, made once, kept here.
export def device-id-file []: nothing -> path { rig-home | path join device-id }

# The machine's own Cloudflare Access service token for fleet-api,
# {client_id, client_secret}, readable by this machine's user alone.
export def access-file []: nothing -> path { rig-home | path join fleet-api-access.json }

# Reports not yet delivered, one file each.
export def spool-dir []: nothing -> path { rig-home | path join report-spool }

# The VMs on this machine, as the VM tool's keeper (irgo-winvm keeper) last
# wrote them: {ts, vms}, vms in fleet-api's shape.
export def vms-file []: nothing -> path { rig-home | path join vms.json }

# The machine id, made the first time it is asked for.
export def device-id []: nothing -> string {
  let file = device-id-file
  let kept = read-text $file | default "" | str trim
  if $kept =~ '^[0-9a-f]{16}$' { return $kept }
  let id = random binary 8 | encode hex | str lowercase
  mkdir ($file | path dirname)
  $id | save --force $file
  $id
}

# The name of this machine's Access service token in fleet-api
# (fleet-api-<name>): the machine's name, as fleet-api's access:token task
# takes it, lower-case letters, digits and dashes.
export def token-name []: nothing -> string {
  let name = machine-name | split row "." | first | str lowercase | str replace --all --regex '[^a-z0-9-]+' "-" | str trim --char "-"
  let name = $name | str substring 0..39 | str trim --char "-"
  if $name == "" { "machine" } else { $name }
}

# A client id or secret holds only these characters.
const ACCESS_CHARS = '^[A-Za-z0-9._-]+$'

# The credentials as the file keeps them, or null if they are not whole.
export def access-from [text: any] {
  let kept = try { $text | from json } catch { null }
  if ($kept | describe) !~ '^record' { return null }
  let id = $kept.client_id? | default "" | into string | str trim
  let secret = $kept.client_secret? | default "" | into string | str trim
  if $id !~ $ACCESS_CHARS or $secret !~ $ACCESS_CHARS { return null }
  {client_id: $id, client_secret: $secret}
}

# The machine's Access service token: the two FLEET_API_ACCESS_CLIENT_*
# variables when both are set, else the access file.
# Null if there is none.
export def access-token [] {
  let id = $env.FLEET_API_ACCESS_CLIENT_ID? | default "" | str trim
  let secret = $env.FLEET_API_ACCESS_CLIENT_SECRET? | default "" | str trim
  if $id != "" and $secret != "" { return (access-from ({client_id: $id, client_secret: $secret} | to json)) }
  access-from (read-text (access-file))
}

# The settings fleet-api.ts reads the token from.
def access-env [token: record]: nothing -> record {
  {FLEET_API_ACCESS_CLIENT_ID: $token.client_id, FLEET_API_ACCESS_CLIENT_SECRET: $token.client_secret}
}

# Keep the token in the access file, readable by this user alone.
export def save-access [token: record] {
  let file = access-file
  mkdir ($file | path dirname)
  # Made empty and locked down first, so the secret is never in a file others can read.
  "" | save --force $file
  if (is-windows) {
    # A file made by an administrator also names Administrators and SYSTEM
    # outright, so those go as well as what it inherits.
    ^icacls $file /inheritance:r /grant:r $"($env.USERNAME):F" /remove:g "*S-1-5-32-544" "*S-1-5-18" | complete | ignore
  } else {
    ^chmod 600 $file
  }
  ($token | to json --raw) + "\n" | save --force $file
}

# The command push runs on a macOS or Linux machine to keep the token file it
# sends on stdin. From the remote's home folder, like the config push sends.
export const ACCESS_UNIX_COMMAND = "sh -c 'umask 077 && mkdir -p .config/claude-rig && cat > .config/claude-rig/fleet-api-access.json && chmod 600 .config/claude-rig/fleet-api-access.json'"

# The PowerShell push sends on stdin to a Windows machine: the token file,
# made empty, closed to everyone but the user, then filled. The text is
# checked JSON of plain characters (access-from), so it is safe in quotes.
export def access-windows-script [text: string]: nothing -> string {
  [
    "$dir = Join-Path $HOME '.config\\claude-rig'"
    "New-Item -ItemType Directory -Force -Path $dir | Out-Null"
    "$file = Join-Path $dir 'fleet-api-access.json'"
    "Set-Content -Path $file -Value '' -NoNewline"
    "icacls $file /inheritance:r /grant:r ($env:USERNAME + ':F') /remove:g '*S-1-5-32-544' '*S-1-5-18' | Out-Null"
    "if ($LASTEXITCODE -ne 0) { exit 1 }"
    $"Set-Content -Path $file -Value '($text)' -NoNewline -Encoding ascii"
    ""
  ] | str join "\n"
}

# --- Reading the machine ----------------------------------------------------

# A path with the home folder written as ~. Another user's home folder is
# written as ~ too: a report never names a user.
export def tilde [text: string]: nothing -> string {
  let unixy = $text | str replace --all '\' '/'
  let home = $nu.home-dir | str replace --all '\' '/'
  if ($unixy | str lowercase) == ($home | str lowercase) { return "~" }
  if ($unixy | str lowercase | str starts-with ($home | str lowercase | $in + "/")) {
    return ("~" + ($unixy | str substring ($home | str length)..))
  }
  if $unixy =~ '^(?i)([a-z]:)?/users/shared(/|$)' { return $text }
  if $unixy =~ '^(?i)([a-z]:)?/(users|home)/[^/]+' {
    return ($unixy | str replace --regex '^(?i)([a-z]:)?/(users|home)/[^/]+' "~")
  }
  $text
}

def ms [when: datetime]: nothing -> int {
  ($when | into int) // 1_000_000
}

def unknown [why: string]: nothing -> record { {status: "unknown", why: $why} }

# Strings in a report are at most 200 bytes.
def cut [text: string]: nothing -> string {
  if ($text | str length) > 200 { $text | str substring 0..199 } else { $text }
}

def run-line [program: string, args: list<string>] {
  if not (have $program) { return null }
  let result = ^$program ...$args | complete
  if $result.exit_code != 0 { return null }
  $result.stdout | str trim
}

def report-os []: nothing -> string {
  match $nu.os-info.name { "macos" => "darwin", $other => $other }
}

def report-arch []: nothing -> string {
  match $nu.os-info.arch { "aarch64" => "arm64", "x86_64" => "amd64", $other => $other }
}

def host-section []: nothing -> record {
  let os = $nu.os-info.name
  let info = try { sys host } catch { {} }
  let os_name = match $os {
    "macos" => "macOS"
    _ => ($info.name? | default "")
  }
  let model = if $os == "macos" { run-line sysctl [-n hw.model] } else { null }
  let guest = match $os {
    "macos" => (run-line sysctl [-n kern.hv_vmm_present] | if $in == null { null } else { $in == "1" })
    "linux" => (if (have systemd-detect-virt) { (^systemd-detect-virt --quiet | complete | get exit_code) == 0 } else { null })
    _ => null
  }
  let boot = try { ms ($info.boot_time) } catch { null }
  {
    name: (machine-name | split row "." | first | cut $in)
    os: (report-os)
    arch: (report-arch)
    os_name: $os_name
    os_version: ($info.os_version? | default "")
    model: $model
    guest: $guest
    boot: $boot
  } | compact --empty
}

def cpu-section []: nothing -> record {
  let count = try { sys cpu | length } catch { 0 }
  if $count < 1 { return (unknown "the processors could not be read") }
  let load = match $nu.os-info.name {
    "linux" => (read-text /proc/loadavg | default "" | split row " " | get 0? )
    "macos" => (run-line sysctl [-n vm.loadavg] | default "" | str trim --char "{" | str trim | split row " " | get 0?)
    _ => null
  }
  let load1 = try { $load | into float } catch { null }
  {status: "ok", count: $count, load1: $load1} | compact
}

def memory-section []: nothing -> record {
  try {
    let mem = sys mem
    {status: "ok", total: ($mem.total | into int), available: ($mem.available | into int)}
  } catch {
    unknown "memory could not be read"
  }
}

# The system volume, and the volume the work folder is on: one entry with
# both roles when they are the same.
def disks-section []: nothing -> list<record> {
  let disks = try { sys disks } catch { [] }
  let os = $nu.os-info.name
  let work = work-dir | path expand
  let entry = {|roles, disk|
    {
      roles: $roles
      path: (tilde $disk.mount)
      status: "ok"
      fs: ($disk.type? | default "")
      total: ($disk.total | into int)
      free: ($disk.free | into int)
    } | compact --empty
  }
  # macOS keeps everything a user writes on the Data volume, beside the
  # sealed system volume: that one entry is both.
  if $os == "macos" {
    let data = $disks | where mount == "/System/Volumes/Data"
    if ($data | is-not-empty) { return [(do $entry [system data] $data.0)] }
  }
  let system_mount = if $os == "windows" { ($env.SystemDrive? | default "C:") + '\' } else { "/" }
  let norm = {|text| $text | str replace --all '\' '/' | str lowercase }
  let system = $disks | where {|disk| (do $norm $disk.mount) == (do $norm $system_mount) } | get 0?
  let work_norm = do $norm $work
  let data = $disks
    | where {|disk| $work_norm | str starts-with (do $norm $disk.mount) }
    | sort-by {|disk| $disk.mount | str length }
    | last 1 | get 0?
  let missing = {|roles, where| {roles: $roles, path: $where, status: "unknown", why: "not found in the list of volumes"} }
  if $system != null and $data != null and $system.mount == $data.mount {
    return [(do $entry [system data] $system)]
  }
  [
    (if $system != null { do $entry [system] $system } else { do $missing [system] $system_mount })
    (if $data != null { do $entry [data] $data } else { do $missing [data] (tilde $work) })
  ]
}

# Power source, battery and lid, on macOS from pmset and ioreg.
def macos-power []: nothing -> record {
  let batt = run-line pmset [-g batt]
  if $batt == null {
    let why = unknown "pmset -g batt did not answer"
    return {power: $why, battery: $why, lid: $why}
  }
  let source = $batt | parse --regex "Now drawing from '(?<source>[^']+)'" | get source.0? | default ""
  let power = match $source {
    "AC Power" => {status: "ok", source: "ac"}
    "Battery Power" => {status: "ok", source: "battery"}
    "UPS Power" => {status: "ok", source: "ups"}
    _ => (unknown "pmset -g batt names no power source")
  }
  let cells = $batt | lines | where {|line| $line =~ 'InternalBattery' }
  if ($cells | is-empty) {
    return {power: $power, battery: {status: "none"}, lid: {status: "none"}}
  }
  let parsed = $cells | parse --regex '\t(?<percent>\d+)%; (?<state>[^;]+); (?<rest>.*)'
  let battery = if ($parsed | is-empty) {
    unknown "pmset -g batt could not be read"
  } else {
    let first = $parsed.0
    let state = match $first.state {
      "charging" | "finishing charge" => "charging"
      "discharging" => "discharging"
      "charged" => "full"
      "AC attached" => "idle"
      _ => ""
    }
    let remaining = $first.rest | parse --regex '^(?<h>\d+):(?<m>\d+) remaining' | get 0?
    let remaining_s = if $remaining != null and $state in [charging discharging] {
      ($remaining.h | into int) * 3600 + ($remaining.m | into int) * 60
    } else { null }
    if $state == "" {
      unknown $"pmset -g batt says ($first.state)"
    } else {
      {status: "ok", count: ($cells | length), percent: ($first.percent | into int), state: $state, remaining_s: $remaining_s} | compact
    }
  }
  let clamshell = run-line ioreg [-r -k AppleClamshellState -d "4"] | default "" | parse --regex '"AppleClamshellState" = (?<closed>Yes|No)' | get closed.0?
  let lid = if $clamshell == null { unknown "ioreg shows no lid state" } else { {status: "ok", closed: ($clamshell == "Yes")} }
  {power: $power, battery: $battery, lid: $lid}
}

# Power source, battery and lid, on Linux from /sys and /proc.
def linux-power []: nothing -> record {
  let base = "/sys/class/power_supply"
  if not ($base | path exists) {
    let why = unknown "no /sys/class/power_supply"
    return {power: $why, battery: $why, lid: $why}
  }
  let read = {|dir, name| read-text ($dir | path join $name) | default "" | str trim }
  let supplies = ls $base | each {|entry|
    {type: (do $read $entry.name type), online: (do $read $entry.name online), status: (do $read $entry.name status), capacity: (do $read $entry.name capacity)}
  }
  let batteries = $supplies | where type == "Battery"
  let mains_on = $supplies | any {|supply| $supply.type in [Mains USB] and $supply.online == "1" }
  let battery = if ($batteries | is-empty) {
    {status: "none"}
  } else {
    let states = $batteries | get status | each {|status|
      match $status { "Charging" => "charging", "Discharging" => "discharging", "Full" => "full", "Not charging" => "idle", _ => "" }
    }
    let percents = $batteries | get capacity | where {|value| $value =~ '^\d+$' } | into float
    if ("" in $states) or ($percents | is-empty) {
      unknown "the battery state could not be read"
    } else {
      let state = if "discharging" in $states { "discharging" } else if "charging" in $states { "charging" } else { $states.0 }
      {status: "ok", count: ($batteries | length), percent: ($percents | math avg | math round --precision 1), state: $state}
    }
  }
  let power = if $mains_on {
    {status: "ok", source: "ac"}
  } else if ($battery.state? == "discharging") {
    {status: "ok", source: "battery"}
  } else {
    unknown "no power supply says it is online"
  }
  let lid_files = try { glob /proc/acpi/button/lid/*/state } catch { [] }
  let lid = if ($lid_files | is-not-empty) {
    {status: "ok", closed: (open --raw $lid_files.0 | decode utf-8 | str contains "closed")}
  } else if $battery.status == "none" {
    {status: "none"}
  } else {
    unknown "no ACPI lid entry"
  }
  {power: $power, battery: $battery, lid: $lid}
}

def power-sections []: nothing -> record {
  match $nu.os-info.name {
    "macos" => (macos-power)
    "linux" => (linux-power)
    _ => {
      let why = unknown "not read on Windows yet"
      {power: $why, battery: $why, lid: $why}
    }
  }
}

# When the machine would sleep by itself, and what holds it off.
def sleep-section [lid: record]: nothing -> record {
  match $nu.os-info.name {
    "macos" => {
      let settings = run-line pmset [-g]
      let assertions = run-line pmset [-g assertions]
      if $settings == null or $assertions == null { return (unknown "pmset did not answer") }
      let minutes = {|name| $settings | parse --regex ('(?m)^\s*' + $name + '\s+(?<value>\d+)') | get value.0? }
      let idle = do $minutes sleep
      if $idle == null { return (unknown "pmset -g shows no sleep setting") }
      let display = do $minutes displaysleep
      let count = {|name| $assertions | parse --regex ('(?m)^\s+' + $name + '\s+(?<value>\d+)\s*$') | get value.0? | default "0" | into int }
      let inhibited = (do $count PreventUserIdleSystemSleep) > 0 or (do $count PreventSystemSleep) > 0
      let inhibitors = if $inhibited {
        $assertions | parse --regex '(?m)^\s*pid \d+\((?<name>[^)]+)\): .*(PreventUserIdleSystemSleep|PreventSystemSleep) ' | get name | uniq | first 8 | each {|name| cut $name }
      } else { [] }
      let lid_action = if $lid.status == "ok" {
        if ($settings =~ '(?m)^\s*SleepDisabled\s+1') { "nothing" } else { "sleep" }
      } else { null }
      {
        status: "ok"
        idle_s: (($idle | into int) * 60)
        display_s: (if $display == null { null } else { ($display | into int) * 60 })
        lid_action: $lid_action
        inhibited: $inhibited
        inhibitors: $inhibitors
      } | compact --empty
    }
    "linux" => {
      if not (linux-can-sleep) {
        {status: "none", why: "the kernel offers no sleep state, or sleep.target is masked"}
      } else {
        unknown "the idle sleep time is not read on Linux"
      }
    }
    _ => (unknown "the idle sleep time is not read on Windows, and listing what holds sleep off (powercfg /requests) needs administrator rights")
  }
}

# --- The login -----------------------------------------------------------------

# The refresh token's expiry, from the text of Claude's stored login. Only
# that one number is taken out; nothing else in the text (the tokens) is kept,
# and a text that cannot be read gives a reason that does not quote it.
export def expiry-from [text: string]: nothing -> record {
  let at = try { $text | from json | get claudeAiOauth.refreshTokenExpiresAt } catch { null }
  if ($at | describe) != "int" or $at <= 0 { return {why: "the stored login has no refresh token expiry"} }
  # Unix milliseconds; a number this small is seconds.
  {at: (if $at < 100_000_000_000 { $at * 1000 } else { $at })}
}

# When the stored login's refresh token expires, Unix milliseconds, or why
# that is not known. Claude keeps the login in ~/.claude/.credentials.json
# on Linux and Windows, and in the keychain item "Claude Code-credentials" on
# macOS (the file wins when it is there).
def refresh-expiry []: nothing -> record {
  let file = claude-home | path join .credentials.json
  if ($file | path exists) {
    return (expiry-from (try { open --raw $file | decode utf-8 } catch { "" }))
  }
  if $nu.os-info.name != "macos" { return {why: "no ~/.claude/.credentials.json"} }
  let found = ^security find-generic-password -s "Claude Code-credentials" -w | complete
  if $found.exit_code != 0 { return {why: "no Claude login in the keychain"} }
  let text = $found.stdout | str trim
  # security prints the item as hex when it is not plain text.
  let text = if ($text | str starts-with "{") { $text } else { try { $text | decode hex | decode utf-8 } catch { "" } }
  expiry-from $text
}

# What `claude auth status` printed, as the report has it: only loggedIn and
# authMethod, never the email or the organisation.
export def auth-from [text: string]: nothing -> record {
  let info = try { $text | from json } catch { null }
  if ($info | describe) !~ '^record' { return (unknown "claude auth status gave no answer") }
  {
    status: "ok"
    logged_in: ($info.loggedIn? | default false)
    auth_method: ($info.authMethod? | default "" | into string | cut $in)
  } | compact --empty
}

# The login, as the login plan needs it: logged in, how (status says whether
# `claude auth status` answered), and when the refresh token runs out (with
# its own why when that is not known). Never a token.
def login-section []: nothing -> record {
  let auth = with-env {PATH: ($env.PATH ++ [(local-bin)])} {
    if (have claude) { auth-from (^claude auth status | complete | get stdout) } else { unknown "Claude is not installed" }
  }
  let expiry = refresh-expiry
  $auth | merge ({refresh_expires: $expiry.at?, refresh_expires_why: $expiry.why?} | compact)
}

# --- doctor --json -----------------------------------------------------------

# This machine's doctor report, or null with why it could not be had.
def doctor-facts []: nothing -> record {
  let script = $HERE | path join doctor.nu
  # A service starts with almost nothing on PATH, and doctor looks for mise
  # on it: add where Homebrew puts it, as a shell on a Mac would have it.
  let path = if $nu.os-info.name == "macos" { $env.PATH ++ [/opt/homebrew/bin /usr/local/bin] } else { $env.PATH }
  let result = with-env {PATH: $path} { ^$nu.current-exe $script --json | complete }
  if $result.exit_code != 0 { return {facts: null, why: "doctor --json failed"} }
  try { {facts: ($result.stdout | from json), why: ""} } catch { {facts: null, why: "doctor --json printed no JSON"} }
}

# The rig section. `login` is an addition of claude-rig's: fleet-api keeps
# fields it does not know, as posted.
def rig-section [facts: any, why: string]: nothing -> record {
  if $facts == null { return (unknown $why) }
  {
    status: "ok"
    commit: ($facts.rig_commit? | default "")
    tools_installed: ($facts.tools_installed? | default false)
    claude_version: ($facts.claude_version? | default "" | cut $in)
    config_applied: ($facts.config_applied? | default false)
    logged_in: ($facts.logged_in? | default false)
    session_running: ($facts.session_running? | default false)
    work_dir: (tilde ($facts.work_dir? | default "") | cut $in)
    login: (login-section)
  } | compact --empty
}

# Who holds the machine, from doctor's `slots` and `claims`, when it has them.
# A caller written as user@host names a person, so only the host is kept.
def claims-section [facts: any] {
  if $facts == null or ("claims" not-in ($facts | columns)) { return null }
  let held = $facts.claims | default [] | first 64 | each {|claim|
    let caller = $claim.who? | default ($claim.caller? | default "someone") | into string
    let caller = if ($caller | str contains "@") { $"a person on ($caller | split row '@' | last)" } else { $caller }
    {
      id: ($claim.id | into string | str replace --all --regex '[^A-Za-z0-9._-]' "-" | str substring 0..63)
      caller: (cut $caller)
      job: (cut ($claim.what? | default ($claim.job? | default "a job") | into string))
      since: (try { ms ($claim.since | into datetime) } catch { 1 })
      until: (try { ms ($claim.until | into datetime) } catch { null })
    } | compact
  }
  let slots = [($facts.slots? | default 1 | into int) ($held | length) 1] | math max
  {status: "ok", slots: ([$slots 64] | math min), held: $held} | compact --empty
}

# --- The VMs -------------------------------------------------------------------

# The vms section: what the VM keeper last wrote, unknown when that is stale,
# or null (left out) where no keeper has written one.
export def vms-section [now: int] {
  let text = read-text (vms-file)
  if $text == null { return null }
  let kept = try { $text | from json } catch { null }
  if ($kept | describe) !~ '^record' { return (unknown "the VM keeper's file is not a JSON object") }
  let vms = $kept.vms?
  if ($vms | describe) !~ '^record' { return (unknown "the VM keeper's file has no vms") }
  let age_s = ($now - ($kept.ts? | default 0)) // 1000
  if $age_s > $VMS_FRESH_S and $vms.status? != "unknown" {
    return (unknown $"the VM keeper last wrote its list ($age_s // 60) min ago")
  }
  $vms
}

# --- The report --------------------------------------------------------------

# The report, from doctor's facts (null: run doctor) at this moment.
export def build-report [reason: string, --doctor: any, --command: string = "report"]: nothing -> record {
  let from = if $doctor != null { {facts: $doctor, why: ""} } else { doctor-facts }
  let facts = $from.facts
  let power = power-sections
  let now = ms (date now)
  let report = {
    schema: $SCHEMA
    id: (device-id)
    ts: $now
    reason: $reason
    next_s: (if $reason in [start change interval] { $EVERY_S } else { 0 })
    tool: {name: "claude-rig", version: ($facts.rig_commit? | default "unknown"), command: $command}
    host: (host-section)
    cpu: (cpu-section)
    memory: (memory-section)
    disks: (disks-section)
    power: $power.power
    battery: $power.battery
    lid: $power.lid
    sleep: (sleep-section $power.lid)
    keeper: (keeper-state)
    rig: (rig-section $facts $from.why)
  }
  # A stop report is sent as the session ends, whatever the process list
  # still shows.
  let report = if $reason == "stop" and $report.rig.status == "ok" { $report | upsert rig.session_running false } else { $report }
  let claims = claims-section $facts
  let report = if $claims == null { $report } else { $report | insert claims $claims }
  let vms = vms-section $now
  if $vms == null { $report } else { $report | insert vms $vms }
}

# --- Sending -----------------------------------------------------------------

# Where fleet-api's SDK is: FLEET_API_SDK, else where mise installed it. Null
# when it is not installed.
def sdk-dir [] {
  let given = $env.FLEET_API_SDK? | default "" | str trim
  if $given != "" { return $given }
  # A service starts with almost nothing on PATH: look where mise is put.
  let path = $env.PATH ++ [(local-bin) /opt/homebrew/bin /usr/local/bin]
  let found = with-env {PATH: $path} {
    if (have mise) { ^mise where $SDK_TOOL | complete } else { {exit_code: 1, stdout: ""} }
  }
  if $found.exit_code != 0 { return null }
  let root = $found.stdout | str trim
  if ($root | path join index.ts | path exists) { return $root }
  # mise strips an archive's single top folder; in case it did not.
  let nested = try { ls $root | where type == dir | get name | where {|dir| $dir | path join index.ts | path exists } } catch { [] }
  $nested | get 0?
}

# Run fleet-api.ts (fleet-api's SDK) with what it reads on stdin and these
# settings. Its answer: {ok, answer} or {ok: false, retry, why}.
export def fleet-api [command: string, settings: record = {}, --input: string = ""]: nothing -> record {
  let script = $HERE | path join fleet-api.ts
  let path = $env.PATH ++ [(local-bin) (mise-shims)]
  let sdk = sdk-dir
  let bun = with-env {PATH: $path} { which bun | get path.0? }
  if $bun == null { return {ok: false, retry: true, why: "bun is not installed (the tool list has it)"} }
  let result = with-env ({FLEET_API_SDK: ($sdk | default "")} | merge $settings) {
    $input | ^$bun $script $command | complete
  }
  try { $result.stdout | from json } catch {
    {ok: false, retry: true, why: $"fleet-api.ts failed: ($result.stderr | str trim | lines | last 1 | get 0? | default 'no output')"}
  }
}

# Post one spooled report. keep: false when it is done with, delivered or
# refused for good; true when it should be tried again later.
def post-file [file: path, token: record]: nothing -> record {
  let body = open --raw $file | decode utf-8
  let answer = fleet-api report (access-env $token) --input $body
  if $answer.ok { return {keep: false, why: ""} }
  {keep: $answer.retry, why: $answer.why}
}

# Send what is in the spool, oldest first, stopping at the first that has to
# wait. Returns why it stopped ("" when the spool is empty now), and the
# reports fleet-api refused for good, which are dropped.
def flush [token: record]: nothing -> record {
  let dir = spool-dir
  let files = if ($dir | path exists) { ls $dir | where name =~ '\.json$' | sort-by name | get name } else { [] }
  mut waiting = ""
  mut refused = []
  for file in $files {
    let result = post-file $file $token
    if $result.keep {
      $waiting = $result.why
      break
    }
    if $result.why != "" { $refused = $refused | append {file: ($file | path basename), why: $result.why} }
    rm --force $file
  }
  {waiting: $waiting, refused: $refused}
}

# Spool a report and send the spool. Never fails: says what happened in one
# line: sent, spooled (and why), refused (and why), or skipped (and why).
export def send-report [report: record]: nothing -> string {
  let access = access-token
  if $access == null {
    return $"skipped: no fleet-api token \(set FLEET_API_ACCESS_CLIENT_ID and FLEET_API_ACCESS_CLIENT_SECRET, or push gives the machine one in (access-file))"
  }
  let dir = spool-dir
  mkdir $dir
  let name = $"($report.ts | fill --alignment right --character '0' --width 13)-($report.reason).json"
  let file = $dir | path join $name
  $report | to json --raw | save --force $file
  # Keep the spool to a day of reports: the oldest go first.
  let all = ls $dir | where name =~ '\.json$' | sort-by name
  if ($all | length) > $SPOOL_MAX { $all | first (($all | length) - $SPOOL_MAX) | each {|old| rm --force $old.name } | ignore }
  let result = flush $access
  let mine = $result.refused | where file == $name
  if ($file | path exists) {
    $"spooled: ($result.waiting)"
  } else if ($mine | is-not-empty) {
    $"refused: ($mine.0.why)"
  } else {
    let others = $result.refused | length
    if $others > 0 { $"sent \(($others) older ones were refused and dropped)" } else { "sent" }
  }
}

# Build a report and send it. Never fails, so the session can call it freely.
export def report-now [reason: string, --command: string = "session"]: nothing -> string {
  try {
    send-report (build-report $reason --command $command)
  } catch {|error|
    $"failed: ($error.msg)"
  }
}

# --- Reading the fleet -------------------------------------------------------

def list-fleet [as_json: bool] {
  let access = access-token
  if $access == null {
    fail report $"no fleet-api token to read the fleet with: set FLEET_API_ACCESS_CLIENT_ID and FLEET_API_ACCESS_CLIENT_SECRET, or put one in (access-file)"
  }
  let answer = fleet-api list (access-env $access)
  if not $answer.ok { fail report $answer.why }
  let list = $answer.answer
  if $as_json {
    print ($list | to json --indent 2)
    return
  }
  let now = $list.now
  let ago = {|ms|
    let seconds = ($now - $ms) // 1000
    if $seconds < 120 { $"($seconds)s" } else if $seconds < 7200 { $"($seconds // 60)m" } else { $"($seconds // 3600)h" }
  }
  let yes = {|value| match $value { true => "yes", false => "no", _ => "?" } }
  let rows = $list.devices | each {|device|
    let report = $device.report
    let rig = $report.rig? | default {}
    {
      name: $report.host.name
      os: $"($report.host.os)/($report.host.arch)"
      last: $report.reason
      heard: (do $ago $device.received)
      logged_in: (do $yes $rig.logged_in?)
      session: (do $yes $rig.session_running?)
      awake: (do $yes $report.keeper.running?)
      conditions: ($device.conditions | get code | str join ", ")
      id: $report.id
    }
  }
  print ($rows | table --index false)
}

def main [
  --print           # Print the report and post nothing
  --check           # Check the report against fleet-api's schema and post nothing
  --doctor: path    # Take doctor's facts from this file (doctor --json output) instead of running it
  --reason: string = "once"  # Why it is sent: once, start, interval, stop
  --list            # Print the fleet as fleet-api has it
  --json            # With --list: the answer as JSON
  --whoami          # Print {id, token_name, has_token}: the machine id (made if missing), its token's name, whether it has one
] {
  if $whoami {
    print ({id: (device-id), token_name: (token-name), has_token: ((access-from (read-text (access-file))) != null)} | to json --raw)
    return
  }
  if $list {
    list-fleet $json
    return
  }
  if $reason not-in [once start change interval stop] { fail report $"'($reason)' is not a reason" }
  let facts = if $doctor != null { open --raw $doctor | decode utf-8 | from json } else { null }
  let report = build-report $reason --doctor $facts --command report
  if $print {
    print ($report | to json --indent 2)
    return
  }
  if $check {
    let answer = fleet-api check --input ($report | to json --raw)
    if not $answer.ok { fail report $answer.why }
    print $"report: ($report.reason) holds to fleet-api's schema"
    return
  }
  print $"report: ($report.reason) ((send-report $report))"
}
