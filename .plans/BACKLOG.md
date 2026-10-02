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
| Always-on session on Windows, started at sign-in | CI on Windows x64 and ARM64, and the Windows 11 VM in UTM over SSH: the sign-in entry, the restart loop, the session surviving the SSH connection closing, a second run changing nothing. The server connecting is not tested until that VM is logged in |
| `push`: rig a remote machine over SSH from the Mac | Ubuntu containers over SSH, and the Windows 11 ARM64 VM in UTM set up like the office PC (OpenSSH Server, key in `administrators_authorized_keys`, cmd as the shell): dry run, real run from nothing, second run with no changes. CI also pushes from a Windows runner to its own SSH server (x64 and ARM64), with cmd and with PowerShell as the SSH shell. Not tested: a macOS remote, a machine whose sudo asks for a password, a Windows account that is not an administrator, a user name with a space in it |
| One-line bootstrap on a real Linux machine with systemd | A fresh Ubuntu 24.04 VM in OrbStack. It stops at the login step, as designed |
| `doctor`: a short report on the machine, and `--json` for a control plane | This Mac, and CI on all five runners |
| `unrig`: take a machine out of the fleet | This Mac and the Windows 11 VM: unrig, unrig again (nothing to do), rig again (session back) |
| AGENTS.md and this backlog | |

## Next

| Item | Notes |
|---|---|
| Rig the office Windows PC | It has an old Claude install and winget packages to look at first. Blocked on turning on OpenSSH Server there and its user name and address |
| First real Windows login and session | Everything on Windows is tested only on CI runners, which cannot log in. The office PC is the first real test: the login prompt, the work folder approval, and the session showing up in the Claude app |
| Finish the two test VMs | The Linux VM (OrbStack) and the Windows VM (UTM) are rigged and waiting at the login prompt. With the owner's two codes: test the session on each, then reboot each |
| Reboot test on each OS | Confirms the session comes back by itself |
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
| Recover when the UTM app is closed or hung | `vm-create` cloned fine, then failed to boot with `AppleEvent timed out (-1712)` because UTM had been closed down and was not answering. Quitting and reopening UTM fixed it. The tool should notice and restart UTM itself, since no VM is running at that point |
| Formalise SSH into a VM | The rig's tests needed SSH in the guest. It was turned on by hand: a small program run through `app-create` that installs OpenSSH Server, opens the firewall and adds a key. That should be a command (or part of the golden image) so any agent can do it |
| A command that runs a shell command in the guest and returns the output | `utmctl exec` returns neither output nor exit code. `app-create` does, but only for an `.exe` |
| Linux VMs | The owner wants Linux in UTM too, done properly. Today the tool is Windows only; the rig's Linux test machine is an OrbStack VM |
| Run the rig before sealing the golden image | Plan step 6: every clone then starts as a rigged machine, and only needs its login |
| Releases | The owner wants releases pushed for both repos, when the lead judges them ready |

## Later

| Item | Notes |
|---|---|
| Control plane: see every machine in one place | The owner's Cloudflare Worker in irgo-windows-vm is the place. Its ledger could take a check-in today only as a hack, and a plan there (`.plans/2026-10-01_1520_device-schema.md`) already proposes a devices API that is waiting on four owner decisions. `doctor --json` is the check-in a machine would send; post it to that API once it exists. Before then, a `fleet` task could run `doctor --json` on every machine over SSH and show one table. The Claude app already shows which machines are connected |
| Sort out the overlap with the UTM repo | The owner wants no loose ends: decide what lives where, shared naming, and whether the repos merge. Starts after this ships. First seam: irgo-winvm runs the bootstrap before it takes the golden image (plan step 6) |
| Look at nur as the task runner | The owner pointed at https://github.com/nur-taskrunner/nur, a task runner where the tasks are nushell. Today mise runs the tasks and needs to be there anyway for the tools, so the question is whether nur adds enough |
| Windows session with nobody signed in | The session starts at sign-in. A PC that reboots unattended needs auto sign-in or a service, which needs administrator rights |
| Keep the Windows session log small | `~/.claude-rig-session.log` is started fresh on each start but grows while the server runs |
| Stricter nushell checks | CI runs `nu-check`. It missed one error that only showed at run time, so add a linter or tests that run each task |
| A dedicated user for the session | The plan asks for it where the OS allows |
| Product basics | Licence, versioned releases, a changelog |
