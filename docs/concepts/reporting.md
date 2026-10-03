---
title: Reporting
nav_order: 4
parent: Concepts
---

# Reporting: what a machine tells fleet-api, and when

Every rigged machine with a write token tells fleet-api, the fleet's control plane ([fleet-api](https://github.com/joeblew999/fleet-api), deployed at `https://fleet-api.gedw99.workers.dev`), what it is and how it is doing. Anyone with the read token then sees the whole fleet from one place, a phone included. Read this to know what leaves a machine, when, and with which token.

```sh
mise run report                 # post this machine's report now
mise run report -- --print      # show the report, post nothing
mise run report -- --check      # check the report against fleet-api's schema, post nothing
mise run report -- --list       # the fleet as fleet-api has it (needs FLEET_API_READ_TOKEN)
```

## When a machine reports

The session ([Login and the session](login-and-session.md)) reports while it runs. A report that fails never stops it.

| Reason | When | `next_s` |
|---|---|---|
| `start` | 10 s after the session starts | 300 |
| `interval` | Every 5 minutes after that | 300 |
| `stop` | The server exits (sent by the session), or pitchfork stops the session (sent by pitchfork's `on_stop` hook, which runs `tasks/report.nu --reason stop`) | 0 |
| `once` | `mise run report`, by hand | 0 |

`next_s` is a promise: fleet-api marks a machine `quiet` when a promised report is more than three times late. `start` waits 10 s so that on a restart the hook's `stop` is the older report: fleet-api shows the newest. A Windows session is ended by stopping its process, so it sends no `stop`; fleet-api sees it go quiet instead.

## What a machine reports

One JSON object, fleet-api's `DeviceReport` (schema 1; every field's rule is in fleet-api's `api/device.go`). Built by `tasks/report.nu`, from `doctor --json`, what nushell reads without new tools, and the VM keeper's list.

| Section | From | Not read |
|---|---|---|
| `host` | The machine's name (as in the Claude app), OS, architecture, OS version, boot time; on macOS also the model and whether it is a VM, on Linux whether it is a VM | |
| `cpu`, `memory`, `disks` | `sys cpu`, `sys mem`, `sys disks`, in bytes. `disks` is the system volume and the volume the work folder is on, one entry when they are the same | |
| `power`, `battery`, `lid` | `pmset -g batt` and `ioreg` on macOS; `/sys/class/power_supply` and `/proc/acpi/button/lid` on Linux | Windows: `unknown`, with why |
| `sleep` | `pmset -g` and `pmset -g assertions` on macOS: idle and display sleep, and the processes holding sleep off. `none` on a Linux machine that cannot sleep | Linux and Windows otherwise: `unknown`, with why |
| `keeper` | Whether the session's keep-awake is running now, from the process list | |
| `rig` | `doctor --json`: rig commit, tools installed, Claude version, config applied, logged in, session running, work folder. Also `rig.login` (below) | |
| `claims` | `doctor --json`'s `slots` and `claims`, when it has them | |
| `vms` | `~/.config/claude-rig/vms.json`, which the VM tool's keeper (`irgo-winvm keeper`) writes every 15 s on a Mac with UTM: the VMs, their state, whose, kept running. Taken as written while under 2 minutes old; older, `unknown` with its age. No file: no `vms` section | Machines with no keeper |

A section that could not be read says `unknown` and why, never a zero that looks like a measurement.

### The login (`rig.login`)

For seeing a login run out before it does. It is part of fleet-api's contract (`rig.login`); fleet-api has no condition for it yet.

| Field | From |
|---|---|
| `status`, `why` | `ok` when `claude auth status` answered; `unknown` and why when it did not. The two `refresh_expires` fields are there either way |
| `logged_in`, `auth_method` | `claude auth status`: `loggedIn` and `authMethod` only |
| `refresh_expires` | When the refresh token expires, Unix milliseconds: `claudeAiOauth.refreshTokenExpiresAt` of Claude's stored login, `~/.claude/.credentials.json` on Linux and Windows, the keychain item `Claude Code-credentials` on macOS (the file wins when it is there) |
| `refresh_expires_why` | Instead of `refresh_expires`, when it cannot be read |

Only that one number is taken out of the stored login; the rest of it, the tokens, is never kept or printed.

## What is never sent

- **Nothing that names a person or a network.** No user names, IP or MAC addresses, serial numbers. A home folder is written `~` (`~/work`), whoever's it is. A claim held by `user@host` is sent as `a person on <host>`.
- **The write token.** It is only in the `Authorization` header.
- **Claude's login.** No access or refresh token, and not the email or organisation `claude auth status` shows.

The machine's name is sent as `host.name`. It is the name the machine has in the Claude app: the host name, or `RIG_NAME` ([Settings](../reference/settings.md)). If the host name contains your name, set `RIG_NAME`.

## How it is sent

`tasks/report.nu` builds the report; `tasks/fleet-api.ts` sends it, and holds no code of its own against fleet-api: it runs fleet-api's generated TypeScript SDK with bun. The SDK comes from fleet-api's release, installed by mise from the tool list (`github:joeblew999/fleet-api`, pinned in `mise/claude-rig.toml`). Before posting, the SDK checks the report against fleet-api's schema (types, enums, required fields); fleet-api checks the rest and answers 422. `--check` runs that check alone.

This is the one program that reports for a machine. The VM keeper on a Mac does not post: it writes its list for this report to carry, so a machine is one device in fleet-api, with one id.

## The machine id

16 random hex digits, made the first time the machine reports and kept in `~/.config/claude-rig/device-id`. It is made from nothing about the machine, so it says nothing about it. A VM image must be sealed without that file, or every VM made from it reports as the same machine.

## The write token

A machine posts with fleet-api's write token, kept in `~/.config/claude-rig/fleet-api.token`, readable by its user alone (mode 600; on Windows, an access list with only that user).

| How it gets there | What happens |
|---|---|
| `push` | Sends `FLEET_API_WRITE_TOKEN` from the machine running `push` over the same SSH connection as the config, on stdin, never on a command line ([guide](../guides/push.md)) |
| The one-line bootstrap | The run keeps `FLEET_API_WRITE_TOKEN` from its environment (its step "Reporting") |
| Neither | Reporting is `skipped`, and says why. Everything else works |

The token is never in this repo, the captured config, or a VM image. To read the fleet, `--list` takes `FLEET_API_READ_TOKEN`, or the write token, which also reads.

## A report that cannot be delivered

Each report is written to the spool, `~/.config/claude-rig/report-spool/`, then the spool is sent oldest first. A report fleet-api took (or already had: the same id and time is a duplicate) leaves the spool. One the SDK or fleet-api refused as invalid is dropped, with the reason in the session's log. One that could not be delivered (no network, fleet-api down, the token refused, the SDK or bun not installed yet) stays and goes with the next. The spool keeps at most 288 reports, a day of them.

## Limits

- **Windows reads no power, battery, lid or sleep state yet,** and sends no `stop`.
- **Linux reads no idle sleep time,** so its `sleep` is `unknown` unless the machine cannot sleep at all.
- **Every report runs `doctor`:** about 1 s on the owner's Mac.
- **Tested on the owner's Mac and CI runners only;** see [Findings](../findings.md).
