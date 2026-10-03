---
name: push
description: "Rig a machine over SSH with claude-rig: tools, Claude Code, config and an always-on session, so it shows in the Claude app."
argument-hint: "<user@host> [--dry-run] [--port <n>] [--identity <key file>] [--ref <branch>]"
disable-model-invocation: true
allowed-tools: Bash(ls ~/.claude-rig/mise.toml)
---

# Rig a machine over SSH

Arguments: "$ARGUMENTS". The first is the machine as `user@host`; the rest are flags for the task.

1. If there is no `user@host`, ask for it and stop.
2. Run `ls ~/.claude-rig/mise.toml`. If it is missing, claude-rig is not installed on this machine: use the `rig:setup` skill (it asks the user first), then continue.
3. Unless the arguments include `--dry-run`, say what will happen and ask before going on: the machine gets git, mise, the rig's tool list, Claude Code, the Claude config and an always-on Claude session. Offer a dry run first.
4. Run `mise -C ~/.claude-rig run push -- <the arguments>`. It needs SSH key login to the machine, with no password, and `sudo` on Linux without a password. It takes a few minutes.
5. Report in a few lines what changed. If the login step was skipped (there is no terminal here to ask on), tell the user to log the machine in once, from a terminal: `ssh -t user@host`, then `claude auth login`, then run `/rig:push user@host` again so the session starts. When it succeeds, the machine shows in `/rig:fleet`.

The flags are listed at https://joeblew999.github.io/claude-rig/guides/push.html
