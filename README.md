# claude-rig

Turn any Mac, Linux or Windows machine into a Claude coding machine you can control from the Claude app.

It installs the tools, applies your global Claude config, and keeps a Claude session running. Every run is safe to repeat.

## Rig a Mac or Linux machine

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
```

To see what it would change without changing anything, add `-s -- --dry-run` after `sh`.

## Rig a Windows machine

In PowerShell (no administrator rights needed):

```powershell
irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1 | iex
```

To only look:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1))) -DryRun
```

## What a run does

It installs git and mise if they are missing (with winget on Windows), the tools in [mise/claude-rig.toml](mise/claude-rig.toml), and Claude Code. Then it merges the config in [claude/](claude/) into `~/.claude`, after backing up what was there.

Then it logs in and starts the always-on session:

- **Login.** If the machine is not logged in, Claude prints a link. Open it on any device, approve, and paste the code back. This is the one step that needs you, once per machine.
- **Session.** [pitchfork](https://pitchfork.jdx.dev) keeps `claude remote-control` running in `~/work` and brings it back after a reboot. The machine then shows up in the Claude app under its own name.

The always-on session is built for macOS and Linux. On Windows the rig installs everything and logs in, and the session part is next.

`mise run doctor` (in `~/.claude-rig`) shows what is set up and what is missing without changing anything. The design is in [the plan](.plans/2026-10-02-01-claude-rig.md), and what is done and what is next is in [the backlog](.plans/BACKLOG.md).

## Update the config from the Mac

```sh
mise run capture
```

This copies the Mac's `~/.claude` settings and skills into `claude/`. Commit the result, and every machine picks it up on its next run.

## Credits

`claude/skills/mise-configuration` and `claude/skills/mise-tasks` come from [terrylica/cc-skills](https://github.com/terrylica/cc-skills) (MIT).
