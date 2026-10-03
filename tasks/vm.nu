#!/usr/bin/env nu
# vm.nu — a UTM VM on this Mac, made and enrolled in one step.
#
# Uses the VM tool (irgo-winvm, pinned in mise.toml) to make the VM and turn
# on SSH in it, then rigs it with push, so it lands in `mise run fleet`.
# Apple Silicon Macs only, as UTM's VMs are.
#
#   nu tasks/vm.nu new linux <name>      an Ubuntu VM from Ubuntu's cloud image (about a minute)
#   nu tasks/vm.nu new windows <name>    a clone of the Windows golden image
#   nu tasks/vm.nu rm <name>             delete the VM and take it off the machine list

use lib.nu *
use remote.nu *

# Whose VMs these are, for the VM tool's quotas and its status table.
const OWNER = "claude-rig"

# Run the VM tool and stop if it fails. Returns what it printed.
def --wrapped vm-tool [...args: string]: nothing -> string {
  let result = with-env { IRGO_WINVM_OWNER: ($env.IRGO_WINVM_OWNER? | default $OWNER) } {
    ^irgo-winvm ...$args | complete
  }
  let printed = $"($result.stdout)($result.stderr)"
  if $result.exit_code != 0 {
    print --stderr ($printed | lines | last 6 | str join "\n")
    fail vm $"irgo-winvm ($args | first) failed with exit code ($result.exit_code)."
  }
  $printed
}

# Make a VM, turn SSH on in it, and rig it.
def "main new" [
  os: string         # linux or windows
  name: string       # The VM's name in UTM
  --ref: string = "main"  # The branch of claude-rig to rig from
] {
  if $os not-in [linux windows] { fail vm "the OS is linux or windows." }
  if not (have irgo-winvm) { fail vm "the VM tool is missing. Run: mise install" }

  print $"vm: making ($name) \(($os))"
  let create = if $os == "linux" { [vm-create -os linux -vm $name -install -golden=false] } else { [vm-create -vm $name] }
  vm-tool ...$create | lines | last 3 | each {|line| print $"  ($line)" } | ignore

  print $"vm: turning SSH on in ($name)"
  let ssh = vm-tool vm-ssh-create -vm $name
  let target = $ssh | lines | where {|line| $line starts-with "ssh " } | last 1 | get 0? | default "" | str replace "ssh " "" | str trim
  if $target == "" { fail vm $"the VM tool did not print an ssh line for ($name)." }
  print $"  ($target)"

  # A VM's address is handed out again to the next VM, so its host key is
  # never kept in ~/.ssh/known_hosts.
  print $"vm: rigging ($name)"
  let push = $env.FILE_PWD | path join push.nu
  ^$nu.current-exe $push $target --known-hosts /dev/null --ref $ref

  let entry = known-machines | where target == $target | first
  remember-machine ($entry | upsert vm $name)
  print $"vm: ($name) is rigged at ($target). Log it in: ssh -t ($target), then run `claude auth login`. It then shows in `mise run fleet`."
}

# Delete a VM made with `new`, and take it off the machine list.
def "main rm" [
  name: string  # The VM's name in UTM
] {
  let entry = known-machines | where {|machine| ($machine.vm? | default "") == $name }
  if ($entry | is-not-empty) {
    forget-machine $entry.0.target | ignore
    print $"vm: ($entry.0.target) is off the machine list."
  }
  vm-tool vm-delete -vm $name -force | lines | last 1 | each {|line| print $"  ($line)" } | ignore
  print $"vm: ($name) is deleted."
}

def main [] {
  print "usage: mise run vm -- new <linux|windows> <name> | rm <name>"
}
