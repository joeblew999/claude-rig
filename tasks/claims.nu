#!/usr/bin/env nu
# claims.nu — who is using this machine, so jobs handed to it do not collide.
#
# Runs on the machine itself: the claims in its own folder are the authority.
# `fleet` reaches it over SSH; it is also run directly here.
#
#   nu --stdin tasks/claims.nu job --caller <who> --label <what> [--wait]
#                                       take a slot, run the work on stdin with
#                                       Claude in its own job folder, let go
#   nu tasks/claims.nu list [--json]    the claims, live and expired
#   nu tasks/claims.nu release <id> [--caller <who>] [--force]
#   nu tasks/claims.nu take --caller <who> --label <what> [--ttl <s>] [--wait]
#   nu tasks/claims.nu slots [<n>]      how many jobs at once; set it with <n>
#
# A claim is one file, <id>.json, in the claims folder. Every change to that
# folder happens while holding its lock, a folder named .lock made with the
# OS's own mkdir, which either makes it or fails: two callers can never both
# hold it. So two callers racing for the last slot cannot both get it.
#
# Exit codes: 0 done, 1 failed, 6 busy (every slot is held).

use lib.nu *

const BUSY = 6
# A claim lives this long unless it is renewed; a running job renews it.
const TTL_SECONDS = 120
# A lock older than this was left by a caller that died while holding it.
const STALE_LOCK = 30sec

# The folder the claims are kept in.
export def claims-dir []: nothing -> path {
  $env.RIG_CLAIMS? | default ($nu.home-dir | path join .local state claude-rig claims)
}

# The file that holds this machine's number of slots.
def slots-file []: nothing -> path {
  $nu.home-dir | path join .config claude-rig slots
}

# How many jobs this machine takes at once.
export def slot-count []: nothing -> int {
  let value = if "RIG_SLOTS" in $env { $env.RIG_SLOTS } else { read-text (slots-file) | default "1" }
  try { $value | str trim | into int | [$in 1] | math max } catch { 1 }
}

# Who is calling when nobody says: user@host.
export def default-caller []: nothing -> string {
  let user = $env.USER? | default ($env.USERNAME? | default "someone")
  $"($user)@(machine-name)"
}

def now-text []: nothing -> string {
  date now | format date "%Y-%m-%dT%H:%M:%S%:z"
}

def short-time [text: string]: nothing -> string {
  try { $text | into datetime | format date "%H:%M:%S" } catch { $text }
}

# --- The lock --------------------------------------------------------------

# Make a folder, failing if it is already there. nushell's own mkdir does not
# fail then, so the OS's is used: mkdir(2) on macOS and Linux, CreateDirectory
# through cmd on Windows. Both are atomic.
def make-new-dir [dir: path]: nothing -> bool {
  let result = if (is-windows) { ^cmd /c mkdir $dir | complete } else { ^mkdir $dir | complete }
  $result.exit_code == 0
}

def lock-dir []: nothing -> path { claims-dir | path join .lock }

def take-lock [] {
  mkdir (claims-dir)
  let lock = lock-dir
  let deadline = (date now) + 15sec
  loop {
    if (make-new-dir $lock) { return }
    let age = try { (date now) - (ls --directory $lock | get 0.modified) } catch { 0sec }
    if $age > $STALE_LOCK {
      rm --recursive --force $lock
      continue
    }
    if (date now) > $deadline { fail claims $"the claims folder stayed locked for 15 s: ($lock). If nothing is taking a claim, remove it." }
    sleep (50ms + (random int 0..100 | into duration --unit ms))
  }
}

def drop-lock [] {
  rm --recursive --force (lock-dir)
}

# Do something while holding the lock, and let go of it whatever happens.
def with-lock [action: closure]: nothing -> any {
  take-lock
  let outcome = try { {value: (do $action)} } catch {|failure| {failure: $failure.msg} }
  drop-lock
  if "failure" in $outcome { error make {msg: $outcome.failure} }
  $outcome.value
}

# --- Claims ----------------------------------------------------------------

def claim-file [id: string]: nothing -> path { claims-dir | path join $"($id).json" }

def write-claim [claim: record] {
  # Written to the side and moved in, so a reader without the lock never sees half a file.
  let file = claim-file $claim.id
  $claim | to json --indent 2 | save --force $"($file).part"
  mv --force $"($file).part" $file
}

# Every claim, oldest first, each with `live`: false once it is past `until`.
export def all-claims []: nothing -> list<record> {
  let dir = claims-dir
  if not ($dir | path exists) { return [] }
  let now = date now
  ls $dir
  | where {|entry| $entry.type == "file" and ($entry.name | str ends-with ".json") }
  | each {|entry| try { open --raw $entry.name | from json } catch { null } }
  | compact
  | each {|claim| $claim | upsert live ((try { $claim.until | into datetime } catch { $now }) > $now) }
  | sort-by since
}

# The claims still held.
export def live-claims []: nothing -> list<record> {
  all-claims | where live | reject live
}

# One line saying who holds the machine.
def holders-text [claims: list<record>]: nothing -> string {
  $claims | each {|claim| $"($claim.who) \(job \"($claim.what)\", claim ($claim.id)) since (short-time $claim.since), until (short-time $claim.until)" } | str join "; "
}

# Take a slot. Clears expired claims first: their callers stopped renewing
# them, so they are gone. Returns {taken: true, claim} or {taken: false, holders}.
export def take [who: string, what: string, ttl: int]: nothing -> record {
  with-lock {
    for claim in (all-claims | where not live) { rm --force (claim-file $claim.id) }
    let held = live-claims
    if ($held | length) >= (slot-count) {
      {taken: false, holders: $held}
    } else {
      let started = date now
      let id = $"($started | format date '%Y%m%d-%H%M%S')-(random uuid | str substring 0..5)"
      let claim = {
        id: $id
        who: $who
        what: $what
        since: (now-text)
        until: ($started + ($ttl * 1sec) | format date "%Y-%m-%dT%H:%M:%S%:z")
        job_dir: (work-dir | path join jobs $id)
      }
      write-claim $claim
      {taken: true, claim: $claim}
    }
  }
}

# Push a claim's expiry on. False if it is no longer there.
def renew [id: string, ttl: int]: nothing -> bool {
  with-lock {
    let file = claim-file $id
    if not ($file | path exists) { return false }
    let claim = open --raw $file | from json
    write-claim ($claim | upsert until ((date now) + ($ttl * 1sec) | format date "%Y-%m-%dT%H:%M:%S%:z"))
    true
  }
}

# Take a slot, or with `wait`, keep trying until one is free.
def take-or-wait [who: string, what: string, ttl: int, wait: bool] {
  mut told = false
  loop {
    let attempt = take $who $what $ttl
    if $attempt.taken or not $wait { return $attempt }
    if not $told {
      print --stderr $"claims: waiting: (machine-name) is busy: (holders-text $attempt.holders)"
      $told = true
    }
    sleep 5sec
  }
}

def busy [holders: list<record>] {
  print $"busy: (machine-name) is held by (holders-text $holders). Add --wait to wait for it."
  exit $BUSY
}

# --- Commands --------------------------------------------------------------

# Take a slot and print the claim as JSON. Exit 6 if every slot is held.
def "main take" [
  --caller: string    # Who is taking it (default: user@host)
  --label: string     # What the job is (default: "by hand")
  --ttl: int          # Seconds until it expires if not renewed
  --wait              # Wait for a free slot instead of failing
] {
  let attempt = take-or-wait ($caller | default (default-caller)) ($label | default "by hand") ($ttl | default $TTL_SECONDS) $wait
  if not $attempt.taken { busy $attempt.holders }
  print ($attempt.claim | to json --indent 2)
}

# Take a slot, run the work on stdin with Claude in the claim's own job
# folder, renewing the claim while it runs, then let it go. Needs `nu --stdin`.
def "main job" [
  --caller: string    # Who is giving the work (default: user@host)
  --label: string     # What the job is, in a few words
  --wait              # Wait for a free slot instead of failing
  --ttl: int          # Seconds the claim lasts if not renewed; renewed every quarter of that
] {
  let work = $in | default ""
  if ($work | str trim) == "" { fail claims "there is no work on stdin (run it as `nu --stdin`)." }
  let ttl = $ttl | default $TTL_SECONDS
  let attempt = take-or-wait ($caller | default (default-caller)) ($label | default "work") $ttl $wait
  if not $attempt.taken { busy $attempt.holders }
  let claim = $attempt.claim

  # Renewed in the background, until told to stop. Told, not killed: killed
  # in the middle of a renewal, it would leave the lock behind.
  let every = $ttl * 250ms
  let renewer = job spawn {
    loop {
      let message = try { job recv --timeout $every } catch { null }
      if $message == "stop" { break }
      try { renew $claim.id $ttl } catch { }
    }
  }
  let result = try {
    mkdir $claim.job_dir
    cd $claim.job_dir
    # After the caller's own PATH, so a claude already on it wins (the tests rely on that).
    $env.PATH = $env.PATH ++ [(local-bin) (mise-shims)]
    $work | ^claude -p | complete
  } catch {|failure| {exit_code: 1, stdout: "", stderr: $failure.msg} }
  "stop" | job send $renewer
  let deadline = (date now) + 20sec
  while (job list | where id == $renewer | is-not-empty) and (date now) < $deadline { sleep 20ms }
  with-lock { rm --force (claim-file $claim.id) }

  print --no-newline $result.stdout
  if $result.stderr != "" { print --stderr --no-newline $result.stderr }
  exit $result.exit_code
}

# The claims on this machine.
def "main list" [
  --json  # Print them as JSON
] {
  let claims = all-claims
  if $json {
    print ({slots: (slot-count), claims: $claims} | to json --indent 2)
    return
  }
  if ($claims | is-empty) {
    print $"claims: (machine-name) is free \((slot-count) slot\(s))."
    return
  }
  let rows = $claims | each {|claim|
    {id: $claim.id, who: $claim.who, job: $claim.what, since: (short-time $claim.since), until: (short-time $claim.until), state: (if $claim.live { "live" } else { "expired" })}
  }
  print ($rows | table --index false --width 200)
  print $"claims: (slot-count) slot\(s)."
}

# Let go of a claim. Someone else's live claim needs --force; the work it
# was taken for is not stopped.
def "main release" [
  id: string          # The claim's id, from `list`
  --caller: string    # Who is releasing it (default: user@host)
  --force             # Release it even though it is someone else's and still live
] {
  let who = $caller | default (default-caller)
  let outcome = with-lock {
    let file = claim-file $id
    if not ($file | path exists) { return {done: false, message: $"there is no claim ($id) on (machine-name)."} }
    let claim = open --raw $file | from json
    let live = (try { $claim.until | into datetime } catch { date now }) > (date now)
    if $live and $claim.who != $who and not $force {
      return {done: false, message: $"claim ($id) is ($claim.who)'s \(job \"($claim.what)\"), live until (short-time $claim.until). Add --force to release it anyway."}
    }
    rm --force $file
    let whose = if $claim.who == $who { "yours" } else { $"($claim.who)'s" }
    let state = if $live { "still live; its work, if running, was not stopped" } else { "expired" }
    {done: true, message: $"released claim ($id), which was ($whose) \(job \"($claim.what)\", ($state))."}
  }
  if not $outcome.done { fail claims $outcome.message }
  print $"claims: ($outcome.message)"
}

# How many jobs this machine takes at once. With a number, set it.
def "main slots" [
  count?: int  # The new number of slots
] {
  if $count == null {
    print (slot-count)
    return
  }
  if $count < 1 { fail claims "a machine needs at least one slot." }
  let file = slots-file
  if (read-text $file | default "" | str trim) == ($count | into string) {
    ok $"($count) slot\(s)"
  } else {
    change $"set ($count) slot\(s) in ($file)" {
      mkdir ($file | path dirname)
      $count | into string | save --force $file
    }
  }
  if "RIG_SLOTS" in $env { print $"claims: RIG_SLOTS is set here, so ($env.RIG_SLOTS) applies instead." }
}

def main [] {
  print "claims: say job, take, list, release or slots. See the top of tasks/claims.nu."
}
