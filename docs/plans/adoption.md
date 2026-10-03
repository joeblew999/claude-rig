---
title: Adoption
nav_order: 3
parent: Plans
grand_parent: This repository
---

# Adoption: anyone can rig their machines

The goal: someone who is not the owner finds claude-rig and has their own machines in the Claude app within minutes, with their own config, without forking.

## What stands in the way today

| Problem | Why it blocks |
|---|---|
| **The repo ships the owner's config.** `claude/` is the owner's settings and skills, including `bypassPermissions` | Anyone running the rig gets the owner's Claude setup |
| **No front door in Claude.** Everything starts from a terminal and `mise run` | A Claude user expects to install something in Claude and ask it |
| **The docs read as one person's setup** ("your Mac", "the office PC") | The rig works on any machine reachable over SSH: a VPS, a cloud server, a Raspberry Pi |

## The work, as independent pieces

| # | Piece | Where | Depends on |
|---|---|---|---|
| 1 | **Bring your own config.** The product ships no one's config. A user's config lives in their own repo (or a folder): `capture` writes to it, every run reads from it. The owner's config moves to a repo of the owner's. The rig without a config still installs the tools, Claude Code, login and session | claude-rig: `tasks/capture.nu`, `tasks/apply.nu`, `tasks/rig.nu`, bootstraps, `push`, docs | nothing |
| 2 | **A Claude Code plugin, and this repo as its marketplace.** The plugin holds the Claude-facing side: the fleet skill, and commands to rig a machine, show the fleet and give work. The commands call the tasks; the machines still get the bootstraps | claude-rig: new plugin files | nothing (the commands call tasks that 1 may change; agree the task names first) |
| 3 | **The UTM repo's docs in charter's layout,** with its intent on the home page | irgo-windows-vm | nothing |
| 4 | **Docs for any machine over SSH:** lead with "a machine you can SSH into", with the Mac as one case; a guide for a cloud or rented Linux server | claude-rig: `docs/` | 1 (same pages) |
| 5 | **Fewer repos:** archive `vm-servers` (superseded by vm-uncloud); rename the VM tool; move the glaze suite into Irgo ([How the repos fit](how-the-repos-fit.md)) | several | the owner's yes |

## Done when

A new user, on a Mac with Claude Code: installs the plugin, makes their config repo with one command, and rigs a Linux server and a VM with one command each; both show in the Claude app after one login each. Written as [Getting started](../getting-started.md), and run as written on a clean account.
