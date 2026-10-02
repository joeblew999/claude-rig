# enroll.nu — the two steps that put a rigged machine in the Claude app:
# log in, and keep a Claude session running. Used by rig.nu.

use lib.nu *

const DAEMON = "claude-rig"

# --- Login -----------------------------------------------------------------

# True if Claude is logged in with a claude.ai account. Remote Control needs
# that: an API key or a `claude setup-token` token can only make model requests.
export def logged-in []: nothing -> bool {
  if not (have claude) { return false }
  let info = try { ^claude auth status | complete | get stdout | from json } catch { {} }
  ($info.loggedIn? | default false) and ($info.authMethod? | default "") == "claude.ai"
}

# Log in if needed. Returns whether the machine is logged in afterwards.
export def --env login-step []: nothing -> bool {
  # For CI only: exercise the session step on a machine that cannot log in.
  if ($env.RIG_ASSUME_LOGGED_IN? | default "0") == "1" {
    skip "login (RIG_ASSUME_LOGGED_IN is set, for tests)"
    return true
  }
  if (logged-in) {
    ok "logged in with a claude.ai account"
    return true
  }
  if (dry-run) {
    change "log in to Claude (it prints a link: approve it, paste the code back)" { }
    return false
  }
  if not (is-terminal --stdin) {
    skip "login: there is no terminal to ask on. Run `claude auth login`, then run the rig again"
    return false
  }
  change "log in to Claude: open the link it prints, approve it, and paste the code back" {
    ^claude auth login --claudeai
  }
  if not (logged-in) { fail rig "the login did not finish. Run the rig again to retry." }
  true
}

# --- The always-on session -------------------------------------------------

# Claude will not start in a folder nobody has approved, and a service has no
# terminal to ask on. The rig made this folder, so it records the approval
# itself. This is the only thing the rig ever writes to ~/.claude.json.
def --env trust-work-dir [] {
  let state = $nu.home-dir | path join .claude.json
  # Claude names folders with forward slashes on every OS.
  let dir = work-dir | str replace --all '\' '/'
  if not ($state | path exists) {
    skip "work folder approval (Claude has not run on this machine yet)"
    return
  }
  let data = open --raw $state | from json
  let project = $data | get --optional projects | default {} | get --optional $dir | default {}
  if ($project.hasTrustDialogAccepted? | default false) {
    ok "work folder is approved for Claude"
    return
  }
  change "approve the work folder for Claude" {
    let projects = $data | get --optional projects | default {} | upsert $dir ($project | upsert hasTrustDialogAccepted true)
    let tmp = $"($state).rig-tmp"
    $data | upsert projects $projects | to json --indent 2 | save --force $tmp
    mv --force $tmp $state
  }
}

# What pitchfork should run: this machine's session, restarted if it stops,
# started again after a reboot.
def daemon-wanted []: nothing -> record {
  let script = $env.FILE_PWD | path join session.nu
  {
    run: $"\"($nu.current-exe)\" \"($script)\""
    dir: (work-dir)
    boot_start: true
    retry: true
    ready_output: "Connected"
  }
}

# Put the session in pitchfork's machine-wide config, keeping whatever else is
# there. Returns true if the config was changed.
def --env configure-daemon []: nothing -> bool {
  let file = $nu.home-dir | path join .config pitchfork config.toml
  let config = if ($file | path exists) { open $file } else { {} }
  let wanted = daemon-wanted
  if ($config | get --optional daemons | default {} | get --optional $DAEMON) == $wanted {
    ok $"session service \(($file))"
    return false
  }
  change $"add the session service to ($file)" {
    mkdir ($file | path dirname)
    let backup = $"($file).rig-backup"
    if ($file | path exists) and not ($backup | path exists) { cp $file $backup }
    let daemons = $config | get --optional daemons | default {} | upsert $DAEMON $wanted
    $config | upsert daemons $daemons | to toml | save --force $file
  }
  true
}

# Have pitchfork itself start when the machine boots.
def --env start-at-boot [] {
  let status = ^pitchfork boot status | complete
  if $"($status.stdout)($status.stderr)" =~ "is enabled" {
    ok "pitchfork starts at boot"
    return
  }
  change "have pitchfork start at boot" {
    let result = ^pitchfork boot enable | complete
    if $result.exit_code != 0 {
      print $"          could not: ($result.stderr | str trim | lines | last)"
      print "          the session runs now, but will not come back after a reboot"
    }
  }
}

def session-running []: nothing -> bool {
  let list = ^pitchfork list --hide-header | complete | get stdout
  let name = '(^|/)' + $DAEMON + '\s'
  $list | lines | any {|line| $line =~ $name and $line =~ '\srunning' }
}

def start-session [] {
  let result = ^pitchfork start $DAEMON --force | complete
  if $result.exit_code != 0 {
    print --stderr ($result.stderr | str trim)
    fail rig $"the session did not start. See: pitchfork logs ($DAEMON)"
  }
}

# --- Windows: start at sign-in ---------------------------------------------

# pitchfork cannot start at boot on Windows. Instead a small file in the
# user's Startup folder starts the session when the user signs in, with no
# window, and the session restarts itself. No administrator rights needed.
def startup-file []: nothing -> path {
  $env.APPDATA | path join Microsoft Windows "Start Menu" Programs Startup claude-rig.cmd
}

def startup-wanted []: nothing -> string {
  let script = $env.FILE_PWD | path join session.nu
  [
    "@echo off"
    "rem Written by claude-rig. Starts the always-on Claude session with no window."
    $"start \"\" conhost.exe --headless \"($nu.current-exe)\" \"($script)\" --keep-alive"
    ""
  ] | str join "\r\n"
}

def windows-session-running []: nothing -> bool {
  ps --long | where {|process| ($process.command? | default "") =~ 'session\.nu' and $process.pid != $nu.pid } | is-not-empty
}

def --env session-windows [] {
  let file = startup-file
  let wanted = startup-wanted
  let changed = (read-text $file) != $wanted
  if $changed {
    change $"start the session at sign-in \(($file))" { $wanted | save --force $file }
  } else {
    ok $"session starts at sign-in \(($file))"
  }
  if (windows-session-running) and not $changed {
    ok $"session is running as \"(machine-name)\""
  } else {
    change $"start the session as \"(machine-name)\"" {
      # Stop an older session first, so two never run side by side.
      powershell 'Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match "session\.nu" } | ForEach-Object { taskkill /PID $_.ProcessId /T /F | Out-Null }'
      ^cmd /c $file
    }
  }
}

# Keep a Claude session running on this machine.
export def --env session-step [] {
  let dir = work-dir
  if ($dir | path exists) {
    ok $"work folder \(($dir))"
  } else {
    change $"create the work folder ($dir)" { mkdir $dir }
  }
  trust-work-dir
  if (is-windows) {
    session-windows
    return
  }
  let changed = configure-daemon
  start-at-boot
  if $changed {
    change $"start the session as \"(machine-name)\"" { start-session }
  } else if (session-running) {
    ok $"session is running as \"(machine-name)\""
  } else {
    change $"start the session as \"(machine-name)\"" { start-session }
  }
}
