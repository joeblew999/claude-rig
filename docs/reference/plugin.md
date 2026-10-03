---
title: Plugin commands
nav_order: 4
parent: Reference
---

# Plugin commands

The commands of the Claude Code plugin `rig`, from the marketplace `claude-rig` ([guide](../guides/plugin.md)). Each one is a skill in `plugin/skills/`, typed in a Claude Code session. A command that finds no `~/.claude-rig` runs `/rig:setup` first, which asks before it does anything.

| Command | Arguments | What it runs | Changes |
|---|---|---|---|
| `/rig:setup` | `[--dry-run]` | The published bootstrap for this OS | This machine, after asking |
| `/rig:fleet` | `[--json]` | `mise -C ~/.claude-rig run fleet` | Nothing |
| `/rig:doctor` | | `mise -C ~/.claude-rig run doctor` | Nothing |
| `/rig:push` | `<user@host>` and the flags of the `push` task ([Tasks](tasks.md)) | `mise -C ~/.claude-rig run push -- <arguments>` | That machine, after asking |
| `/rig:work` | `<user@host>` or `--all`, then the work | `mise -C ~/.claude-rig run fleet -- run <machine> "<work>" --json` | What the work does, on that machine |
| `/rig:vm` | `new <linux\|windows> <name>` or `rm <name>` | `mise -C ~/.claude-rig run vm -- <arguments>` | Makes or deletes a UTM VM on this Mac; asks before `rm` |

The plugin also holds the skill `claude-rig-fleet`, which Claude uses by itself when you ask for work on other machines.

## Files

| Path | What it is |
|---|---|
| `.claude-plugin/marketplace.json` | The marketplace `claude-rig`, listing the plugin |
| `plugin/.claude-plugin/plugin.json` | The plugin's manifest. It sets no `version`, so Claude Code takes the commit as the version and an update follows every commit |
| `plugin/skills/<name>/SKILL.md` | One command or skill each |

`mise run plugin:check` checks all of them with Claude Code's own validator.
