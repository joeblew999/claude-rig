---
name: setup
description: "Install claude-rig on this machine, so the rig's commands (/rig:push, /rig:fleet, /rig:work, /rig:vm, /rig:doctor) can run. Use when ~/.claude-rig does not exist, or the user asks to set up or install claude-rig here. Asks the user before it changes anything."
argument-hint: "[--dry-run]"
allowed-tools: Bash(ls ~/.claude-rig/mise.toml)
---

# Install claude-rig on this machine

The rig's commands run the tasks in `~/.claude-rig`, a clone of https://github.com/joeblew999/claude-rig. The published one-line bootstrap makes it.

1. **Check first.** Run `ls ~/.claude-rig/mise.toml`. If it exists, the rig is installed: say so and stop.
2. **Say what the bootstrap does, and ask.** It installs git and mise if missing, clones the rig to `~/.claude-rig`, installs the rig's tool list with mise, Claude Code, the Claude config the rig is set up to apply, and starts an always-on `claude remote-control` session, so this machine also shows in the Claude app. It changes this machine. Ask the user whether to look first (a dry run, which changes nothing), install, or stop. Do not run it without a yes.
3. **Run it** for this OS, adding the dry-run flag if the user chose to look first or passed `--dry-run` ($ARGUMENTS):

   ```sh
   # macOS, Linux
   curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh -s -- --dry-run   # look
   curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh                   # install
   ```

   ```powershell
   # Windows, in PowerShell
   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1))) -DryRun   # look
   irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1 | iex                                   # install
   ```

   It takes a few minutes. Each line it prints says `ok`, `would`, `change` or `skip`.
4. **Report** what it changed and anything it skipped, in a few lines. A `skip` for the login means this machine is not logged in to Claude: the user runs `claude auth login` in a terminal, then runs the bootstrap again.

The guide: https://joeblew999.github.io/claude-rig/guides/plugin.html
