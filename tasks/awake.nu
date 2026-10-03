# awake.nu — keeping the machine awake while the session runs, and reading
# whether that is being done. Used by session.nu and report.nu.
#
# A machine that sleeps drops out of the Claude app and stops its VMs. What
# holds sleep off lives exactly as long as the session, on every OS:
#
#   macOS    caffeinate -i -s in front of the server (idle and system sleep,
#            on mains power only; closing the lid still sleeps it)
#   Linux    systemd-inhibit --what=idle:sleep --mode=block in front of the
#            server, when the machine can sleep and logind allows it
#   Windows  a PowerShell process next to the server that calls
#            SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED) and
#            holds it until the session ends. No administrator rights:
#            powercfg's request overrides need them, and a power plan change
#            would outlast the session

use lib.nu *

const INHIBIT = [systemd-inhibit --what=idle:sleep --mode=block --who=claude-rig "--why=the Claude session is running"]

# True if this Linux machine can sleep at all. A server or container with no
# sleep state in the kernel, or with sleep.target masked, cannot.
export def linux-can-sleep []: nothing -> bool {
  let states = read-text /sys/power/state | default "" | str trim
  if $states == "" { return false }
  if (have systemctl) {
    let enabled = ^systemctl is-enabled sleep.target | complete | get stdout | str trim
    if $enabled == "masked" { return false }
  }
  true
}

# True if logind lets this user hold sleep off. polkit can refuse it, for
# example over SSH on a machine set up that way.
def inhibit-allowed []: nothing -> bool {
  (^systemd-inhibit ...($INHIBIT | skip 1) true | complete | get exit_code) == 0
}

# How the session keeps this machine awake: what goes in front of the
# server's command line (`prefix`), and one line saying what is held.
# On Windows the prefix is empty: the keeper runs beside the server instead
# (run-windows-keeper).
export def awake-plan []: nothing -> record {
  match $nu.os-info.name {
    "macos" => {
      if (have caffeinate) {
        {prefix: [caffeinate -i -s], note: "caffeinate holds off idle and system sleep while the session runs (mains power only)"}
      } else {
        {prefix: [], note: "no caffeinate, so sleep is not held off"}
      }
    }
    "linux" => {
      if not (linux-can-sleep) {
        {prefix: [], note: "this machine has no sleep, so nothing is held"}
      } else if not (have systemd-inhibit) {
        {prefix: [], note: "no systemd-inhibit, so sleep is not held off"}
      } else if not (inhibit-allowed) {
        {prefix: [], note: "systemd-inhibit was refused for this user, so sleep is not held off"}
      } else {
        {prefix: $INHIBIT, note: "systemd-inhibit holds off idle sleep and sleep while the session runs"}
      }
    }
    "windows" => {prefix: [], note: "SetThreadExecutionState holds off sleep while the session runs"}
    _ => {prefix: [], note: ""}
  }
}

# --- Windows ----------------------------------------------------------------

# The keeper: ES_CONTINUOUS | ES_SYSTEM_REQUIRED (0x80000001) is held by the
# thread that set it until that thread ends, so the script waits while the
# session it belongs to is alive, then ends and lets go.
const WINDOWS_KEEPER = r#'$api = Add-Type -Name Power -Namespace ClaudeRigAwake -PassThru -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);'
[void]$api::SetThreadExecutionState([uint32]2147483649)
$session = [int]$env:CLAUDE_RIG_SESSION_PID
while (Get-Process -Id $session -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 10 }
'#

# The keeper as PowerShell's -EncodedCommand takes it: base64 of UTF-16LE.
# Sent this way there is no quoting to get wrong, and the same text on the
# command line every time tells the keeper apart from other PowerShell.
export def windows-keeper-encoded []: nothing -> string {
  $WINDOWS_KEEPER | split chars | each {|char| bytes build ($char | encode utf-8) 0x[00] } | bytes collect | encode base64
}

# Run the keeper until this session ends. Blocks: run it in a job.
export def run-windows-keeper [] {
  with-env {CLAUDE_RIG_SESSION_PID: ($nu.pid | into string)} {
    ^powershell -NoProfile -NonInteractive -EncodedCommand (windows-keeper-encoded)
  }
}

# --- What the report says ----------------------------------------------------

# The report's `keeper` section: is the session's keep-awake running now.
# Read from the process list, so it is right whoever asks.
export def keeper-state []: nothing -> record {
  let os = $nu.os-info.name
  if $os == "linux" and not (linux-can-sleep) {
    return {status: "none", why: "this machine has no sleep, so nothing needs holding off"}
  }
  if $os == "linux" and not (have systemd-inhibit) {
    return {status: "none", why: "no systemd-inhibit on this machine"}
  }
  if $os not-in [macos linux windows] {
    return {status: "none", why: $"no keep-awake for ($os)"}
  }
  let processes = try { ps --long } catch { return {status: "unknown", why: "the process list could not be read"} }
  let encoded = if $os == "windows" { windows-keeper-encoded } else { "" }
  let running = $processes | any {|process|
    let command = $process.command? | default ""
    match $os {
      "macos" => ($process.name == "caffeinate" and $command =~ 'remote-control')
      "linux" => ($process.name == "systemd-inhibit" and $command =~ '--who=claude-rig')
      _ => ($command =~ 'EncodedCommand' and ($command | str contains $encoded))
    }
  }
  # Nothing here ever changes what closing the lid does.
  {status: "ok", running: $running, idle: $running, lid: false}
}
