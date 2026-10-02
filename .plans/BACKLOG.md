# Backlog

Every ask from the owner, and every loose end found while building. The rules for this file are in [AGENTS.md](../AGENTS.md).

Status: `done`, `doing`, `next`, `later`, `needs owner`.

## Done

| Item | Where it was tested |
|---|---|
| Capture the Mac's Claude config into `claude/` | This Mac |
| Bootstrap for macOS and Linux, one line with `curl` | CI on fresh macOS and Ubuntu (x64, ARM64); Ubuntu and Debian containers; this Mac |
| Bootstrap for Windows, using winget for git and mise | CI on fresh Windows Server x64 and Windows 11 ARM64, and a fresh Windows 11 ARM64 VM in UTM (a clone of the irgo-winvm golden image) |
| Tasks in nushell, one implementation for every OS | CI on all five runners |
| `--dry-run` that changes nothing, even on a bare machine | CI on all five runners |
| Login step: `claude auth login` with a claude.ai account | This Mac (already logged in). The login prompt itself has not been run on a new machine |
| Always-on session under pitchfork, back after a reboot | This Mac: starts, shows in the Claude app, the rig restarts it when stopped. Not rebooted. Linux is the same code, not yet run on a real Linux machine with a login |
| Always-on session on Windows, started at sign-in | CI on Windows x64 and ARM64, and the Windows 11 VM in UTM over SSH: the sign-in entry, the restart loop, the session surviving the SSH connection closing, a second run changing nothing, and a reboot (the VM signed in by itself and the session loop came back). The server connecting is not tested until that VM is logged in |
| `push`: rig a remote machine over SSH from the Mac | Ubuntu containers over SSH, and the Windows 11 ARM64 VM in UTM set up like the office PC (OpenSSH Server, key in `administrators_authorized_keys`, cmd as the shell): dry run, real run from nothing, second run with no changes. CI also pushes from a Windows runner to its own SSH server (x64 and ARM64), with cmd and with PowerShell as the SSH shell. Not tested: a macOS remote, a machine whose sudo asks for a password, a Windows account that is not an administrator, a user name with a space in it |
| One-line bootstrap on a real Linux machine with systemd | A fresh Ubuntu 24.04 VM in OrbStack. It stops at the login step, as designed |
| `doctor`: a short report on the machine, and `--json` for a control plane | This Mac, and CI on all five runners |
| `unrig`: take a machine out of the fleet | This Mac and the Windows 11 VM: unrig, unrig again (nothing to do), rig again (session back) |
| `fleet`: every rigged machine in one table | This Mac, the Windows 11 VM and the Ubuntu VM, side by side. `push` adds a machine to the list; the list stays on the Mac, outside the repo |
| First release: `v0.1.0`, a pre-release | Tagged on the commit where every CI job on main passed, including the ARM64 push test |
| Tests (`mise run test`) | This Mac and CI on all five runners. The config merge: a fresh machine, a machine with its own config, a changed skill, a dropped skill, broken settings. Capture: secret-named settings and Mac-only keys dropped, synced skills left out, and a GitHub token, an Anthropic key, a private key or a path under the home folder each stop it with what was captured before untouched. Checked once for each that breaking the code fails the tests |
| Licence: MIT, the same as the UTM repo | The lead chose it after asking twice; the owner can change it |
| AGENTS.md and this backlog | |

## Next

| Item | Notes |
|---|---|
| Rig the office Windows PC | It has an old Claude install and winget packages to look at first. Blocked on turning on OpenSSH Server there and its user name and address |
| First real Windows login and session | Everything on Windows is tested only on CI runners, which cannot log in. The office PC is the first real test: the login prompt, the work folder approval, and the session showing up in the Claude app |
| Finish the two test VMs | The Linux VM (OrbStack) and the Windows VM (UTM) are rigged and waiting at the login prompt. With the owner's two codes: test the session on each, then reboot each |
| Reboot test on macOS and Linux | Windows is done (see above). The Mac has not been rebooted, and the Linux VM has no session until it is logged in |
| Scale work out across the fleet | The owner asked whether Claude, given work, will spread it over the machines. Not by itself: one session runs on one machine, and nothing found says Claude splits a task across them. The first version is built: `mise run fleet -- run <machine> "<work>"` has Claude run the work on that machine, in its work folder, and brings the answer back; `--all` gives every machine the same work at once. Tested: this Mac answered in 4.9 s; the Linux VM was reached and said "Not logged in", as expected. Not tested: an answer coming back from another machine, and Windows. Still to build: a lead Claude splitting one job into pieces and choosing machines for them |
| Make enrolling a machine as easy as possible | Today: one line on the machine, or `push` from the Mac, plus one login (open a link, paste a code). See "needs owner" for removing the login |

## Needs owner

| Item | Recommendation |
|---|---|
| Log every machine in from one captured secret | Remote Control needs a full claude.ai login. A `claude setup-token` token cannot do it (Claude's docs say so). Copying the Mac's own login to other machines is not documented, and those logins refresh themselves, so one copy may log out the others, including the Mac. Recommended: each machine logs in once, about 30 seconds. If you want the copy tried, it should be on a spare machine, accepting that the Mac may need to log in again |
| What a machine may do without asking | The Mac's settings (`bypassPermissions`) are applied to every machine. That is right for a VM or a dedicated worker. Say if some machines should be stricter |
| Should this Mac stay an always-on worker | It is one now, as the test. To turn it off: `mise run unrig` in the repo |

## The UTM repo (irgo-windows-vm)

The owner has put this repo in the lead's hands too, and wants the two to fit together with no loose ends. Found while using it to test the rig:

| Item | Notes |
|---|---|
| Recover when the UTM app is closed or hung | A fallback is merged there: when UTM does not answer a start, the tool restarts UTM once and retries, only when every VM is stopped. The cause was then measured (2 Oct 2026): a request that reaches UTM while it is launching makes every later VM start hang (3 of 3), and waiting 0.3 s or more before the first request avoids it (16 of 16). Opening UTM takes about 1 s and checking whether it runs 0.014 s. A helper is building the real fix: check first, open UTM if it is closed, wait without talking to it, then ask |
| Formalise SSH into a VM | Done, merged there: `irgo-winvm vm-ssh-create -vm <name>` turns on OpenSSH Server, opens the firewall to the local subnet, adds a public key and prints the `ssh` line; `vm-ssh-delete` undoes it. Run live on a fresh clone: 9 min 46 s the first time (Windows installing the capability), 16 s on a repeat, key login worked, the undo closed the port |
| Seal the golden image with OpenSSH Server installed | The ten minutes above is Windows installing the capability. Sealed into the golden image, every clone would have SSH in seconds |
| Release the UTM repo | Done: `v0.6.0`, with the two changes above |
| A command that runs a shell command in the guest and returns the output | `utmctl exec` returns neither output nor exit code. `app-create` does, but only for an `.exe` |
| Linux VMs | The plan is merged there (`.plans/2026-10-02_1950_linux-vms.md`): an Ubuntu 24.04 ARM64 cloud image with cloud-init, behind one guest description so nothing is implemented twice. No R2 cache is needed for Linux: Ubuntu publishes the 591 MB image itself. Phase 1 is a draft pull request there: `vm-create -os linux` took 1 min 42 s with the download, `vm-ssh-create` 2.7 s, and the rig's `push` rigged the VM with a second run changing nothing. Two late changes are unit-tested only and need a live run before it merges. Then the rig's Linux test machine moves from OrbStack to UTM |
| The UTM tool's name | With Linux in it, "irgo-windows-vm" no longer fits. Needs the owner: keep it, rename the binary, rename the repo, or decide it together with how the two repos fit |
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
