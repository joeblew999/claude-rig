---
title: Your config
nav_order: 3
parent: Concepts
---

# Your config: your own folder, merged everywhere

The rig ships no one's Claude config. Yours is a folder of your own, and every run on every machine merges it into `~/.claude`. This page says what is in that folder, where a run finds it, and how it is merged. To change it and send the change out: [Change the config everywhere](../guides/capture.md).

## What a config folder holds

A config folder is laid out like `~/.claude`: `settings.json`, `CLAUDE.md`, and the folders `skills/`, `agents/`, `commands/` and `hooks/`, each part only if you have one. Anything else in the folder, such as a `README.md` or `.git`, is not part of the config: the rig neither sends it nor applies it. The folder may be a git repo, and can be private. `tests/fixtures/config` is a small example; the tests apply it.

## Where a run finds it

The first of these that is there wins:

| Where | Used on | Set by |
|---|---|---|
| `RIG_CONFIG`: a folder, or a git URL | any machine, for that run | you, before the bootstrap ([Settings](../reference/settings.md)) |
| The folder named in `~/.config/claude-rig/config.toml` | the machine you rig from, normally your Mac | `mise run config -- init <folder>` |
| The machine's copy, `~/.config/claude-rig/config/` | a machine rigged with `push`, or given a git URL before | `push`, or the run that cloned the URL |
| None | | The config step says `skip config: none chosen`; the tools, Claude Code, the login and the session are set up all the same |

A git URL is cloned into the machine's copy, and later runs bring that clone up to date, also without `RIG_CONFIG`. The machine needs access to the repo for that.

`push` sends your config folder over the SSH connection it already has: it packs the config's parts into one file, checks the pack for secrets, and copies it to `~/.config/claude-rig/config.tar` on the machine. The run there takes it in as the machine's copy and removes the file. So the machine needs no access to your repo, and a private repo stays private.

## What is captured

`mise run capture` copies this machine's `~/.claude` into your config folder: `settings.json`, `CLAUDE.md`, and `skills/`, `agents/`, `commands/` and `hooks/` when they exist. It replaces only those parts of the folder. It leaves out:

- **`skills/synced/`**, which your Claude account fills in on each machine.
- **Settings that only make sense on the Mac**: `permissions.additionalDirectories` and `sandbox.network.allowUnixSockets`.
- **Settings in `env` named like a secret** (`TOKEN`, `KEY`, `SECRET`, `PASSWORD`, `CREDENTIAL`).
- **`~/.claude.json`**, which holds your login. Never.

It stops, and leaves the folder as it was, if anything token-shaped (a GitHub, Anthropic, AWS or Slack token, or a private key) or a path under your home folder is still in the copy. `push` runs the same check on what it is about to send.

## How it is applied on a machine

| What | How |
|---|---|
| A backup | The first run copies everything it could change to `~/.claude.rig-backup-<date>`, once |
| `settings.json` | Merged: the config's keys are set, keys only the machine has are kept, lists keep both |
| Skills, agents, commands, hooks | Each entry added or replaced as a whole; entries only the machine has are left alone. A record in `~/.claude/.rig-manifest` lets an entry removed from the config be removed from the machine too |
| `CLAUDE.md` | Replaced, if it differs |

With no config, none of this happens: `~/.claude` is not touched.

## No secrets stored

Nothing secret is in this repo, in a config folder that went through `capture`, in what `push` sends, or in a VM image made from a rigged machine. The one secret a machine needs, its login, is made on the machine when you approve it.

## Limits

- **`capture` takes every skill in `~/.claude/skills/`** except `synced/`. A skill you keep on the Mac only must be taken out of the config folder by hand after each capture.
- **A git URL needs access on the machine.** For a private repo, `push` from your Mac is the way that needs none.
