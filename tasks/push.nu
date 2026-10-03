#!/usr/bin/env nu
# push.nu — rig a remote machine over SSH, from this one.
#
# Connects with the system ssh, works out which OS is on the other end, and
# runs the published one-line bootstrap there: bootstrap.sh on macOS and
# Linux, bootstrap.ps1 on Windows. The remote output is shown as it happens.
# Safe to repeat, because the bootstrap is.
#
# The one secret sent is the remote's own fleet-api token: a Cloudflare Access
# service token that posts for that machine's id only. After the rig has run
# there, push asks the remote for its machine id, has fleet-api's own
# access:token task make the token (in fleet-api's checkout, FLEET_API_DIR),
# and sends it over the same SSH connection, on stdin (never on a command
# line), into ~/.config/claude-rig/fleet-api-access.json, readable by that
# user only. A remote that already has one keeps it, unless --new-token. The
# secret is never printed. --no-report skips all of it.
#
# If this machine has a config folder (`mise run config`), it is packed, checked
# for secrets, and copied over the same SSH connection to
# ~/.config/claude-rig/config.tar on the remote, where the run takes it in. So
# the remote needs no access to where the config is kept.
#
#   nu tasks/push.nu user@host [--dry-run] [--ref <branch>]
#                              [--port <n>] [--identity <key file>]
#                              [--known-hosts <file>] [--new-token | --no-report]
#
# The machine must accept an SSH key without asking for a password.
# A host seen for the first time is added to ~/.ssh/known_hosts. To keep a
# throwaway test machine out of that file, pass --known-hosts /dev/null
# (--known-hosts NUL when this machine is Windows).

use lib.nu *
use remote.nu *
use userconfig.nu [local-folder pack-for-push REMOTE_DIR REMOTE_SENT_FILE settings-file]
use report.nu [ACCESS_UNIX_COMMAND access-windows-script access-from]

const RAW = "https://raw.githubusercontent.com/joeblew999/claude-rig"

# Where a file of the rig is published for a branch.
def raw-url [ref: string, file: string]: nothing -> string {
  $"($RAW)/($ref)/($file)"
}

# The remote OS: macOS, Linux or Windows. Stops if it is none of those.
def remote-os [options: list<string>, target: string]: nothing -> string {
  let uname = probe $options $target "uname -s"
  if $uname.exit_code == 0 {
    let name = $uname.stdout | str trim
    if $name == "Darwin" { return "macOS" }
    if $name == "Linux" { return "Linux" }
    # A Windows machine with Git for Windows can have a uname on PATH. It
    # answers with a name like MINGW64_NT-10.0 or MSYS_NT-10.0.
    if $name !~ '^(MINGW|MSYS|CYGWIN)' {
      fail push $"($target) runs ($name), which the rig does not support."
    }
  }
  # Otherwise Windows OpenSSH handed the command to cmd.exe, which has no
  # uname. Ask PowerShell, which every supported Windows has.
  let powershell = probe $options $target 'powershell -NoProfile -Command "[Environment]::OSVersion.Platform"'
  if $powershell.exit_code == 0 and ($powershell.stdout | str trim) == "Win32NT" { return "Windows" }
  fail push $"could not tell which OS ($target) runs \(no uname and no PowerShell)."
}

# How a macOS or Linux remote can download the bootstrap: curl, wget or none.
def remote-fetcher [options: list<string>, target: string]: nothing -> string {
  let found = probe $options $target "sh -c 'command -v curl >/dev/null 2>&1 && echo curl || { command -v wget >/dev/null 2>&1 && echo wget; } || echo none'"
  if $found.exit_code != 0 { fail push $"could not look for curl on ($target)." }
  $found.stdout | str trim
}

# The macOS and Linux command line. With a fetcher, the remote downloads
# bootstrap.sh and pipes it to sh, and a failed download stops the run rather
# than handing sh an empty script. With none, sh reads the script from stdin.
def unix-command [fetcher: string, ref: string, dry_run: bool]: nothing -> string {
  let run = [$"RIG_REF=($ref)" sh -s --] ++ (if $dry_run { [--dry-run] } else { [] }) | str join " "
  let url = raw-url $ref bootstrap.sh
  let download = match $fetcher {
    "curl" => $"curl -fsSL ($url)"
    "wget" => $"wget -qO- ($url)"
    _ => (return $run)
  }
  ["sh -c 'script=$(" $download ') && printf "%s\n" "$script" | ' $run "'"] | str join
}

# The Windows command line. Windows OpenSSH hands it to the account's SSH
# shell, which is cmd.exe unless the PC was set up otherwise. Everything
# PowerShell has to see is inside one pair of double quotes, where cmd leaves
# & | ( ) and ; alone. Inside them there is no $, no backtick and no double
# quote, so the line also means the same when the SSH shell is PowerShell.
def windows-command [ref: string, dry_run: bool]: nothing -> string {
  let script = [
    "[Environment]::SetEnvironmentVariable('RIG_REF', '" $ref "'); "
    "& ([scriptblock]::Create((irm " (raw-url $ref bootstrap.ps1) ")))"
    (if $dry_run { " -DryRun" } else { "" })
  ] | str join
  ['powershell -NoProfile -ExecutionPolicy Bypass -Command "' $script '"'] | str join
}

# Send the config folder to the remote, as one packed file next to where the
# run looks for it. Stops if it cannot.
def send-config [options: list<string>, scp: list<string>, target: string, os: string, folder: path] {
  let dir = mktemp --directory | path expand
  pack-for-push $folder ($dir | path join config.tar)
  let parent = $REMOTE_DIR
  let make_dir = if $os == "Windows" {
    $'powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path ($parent | str replace --all "/" "\\") | Out-Null"'
  } else {
    $"mkdir -p ($parent)"
  }
  let made = probe $options $target $make_dir
  if $made.exit_code != 0 { fail push $"could not make ($parent) on ($target): ($made.stderr | str trim)" }
  # scp is run next to the file, so no local path with a drive letter is given.
  let sent = do { cd $dir; ^scp -q -o BatchMode=yes ...$scp config.tar $"($target):($REMOTE_SENT_FILE)" | complete }
  rm --recursive --force $dir
  if $sent.exit_code != 0 { fail push $"could not send the config to ($target): ($sent.stderr | str trim)" }
}

# --- The remote's fleet-api token ------------------------------------------

# fleet-api's checkout, where its access:token task makes a machine's token:
# FLEET_API_DIR, else where the owner keeps it.
export def fleet-api-dir []: nothing -> path {
  $env.FLEET_API_DIR? | default "" | str trim | if $in != "" { $in } else {
    $nu.home-dir | path join workspace go src github.com joeblew999 fleet-api
  }
}

# Run fleet-api's access:token task (mise run access:token -- <args>) in its
# checkout. It prints no secret.
def access-task [dir: path, args: list<string>]: nothing -> record {
  do { cd $dir; ^mise run access:token -- ...$args | complete }
}

# Make the token for a machine with fleet-api's task, into a new file in
# folder. If fleet-api already has a token of that name for the same machine
# id, it cannot give its secret again, so that one is revoked and a new one
# made: the token is rotated. A token of that name for another machine id is
# left alone, and push stops. Returns {file, rotated}.
export def make-token [dir: path, name: string, id: string, folder: path]: nothing -> record {
  let file = $folder | path join fleet-api-access.json
  let made = access-task $dir [create $name $id $file]
  if $made.exit_code == 0 and ($file | path exists) { return {file: $file, rotated: false} }
  let said = $"($made.stdout)($made.stderr)"
  let taken = $said | parse --regex 'FAIL\s+(?<token>\S+) exists' | get token.0?
  if $taken == null {
    fail push $"fleet-api's access:token task could not make a token for ($name):\n($said | str trim)"
  }
  let listed = access-task $dir [list]
  let device = $listed.stdout | lines | where {|line| $line starts-with ($taken + "\t") } | get 0? | default "" | parse --regex 'device (?<id>\S+)' | get id.0?
  if $device != $id {
    fail push $"fleet-api already has a token ($taken) for another machine \(device ($device | default '?')). Give one of them another name with RIG_NAME."
  }
  let revoked = access-task $dir [revoke $name]
  if $revoked.exit_code != 0 { fail push $"could not revoke ($taken) to make it again:\n($revoked.stdout)($revoked.stderr | str trim)" }
  let again = access-task $dir [create $name $id $file]
  if $again.exit_code != 0 or not ($file | path exists) {
    fail push $"fleet-api's access:token task could not make a token for ($name):\n($again.stdout)($again.stderr | str trim)"
  }
  {file: $file, rotated: true}
}

# Send the remote its token file, on stdin. Returns why it could not, or "".
def send-token [options: list<string>, target: string, os: string, file: path]: nothing -> string {
  let access = access-from (open --raw $file | decode utf-8)
  if $access == null { return "fleet-api's access:token task wrote no client_id and client_secret" }
  let text = $access | to json --raw
  let sent = if $os == "Windows" {
    access-windows-script $text | ^ssh -T -o BatchMode=yes ...$options $target "powershell -NoProfile -Command -" | complete
  } else {
    $text | ^ssh -T -o BatchMode=yes ...$options $target $ACCESS_UNIX_COMMAND | complete
  }
  if $sent.exit_code != 0 { $sent.stderr | str trim | if $in == "" { $"exit code ($sent.exit_code)" } else { $in } } else { "" }
}

# Give the rigged remote its own fleet-api token, unless it has one (or
# new_token), then have it report once, so the token is tried at once.
def give-token [options: list<string>, target: string, os: string, dir: path, new_token: bool] {
  let asked = run-nu $options $target (nu-on $os report.nu [--whoami])
  let who = try { $asked.stdout | lines | last | from json } catch { null }
  if $asked.exit_code != 0 or $who == null {
    fail push $"($target) did not say its machine id \(report.nu --whoami): ($asked.stderr | str trim)"
  }
  if $who.has_token and not $new_token {
    print $"push: ($target) keeps its fleet-api token \(($who.token_name)); --new-token makes a new one"
  } else {
    # The secret is on this machine only in this folder, only for as long as it takes to send it.
    let folder = mktemp --directory | path expand
    let made = make-token $dir $who.token_name $who.id $folder
    let why = send-token $options $target $os $made.file
    rm --recursive --force $folder
    if $why != "" { fail push $"could not send the fleet-api token to ($target): ($why). It exists in fleet-api: push again with --new-token" }
    let how = if $made.rotated { "made again (the old one is revoked)" } else { "made" }
    print $"push: ($target)'s fleet-api token, for machine ($who.id), ($how) and sent; readable there by that user only"
  }
  let reported = run-nu $options $target (nu-on $os report.nu)
  print $"push: ($target): ($reported.stdout | str trim | lines | last 1 | get 0? | default $'the report did not run: ($reported.stderr | str trim)')"
}

# Run the bootstrap on the remote, showing its output live. Returns its exit code.
def run-remote [options: list<string>, target: string, command: string, script: any]: nothing -> int {
  let options = [-o ServerAliveInterval=30] ++ $options
  try {
    if $script != null {
      # The script travels on stdin, so there is no terminal on the remote.
      $script | ^ssh -T ...$options $target $command
    } else if (is-terminal --stdin) {
      # A terminal, so a login step on the remote can ask the person here.
      ^ssh -t ...$options $target $command
    } else {
      ^ssh ...$options $target $command
    }
    0
  } catch {|error|
    $error.exit_code? | default 1
  }
}

def main [
  target: string         # The machine to rig, as user@host
  --dry-run              # Report what would change on the remote and change nothing
  --ref: string = "main" # The branch of claude-rig to rig from
  --port: int            # The SSH port, if it is not 22
  --identity: path       # The SSH private key to log in with
  --known-hosts: string  # Keep host keys in this file instead of ~/.ssh/known_hosts
  --new-token            # Make the remote a new fleet-api token even if it has one (the old one is revoked)
  --no-report            # Make no fleet-api token: the remote does not report
] {
  if not (have ssh) { fail push "ssh is missing on this machine." }
  if $target !~ '^[A-Za-z0-9_.@:\[\]-]+$' or ($target starts-with "-") {
    fail push $"'($target)' is not a machine name. Use user@host."
  }
  # The branch name ends up in a command line on the remote, so keep it plain.
  if $ref !~ '^[A-Za-z0-9_./-]+$' or ($ref starts-with "-") {
    fail push $"'($ref)' is not a branch name."
  }
  if $identity != null and not ($identity | path exists) {
    fail push $"no SSH key at ($identity)."
  }

  if $new_token and $no_report { fail push "--new-token and --no-report do not go together." }
  # The token is made with fleet-api's own task, in its checkout.
  let fleet_api = fleet-api-dir
  if not $no_report and not ($fleet_api | path join mise.toml | path exists) {
    fail push $"no fleet-api checkout at ($fleet_api), so no fleet-api token can be made for ($target). Clone joeblew999/fleet-api there or set FLEET_API_DIR to it; or pass --no-report and the machine does not report."
  }

  let options = ssh-options $port $identity $known_hosts

  let reach = probe $options $target "exit"
  if $reach.exit_code != 0 {
    let why = $reach.stderr | lines | where {|line| ($line | str trim) != "" and $line !~ '^Warning: Permanently added' } | last 1 | get 0? | default $"exit code ($reach.exit_code)" | str trim
    fail push $"cannot reach ($target) over SSH with a key \(($why))."
  }

  let os = remote-os $options $target
  let what = if $dry_run { "dry run on" } else { "rigging" }
  print $"push: ($what) ($target) \(($os)) from ($ref)"

  let config = local-folder push
  if $config == null {
    print $"push: no config folder here \(none in (settings-file)), so none is sent"
  } else if not ($config | path exists) {
    fail push $"the config folder ($config) does not exist."
  } else if $dry_run {
    print $"push: a real run sends the config in ($config); this dry run sends nothing"
  } else {
    send-config $options (scp-options $port $identity $known_hosts) $target $os $config
    print $"push: sent the config in ($config)"
  }

  let code = if $os == "Windows" {
    run-remote $options $target (windows-command $ref $dry_run) null
  } else {
    let fetcher = remote-fetcher $options $target
    let script = if $fetcher == "none" {
      print $"push: no curl or wget on ($target), sending bootstrap.sh from this checkout"
      open --raw (repo-dir | path join bootstrap.sh)
    } else {
      null
    }
    run-remote $options $target (unix-command $fetcher $ref $dry_run) $script
  }

  if $code != 0 {
    print --stderr $"push: ($target) \(($os)): the remote run failed with exit code ($code)."
    exit $code
  } else if $dry_run {
    if not $no_report { print $"push: a real run gives ($target) its own fleet-api token, made with ($fleet_api)'s access:token task; this dry run makes none" }
    print $"push: ($target) \(($os)): dry run finished. Nothing was changed."
  } else {
    remember-machine {target: $target, os: $os, port: $port, identity: $identity, known_hosts: $known_hosts}
    if $no_report {
      print $"push: --no-report, so ($target) gets no fleet-api token and does not report"
    } else {
      give-token $options $target $os $fleet_api $new_token
    }
    print $"push: ($target) \(($os)): rigged. `mise run fleet` shows it with the others."
  }
}
