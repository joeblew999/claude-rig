# 2026-10-03-01-how-the-repos-fit.md

How claude-rig and the owner's other machine projects fit together, and what to decide so there are no loose ends. A proposal: nothing here is built until the owner picks.

## What exists

| Repo | What it does | Language | State |
|---|---|---|---|
| **claude-rig** | Turns any existing machine (Mac, Linux, Windows; physical or VM) into a Claude worker, and lists and steers the fleet over SSH | nushell, two native bootstraps | active, v0.2.0 |
| **irgo-windows-vm** | Makes VMs on a Mac with UTM: Windows 11 (unattended install, golden image, clones in seconds) and now Ubuntu; SSH into them; runs a program in them. Also Irgo's glaze conformance suite, and a Cloudflare Worker (ledger, remote job queue, golden-image links) | Go, GoReleaser | active, v0.7.0 |
| **vm-uncloud** | Makes machines in the cloud (Hetzner, with Cloudflare DNS) and runs apps on them with Uncloud | nushell | active |
| **irgo** | The Go + Datastar app framework. irgo-windows-vm's README says the VM tool "moves into Irgo" once dependable | Go | active |
| **utm-dev** | Tauri builds in UTM VMs | TypeScript | archived |

## Where they overlap

Four jobs, each done in more than one place:

1. **Making a machine.** Local VMs: irgo-windows-vm (and utm-dev before it). Cloud machines: vm-uncloud.
2. **Getting into it.** irgo-windows-vm has `vm-ssh-create`; claude-rig's `push` needs exactly that; vm-uncloud has its own `connect`.
3. **Knowing what is out there.** claude-rig keeps a machine list on the Mac (`fleet`); irgo-windows-vm's Worker keeps a ledger per machine; an unmerged plan there (`.plans/2026-10-01_1520_device-schema.md`, waiting on owner decisions) designs a device report; vm-uncloud keeps its own state.
4. **Steering it from one place.** claude-rig's `fleet run` over SSH; the Worker's job queue (built for Windows test binaries only).

And one thing that belongs elsewhere: the glaze conformance suite in irgo-windows-vm is Irgo's, not the VM tool's.

## The principle

Split by layer, not by repo history. Each layer has one home:

| Layer | Question it answers | Home |
|---|---|---|
| **Provision** | where does a machine come from? | the VM tool (UTM on a Mac), later the same commands for the cloud (vm-uncloud) |
| **Rig** | what runs on it? | claude-rig |
| **Control plane** | what is out there, and is it healthy? | one Worker with the device API |
| **App testing** | does my app work on Windows? | Irgo |

Each layer calls the one below through a small, stable seam: claude-rig asks the VM tool for a machine and an `ssh` line; a machine reports `doctor --json` to the device API; Irgo asks the VM tool to run a binary.

## Options

**A. Two products with a clean seam (recommended).** Keep claude-rig and the VM tool as separate repos. Give the VM tool a name that is no longer Windows-only. Move the glaze conformance suite into Irgo, as its README already plans. The Worker becomes the fleet's control plane by finishing the device-schema plan; claude-rig's `doctor --json` is the report a machine sends.
- For: each repo keeps its language, release process and rules (the VM tool is a Mac-only Go binary with strict conventions; the rig is scripts for every OS). Irgo can use the VM tool without anything Claude. Least churn.
- Against: two repos to release, and the seam has to be kept stable.

**B. One product: claude-rig absorbs the VM tool.** "Make a machine and make it a Claude worker" in one repo.
- For: one name, one release, one backlog.
- Against: mixes a Go binary with GoReleaser and Homebrew cask into a scripts repo; Irgo would depend on a Claude product to test desktop apps; the biggest move of the three.

**C. One product: the VM tool absorbs claude-rig.**
- For: the larger, more mature codebase becomes the home.
- Against: the rig runs on machines that are not VMs (the office PC, any Linux box); it would live under a VM tool's name and Mac-only conventions.

## Decisions for the owner

1. **A, B or C.** Recommended: A.
2. **The VM tool's name.** It makes Windows and Linux VMs now. Keep `irgo-windows-vm` / `irgo-winvm`, or rename. Renaming the GitHub repo keeps redirects for old links; the Homebrew tap and the install URL would change. If A, a short neutral name for "VMs on a Mac" fits; the owner's naming, not the lead's.
3. **Cloud machines under the same commands?** Later, vm-uncloud could be the cloud backend of the provision layer (same `create`, `ssh`, `delete` verbs). Recommended: yes, but not now.
4. **The device API.** The device-schema plan in irgo-windows-vm is waiting on four owner decisions. Recommended: answer those next, since the control plane for both products depends on it.

## What happens after a pick (option A)

1. The VM tool: rename (if chosen) and release; update the install URL and the tap.
2. Move the glaze conformance suite and its docs into Irgo; the VM tool keeps only what any caller needs.
3. claude-rig: a `machine` command that asks the VM tool for a test VM and enrols it in one step (`create`, `ssh on`, `push`), replacing the manual steps used in testing.
4. The device API: once its schema is agreed, `doctor` posts its report to it, and `fleet` reads from it instead of only asking over SSH.
5. Archive what is replaced; utm-dev already is.
