---
title: Reporting
nav_order: 4
parent: Concepts
---

# Reporting: what a machine tells fleet-api, and when

Every rigged machine with its own fleet-api token tells fleet-api, the fleet's control plane ([fleet-api](https://github.com/joeblew999/fleet-api), deployed at `https://fleet-api.gedw99.workers.dev` behind Cloudflare Access), what it is and how it is doing. The owner then sees the whole fleet from one place, a phone included. Read this to know what leaves a machine, when, and with which token.

```sh
mise run report                 # post this machine's report now
mise run report -- --print      # show the report, post nothing
mise run report -- --check      # check the report against fleet-api's schema, post nothing
mise run report -- --list       # the fleet as fleet-api has it, read with this machine's token
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
- **The machine's token.** It is only in the two Access headers (`CF-Access-Client-Id`, `CF-Access-Client-Secret`).
- **Claude's login.** No access or refresh token, and not the email or organisation `claude auth status` shows.

The machine's name is sent as `host.name`. It is the name the machine has in the Claude app: the host name, or `RIG_NAME` ([Settings](../reference/settings.md)). If the host name contains your name, set `RIG_NAME`.

## How it is sent

`tasks/report.nu` builds the report; `tasks/fleet-api.ts` sends it, and holds no code of its own against fleet-api: it runs fleet-api's generated TypeScript SDK with bun, made as fleet-api's own live test makes it. The SDK sends only one of the two Access headers by itself ([fern-api/fern#17775](https://github.com/fern-api/fern/issues/17775)), so it is given both as headers, with its own auth off. The SDK comes from fleet-api's release, installed by mise from the tool list (`github:joeblew999/fleet-api`, pinned in `mise/claude-rig.toml`). Before posting, the SDK checks the report against fleet-api's schema (types, enums, required fields); fleet-api checks the rest and answers 422. `--check` runs that check alone.

This is the one program that reports for a machine. The VM keeper on a Mac does not post: it writes its list for this report to carry, so a machine is one device in fleet-api, with one id.

## The machine id

16 random hex digits, made the first time the machine reports and kept in `~/.config/claude-rig/device-id`. It is made from nothing about the machine, so it says nothing about it. A VM image must be sealed without that file, or every VM made from it reports as the same machine.

## The machine's token

Each machine has its own fleet-api token: a Cloudflare Access service token, made for that machine by fleet-api's `access:token` task, which ties it to the machine id. fleet-api takes a report from it only for that id (another id is 403), and lets it read the fleet. How fleet-api checks it: fleet-api's [Auth and authz](https://github.com/joeblew999/fleet-api/blob/main/docs/concepts/auth.md).

It is kept in `~/.config/claude-rig/fleet-api-access.json`, `{"client_id": ..., "client_secret": ...}`, readable by its user alone (mode 600; on Windows, an access list with only that user). `FLEET_API_ACCESS_CLIENT_ID` and `FLEET_API_ACCESS_CLIENT_SECRET`, both set, win over the file.

| How a machine gets it | What happens |
|---|---|
| `push`, from the owner's Mac | After the rig has run there, `push` asks the machine for its id (made then if it has none), runs fleet-api's `access:token` task, `create <name> <id> <file>`, in fleet-api's checkout (`FLEET_API_DIR`), and sends the file over the same SSH connection, on stdin, never on a command line. The secret is on the Mac only in a temporary folder, removed once sent, and never printed. Then the machine reports once, so the token is tried at once ([guide](../guides/push.md)) |
| The one-line bootstrap | The run keeps `FLEET_API_ACCESS_CLIENT_ID` and `FLEET_API_ACCESS_CLIENT_SECRET` from its environment in the file (its step "Reporting"). The token is made beforehand with fleet-api's task, for the machine's id |
| Neither | Reporting is `skipped`, and says why. Everything else works |

`<name>` is the machine's name (`RIG_NAME`, else the host name) in lower case, with anything but letters, digits and dashes made a dash: fleet-api calls the token `fleet-api-<name>`.

| When `push` runs again | What it does |
|---|---|
| The machine has a token file | Keeps it: no token is made |
| `--new-token`, or no token file there, and fleet-api has a token of that name for the same machine id | Rotates it: fleet-api shows a secret only once, so the old token is revoked (`access:token -- revoke`) and a new one made and sent |
| fleet-api has a token of that name for another machine id | Stops, and says to give one of the machines another name with `RIG_NAME`. The other machine's token is left alone |

A machine loses its token when the owner revokes it, from the owner's Mac, with fleet-api's task. Access refuses it from then on. `unrig` on the machine does not revoke it: a machine has no Cloudflare credentials, and should not. It prints the command, with the machine's name ([guide](../guides/unrig.md)). A token lasts a year.

```sh
mise -C ~/workspace/go/src/github.com/joeblew999/fleet-api run access:token -- revoke <name>   # the machine's token stops working
mise -C ~/workspace/go/src/github.com/joeblew999/fleet-api run access:token -- list            # every machine's token: name, machine id, expiry; no secret
```

The token is never in this repo, the captured config, or a VM image. A run removes `~/.config/claude-rig/fleet-api.token` when it is there: fleet-api's shared write token, which Access refuses.

## A report that cannot be delivered

Each report is written to the spool, `~/.config/claude-rig/report-spool/`, then the spool is sent oldest first. A report fleet-api took (or already had: the same id and time is a duplicate) leaves the spool. One the SDK or fleet-api refused as invalid is dropped, with the reason in the session's log. One that could not be delivered (no network, fleet-api down, the token refused or not given yet, the SDK or bun not installed yet) stays and goes with the next. The spool keeps at most 288 reports, a day of them.

## Limits

- **Windows reads no power, battery, lid or sleep state yet,** and sends no `stop`.
- **Linux reads no idle sleep time,** so its `sleep` is `unknown` unless the machine cannot sleep at all.
- **Every report runs `doctor`:** about 1 s on the owner's Mac.
- **Tested on the owner's Mac and CI runners only;** see [Findings](../findings.md).
