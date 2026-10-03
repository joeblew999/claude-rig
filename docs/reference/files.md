---
title: What the rig writes
nav_order: 3
parent: Reference
---

# What the rig writes on a machine

`~` is the user's home folder (`%USERPROFILE%` on Windows).

| Path | What it is | Written by |
|---|---|---|
| `~/.claude-rig/` | The rig's clone | the bootstraps |
| `~/.config/mise/conf.d/claude-rig.toml` | The tool list | the run |
| `~/.bashrc`, `~/.profile` or `~/.zshrc` | A block marked `claude-rig` putting the tools on PATH, if the file does not set up mise already (macOS, Linux) | the run |
| The user `Path` variable | The same, on Windows | the run |
| `~/.local/bin/claude` | Claude Code, from its own installer | the run |
| `~/.claude/` | The merged config, and `.rig-manifest` | the run |
| `~/.claude.rig-backup-<date>/` | The backup before the first change | the run, once |
| `~/.claude.json` | Only the work folder's approval | the session step |
| `~/work/` | The work folder | the session step |
| `~/.config/pitchfork/config.toml` | The session service, `[daemons.claude-rig]`; a first-time backup next to it (macOS, Linux) | the session step |
| `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\claude-rig.cmd` | Starts the session at sign-in (Windows) | the session step |
| `~/.claude-rig-session.log` | What the server last printed (Windows) | the session |
| `~/.config/claude-rig/machines.json` | The machine list, on the Mac you push from | `push`, `fleet add` |
