# userconfig.nu — where a user's Claude config comes from, and how it travels.
# Used by apply.nu, capture.nu, config.nu, push.nu and doctor.nu.
#
# A config is a folder laid out like ~/.claude: settings.json, CLAUDE.md,
# skills/, agents/, commands/, hooks/. The rig ships none. A run takes it from,
# in this order:
#
#   1. RIG_CONFIG: a folder, or a git URL that is cloned into the machine's copy
#   2. the folder named in ~/.config/claude-rig/config.toml (the machine you rig from)
#   3. the machine's copy, ~/.config/claude-rig/config/: what push sent last,
#      or the clone of a git URL given earlier
#
# With none of these there is no config, and the config step is skipped.

use lib.nu *

# What a config holds. Anything else in the folder (README, .git) is not part of it.
export const ENTRIES = [settings.json CLAUDE.md skills agents commands hooks]

const SECRET_VALUE = 'sk-ant-[A-Za-z0-9_-]{10,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}'

# The rig's own folder on this machine: config.toml, the machine's copy of the
# config, and machines.json.
export def rig-home []: nothing -> path {
  $env.RIG_CONFIG_HOME? | default ($nu.home-dir | path join .config claude-rig)
}

# Where the config folder's location is remembered.
export def settings-file []: nothing -> path {
  rig-home | path join config.toml
}

# The machine's copy of its config: what push sent, or a clone of a git URL.
export def copy-dir []: nothing -> path {
  rig-home | path join config
}

# Where push leaves the packed config for the run to take in.
export def sent-file []: nothing -> path {
  rig-home | path join config.tar
}

# Where push puts the packed config on the remote, from the remote's home folder.
export const REMOTE_DIR = ".config/claude-rig"
export const REMOTE_SENT_FILE = ".config/claude-rig/config.tar"

export def is-git-url [text: string]: nothing -> bool {
  $text =~ '^(https?|ssh|git|file)://' or $text =~ '^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+:'
}

# The value of RIG_CONFIG, or null when it is unset or empty.
def wanted []: nothing -> any {
  let value = $env.RIG_CONFIG? | default "" | str trim
  if $value == "" { null } else { $value }
}

# The folder named in config.toml, or null.
export def chosen-folder []: nothing -> any {
  let file = settings-file
  if not ($file | path exists) { return null }
  open --raw $file | from toml | get --optional folder
}

# Remember the config folder in config.toml, keeping anything else in it.
export def choose-folder [folder: path] {
  let file = settings-file
  let current = if ($file | path exists) { open --raw $file | from toml } else { {} }
  mkdir ($file | path dirname)
  $current | upsert folder $folder | to toml | save --force $file
}

# The config folder on the machine you rig from: RIG_CONFIG when it names a
# folder, else the one in config.toml. Null if there is none. This is what
# capture writes to and push sends.
export def local-folder [task: string]: nothing -> any {
  let value = wanted
  if $value != null {
    if (is-git-url $value) {
      fail $task $"RIG_CONFIG is a git URL \(($value)). ($task) needs a folder: unset RIG_CONFIG to use the one in (settings-file)."
    }
    return ($value | path expand)
  }
  chosen-folder
}

# Where this machine's config comes from, in words, without changing anything.
# Null if there is none.
export def describe-config []: nothing -> any {
  let value = wanted
  if $value != null { return $"($value) \(RIG_CONFIG)" }
  let chosen = chosen-folder
  if $chosen != null { return $"($chosen) \(set in (settings-file))" }
  if (sent-file | path exists) { return $"(sent-file) \(sent by push, taken in on the next run)" }
  let copy = copy-dir
  if ($copy | path join .git | path exists) {
    let url = ^git -C $copy remote get-url origin | complete | get stdout | str trim
    return $"($copy) \(a clone of ($url))"
  }
  if ($copy | path exists) { return $"($copy) \(sent by push)" }
  null
}

# --- Packing a config to send it -------------------------------------------

# Pack the config in a folder into one tar file. Only the config's entries go
# in: not .git, not a README, not .DS_Store.
export def pack-config [folder: path, out: path] {
  let present = $ENTRIES | where {|entry| $folder | path join $entry | path exists }
  if ($present | is-empty) { fail push $"($folder) holds no config \(none of: ($ENTRIES | str join ', '))." }
  # tar is given no absolute paths: GNU tar reads "C:" in one as a host name.
  do {
    cd $folder
    with-env { COPYFILE_DISABLE: "1" } { ^tar --exclude .DS_Store -cf - ...$present }
  } | save --raw --force $out
}

# Unpack a packed config into a folder.
export def unpack-config [file: path, dest: path] {
  mkdir $dest
  do {
    cd $dest
    open --raw $file | ^tar -xf -
  }
}

# The files under a folder whose text matches a pattern. Binary files are skipped.
def files-matching [root: path, pattern: string]: nothing -> list<string> {
  cd $root
  glob "**/*" --no-dir | where {|file|
    let text = try { open --raw $file | decode utf-8 } catch { "" }
    $text =~ $pattern
  } | each {|file| $file | path relative-to $root }
}

# What must stop a config from being stored or sent: anything token-shaped,
# and paths under this machine's home folder. One record per problem found.
export def config-problems [root: path]: nothing -> list<record> {
  let home = $nu.home-dir | str replace --all '\' '\\' | str replace --all '.' '\.'
  [
    {problem: "possible secret in", files: (files-matching $root $SECRET_VALUE)}
    {problem: $"a path under ($nu.home-dir) in", files: (files-matching $root $home)}
  ] | where {|check| $check.files | is-not-empty }
}

# Pack a folder for push and check what is in the pack. Stops on a problem.
export def pack-for-push [folder: path, out: path] {
  pack-config $folder $out
  let look = mktemp --directory | path expand
  unpack-config $out $look
  let problems = config-problems $look
  rm --recursive --force $look
  if ($problems | is-not-empty) {
    for check in $problems {
      print --stderr $"push: ($check.problem) these files of ($folder) \(nothing was sent):"
      $check.files | each {|file| print --stderr $"  ($file)" }
    }
    rm --force $out
    exit 1
  }
}

# --- Finding the config on a run -------------------------------------------

# A clone of a git URL, kept as the machine's copy and brought up to date.
def --env from-git [url: string]: nothing -> path {
  let copy = copy-dir
  let origin = if ($copy | path join .git | path exists) {
    ^git -C $copy remote get-url origin | complete | get stdout | str trim
  } else {
    ""
  }
  if $origin != $url {
    if (dry-run) {
      # Look at it without keeping a clone.
      let look = mktemp --directory | path expand
      ^git clone -q --depth 1 $url ($look | path join config)
      change $"clone the config from ($url) into ($copy)" { }
      return ($look | path join config)
    }
    change $"clone the config from ($url) into ($copy)" {
      rm --recursive --force $copy
      mkdir ($copy | path dirname)
      ^git clone -q $url $copy
    }
    return $copy
  }
  if (dry-run) {
    ok $"config: a clone of ($url) at ($copy) \(a real run brings it up to date)"
    return $copy
  }
  ^git -C $copy fetch -q origin HEAD
  let head = ^git -C $copy rev-parse HEAD | str trim
  let fetched = ^git -C $copy rev-parse FETCH_HEAD | str trim
  if $head == $fetched {
    ok $"config: a clone of ($url) at ($copy)"
  } else if (^git -C $copy status --porcelain | str trim) != "" {
    fail apply $"($copy) has local changes. Commit or discard them, then run again."
  } else {
    change $"update the config from ($url)" { ^git -C $copy checkout -q --detach FETCH_HEAD }
  }
  $copy
}

# Take in the config push left here, as the machine's copy.
def --env from-push []: nothing -> path {
  let file = sent-file
  let copy = copy-dir
  let look = mktemp --directory | path expand
  unpack-config $file $look
  if ($copy | path exists) and (contents $look) == (contents $copy) {
    ok $"config sent by push \(($copy))"
    rm --recursive --force $look
    # The same config was sent again: the file has done its job.
    if not (dry-run) { rm --force $file }
    return $copy
  }
  if (dry-run) {
    change $"take in the config sent by push, as ($copy)" { }
    return $look
  }
  change $"take in the config sent by push, as ($copy)" {
    rm --recursive --force $copy
    cp --recursive $look $copy
    rm --force $file
  }
  rm --recursive --force $look
  $copy
}

# The folder to apply on this run, after bringing it up to date. Null if this
# machine has no config. Prints one line saying where it came from.
export def --env resolve-config []: nothing -> any {
  let value = wanted
  if $value != null {
    if (is-git-url $value) { return (from-git $value) }
    let folder = $value | path expand
    if not ($folder | path exists) { fail apply $"RIG_CONFIG names ($folder), which does not exist." }
    ok $"config: ($folder) \(RIG_CONFIG)"
    return $folder
  }
  let chosen = chosen-folder
  if $chosen != null {
    if not ($chosen | path exists) { fail apply $"the config folder ($chosen), set in (settings-file), does not exist." }
    ok $"config: ($chosen) \(set in (settings-file))"
    return $chosen
  }
  if (sent-file | path exists) { return (from-push) }
  let copy = copy-dir
  if ($copy | path join .git | path exists) {
    let url = ^git -C $copy remote get-url origin | complete | get stdout | str trim
    if $url != "" { return (from-git $url) }
  }
  if ($copy | path exists) {
    ok $"config: ($copy) \(sent by push)"
    return $copy
  }
  null
}
