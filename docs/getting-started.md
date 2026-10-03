---
title: Getting started
nav_order: 2
---

# Getting started: from a bare machine to one in the Claude app

One tutorial for a Mac or a Linux machine. You end with the machine in the Claude app, ready for work from your phone. For Windows: [Rig a Windows PC](guides/windows.md). To do it from your Mac to another machine: [Rig a machine over SSH](guides/push.md).

Using Claude Code? The easy start is the plugin: two commands install it, and `/rig:setup` does the steps below for you, asking first ([Use it from Claude Code](guides/plugin.md)).

You need a terminal on the machine, internet access, and a Claude subscription (Pro, Max, Team or Enterprise). On Linux, an account that can use `sudo`.

## 1. Look first

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh -s -- --dry-run
```

Every line says `ok` (already right), `would` (a real run changes this) or `skip` (not this time, and why). Nothing is changed, not even a clone is left behind.

## 2. Rig it

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
```

It installs git and mise if missing, the tools and Claude Code, then asks you to log in. It sets up no Claude config: the config step says `skip`. To bring your own, a folder or a git repo laid out like `~/.claude`, name it in `RIG_CONFIG`:

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | RIG_CONFIG=https://github.com/you/claude-config.git sh
```

How to make one, and where a run looks for it: [Your config](concepts/config.md).

## 3. Log in, once

Claude prints a link. Open it on any device (your phone is fine), approve, and paste the code it shows back into the terminal. Each machine needs this once; why there is no shortcut: [Login and the session](concepts/login-and-session.md).

## 4. Check it

```sh
cd ~/.claude-rig && mise run doctor
```

The report says `logged_in true` and `session_running true`. Open the Claude app: the machine is there under its name.

## 5. Run it again

```sh
curl -fsSL https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.sh | sh
```

Every line says `ok`. That is the rig's promise: running it again only fixes what is missing ([A run](concepts/a-run.md)).

## Next

- Keep your config in one folder and send it to every machine: [Change the config everywhere](guides/capture.md).
- Rig more machines from your Mac: [Rig a machine over SSH](guides/push.md), or make one: [Make a VM worker](guides/vm.md).
- See them all and give them work: [See and steer the fleet](guides/fleet.md).
