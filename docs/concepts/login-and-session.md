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
| macOS, Linux | pitchfork runs `tasks/session.nu`, restarts it if it stops, and starts it at boot (`pitchfork boot enable`: launchd on macOS, systemd on Linux) |
| Windows | pitchfork cannot start at boot there. A file in the user's Startup folder starts `tasks/session.nu --keep-alive` at sign-in with no window, and the session restarts the server itself. Started over SSH, it goes through the Task Scheduler, because a program started from an SSH connection is stopped when the connection closes |

Two first-run questions are answered for you, because a service has no terminal: "Enable Remote Control?" (yes: rigging the machine is that decision), and approval of the work folder. The rig made that folder, and records the approval in `~/.claude.json`, the only thing it ever writes there.

## Limits

- **A Windows PC with nobody signed in stays offline** until someone signs in.
- **Every machine gets your Mac's permission settings,** so a machine may act without asking if your Mac does. Right for a VM or a dedicated worker; think before rigging a shared PC.
