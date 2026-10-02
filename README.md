# claude-rig

Turn any Mac, Linux or Windows machine into a Claude coding machine you can control from the Claude app.

It installs the tools, applies your global Claude config, and keeps a Claude session running. Every run is safe to repeat.

## Rig a Mac or Linux machine

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
```

To see what it would change without changing anything, add `-s -- --dry-run` after `sh`.

It installs git and mise if they are missing, the tools in [mise/claude-rig.toml](mise/claude-rig.toml), and Claude Code. Then it merges the config in [claude/](claude/) into `~/.claude`, after backing up what was there.

Windows, login and the always-on session are not built yet. The design and build order are in [.plans/2026-10-02-01-claude-rig.md](.plans/2026-10-02-01-claude-rig.md).

## Update the config from the Mac

```sh
mise run capture
```

This copies the Mac's `~/.claude` settings and skills into `claude/`. Commit the result, and every machine picks it up on its next run.

## Credits

`claude/skills/mise-configuration` and `claude/skills/mise-tasks` come from [terrylica/cc-skills](https://github.com/terrylica/cc-skills) (MIT).
