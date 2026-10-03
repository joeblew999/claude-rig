---
title: Backlog
nav_order: 1
parent: Plans
grand_parent: This repository
---

# Backlog: every open ask and loose end

Every ask from the owner goes here when it is said, with its status. What is done leaves this page: its result goes to [Findings](../findings.md) and its description to the page of the part.

## The order

Decided 3 Oct 2026, after the owner: "Each repo that uses the charter system needs to fully use it. Dev time, run time." charter is fixed first; each repo then moves onto a charter release and deletes its local copies; only then new features. charter's other session owns #20, #21, #30 and #32–#36 (done: tasks by include, go/auth with scopes, `charter new -empty`, `charter repo`); the lead owns the rest below.

| Step | What | Where | Why here |
|---|---|---|---|
| 1 | Local release in minutes, for repos with and without binaries ([charter#39](https://github.com/joeblew999/charter/issues/39)) | charter | every repo releases through charter, from the developer's machine |
| 2 | The generated CLI built for every OS in a release ([charter#37](https://github.com/joeblew999/charter/issues/37)) | charter | machines talk to a charter API through a released client, not a script |
| 3 | Access service tokens and an OIDC issuer on top of go/auth (new issue; fleet-api's verifier moves in) | charter | run-time auth for every charter project, one implementation |
| 4 | fleet-api fully on charter: its tasks by include, the release binary, `charter repo`, go/auth with step 3, release by step 1 | fleet-api | the control plane is the first full adopter |
| 5 | claude-rig fully on charter: `charter repo`, release by step 1, fleet-api's CLI from step 2 in place of the bun script, fleet-api's tasks by include | claude-rig | its own release script, workflows and client go |
| 6 | The UTM repo fully on charter, renamed `utm-vm`: `charter repo`, release by step 1, its R2 keys in fnox; the keeper runs the released binary | irgo-windows-vm | one copy of the VM tool on the Mac |
| 7 | The remaining single-source-of-truth debts below (machine list, fleet skill, pins, scanners) | all | nothing left twice |
| 8 | Discovery and release propagation ([charter#38](https://github.com/joeblew999/charter/issues/38)) | charter, then every repo | a release reaches its consumers |
| 9 | Logins without people: the 17:07 measurement decides copying a login or the inbox; then the inbox or copy, through fleet-api | fleet-api, claude-rig | enrolment needs no human |
| 10 | The Windows golden image with SSH, pushed to R2 | utm-vm | VMs in seconds |
| 11 | fleet-api as the message bus; `fleet run` and the login inbox through it | fleet-api, claude-rig | no inbound SSH |
| 12 | Repos in the control plane, Renovate centrally, Claude workers for breaking changes | fleet-api | builds on step 8 |
| 13 | An identity service for end users: Better Auth as a charter project | new repo | charter apps' users log in |
| 14 | Docs for any machine over SSH; the office PC; another Mac | claude-rig | adoption |

## Next

| Item | Notes |
|---|---|
| Rig the office Windows PC | It has an old Claude install and winget packages to look at first. Blocked on turning on OpenSSH Server there and its user name and address |
| First real Windows login and session | Everything on Windows is tested only on CI runners, which cannot log in. The office PC is the first real test: the login prompt, the work folder approval, and the session showing up in the Claude app |
| Finish the two test VMs | The Linux VM and the Windows VM (both in UTM now) are rigged and waiting at the login prompt. With the owner's two codes: test the session on each, then reboot each |
| Reboot test on macOS and Linux | Windows is done (see above). The Mac has not been rebooted, and the Linux VM has no session until it is logged in |
| Scale work out across the fleet | The owner asked whether Claude, given work, will spread it over the machines. Not by itself: one session runs on one machine, and nothing found says Claude splits a task across them. The first version is built: `mise run fleet -- run <machine> "<work>"` has Claude run the work on that machine, in its work folder, and brings the answer back; `--all` gives every machine the same work at once. Tested: this Mac answered in 4.9 s; the Linux VM was reached and said "Not logged in", as expected. Not tested: an answer coming back from another machine, and Windows. The skill `claude-rig-fleet` now teaches any Claude session to split a job and hand the pieces out; it needs logged-in machines to be tested beyond the Mac |
| Adoption by other users | The owner asked (3 Oct 2026) whether to make it a Claude plugin, said the rig should cover any Linux server over SSH and the docs be less office-centric, and asked whether repos should be consolidated or deleted. Plan: [Adoption](adoption.md). Pieces 1 to 3 started |
| Make enrolling a machine as easy as possible | Today: one line on the machine, `push` from the Mac, or `mise run vm -- new linux <name>` for a UTM VM, plus one login (open a link, paste a code). See "needs owner" for removing the login. `vm new windows` is not run yet |

## Single-source-of-truth debts

Every place one fact or definition still lives twice ([rules](../rules.md): one source of truth). Listed 3 Oct 2026; each is fixed before new features.

| # | Two copies of | Fix |
|---|---|---|
| 1 | charter's tasks, copied into fleet-api's `mise.toml` | charter publishes its tasks for include ([charter#32](https://github.com/joeblew999/charter/issues/32)) |
| 2 | fleet-api's token task, reached by `push` through a local checkout | include fleet-api's tasks by git ref |
| 3 | claude-rig's tasks, which other repos cannot include | mise file tasks |
| 4 | the nushell pin: claude-rig's `mise.toml` and `mise/claude-rig.toml` | one pin |
| 5 | charter's version: 0.9.0 in claude-rig and the UTM repo, 0.9.1 for fleet-api | one version everywhere |
| 6 | the VM tool on the owner's Mac: v0.7.0 from mise, and a locally built keeper | release the UTM repo; the keeper runs the release |
| 7 | the machine list: `~/.config/claude-rig/machines.json` and fleet-api's devices | `fleet` reads fleet-api; `machines.json` goes |
| 8 | the fleet skill: the plugin, and a copy in the owner's `~/.claude/skills` | the plugin only |
| 9 | secret scanning: `capture`'s patterns and `fnox scan` | one scanner, chosen by measuring both |
| 10 | the release script: claude-rig's own and charter's | [charter#39](https://github.com/joeblew999/charter/issues/39) |
| 11 | workflows written by hand, and charter's generated ones | [charter#36](https://github.com/joeblew999/charter/issues/36) |
| 12 | the UTM repo's docs systems: charter's layout and its own docsite | docsite's features move into charter |
| 13 | the Fern TypeScript SDK's missing-header workaround, in fleet-api's test and in claude-rig | fixed upstream ([fern#17775](https://github.com/fern-api/fern/issues/17775)); until then one shared helper |
| 14 | pitchfork: several versions installed on the Mac | one pin, old installs removed |

## After fleet-api is wired up

| Item | Notes |
|---|---|
| Import a repo's tasks instead of copying them | The owner's trick (3 Oct 2026): a project takes another repo's mise tasks with `[task_config] includes = ["git::https://github.com/<owner>/<repo>.git//<folder>?ref=<tag>"]`, pinned to a release, as `remy-auth-app` does with remy-auth's tasks. So upgrading every user is a ref bump |
| charter publishes its tasks for include | `charter new` copies the example's tasks into each project (fleet-api has its own full mise file). Better: charter publishes its task folder at each release and projects include it by tag. How charter publishes and versions that folder is charter's design: raise it with the session that works in charter, don't edit under it |
| claude-rig's tasks includable by any project | Today tasks are `mise.toml` entries running `nu tasks/<x>.nu` relative to the project, which breaks when included. They become mise file tasks (scripts with a mise header in the included folder), so a project can include `push`, `fleet` and `vm` by tag with no checkout |
| fleet-api includes charter's tasks | Once charter publishes them |
| Discovery and release propagation across repos | The owner (3 Oct 2026): repos consume each other's APIs, SDKs, binaries and tasks, "like NATS but more strongly typed", and a release affects its consumers. Decided: pins stay where they are (each consumer's `mise.toml`, `go.mod`, `package.json`); producers carry the GitHub topic `charter`; a generated catalog lists producers and the consumers found from their pins; a producer's release diffs its spec and calls a breaking change a major, naming the affected consumers; Renovate (as a GitHub Action) opens a PR in each consumer, whose `mise run check` proves it. Filed for charter as [charter#38](https://github.com/joeblew999/charter/issues/38); the Renovate setup can start in claude-rig, fleet-api and the UTM repo before charter has it |

## Needs owner

| Item | Recommendation |
|---|---|
| Log every machine in from one captured secret | Now decided by the lead: [Login](login.md). The owner wants it fully automatic for every developer |
| What a machine may do without asking | The Mac's settings (`bypassPermissions`) are applied to every machine. That is right for a VM or a dedicated worker. Say if some machines should be stricter |
| Should this Mac stay an always-on worker | It is one now, as the test. To turn it off: `mise run unrig` in the repo |

## The UTM repo (irgo-windows-vm)

The owner has put this repo in the lead's hands too, and wants the two to fit together with no loose ends. Found while using it to test the rig:

| Item | Notes |
|---|---|
| Recover when the UTM app is closed or hung | Done, merged there. The cause, measured on 2 Oct 2026: a request from outside UTM's own app (AppleScript, or `utmctl` through Homebrew's link) that launches UTM, or reaches it in its first 0.3 s, leaves UTM unable to start VMs until it is quit and reopened. The tool now checks whether UTM is running before every request, opens it if not, and waits 2 s before asking. Run live from UTM closed: the old binary hung 2 of 2, the new one 0 of 2. Opening UTM takes about 1 s; the check 0.014 s. The older restart-and-retry stays as a fallback and has not been run live |
| Formalise SSH into a VM | Done, merged there: `irgo-winvm vm-ssh-create -vm <name>` turns on OpenSSH Server, opens the firewall to the local subnet, adds a public key and prints the `ssh` line; `vm-ssh-delete` undoes it. Run live on a fresh clone: 9 min 46 s the first time (Windows installing the capability), 16 s on a repeat, key login worked, the undo closed the port |
| Seal the golden image with OpenSSH Server installed | The ten minutes above is Windows installing the capability. Sealed into the golden image, every clone would have SSH in seconds |
| Release the UTM repo | Done: `v0.6.0`, with the two changes above |
| A command that runs a shell command in the guest and returns the output | `utmctl exec` returns neither output nor exit code. `app-create` does, but only for an `.exe` |
| Linux VMs | Phase 1 is merged there: `irgo-winvm vm-create -os linux -vm <name> -install` makes an Ubuntu 24.04 ARM64 VM from Ubuntu's own cloud image in about a minute, and `vm-ssh-create` turns SSH on in 3 s. No R2 cache is needed for Linux. The rig's Linux test machine is now that: the UTM VM `claude-rig-linux`, rigged with `push` (dry run, real run, second run with no changes). The OrbStack VM is deleted. Later phases there: a Linux golden image and clones, running a Linux program in the guest, sealing OpenSSH into the Windows golden image |
| How the repos fit together, and the UTM tool's name | A proposal is written: [2026-10-03-01-how-the-repos-fit.md](how-the-repos-fit.md). Recommended: two products split by layer (provision, rig, control plane), the VM tool renamed, the glaze suite moved into Irgo. Needs the owner to pick |
| Run the rig before sealing the golden image | Plan step 6: every clone then starts as a rigged machine, and only needs its login |
| Releases | The owner wants releases pushed for both repos, when the lead judges them ready |

## Later

| Item | Notes |
|---|---|
| Control plane: see every machine in one place | The owner's Cloudflare Worker in irgo-windows-vm is the place. Its ledger could take a check-in today only as a hack, and a plan there (`.plans/2026-10-01_1520_device-schema.md`) already proposes a devices API that is waiting on four owner decisions. `doctor --json` is the check-in a machine would send; post it to that API once it exists. Until then, `mise run fleet` on the Mac is the control plane: it asks each machine over SSH. It only sees machines the Mac can reach. The Claude app already shows which machines are connected |
| Sort out the overlap with the UTM repo | The owner wants no loose ends: decide what lives where, shared naming, and whether the repos merge. Starts after this ships. First seam: irgo-winvm runs the bootstrap before it takes the golden image (plan step 6) |
| nur as the task runner | Looked at on 2 Oct 2026: active (released 28 Sep 2026, built on the same nushell 0.116 the rig pins), tasks are nushell functions in one `nurfile`. Verdict: not now. mise has to be on every machine anyway to install the tools, and it already runs the nushell tasks, so nur would be a second runner to install and keep in step on three OSes. Worth another look if the tasks grow shared arguments and sub-commands that mise handles badly |
| Windows session with nobody signed in | The session starts at sign-in. A PC that reboots unattended needs auto sign-in or a service, which needs administrator rights |
| Keep the Windows session log small | `~/.claude-rig-session.log` is started fresh on each start but grows while the server runs |
| Tests for the other tasks | `apply` and `capture` have tests. `doctor`, `fleet` and the session steps are covered only by the CI runs and by hand |
| A dedicated user for the session | The plan asks for it where the OS allows |
| Product basics | A changelog. Releases have started (`v0.1.0`) |
