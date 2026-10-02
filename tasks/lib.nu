# lib.nu — shared by the rig tasks.
#
# Every change goes through `change`, so a run can report what it did and
# --dry-run can report what it would do without doing it.

# The thing is already as it should be.
export def ok [what: string] {
  print $"  ok      ($what)"
}

# Nothing to do here, and why.
export def skip [what: string] {
  print $"  skip    ($what)"
}

# Stop with a message.
export def fail [task: string, message: string] {
  print --stderr $"($task): ($message)"
  exit 1
}

# Make a change, or only announce it on --dry-run.
export def --env change [what: string, action: closure] {
  $env.RIG_CHANGES = (changes) + 1
  if (dry-run) {
    print $"  would   ($what)"
  } else {
    print $"  change  ($what)"
    do $action
  }
}

# Changes made (or announced) so far in this run.
export def changes []: nothing -> int {
  $env.RIG_CHANGES? | default 0 | into int
}

export def dry-run []: nothing -> bool {
  ($env.RIG_DRY_RUN? | default "0") == "1"
}

export def is-windows []: nothing -> bool {
  $nu.os-info.name == "windows"
}

# The top folder of this repo.
export def repo-dir []: nothing -> path {
  $env.FILE_PWD | path dirname
}

# This machine's global Claude config folder.
export def claude-home []: nothing -> path {
  $env.CLAUDE_HOME? | default ($nu.home-dir | path join ".claude")
}

# True if a program is on PATH.
export def have [program: string]: nothing -> bool {
  which $program | is-not-empty
}

# The text of a file, or null if it is missing.
export def read-text [file: path] {
  if ($file | path exists) { open --raw $file | decode utf-8 } else { null }
}

# What is inside a file or folder, as a list that can be compared with ==.
# .DS_Store files are ignored.
export def contents [target: path]: nothing -> list<string> {
  let root = $target | path expand
  if ($root | path type) != "dir" {
    return [(open --raw $root | hash sha256)]
  }
  cd $root
  glob "**/*" --no-dir
  | each {|file| $file | path relative-to $root }
  | where {|file| ($file | path basename) != ".DS_Store" }
  | sort
  | each {|file| $"($file | path split | str join '/') (open --raw $file | hash sha256)" }
}

# Where claude and other user programs live.
export def local-bin []: nothing -> path {
  $nu.home-dir | path join .local bin
}

# Where mise keeps its shims (one small launcher per tool).
export def mise-shims []: nothing -> path {
  let data = if "MISE_DATA_DIR" in $env {
    $env.MISE_DATA_DIR
  } else if (is-windows) {
    $env.LOCALAPPDATA | path join mise
  } else {
    $env.XDG_DATA_HOME? | default ($nu.home-dir | path join .local share) | path join mise
  }
  $data | path join shims
}

# The folder the always-on Claude session works in.
export def work-dir []: nothing -> path {
  $env.RIG_WORKDIR? | default ($nu.home-dir | path join work)
}

# The name this machine shows up under in the Claude app.
export def machine-name []: nothing -> string {
  $env.RIG_NAME? | default (sys host | get hostname | str replace --regex '\.(local|lan)$' "")
}
