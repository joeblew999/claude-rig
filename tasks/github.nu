#!/usr/bin/env nu
# github.nu — the issue forms and labels in .github/ come from charter.
#
# charter writes them with its workflows (`charter workflows`), which also
# writes workflows for an API project that this repo is not, so this takes only
# the forms and labels. The bug form stays this repo's own: charter's asks for
# `charter version` and a project made with `charter new`. Labels are charter's
# and this repo's extra ones.
#
#   mise run github:setup   write them from charter
#   mise run github:check   fail if they differ from what charter writes

use lib.nu [fail]

const REPO = path self ..
# The forms taken from charter exactly as it writes them.
const FORMS = [ISSUE_TEMPLATE/config.yml ISSUE_TEMPLATE/feature.yml ISSUE_TEMPLATE/upstream.yml]

def main [
  --check  # Change nothing; fail if a file differs from charter's
] {
  let tmp = mktemp --directory --tmpdir charter-github.XXXXXX
  let wrote = ^charter workflows -into $tmp | complete
  if $wrote.exit_code != 0 { fail github $"charter workflows: ($wrote.stderr | str trim)" }
  let theirs = $tmp | path join .github
  let ours = $REPO | path join .github
  mut stale = []

  for form in $FORMS {
    let wanted = open --raw ($theirs | path join $form) | decode utf-8
    let file = $ours | path join $form
    let have = if ($file | path exists) { open --raw $file | decode utf-8 } else { "" }
    if $have == $wanted {
      print $"  ok      .github/($form)"
    } else if $check {
      $stale = $stale ++ [$".github/($form)"]
    } else {
      $wanted | save --force $file
      print $"  change  .github/($form)"
    }
  }

  # Every label charter defines, as charter defines it; this repo's own after them.
  let wanted_labels = open --raw ($theirs | path join labels.tsv) | decode utf-8 | lines | where {|line| $line != "" }
  let file = $ours | path join labels.tsv
  let have_labels = open --raw $file | decode utf-8 | lines | where {|line| $line != "" }
  let name = {|line| $line | split row "\t" | first }
  let charter_names = $wanted_labels | each $name
  let own = $have_labels | where {|line| (do $name $line) not-in $charter_names }
  let labels = $wanted_labels ++ $own
  if $labels == $have_labels {
    print "  ok      .github/labels.tsv"
  } else if $check {
    $stale = $stale ++ [".github/labels.tsv"]
  } else {
    $labels | str join "\n" | $in + "\n" | save --force $file
    print "  change  .github/labels.tsv"
  }

  rm --recursive --force $tmp
  if ($stale | is-not-empty) {
    fail github $"not as charter writes them: ($stale | str join ', '). Run: mise run github:setup"
  }
}
