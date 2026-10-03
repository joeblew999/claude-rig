#!/usr/bin/env nu
# rig.nu — the main run: tools, Claude Code, Claude config, login, session.
#
# bootstrap.sh (macOS, Linux) or bootstrap.ps1 (Windows) gets git, mise and
# nushell onto the machine and then runs this. The same code runs on all three.
# Safe to repeat. Each step checks first and acts only if something is
# missing or out of date.
#
#   nu tasks/rig.nu [--dry-run]

use lib.nu *
use enroll.nu *

def mise-config-dir []: nothing -> path {
  $env.MISE_CONFIG_DIR? | default (
    $env.XDG_CONFIG_HOME? | default ($nu.home-dir | path join .config) | path join mise
  )
}

def install-tools [] {
  cd $nu.home-dir
  ^mise install --yes
}

# --- Shell PATH: macOS and Linux -------------------------------------------

const PATH_BLOCK = '
# >>> claude-rig >>>
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
# <<< claude-rig <<<
'

def --env shell-path-unix [] {
  let home = $nu.home-dir
  let rc_files = match ($env.SHELL? | default sh | path basename) {
    "zsh" => [($home | path join .zshrc)]
    "bash" => [($home | path join .bashrc) ($home | path join .profile)]
    _ => [($home | path join .profile)]
  }
  for rc in $rc_files {
    if (read-text $rc | default "") =~ 'claude-rig|mise activate|mise/shims' {
      ok $"PATH in ($rc)"
    } else {
      change $"add the tools to PATH in ($rc)" { $PATH_BLOCK | save --append $rc }
    }
  }
}

# --- Shell PATH: Windows ---------------------------------------------------

def --env shell-path-windows [wanted: list<path>] {
  let current = powershell "[Environment]::GetEnvironmentVariable('Path', 'User')"
    | split row ";"
    | where {|dir| $dir != "" }
  let missing = $wanted | where {|dir| ($dir | str lowercase) not-in ($current | str lowercase) }
  if ($missing | is-empty) {
    ok "user PATH"
  } else {
    let updated = $missing ++ $current | str join ";"
    change $"add to the user PATH: ($missing | str join ', ')" {
      powershell $"[Environment]::SetEnvironmentVariable\('Path', '($updated)', 'User')"
    }
  }
}

# --- Claude Code -----------------------------------------------------------

def install-claude [] {
  if (is-windows) {
    ^powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://claude.ai/install.ps1 | iex"
  } else {
    ^bash -c "curl -fsSL https://claude.ai/install.sh | bash"
  }
}

# Make ~/.claude-rig lead to this checkout, if nothing else is there.
def --env link-rig-home [] {
  let home_rig = $nu.home-dir | path join .claude-rig
  let here = repo-dir | path expand
  if ($home_rig | path exists) {
    if ($home_rig | path expand) == $here {
      ok $"~/.claude-rig is this rig \(($here))"
    } else {
      skipped $"~/.claude-rig is another folder, so it is left alone \(this rig is ($here))"
    }
    return
  }
  change $"link ~/.claude-rig to ($here)" {
    if (is-windows) {
      # A junction needs no administrator rights, unlike a symbolic link.
      ^cmd /c mklink /J $home_rig $here | ignore
    } else {
      ^ln -s $here $home_rig
    }
  }
}

def main [
  --dry-run  # Report what would change and change nothing
] {
  if $dry_run { $env.RIG_DRY_RUN = "1" }

  let local_bin = local-bin
  let shims = mise-shims
  $env.PATH = [$local_bin $shims] ++ $env.PATH

  if not (have mise) { fail rig "mise is missing. Run the bootstrap first." }

  print "Tools"

  let tools_src = repo-dir | path join mise claude-rig.toml
  let tools_dest = mise-config-dir | path join conf.d claude-rig.toml

  if (read-text $tools_src) == (read-text $tools_dest) {
    ok $"tool list \(($tools_dest))"
    if (missing-tools) == "" {
      ok "tools installed"
    } else {
      change "install the missing tools" { install-tools }
    }
  } else {
    change $"install the tool list to ($tools_dest)" {
      mkdir ($tools_dest | path dirname)
      cp $tools_src $tools_dest
    }
    change "install the tools" { install-tools }
  }

  # New shells need ~/.local/bin (claude) and the mise shims (every tool).
  # A machine whose shell already sets up mise is left alone.
  print "Shell"

  if (is-windows) { shell-path-windows [$local_bin $shims] } else { shell-path-unix }

  print "Claude Code"

  if (have claude) {
    ok $"claude \((which claude | get path.0))"
  } else {
    change "install Claude Code with the native installer" { install-claude }
  }

  # Skills and docs say "~/.claude-rig", so make that the rig on every machine,
  # also where the rig runs from a checkout somewhere else.
  print "The rig"

  link-rig-home

  print "Claude config"

  let apply = $env.FILE_PWD | path join apply.nu
  let flags = if (dry-run) { [--dry-run] } else { [] }
  with-env { RIG_CHANGES: "0" } { ^$nu.current-exe $apply ...$flags }

  print "Login"

  let logged_in = login-step

  print "Session"

  if $logged_in {
    session-step
  } else {
    skipped "always-on session: needs the login first"
  }

  print "Reporting"

  token-step

  if (dry-run) {
    print "rig: dry run finished. Nothing was changed."
  } else {
    print "rig: done."
  }
}
