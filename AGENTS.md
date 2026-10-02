# For agents

claude-rig is a product: it turns any Mac, Linux or Windows machine into a Claude worker the owner controls from the Claude app. One agent (the lead) owns it end to end. This file is how the work is run.

Read [the plan](.plans/2026-10-02-01-claude-rig.md) for the design and [the backlog](.plans/BACKLOG.md) for what is done and what is next.

## The backlog is the memory

- Everything the owner asks for or suggests goes into [.plans/BACKLOG.md](.plans/BACKLOG.md) when it is said, in the owner's words, with a status. Nothing is dropped because the conversation moved on.
- An item is `done` only when it is merged and the backlog says where it was tested. If a platform was not tested, the item says so.
- A decision that is the owner's to make (money, accounts, what a machine may do unattended) is written down as `needs owner` with a recommendation, and the work carries on around it.

## How work lands

1. One backlog item, one branch, one pull request.
2. CI must be green before a merge. CI runs the bootstrap on fresh macOS, Linux (x64 and ARM64) and Windows (x64 and ARM64) machines, and fails if a second run changes anything. It also pushes a rig over SSH to a Windows runner. That job's ARM64 leg takes about 20 minutes, so it runs only on main.
3. The lead merges its own pull requests. It does not wait for the owner unless the item is `needs owner`.
4. The plan, the README and the backlog are updated in the same pull request as the change they describe.

## Scaling up with agents

The lead decides when to bring in helpers. Use them when items do not touch the same files, or when a question needs reading across another repository. Do the work directly when it is a few edits in files already open.

- Each helper works in its own git worktree under `../claude-rig.worktrees/<name>`, on its own branch, and opens a pull request. Helpers do not merge.
- Helpers do not edit the shared files: `README.md`, `AGENTS.md`, `.plans/`. They report what should change there, and the lead edits them.
- A helper's brief states the goal, the files to read, how to test, and what "done" means. A helper's report states what was actually run and what was not.
- The lead reads every helper's diff before merging. A report is a claim, not a result.

## Rules for the code

- **Safe to repeat.** Every step checks first and acts only if something is missing or wrong. A second run changes nothing. Every change goes through `change` in `tasks/lib.nu`, so `--dry-run` works everywhere.
- **Public repo, no secrets.** Nothing personal or secret is committed. `capture` stops if it finds a token or a path under the Mac's home folder.
- **Two native scripts, then nushell.** `bootstrap.sh` and `bootstrap.ps1` only install git and mise and start the rig. Everything else is nushell in `tasks/`, the same code on every OS. Do not add a second implementation for one OS.
- **Services run under pitchfork.** Use the OS's own service manager only for what pitchfork cannot do, and say why.
- **Never destroy local state.** Back up before the first change, merge rather than overwrite, and never copy or overwrite `~/.claude.json`.
- **Nushell traps found so far.** Do not `glob` an absolute path (it fails on Windows backslashes): `cd` there and glob a relative pattern, or use `ls`. Do not put a regex with `(` inside an interpolated string. Use `str lowercase`, not `str downcase`.
- **Windows traps found so far.** A program started from an SSH connection is stopped when the connection closes: start anything long-lived through the Task Scheduler (see `start-on-desktop` in `tasks/enroll.nu`). To run PowerShell on a Windows machine over SSH, send the script on stdin to `powershell -Command -`; quoting it through cmd.exe goes wrong.
- **Say where it was tested.** Fresh CI runners, a Docker container, this Mac, a real Windows PC and a UTM VM are different things. Name the one that was used. Never write that something works on a platform it was not run on.
- **Plain English** in messages, comments and docs.

## Testing

```sh
mise run lint            # shellcheck and nushell's checker
mise run test            # the config merge, against throwaway Claude folders
mise run doctor          # what is set up here and what is missing; changes nothing
mise run rig             # the real run on this machine
```

A change to the bootstrap or a task is tested with a dry run, a real run and a second real run. The second run must print no `change` lines.

A test in `tests/` runs the real task against a temp folder and checks what it left behind. When adding one, break the code on purpose once and see the test fail: a test that cannot fail proves nothing.
