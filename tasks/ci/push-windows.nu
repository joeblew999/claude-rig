#!/usr/bin/env nu
# push-windows.nu — `mise run ci:push`: push a rig over SSH to this Windows
# machine, as to any PC, and check what arrived.
#
# Run after `mise run ci:sshd`, which sets up the SSH server and the key. The
# machine pushes to itself over localhost: a dry run, a first run that makes
# and sends the machine's fleet-api token (with a stand-in for fleet-api's
# access:token task, so a made-up token), a second run that changes nothing
# and keeps the token, and a dry run with PowerShell as the SSH shell. CI only: it rigs this machine and changes its
# SSH server.
#
#   RIG_TEST_REF=<branch> mise run ci:push

use ../lib.nu [is-windows powershell fail]
use common.nu *
use ../../tests/report.nu [fake-fleet-api]

const FIXTURE = path self ../../tests/fixtures/config
const PUSH = path self ../push.nu

def main [] {
  if not (is-windows) { fail ci:push "this pushes to a Windows SSH server" }
  if ($env.CI? | default "") != "true" { fail ci:push "this rigs this machine and changes its SSH server: CI only" }

  # Windows' own ssh, not the one that comes with Git.
  $env.PATH = [($env.SystemRoot | path join System32 OpenSSH)] ++ $env.PATH
  # The config push sends: the tests' made-up one. The SSH session on the other
  # end does not get this variable, so it takes in what was sent.
  $env.RIG_CONFIG = $FIXTURE
  # Rig from the branch under test, not from main.
  let ref = $env.RIG_TEST_REF? | default (^git -C $REPO rev-parse --abbrev-ref HEAD | str trim)
  let target = $"($env.USERNAME)@localhost"
  let key = $nu.home-dir | path join .ssh push-test
  let home = $nu.home-dir
  # fleet-api's checkout, as push finds it: a stand-in that makes made-up tokens.
  let fleet_api = mktemp --directory | path expand
  fake-fleet-api $fleet_api
  $env.FLEET_API_DIR = $fleet_api
  $env.MISE_TRUSTED_CONFIG_PATHS = $fleet_api

  # Run push.nu at this machine and return what it printed.
  let push = {|flags: list<string>|
    let result = ^$nu.current-exe $PUSH $target --identity $key --known-hosts NUL --ref $ref ...$flags | complete
    print $result.stdout $result.stderr
    check $"push ($flags | str join ' ') finished \(exit code ($result.exit_code))" ($result.exit_code == 0)
    $result.stdout
  }

  print "The key logs in and the SSH shell is cmd.exe"
  print $"    ssh: (which ssh | get path.0)"
  let login = ["-n" "-i" $key "-o" "IdentitiesOnly=yes" "-o" "BatchMode=yes" "-o" "StrictHostKeyChecking=accept-new" "-o" "UserKnownHostsFile=NUL" $target]
  let shell = ^ssh ...$login 'echo %COMSPEC%' | complete
  check "the key is accepted" ($shell.exit_code == 0)
  check $"the SSH shell is cmd.exe \(($shell.stdout | str trim))" (($shell.stdout | str trim) =~ 'cmd\.exe$')
  # For the record: whether this machine has a uname for push to find.
  let uname = ^ssh ...$login 'uname -s' | complete
  print $"    uname -s: exit code ($uname.exit_code), said '($uname.stdout | str trim)'"

  print "A dry run over SSH"
  do $push ["--dry-run"] | ignore
  check "no clone of the rig" (not ($home | path join .claude-rig | path exists))
  check "no tool list" (not ($home | path join .config mise conf.d claude-rig.toml | path exists))
  check "no config applied" (not ($home | path join .claude .rig-manifest | path exists))
  check "no config sent" (not ($home | path join .config claude-rig config.tar | path exists))
  check "no Claude Code" (not ($home | path join .local bin claude.exe | path exists))

  print "A first run over SSH, making and sending the machine's fleet-api token"
  let first = do $push []
  let id = open --raw ($home | path join .config claude-rig device-id) | decode utf-8 | str trim
  check $"the machine id was made first \(($id))" ($id =~ '^[0-9a-f]{16}$')
  check "fleet-api's task made a token for that machine id" ((open ($fleet_api | path join tokens.json) | get device) == [$id])
  let token = $home | path join .config claude-rig fleet-api-access.json
  let kept = open --raw $token | decode utf-8 | from json
  check "the token was kept" ($kept.client_id == "stub-1.access" and ($kept | get client_secret) == "stub-secret-1")
  check "the secret was not printed" (not ($first | str contains "stub-secret"))
  check "the machine reported once with it" ($first =~ 'report: once ')
  let acl = ^icacls $token | complete | get stdout
  print $acl
  check "only this user can read the token" (not ($acl =~ 'Everyone|BUILTIN\\|Authenticated Users|NT AUTHORITY'))

  print "Claude Code and the config"
  with-env { PATH: (user-path) } {
    let claude = ^claude --version | complete
    check $"claude runs: ($claude.stdout | str trim)" ($claude.exit_code == 0)
  }
  check "the config push sent is applied" ($home | path join .claude skills alpha SKILL.md | path exists)
  check "the sent config was taken in" (not ($home | path join .config claude-rig config.tar | path exists))

  print "A second run over SSH"
  let second = do $push []
  unchanged $second
  check "the machine keeps its token" ($second =~ 'keeps its fleet-api token' and (open ($fleet_api | path join made) | into int) == 1)
  check "it said it finished" ($second =~ 'rigged\.')

  # Some PCs are set up with PowerShell as the SSH shell instead of cmd.exe.
  print "A dry run with PowerShell as the SSH shell"
  powershell 'New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Force -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null' | ignore
  let output = do $push ["--dry-run"]
  check "the rig ran on the other end" ($output =~ 'rig: dry run finished')
}
