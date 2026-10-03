---
title: See and steer the fleet
nav_order: 4
parent: Guides
---

# See and steer the fleet

From your Mac, in a checkout of this repo.

## See every machine

```sh
mise run fleet                 # one table: this Mac and every machine rigged from here
mise run fleet -- --json       # the same, as JSON
```

Each row comes from the machine's own `doctor` report, asked over SSH: OS, tools installed, logged in, session running, and the rig's commit. A machine that cannot be reached says so in the `note` column.

```sh
mise run fleet -- add user@host            # a machine rigged by hand (add --windows for Windows)
mise run fleet -- forget user@host         # off the list; nothing on the machine changes
```

## Give a machine work

```sh
mise run fleet -- run user@host "run the tests in ~/work/app and tell me what fails"
mise run fleet -- run --all "which version of node do you have?"
```

Claude runs the work on that machine, in its work folder, with that machine's settings, and the answer comes back here. `--all` gives every machine the same work at the same time. The machine must be logged in.

## Let Claude do it

Every rigged machine has the skill `claude-rig-fleet` (in `claude/skills/`), so Claude knows these commands. The [plugin](plugin.md) brings the same skill, and the commands `/rig:fleet` and `/rig:work`. Ask a Claude session on your Mac, in the app or a terminal, something like "run the test suite on the Windows and Linux machines and tell me what differs", and it splits the job, gives each machine its piece with `fleet run`, and checks the answers before it reports.

## Limits

- **One piece of work per machine per call.** Splitting a job into pieces and choosing machines for them is not built ([Backlog](../plans/backlog.md)).
- **Only machines your Mac can reach.** The table is built by asking each machine over SSH.
- **Not tested:** an answer coming back from a machine other than the Mac, and Windows: both wait on a second machine being logged in.
