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

Each row comes from the machine's own `doctor` report, asked over SSH: OS, tools installed, logged in, session running, who is using it (`claims`: `free`, or who and since when), and the rig's commit. A machine that cannot be reached says so in the `note` column.

```sh
mise run fleet -- add user@host            # a machine rigged by hand (add --windows for Windows)
mise run fleet -- forget user@host         # off the list; nothing on the machine changes
```

## Give a machine work

```sh
mise run fleet -- run user@host "run the tests in a clone of github.com/me/app and tell me what fails"
mise run fleet -- run --all "which version of node do you have?"
```

Claude runs the work on that machine, with that machine's settings, and the answer comes back here. `--all` gives every machine the same work at the same time. The machine must be logged in.

Each piece of work is a job. Before Claude starts, the machine takes a claim for it, and Claude runs in the job's own folder, `~/work/jobs/<claim id>`, so two jobs never edit the same files. Work that must happen in a shared repository should clone it into its job folder, or push a branch, rather than edit a checkout in `~/work` that another job may be using. Why it works this way: [Claims](../concepts/claims.md).

```sh
mise run fleet -- run user@host --caller ci-agent --label "app tests" "run the tests..."   # say who you are and what the job is
```

## When a machine is busy

A machine takes one job at a time unless it is given more slots. Work sent to a busy machine fails at once, with exit code 6, saying who holds it:

```text
--- (this machine): BUSY in 0.0s
busy: apples-MacBook-Pro is held by caller-one (job "Reply with the single word: pong", claim 20261003-104539-377984) since 10:45:39, until 10:47:39. Add --wait to wait for it.
```

```sh
mise run fleet -- run --wait user@host "..."         # wait for a free slot, then run
mise run fleet -- claims user@host                   # who holds it, for which job, until when
mise run fleet -- release user@host <claim id>       # let go of your own claim
mise run fleet -- release user@host <claim id> --force   # someone else's; their job keeps running
mise run fleet -- slots user@host 2                  # let it take two jobs at once
```

With `--all`, a busy machine is reported as busy and not waited for. A claim whose caller stopped (a dropped connection, a crash) expires within two minutes, and the next job clears it.

## Let Claude do it

The [plugin](plugin.md) brings the skill `claude-rig-fleet`, so Claude knows these commands, and the commands `/rig:fleet` and `/rig:work`. Ask a Claude session on your Mac, in the app or a terminal, something like "run the test suite on the Windows and Linux machines and tell me what differs", and it splits the job, gives each machine its piece with `fleet run`, and checks the answers before it reports.

## Limits

- **One piece of work per machine per call.** Splitting a job into pieces and choosing machines for them is not built ([Backlog](../plans/backlog.md)).
- **Only machines your Mac can reach.** The table is built by asking each machine over SSH.
- **A machine must run the rig at a commit with claims** (`tasks/claims.nu`). One rigged earlier fails `fleet run`; push to it again. Its `claims` column shows `?`.
- **Not tested:** an answer coming back from a machine other than the Mac, and Windows: both wait on a second machine being logged in. Claims over SSH are not tested either; on the Mac and in CI they are.
