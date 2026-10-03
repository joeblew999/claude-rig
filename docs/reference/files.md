---
title: What the rig writes
nav_order: 3
parent: Reference
---

# What the rig writes on a machine

`~` is the user's home folder (`%USERPROFILE%` on Windows).

| Path | What it is | Written by |
|---|---|---|
| `~/.claude-rig/` | The rig's clone, or a link to the checkout the rig ran from | the bootstraps, or the run |
| `~/.config/mise/conf.d/claude-rig.toml` | The tool list | the run |
| `~/.bashrc`, `~/.profile` or `~/.zshrc` | A block marked `claude-rig` putting the tools on PATH, if the file does not set up mise already (macOS, Linux) | the run |
| The user `Path` variable | The same, on Windows | the run |
| `~/.local/bin/claude` | Claude Code, from its own installer | the run |
| `~/.claude/` | The merged config, and `.rig-manifest` | the run, when there is a config |
| `~/.config/claude-rig/config/` | The machine's copy of its config: what `push` sent, or a clone of the git URL in `RIG_CONFIG` | the run |
| `~/.config/claude-rig/config.tar` | The packed config `push` sent, until the run takes it in | `push` |
| `~/.claude.rig-backup-<date>/` | The backup before the first change | the run, once |
| `~/.claude.json` | Only the work folder's approval | the session step |
| `~/work/` | The work folder | the session step |
| `~/work/jobs/<claim id>/` | One job's folder, where Claude ran it; kept after the job | `fleet run`, through `tasks/claims.nu` |
| `~/.local/state/claude-rig/claims/` | The machine's claims, one `<claim id>.json` each, and `.lock` for a fraction of a second while one is taken or let go ([Claims](../concepts/claims.md)) | `fleet run`, `fleet release` |
| `~/.config/claude-rig/slots` | How many jobs the machine runs at once, if not one | `fleet slots` |
| `~/.config/pitchfork/config.toml` | The session service, `[daemons.claude-rig]`, with an `on_stop` hook that reports `stop`; a first-time backup next to it (macOS, Linux) | the session step |
| `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\claude-rig.cmd` | Starts the session at sign-in (Windows) | the session step |
| `~/.claude-rig-session.log` | What the server last printed (Windows) | the session |
| `~/.config/claude-rig/machines.json` | The machine list, on the Mac you push from | `push`, `fleet add` |
| `~/.config/claude-rig/config.toml` | `folder = "<path>"`: your config folder, on the Mac you push from | `config init` |
| `~/.config/claude-rig/device-id` | The machine id in its reports: 16 random hex digits, made once | the first report |
| `~/.config/claude-rig/fleet-api.token` | fleet-api's write token, readable by the user only (mode 600; on Windows, an access list with only the user) | `push`, or the run when `FLEET_API_WRITE_TOKEN` is set |
| `~/.config/claude-rig/report-spool/` | Reports not yet delivered to fleet-api, one JSON file each, at most 288 | the session, `report` |
