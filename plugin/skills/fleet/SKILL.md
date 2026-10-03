---
name: fleet
description: "Show every machine rigged with claude-rig in one table: OS, tools, logged in, session running."
argument-hint: "[--json]"
disable-model-invocation: true
allowed-tools: Bash(ls ~/.claude-rig/mise.toml) Bash(mise -C ~/.claude-rig run fleet) Bash(mise -C ~/.claude-rig run fleet -- --json)
---

# Show the fleet

1. Run `ls ~/.claude-rig/mise.toml`. If it is missing, claude-rig is not installed on this machine: use the `rig:setup` skill (it asks the user first), then continue.
2. Run `mise -C ~/.claude-rig run fleet`, or `mise -C ~/.claude-rig run fleet -- --json` if the arguments say `--json` (arguments: "$ARGUMENTS").
3. Show the table as it came out. Then say in one line which machines can take work (`logged in: yes`) and which cannot, and why (the `note` column).

The list of machines lives on the machine that rigged them. On a machine that rigged none, the table has one row: this machine. To add one: `/rig:push user@host` or `/rig:vm new linux <name>`.
