---
title: Claims
nav_order: 4
parent: Concepts
---

# Claims: who is using a machine, and why the machine itself decides

Read this to know why two jobs sent to one machine do not collide, and what a busy machine means. The commands are in [See and steer the fleet](../guides/fleet.md#when-a-machine-is-busy).

## What a claim is

A claim is a record, kept on a machine, that one caller is using one of its slots. It says:

| Field | What it holds |
|---|---|
| `id` | The claim's name: when it was taken and six random characters (`20261003-104539-377984`) |
| `who` | The caller: the name given when the work is sent, else `user@host` of the machine it came from ([Settings](../reference/settings.md)). A label, not a login: anyone can give any name |
| `what` | The job, in a few words: given when the work is sent, else the start of the work |
| `since`, `until` | When it was taken, and when it expires unless renewed |
| `job_dir` | The job's own folder, `~/work/jobs/<id>` |

A machine has a number of slots (one unless set otherwise, [Settings](../reference/settings.md)). Each job sent with `fleet run` takes a claim before Claude starts and lets it go when Claude ends. When every slot is held, the next job is refused with who holds the machine and until when, or waits for a slot if the caller asked to.

## Why the claim is kept on the machine

The machine is the one place every caller has to reach to give it work, so it is the one place that can answer "is this free?" for all of them at once. A claim kept there:

- **Is the authority.** There is no second copy to disagree with it.
- **Is instant and works offline.** Taking one is a few file operations on the machine; nothing else needs to be up.
- **Covers every caller,** whether the work came from your Mac, another Mac, or a session on the machine itself, as long as it goes through the rig's claims.

A shared record of claims across machines, so one place can show who used which machine and when, is planned ([Control plane](../plans/control-plane.md)). It will record what the machines decide; it will not decide anything.

## How two callers cannot both get the last slot

Every change to a machine's claims happens while holding one lock: a folder named `.lock` in the claims folder, made with the operating system's own `mkdir` (through `cmd` on Windows). Making a folder either succeeds or fails because it already exists, as one step, so only one caller holds the lock at a time. While holding it, a caller clears expired claims, counts the live ones, and writes its own claim only if a slot is free. The lock is held for a fraction of a second.

A lock older than 30 seconds was left by a caller that stopped while holding it, and the next caller removes it.

## Why claims expire

A caller can stop without letting go: its connection drops, its machine sleeps, the process is killed. So a claim lasts two minutes, and the job that holds it renews it every 30 seconds while Claude runs. A claim past its `until` belongs to nobody, and the next caller to take a slot clears it. A job that has crashed therefore holds a machine for at most two minutes.

## Why each job gets its own folder

Two jobs on one machine in the same folder would edit the same files. So each job runs in `~/work/jobs/<id>`, a folder of its own, and nothing is shared between jobs by default. Work that must happen in a shared repository clones it into the job folder, or pushes a branch, rather than editing a checkout another job may be using.

Job folders are kept when the job ends, so what a job left behind can be read afterwards. Nothing removes them yet.

## Limits

- **Only work sent with `fleet run` takes a claim.** A session started from the Claude app on the machine, or someone at its keyboard, does not, and is not counted.
- **Releasing someone else's claim does not stop their job.** Forcing a release frees the slot; the work keeps running.
- **Inside a UTM VM, claims are the VM's own.** The VM is a machine like any other; nothing yet ties its claims to the Mac that hosts it.
- **Tested on macOS only,** and in CI on Linux and Windows runners against the task directly. Over SSH to another machine, and on a Windows machine over SSH, it is not tested yet ([Findings](../findings.md)).
