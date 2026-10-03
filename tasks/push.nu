#!/usr/bin/env nu
# push.nu — rig a remote machine over SSH, from this one.
#
# Connects with the system ssh, works out which OS is on the other end, and
# runs the published one-line bootstrap there: bootstrap.sh on macOS and
# Linux, bootstrap.ps1 on Windows. The remote output is shown as it happens.
# Safe to repeat, because the bootstrap is. No tokens are sent.
#
# If this machine has a config folder (`mise run config`), it is packed, checked
# for secrets, and copied over the same SSH connection to
# ~/.config/claude-rig/config.tar on the remote, where the run takes it in. So
# the remote needs no access to where the config is kept.
#
#   nu tasks/push.nu user@host [--dry-run] [--ref <branch>]
#                              [--port <n>] [--identity <key file>]
#                              [--known-hosts <file>]
#
# The machine must accept an SSH key without asking for a password.
# A host seen for the first time is added to ~/.ssh/known_hosts. To keep a
# throwaway test machine out of that file, pass --known-hosts /dev/null
# (--known-hosts NUL when this machine is Windows).

use lib.nu *
use remote.nu *
use userconfig.nu [local-folder pack-for-push REMOTE_DIR REMOTE_SENT_FILE settings-file]

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
    print $"push: ($target) \(($os)): dry run finished. Nothing was changed."
  } else {
    remember-machine {target: $target, os: $os, port: $port, identity: $identity, known_hosts: $known_hosts}
    print $"push: ($target) \(($os)): rigged. `mise run fleet` shows it with the others."
  }
}
