#!/usr/bin/env nu
# release.nu — a release is one command and a version tag.
#
#   mise run release -- vX.Y.Z [--dry-run]   check, then tag main and push the tag
#   mise run release:publish [-- vX.Y.Z]      the GitHub Release for the tag (the release workflow);
#                                             not on a tag, a dry run that prints the notes
#
# charter's `release` attaches built files from dist/ and this repo ships none, its notes are
# GitHub's generated ones, and charter has no step that cuts the tag.
# Upstream: joeblew999/charter#39 (when fixed: call charter's release commands here instead).

use lib.nu [fail]

const REPO = path self ..
const VERSION = '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'
# The workflow whose run on the commit must have passed.
const WORKFLOW = "test.yml"
# A line in README.md that starts with this makes a release a pre-release.
const PRERELEASE = "**Pre-release:**"

def --wrapped git [...args: string]: nothing -> string {
  let result = ^git -C $REPO ...$args | complete
  if $result.exit_code != 0 { fail release $"git ($args | str join ' '): ($result.stderr | str trim)" }
  $result.stdout | str trim
}

# The latest run of the CI workflow on a commit, or null.
def ci-run [commit: string] {
  let result = ^gh run list --commit $commit --workflow $WORKFLOW --limit 1 --json status,conclusion,url | complete
  if $result.exit_code != 0 { return null }
  $result.stdout | from json | get 0?
}

# The checks CI runs, run here: a release is cut from this machine in about a
# minute, and GitHub's CI on the tag verifies every OS afterwards.
const LOCAL_CHECKS = [lint test "docs:check" "github:check" "ci:bootstrap"]

# Run one mise task and say whether it passed. ci:bootstrap rigs the machine it
# runs on, so here it gets a throwaway home folder, removed afterwards.
def run-check [task: string]: nothing -> bool {
  let home = if $task == "ci:bootstrap" { mktemp --directory --tmpdir claude-rig-release.XXXXXX } else { null }
  let result = if $home == null {
    ^mise run $task | complete
  } else {
    # As in CI: the bootstrap's first run on a bare home, then the checks on
    # its output. mise's download cache is shared, so it does not fetch again.
    let cache = $env.MISE_CACHE_DIR? | default ($nu.home-dir | path join Library Caches mise)
    let log = $home | path join first-run.log
    let out = with-env { HOME: $home, MISE_CACHE_DIR: $cache } {
      let first = ^sh bootstrap.sh | complete
      $"($first.stdout)($first.stderr)" | save --force $log
      if $first.exit_code != 0 { $first } else { ^mise run $task -- $log | complete }
    }
    rm --recursive --force $home
    $out
  }
  if $result.exit_code != 0 {
    print --stderr ($"($result.stdout)($result.stderr)" | lines | last 15 | str join "\n")
  }
  $result.exit_code == 0
}

# Check here, tag main as vX.Y.Z, push the tag and publish the release, all
# from this machine. GitHub's CI then runs on the tag for every OS; a failure
# there is fixed with a patch release.
def main [
  tag: string  # The version, vX.Y.Z
  --dry-run    # Run every check and say what would be done, change nothing
  --wait-ci    # Also require GitHub's CI to have passed on HEAD (slow; off by default)
] {
  git fetch --quiet --tags origin main | ignore
  let head = git rev-parse HEAD
  let main = git rev-parse origin/main
  let run = ci-run $head
  let ci = if $run == null { "none" } else { $"($run.status) ($run.conclusion? | default '') ($run.url)" }
  let checks = [
    [what passed];
    [$"($tag) looks like vX.Y.Z" ($tag =~ $VERSION)]
    ["the working tree is clean" ((git status --porcelain) == "")]
    [$"HEAD \(($head | str substring 0..<7)) is main on GitHub \(($main | str substring 0..<7))" ($head == $main)]
    [$"($tag) is not a tag here" ((git tag --list $tag) == "")]
    [$"($tag) is not a tag on GitHub" ((git ls-remote --tags origin $"refs/tags/($tag)") == "")]
  ]
  let checks = if $wait_ci {
    $checks | append {what: $"CI \(($WORKFLOW)) passed on HEAD: ($ci)", passed: ($run != null and $run.status == "completed" and $run.conclusion == "success")}
  } else {
    $checks
  }
  let checks = $checks | append ($LOCAL_CHECKS | each {|task| {what: $"mise run ($task)", passed: (run-check $task)} })
  for check in $checks {
    print $"  (if $check.passed { 'ok  ' } else { 'FAIL' })  ($check.what)"
  }
  if not ($checks | all {|check| $check.passed }) {
    fail release "not tagged: a check failed"
  }
  if $dry_run {
    print $"  would   git tag -a ($tag) -m ($tag) ($head)"
    print $"  would   git push origin ($tag)"
    print $"  would   publish the GitHub Release for ($tag)"
    print "release: dry run finished. Nothing was changed."
    return
  }
  git tag -a $tag -m $tag $head | ignore
  git push --quiet origin $tag | ignore
  main publish $tag
  print $"release: ($tag) is out. GitHub's CI now checks it on every OS: https://github.com/joeblew999/claude-rig/actions"
}

# The notes: the commits since the previous version tag, and where it was tested.
def notes [target: string, link_ref: string]: nothing -> string {
  let before = ^git -C $REPO describe --tags --abbrev=0 --match "v*" $"($target)^" | complete
  let previous = if $before.exit_code == 0 { $before.stdout | str trim } else { null }
  let range = if $previous == null { $target } else { $"($previous)..($target)" }
  let commits = git log --no-merges --format=%s $range | lines | each {|subject| $"- ($subject)" }
  let heading = if $previous == null { "## Changes" } else { $"## Changes since ($previous)" }
  [
    $heading
    ""
    ...$commits
    ""
    "## Where it was tested"
    ""
    $"Every result, with the machine it ran on and when, is in [Findings]\(https://github.com/joeblew999/claude-rig/blob/($link_ref)/docs/findings.md) at this release."
    ""
  ] | str join "\n"
}

# Whether README.md says the rig is a pre-release.
def prerelease []: nothing -> bool {
  open --raw ($REPO | path join README.md) | decode utf-8 | lines | any {|line| $line | str starts-with $PRERELEASE }
}

# The GitHub Release for a tag, made or brought up to date. Without a tag (the
# release workflow on a pull request), a dry run: the notes for HEAD, printed.
def "main publish" [
  tag?: string  # The version tag; default: the tag the workflow runs on
] {
  let tag = $tag | default (if ($env.GITHUB_REF_TYPE? | default "") == "tag" { $env.GITHUB_REF_NAME } else { "" })
  if $tag != "" and not ($tag =~ $VERSION) { fail release $"($tag) is not a version tag \(vX.Y.Z)" }
  let target = if $tag == "" { "HEAD" } else { $tag }
  let body = notes $target (if $tag == "" { "main" } else { $tag })
  let pre = prerelease
  print $body
  print $"pre-release: ($pre) \(README.md (if $pre { 'has a' } else { 'has no' }) line starting ($PRERELEASE))"
  if $tag == "" {
    print "release: dry run (not on a version tag). Nothing was published."
    return
  }
  let file = mktemp --tmpdir release-notes.XXXXXX
  $body | save --force $file
  let exists = (^gh release view $tag | complete | get exit_code) == 0
  let args = if $exists {
    ["release" "edit" $tag "--title" $tag "--notes-file" $file $"--prerelease=($pre)"]
  } else {
    ["release" "create" $tag "--verify-tag" "--title" $tag "--notes-file" $file] ++ (if $pre { ["--prerelease"] } else { [] })
  }
  let result = ^gh ...$args | complete
  rm --force $file
  if $result.exit_code != 0 { fail release $"gh ($args | first 2 | str join ' '): ($result.stderr | str trim)" }
  print $"release: ($tag) (if $exists { 'updated' } else { 'published' }): ($result.stdout | str trim)"
}
