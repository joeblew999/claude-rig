---
title: Login and the session
nav_order: 2
parent: Concepts
---

# Login and the session: how a machine gets into the Claude app

## The login

A machine shows up in the Claude app only when Claude on it is logged in to your account with a claude.ai login. So each machine logs in once: Claude prints a link, you approve it on any device, and paste the code back. The approval is yours to give; the rig never gives it for you.

There is no way to do this from one stored secret:

- **A long-lived token from `claude setup-token` cannot do it.** Claude's documentation says such a token can only make model requests, not establish Remote Control sessions.
- **Copying your Mac's login to other machines is not documented,** and those logins refresh themselves, so copies can log each other out, the Mac included.

With no terminal to ask on (for example a push from a script), the login step says `skip` and how to finish.

## The session

The session is `claude remote-control`, a server that keeps the machine connected to the Claude app and starts a Claude session there for each piece of work. It runs in the work folder (`~/work`) under the machine's name.

| OS | What keeps it running |
|---|---|
| macOS, Linux | pitchfork runs `tasks/session.nu`, restarts it if it stops, and starts it at boot (`pitchfork boot enable`: launchd on macOS, systemd on Linux). When pitchfork stops it, pitchfork's `on_stop` hook sends its last report |
| Windows | pitchfork cannot start at boot there. A file in the user's Startup folder starts `tasks/session.nu --keep-alive` at sign-in with no window, and the session restarts the server itself. Started over SSH, it goes through the Task Scheduler, because a program started from an SSH connection is stopped when the connection closes |

While it runs, the session also keeps the machine awake (below) and reports to fleet-api ([Reporting](reporting.md)).

Two first-run questions are answered for you, because a service has no terminal: "Enable Remote Control?" (yes: rigging the machine is that decision), and approval of the work folder. The rig made that folder, and records the approval in `~/.claude.json`, the only thing it ever writes there.

## Staying awake

A machine that sleeps drops out of the Claude app and stops its VMs. So the session holds sleep off for exactly as long as it runs; when it stops, the hold goes with it. The code is `tasks/awake.nu`.

| OS | What holds sleep off | What it does not do |
|---|---|---|
| macOS | `caffeinate -i -s` in front of the server: idle sleep and system sleep | Only on mains power (`-s`); closing the lid still sleeps the Mac |
| Linux | `systemd-inhibit --what=idle:sleep --mode=block` in front of the server, when the machine can sleep and logind allows it for this user. A machine that cannot sleep (no state in `/sys/power/state`, or `sleep.target` masked, as on many servers) gets nothing, and the session says so | logind can refuse it to a process outside a login session (polkit's default for sleep inhibitors); then the session says so and runs without it. Closing the lid is not held |
| Windows | A PowerShell process beside the server calls `SetThreadExecutionState(ES_CONTINUOUS \| ES_SYSTEM_REQUIRED)` and waits until the session ends | Turning the display off is not held. It needs no administrator rights, which is why it is used: `powercfg /requestsoverride` needs them, and changing the power plan would outlast the session and change the PC for whoever uses it |

The session's first lines say what it holds (`session: caffeinate holds off ...`), and each report says it in its `keeper` and `sleep` sections ([Reporting](reporting.md#what-a-machine-reports)).

## Limits

- **A Windows PC with nobody signed in stays offline** until someone signs in.
- **Every machine gets your Mac's permission settings,** so a machine may act without asking if your Mac does. Right for a VM or a dedicated worker; think before rigging a shared PC.
