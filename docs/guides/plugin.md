---
title: Use it from Claude Code
nav_order: 0
parent: Guides
---

# Use claude-rig from Claude Code, with the plugin

For a Claude Code user who wants to rig machines and give them work without leaving Claude. The plugin adds commands such as `/rig:push` and `/rig:fleet`; each one runs a task of the rig in `~/.claude-rig`, and installs the rig there first if it is missing. Every command is listed in [Plugin commands](../reference/plugin.md).

## Install the plugin

This repository is also a plugin marketplace, named `claude-rig`, and the plugin in it is named `rig`. In a terminal:

```sh
claude plugin marketplace add joeblew999/claude-rig   # once: this repo as a marketplace
claude plugin install rig@claude-rig                  # the plugin, for you in every project
```

Or inside a Claude Code session: `/plugin marketplace add joeblew999/claude-rig`, then `/plugin install rig@claude-rig`. The commands show up in the next session, or after `/reload-plugins`.

## The first run on a machine

```text
/rig:setup
```

If `~/.claude-rig` does not exist, this command, and every other `/rig:` command, says what the published bootstrap does and asks you before running it. You can choose a dry run first. The bootstrap installs the rig, its tools and Claude Code, and puts this machine in the Claude app too; what a run does: [A run](../concepts/a-run.md).

## Rig machines and give them work

```text
/rig:push user@host --dry-run           # look: what rigging that machine would change
/rig:push user@host                     # rig it over SSH
/rig:vm new linux build-1               # or make a UTM VM on this Mac and rig it
/rig:fleet                              # every rigged machine in one table
/rig:work user@host run the tests in ~/work/app and tell me what fails
```

Each command asks before it changes a machine, and Claude Code's own permission prompts still apply: only `/rig:fleet` and `/rig:doctor`, which change nothing, run without one. You can also ask in plain words ("run the tests on the Windows and Linux machines and compare"): the plugin's skill `claude-rig-fleet` teaches Claude to split a job and use `fleet run`.

A new machine is not logged in to Claude. Log it in once from a terminal, because the commands have none to ask on: `ssh -t user@host`, then `claude auth login`.

## Update or remove it

```sh
claude plugin marketplace update claude-rig   # fetch the latest marketplace listing
claude plugin update rig@claude-rig           # then the plugin; restart Claude Code to load it
claude plugin marketplace remove claude-rig   # remove the marketplace and the plugin with it
```

Claude Code does not update plugins from this marketplace by itself: auto-update is off for marketplaces outside Anthropic's own, unless you turn it on in `/plugin`, on the **Marketplaces** tab.

## Limits

- **The plugin is named `rig`, not `claude-rig`.** Claude Code's validator refuses a plugin name that starts with `claude-`, so the commands are `/rig:...`.
- **The commands run without a terminal.** Steps that ask a question, such as a machine's login, are skipped; the command says what to run in a terminal instead.
- **Not tested:** the plugin on a Windows machine, the first run on a machine without `~/.claude-rig`, and `/rig:push`, `/rig:vm` and `/rig:work` through the plugin (the tasks they run are tested: [Findings](../findings.md)).
