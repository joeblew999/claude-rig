---
title: Home
nav_order: 1
permalink: /
---

# claude-rig

[![latest release](https://img.shields.io/github/v/release/joeblew999/claude-rig?include_prereleases)](https://github.com/joeblew999/claude-rig/releases/latest)

You point it at a Mac, a Linux box, a Windows PC or a fresh UTM virtual machine. It installs your dev tools and Claude Code, copies in your Claude config and skills from your Mac, and keeps a Claude session running. After that, the machine shows up in the Claude app and you can give it work from your phone.

Three things make it more than a setup script:

- **One source of truth.** Your Mac's Claude config is the master copy. Change it there, capture it, and every machine picks it up on its next run.
- **Safe to re-run.** Running it again only fixes what's missing or out of date. It never wipes local settings or doubles anything up.
- **No secrets stored.** Tokens are passed in when it runs, never kept in the repo or a VM image.

In short, it's a fleet of interchangeable Claude workers, all set up the same way and all reachable from the Claude app.

Start with [Getting started](getting-started.md).

## What is what

| Name | Where | What it is |
|---|---|---|
| The bootstrap | `bootstrap.sh` (macOS, Linux), `bootstrap.ps1` (Windows) | The only per-OS code: installs git and mise, fetches the rig, starts the run |
| The run | `tasks/rig.nu` | Everything after the bootstrap, the same nushell code on every OS ([A run](concepts/a-run.md)) |
| The captured config | `claude/` | The copy of your Mac's `~/.claude` that every machine gets ([Your config](concepts/config.md)) |
| The tool list | `mise/claude-rig.toml` | The tools every machine gets, at the same versions |
| The session | `tasks/session.nu` | The always-on `claude remote-control` that puts a machine in the Claude app ([Login and the session](concepts/login-and-session.md)) |
| The machine list | `~/.config/claude-rig/machines.json`, on your Mac only | The machines rigged from here, for `fleet` |
| The work folder | `~/work` on each machine | Where the session, and work you send, runs |
| A task | `mise run <task>` | Every command ([Tasks](reference/tasks.md)) |

## What is generated

Never edit these: change the source and run the task.

| Path | Written by |
|---|---|
| `claude/` | `mise run capture`, on your Mac |
| `docs/_config.yml`, `docs/writing.md`, `docs/llms.txt`, `docs/_sass/` | `mise run docs:setup` |

## Every page

| Section | Pages |
|---|---|
| Start | [Getting started](getting-started.md) |
| [Guides](guides.md) | [Rig a Windows PC](guides/windows.md), [Rig a machine over SSH](guides/push.md), [Make a VM worker](guides/vm.md), [See and steer the fleet](guides/fleet.md), [Change the config everywhere](guides/capture.md), [Take a machine out](guides/unrig.md) |
| [Concepts](concepts.md) | [A run](concepts/a-run.md), [Login and the session](concepts/login-and-session.md), [Your config](concepts/config.md) |
| [Reference](reference.md) | [Tasks](reference/tasks.md), [Settings](reference/settings.md), [What the rig writes on a machine](reference/files.md) |
| [This repository](contributing.md) | [Rules](rules.md), [Findings](findings.md), [Plans](plans.md) ([Backlog](plans/backlog.md), [How the repos fit](plans/how-the-repos-fit.md)), [Writing docs](writing.md) |

For an agent: [llms.txt](https://joeblew999.github.io/claude-rig/llms.txt) lists every page as Markdown.
