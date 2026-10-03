---
title: Control plane
nav_order: 4
parent: Plans
grand_parent: This repository
---

# Control plane: who is using which machine, seen from anywhere

Many agents and people will use the same machines, and inside the same VMs. Two layers answer "who is using what", the same two the VM tool already uses for its VMs:

| Layer | What it is | Where | Status |
|---|---|---|---|
| **Claims, on each machine** | The authority: a job takes a slot on a machine before it runs there, and lets go after. Instant, works offline | claude-rig (`fleet run`) | Being built |
| **The record, in one place** | Every machine reports what it is and who holds it; anyone reads the fleet from a phone | `fleet-api`, a new Worker | Next |

## Decided (owner, 3 Oct 2026: "you pick everything")

| Question | Decision | Why |
|---|---|---|
| What a machine reports | The device report already designed in the VM tool's plan (`.plans/2026-10-01_1520_device-schema.md` there: host, memory, disks, power, battery, sleep), plus a `rig` section (tools, Claude version, logged in, session, rig commit) and the machine's claims | One report per machine, for both tools |
| VM capacity | Stays a ledger event in the VM tool's Worker | It is about one Mac's VMs, not a device |
| Cost | Workers Paid | The Go Worker uses 40 to 70 ms of CPU a request, over the Free plan's 10 ms. The account already runs Go Workers made with charter |
| Where it lives | Its own repo and Worker, `fleet-api`, made with charter; both claude-rig and the VM tool use its generated client | The control plane is a layer of its own ([How the repos fit](how-the-repos-fit.md)), owned by neither tool |
| The VM tool's name | `utm-vm` (repo and binary), after its docs PR lands; the glaze suite moves to Irgo | It makes Windows and Linux VMs; its code already calls itself `utmvm` |
| `vm-servers` | Archived | Superseded by vm-uncloud |

## The token a machine needs

A machine needs a write token to report. It is passed in when the machine is rigged (`push` sends it over SSH; the one line takes it from the environment) and kept on that machine only, readable by its user alone. It is never in this repo, the captured config, or a VM image: a golden image is sealed without it.

## Phases

1. **`fleet-api`:** the repo from `charter new`, the report schema and its four routes (post a report, list devices, one device, its history), deployed, with the live test passing.
2. **claude-rig reports:** `doctor` posts its report; the session (or pitchfork) posts one every few minutes and a `stop` when it goes; `fleet` reads the list from `fleet-api`, falling back to SSH.
3. **The VM tool reports** its Mac through the same client.
4. **Claims in the record:** a claim taken or released is posted, so the phone shows who holds which machine.
