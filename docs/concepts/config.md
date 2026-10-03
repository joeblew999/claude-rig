---
title: Your config
nav_order: 3
parent: Concepts
---

# Your config: one master copy, merged everywhere

## What is captured

`mise run capture`, on your Mac, copies into `claude/`: `settings.json`, `CLAUDE.md`, and `skills/`, `agents/`, `commands/` and `hooks/` when they exist. It leaves out:

- **`skills/synced/`**, which your Claude account fills in on each machine.
- **Settings that only make sense on the Mac**: `permissions.additionalDirectories` and `sandbox.network.allowUnixSockets`.
- **Settings in `env` named like a secret** (`TOKEN`, `KEY`, `SECRET`, `PASSWORD`, `CREDENTIAL`).
- **`~/.claude.json`**, which holds your login. Never.

It stops, and leaves `claude/` as it was, if anything token-shaped (a GitHub, Anthropic, AWS or Slack token, or a private key) or a path under your home folder is still in the copy. This repo is public, so that check is what keeps your secrets out of it.

## How it is applied on a machine

| What | How |
|---|---|
| A backup | The first run copies everything it could change to `~/.claude.rig-backup-<date>`, once |
| `settings.json` | Merged: the rig's keys are set, keys only the machine has are kept, lists keep both |
| Skills, agents, commands, hooks | Each entry added or replaced as a whole; entries only the machine has are left alone. A record in `~/.claude/.rig-manifest` lets an entry removed on the Mac be removed from the machine too |
| `CLAUDE.md` | Replaced, if it differs |

## No secrets stored

Nothing secret is in the repo, the captured config, or a VM image made from a rigged machine. The one secret a machine needs, its login, is made on the machine when you approve it.
