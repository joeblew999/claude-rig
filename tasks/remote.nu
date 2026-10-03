# remote.nu — reaching other machines over SSH, and remembering which
# machines this one has rigged. Used by push.nu and fleet.nu.

# The ssh options every connection uses.
export def ssh-options [port: any, identity: any, known_hosts: any]: nothing -> list<string> {
  [-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10]
  | append (if $port != null { [-p ($port | into string)] } else { [] })
  | append (if $identity != null { [-i $identity -o IdentitiesOnly=yes] } else { [] })
  | append (if $known_hosts != null { [-o $"UserKnownHostsFile=($known_hosts)"] } else { [] })
}

# The same options for scp, which names the port with -P.
export def scp-options [port: any, identity: any, known_hosts: any]: nothing -> list<string> {
  ssh-options null $identity $known_hosts
  | append (if $port != null { [-P ($port | into string)] } else { [] })
}

# Run a short command on the remote and capture it. Never asks for anything.
export def probe [options: list<string>, target: string, command: string]: nothing -> record {
  ^ssh -n -o BatchMode=yes ...$options $target $command | complete
}

# Where the list of rigged machines is kept. It is on this machine only,
# never in the repo: it names the owner's machines.
export def machines-file []: nothing -> path {
  $env.RIG_MACHINES? | default ($nu.home-dir | path join .config claude-rig machines.json)
}

# The machines rigged from here, oldest first.
export def known-machines []: nothing -> list<record> {
  let file = machines-file
  if ($file | path exists) { open --raw $file | from json } else { [] }
}

# Add a machine to the list, or update it if it is already there.
export def remember-machine [machine: record] {
  let file = machines-file
  let others = known-machines | where {|known| $known.target != $machine.target or ($known.port? | default null) != ($machine.port? | default null) }
  mkdir ($file | path dirname)
  $others | append $machine | to json --indent 2 | save --force $file
}

# Take a machine off the list. Returns true if it was on it.
export def forget-machine [target: string]: nothing -> bool {
  let known = known-machines
  let kept = $known | where {|machine| $machine.target != $target }
  if ($kept | length) == ($known | length) { return false }
  $kept | to json --indent 2 | save --force (machines-file)
  true
}
