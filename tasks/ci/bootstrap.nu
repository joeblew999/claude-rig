#!/usr/bin/env nu
# bootstrap.nu — `mise run ci:bootstrap`: checks a machine the bootstrap has
# just rigged, on macOS, Linux and Windows.
#
# The bootstrap's first run happens before this, on a bare machine, with what
# it printed kept in a file (it installs mise, so it cannot run under mise).
# Then this checks: that run skipped the config, the tools are in place, a run
# with the tests' made-up config applies it, doctor's report, a second run
# changes nothing, and a dry run against a throwaway home changes nothing there.
#
# It rigs the machine it runs on: only in CI, or with HOME set to a throwaway
# folder (tasks/ci/common.nu).
#
#   mise run ci:bootstrap [-- <file with the first run's output>]

use ../lib.nu [claude-home is-windows]
use common.nu *

const FIXTURE = path self ../../tests/fixtures/config

# What a real run makes in a home folder. A dry run must make none of them.
const RIG_MAKES = [
  .config/mise/conf.d/claude-rig.toml
  .claude/.rig-manifest
  .claude/settings.json
  .claude/skills
  .claude-rig
  .config/claude-rig
  .local/bin/claude
  .local/bin/claude.exe
  .profile
  .bashrc
  .zshrc
  work
]

def main [
  first_run: path = "first-run.log"  # What the bootstrap's first run printed
] {
  guard "ci:bootstrap"

  print "The first run, with no config"
  let first = read-log ($first_run | path expand)
  check "it skipped the config step" ($first | lines | any {|line| $line =~ '^ +skip +config: none chosen' })
  check "it applied no config" (not (claude-home | path join .rig-manifest | path exists))

  print "Tools"
  with-env { PATH: (machine-path) } {
    let claude = ^claude --version | complete
    check $"claude runs: ($claude.stdout | str trim)" ($claude.exit_code == 0)
    for tool in [gh jq yq rg fd node go bun nu fnox pitchfork] {
      let found = which $tool | get path.0? | default "missing"
      check $"($tool): ($found)" ($found != "missing")
    }
  }

  print "A run with a config"
  with-env { RIG_CONFIG: $FIXTURE } { bootstrap | ignore }
  let settings = open --raw (claude-home | path join settings.json) | from json
  check "remote control is on at startup" (($settings.remoteControlAtStartup? | default false) == true)
  check "the model is the config's" (($settings.model? | default "") == "opus")
  check "the config's skill is in place" (claude-home | path join skills alpha SKILL.md | path exists)

  print "Doctor's report"
  let report = with-env { PATH: (machine-path) } {
    ^$nu.current-exe ($REPO | path join tasks doctor.nu) --json | complete
  }
  print $report.stdout
  check "doctor ran" ($report.exit_code == 0)
  let facts = $report.stdout | from json
  check "the tools are installed" $facts.tools_installed
  check "the config is applied" $facts.config_applied
  check "Claude Code's version is known" ($facts.claude_version != null)
  check "not logged in (this machine cannot log in)" (not $facts.logged_in)

  print "A second run"
  let second = with-env { RIG_CONFIG: $FIXTURE } { bootstrap }
  unchanged $second

  print "A dry run on a bare home"
  dry-run-on-bare-home
}

# Dry runs of the bootstrap with the home folder set to an empty throwaway
# one, which must make nothing there: first as if mise were missing, then with
# it, when the dry run must go all the way through the rig and say what it
# would do. mise keeps its own folders, so the nushell the first run installed
# is found and the rig itself runs.
def dry-run-on-bare-home [] {
  let dirs = ^mise doctor --json | from json | get dirs
  let home = mktemp --directory --tmpdir claude-rig-home.XXXXXX
  let bare = {
    HOME: $home
    USERPROFILE: $home
    XDG_CONFIG_HOME: ($home | path join .config)
    MISE_CONFIG_DIR: ($home | path join .config mise)
    MISE_DATA_DIR: $dirs.data
    MISE_CACHE_DIR: $dirs.cache
    MISE_STATE_DIR: $dirs.state
  }
  do {
    hide-env --ignore-errors RIG_CONFIG CLAUDE_HOME RIG_CONFIG_HOME RIG_ASSUME_LOGGED_IN
    # As on a machine without mise: the bootstrap stops at what it would install. Not on
    # Windows, where bootstrap.ps1 reads PATH back from the registry and so finds mise.
    if not (is-windows) {
      let no_mise = $env.PATH | where {|dir| not ($dir | path join mise | path exists) }
      let output = with-env ($bare | insert PATH $no_mise) { bootstrap --dry-run }
      check "with no mise, it would install it" ($output =~ 'would +install mise')
    }
    with-env $bare {
      let seen = ^$nu.current-exe --no-config-file --commands '$nu.home-dir' | str trim
      check $"nushell takes its home from the throwaway \(($seen))" (($seen | path expand) == ($home | path expand))
      let output = bootstrap --dry-run
      check "the rig itself ran" ($output =~ 'rig: dry run finished')
      check "it says what a run would do" ($output | lines | any {|line| $line =~ '^ +would ' })
    }
  }
  for made in $RIG_MAKES {
    check $"no ($made)" (not ($home | path join $made | path exists))
  }
  print $"    left in the throwaway home: (ls --all $home | get name | each {|name| $name | path basename } | str join ', ')"
  rm --recursive --force $home
}
