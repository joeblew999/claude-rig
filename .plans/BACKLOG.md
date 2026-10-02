# Backlog

Every ask from the owner, and every loose end found while building. The rules for this file are in [AGENTS.md](../AGENTS.md).

Status: `done`, `doing`, `next`, `later`, `needs owner`.

## Done

| Item | Where it was tested |
|---|---|
| Capture the Mac's Claude config into `claude/` | This Mac |
| Bootstrap for macOS and Linux, one line with `curl` | CI on fresh macOS and Ubuntu (x64, ARM64); Ubuntu and Debian containers; this Mac |
| Bootstrap for Windows, using winget for git and mise | CI on fresh Windows Server x64 and Windows 11 ARM64. Not yet on a real desktop PC |
| Tasks in nushell, one implementation for every OS | CI on all five runners |
| `--dry-run` that changes nothing, even on a bare machine | CI on all five runners |
| Login step: `claude auth login` with a claude.ai account | This Mac (already logged in). The login prompt itself has not been run on a new machine |
| Always-on session under pitchfork, back after a reboot | This Mac: starts, shows in the Claude app, the rig restarts it when stopped. Not rebooted. Linux is the same code, not yet run on a real Linux machine with a login |
| Always-on session on Windows, started at sign-in | CI on Windows x64 and ARM64 checks the sign-in entry and the restart loop. The runner cannot log in, so the server connecting is not tested: that needs a real Windows machine |
| `push`: rig a remote machine over SSH from the Mac | Ubuntu containers over SSH: dry run, real run, second run. Not tested against Windows or macOS, or a machine whose sudo asks for a password |
| AGENTS.md and this backlog | |

## Next

| Item | Notes |
|---|---|
| Rig the office Windows PC | It has an old Claude install and winget packages to look at first. Blocked on turning on OpenSSH Server there and its user name and address |
| First real Windows login and session | Everything on Windows is tested only on CI runners, which cannot log in. The office PC is the first real test: the login prompt, the work folder approval, and the session showing up in the Claude app |
| `push` to a Windows machine | The command line for Windows is written but has never met a real Windows host. `push` also needs an SSH key on the machine; a password-only PC needs the key added first |
| Run the session on a real Linux machine | Needs a Linux machine or UTM VM with systemd, and one login |
| Reboot test on each OS | Confirms the session comes back by itself |
| Make enrolling a machine as easy as possible | Today: one line on the machine, or `push` from the Mac, plus one login (open a link, paste a code). See "needs owner" for removing the login |
| `doctor --json` | `mise run doctor` is the dry run today. JSON output is the shape a control plane will take in |

## Needs owner

| Item | Recommendation |
|---|---|
| Log every machine in from one captured secret | Remote Control needs a full claude.ai login. A `claude setup-token` token cannot do it (Claude's docs say so). Copying the Mac's own login to other machines is not documented, and those logins refresh themselves, so one copy may log out the others, including the Mac. Recommended: each machine logs in once, about 30 seconds. If you want the copy tried, it should be on a spare machine, accepting that the Mac may need to log in again |
| What a machine may do without asking | The Mac's settings (`bypassPermissions`) are applied to every machine. That is right for a VM or a dedicated worker. Say if some machines should be stricter |
| Should this Mac stay an always-on worker | It is one now, as the test. To turn it off: `pitchfork stop claude-rig`, then remove `[daemons.claude-rig]` from `~/.config/pitchfork/config.toml` |

## Later

| Item | Notes |
|---|---|
| Control plane: see every machine in one place | The owner's Cloudflare Worker in irgo-windows-vm is the place. Its ledger could take a check-in today only as a hack, and a plan there (`.plans/2026-10-01_1520_device-schema.md`) already proposes a devices API that is waiting on four owner decisions. So: `doctor --json` first, then post it to that API once it exists. The Claude app already shows which machines are connected |
| Sort out the overlap with the UTM repo | The owner wants no loose ends: decide what lives where, shared naming, and whether the repos merge. Starts after this ships. First seam: irgo-winvm runs the bootstrap before it takes the golden image (plan step 6) |
| Look at nur as the task runner | The owner pointed at https://github.com/nur-taskrunner/nur, a task runner where the tasks are nushell. Today mise runs the tasks and needs to be there anyway for the tools, so the question is whether nur adds enough |
| Windows session with nobody signed in | The session starts at sign-in. A PC that reboots unattended needs auto sign-in or a service, which needs administrator rights |
| Keep the Windows session log small | `~/.claude-rig-session.log` is started fresh on each start but grows while the server runs |
| Stricter nushell checks | CI runs `nu-check`. It missed one error that only showed at run time, so add a linter or tests that run each task |
| Remove a machine from the fleet | An `unrig` task: stop the session, take out the service, leave the tools |
| A dedicated user for the session | The plan asks for it where the OS allows |
| Product basics | Licence, versioned releases, a changelog |
