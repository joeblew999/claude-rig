#!/usr/bin/env nu
# claims.nu — tests for tasks/claims.nu.
#
# Each test runs the real task against a throwaway claims folder and work
# folder. A job runs a stand-in for Claude that prints the folder it ran in
# and sleeps, so nothing reaches Claude. Nothing outside a temp folder is
# touched.
#
#   nu tests/claims.nu

const CLAIMS = path self ../tasks/claims.nu

# Run the task. Returns what it printed and its exit code.
def claims [root: path, slots: int, args: list<string>]: nothing -> record {
  with-env (setting $root $slots) { ^$nu.current-exe $CLAIMS ...$args | complete }
}

# Run a job, with the work on stdin.
def job [root: path, slots: int, args: list<string>]: nothing -> record {
  with-env (setting $root $slots) { "the work" | ^$nu.current-exe --stdin $CLAIMS job ...$args | complete }
}

def setting [root: path, slots: int]: nothing -> record {
  {
    RIG_CLAIMS: ($root | path join claims)
    RIG_WORKDIR: ($root | path join work)
    RIG_SLOTS: ($slots | into string)
    PATH: ([($root | path join bin)] ++ $env.PATH)
  }
}

# A stand-in for `claude` on PATH: reads the work, prints the folder it runs
# in, and takes about FAKE_SECONDS (default 0) seconds.
def make-fake-claude [root: path] {
  let bin = $root | path join bin
  mkdir $bin
  if $nu.os-info.name == "windows" {
    "@echo off\r\nmore > nul\r\ncd\r\nif not \"%FAKE_SECONDS%\"==\"\" ping -n %FAKE_SECONDS% 127.0.0.1 > nul\r\n" | save --force ($bin | path join claude.cmd)
  } else {
    let file = $bin | path join claude
    "#!/bin/sh\ncat > /dev/null\npwd -P\nsleep \"${FAKE_SECONDS:-0}\"\n" | save --force $file
    ^chmod +x $file
  }
}

def check [what: string, passed: bool] {
  if not $passed { error make { msg: $"FAILED: ($what)" } }
  print $"    ok  ($what)"
}

# The claims on file, as the task lists them.
def held [root: path]: nothing -> list<record> {
  (claims $root 1 [list --json]).stdout | from json | get claims
}

def clear [root: path] {
  rm --recursive --force ($root | path join claims)
}

def test-race [root: path] {
  print "eight callers race for one slot"
  let attempts = 1..8 | par-each {|n| claims $root 1 [take --caller $"caller-($n)" --label race] }
  let winners = $attempts | where exit_code == 0
  check "exactly one gets it" (($winners | length) == 1)
  check "the others are told it is busy (exit 6)" ($attempts | where exit_code != 0 | all {|attempt| $attempt.exit_code == 6 and $attempt.stdout =~ "busy" })
  check "one claim is on file" ((held $root | length) == 1)
  check "a busy answer names the holder" (($attempts | where exit_code == 6 | get 0.stdout) =~ ($winners.0.stdout | from json | get who))
  clear $root
}

def test-slots [root: path] {
  print "a machine with two slots"
  let first = claims $root 2 [take --caller alice]
  let second = claims $root 2 [take --caller bob]
  let third = claims $root 2 [take --caller carol]
  check "two callers get a slot" ($first.exit_code == 0 and $second.exit_code == 0)
  check "the third is told it is busy" ($third.exit_code == 6)
  clear $root
}

def test-expired [root: path] {
  print "a claim whose caller stopped renewing it"
  let old = claims $root 1 [take --caller crashed --ttl "1"]
  check "the first caller gets it" ($old.exit_code == 0)
  sleep 1500ms
  let new = claims $root 1 [take --caller next]
  check "the next caller takes the slot" ($new.exit_code == 0)
  check "the expired claim is cleared" ((held $root | get who) == ["next"])
  clear $root
}

def test-release [root: path] {
  print "releasing claims"
  let taken = (claims $root 1 [take --caller alice --label "alice's job"]).stdout | from json
  let refused = claims $root 1 [release $taken.id --caller bob]
  check "someone else's live claim is not released" ($refused.exit_code == 1 and (held $root | length) == 1)
  check "the refusal says whose it is" ($refused.stderr =~ "alice")
  let forced = claims $root 1 [release $taken.id --caller bob --force]
  check "--force releases it" ($forced.exit_code == 0 and (held $root | is-empty))
  check "and says whose it was" ($forced.stdout =~ "alice's")
  let mine = (claims $root 1 [take --caller alice]).stdout | from json
  let own = claims $root 1 [release $mine.id --caller alice]
  check "your own claim is released without --force" ($own.exit_code == 0 and (held $root | is-empty))
  let gone = claims $root 1 [release $mine.id --caller alice]
  check "a claim that is not there is an error" ($gone.exit_code == 1)
  clear $root
}

def test-job [root: path] {
  print "a job"
  let done = job $root 1 [--caller alice --label test]
  check "it runs" ($done.exit_code == 0)
  # Compared by name: the stand-in may print the folder in another spelling
  # (a resolved link on macOS, a short 8.3 name on Windows).
  let ran_in = $done.stdout | str trim
  let jobs = ls ($root | path join work jobs) | get name | each {|dir| $dir | path basename }
  check "in its own folder under the work folder's jobs/" (($ran_in | path dirname | path basename) == "jobs" and ($ran_in | path basename) in $jobs)
  check "and lets go of its claim when it ends" (held $root | is-empty)

  # A job that outlives its claim's first expiry (1 s) keeps it by renewing it.
  let both = [
    {|| with-env {FAKE_SECONDS: "4"} { job $root 1 [--caller long --label long --ttl "1"] } }
    {|| sleep 2500ms; claims $root 1 [take --caller late] }
  ] | par-each --keep-order {|step| do $step }
  check "a running job keeps its claim past the first expiry" ($both.1.exit_code == 6 and $both.1.stdout =~ "long")
  check "and the job finished" ($both.0.exit_code == 0)
  clear $root
}

def test-wait [root: path] {
  print "waiting for a busy machine"
  let both = [
    {|| with-env {FAKE_SECONDS: "3"} { job $root 1 [--caller first --label first] } }
    {|| sleep 1sec; {started: (date now), result: (job $root 1 [--caller second --label second --wait])} }
  ] | par-each --keep-order {|step| do $step }
  check "the second job waits, then runs" ($both.1.result.exit_code == 0)
  check "the first job ran too" ($both.0.exit_code == 0)
  check "the two ran in different folders" (($both.0.stdout | str trim) != ($both.1.result.stdout | str trim))
  clear $root
}

def main [] {
  let root = mktemp --directory | path expand
  make-fake-claude $root
  try {
    test-race $root
    test-slots $root
    test-expired $root
    test-release $root
    test-job $root
    test-wait $root
  } catch {|failure|
    rm --recursive --force $root
    print --stderr $failure.msg
    exit 1
  }
  rm --recursive --force $root
  print "claims: every test passed."
}
