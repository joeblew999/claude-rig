---
title: Rules
nav_order: 1
parent: This repository
---

# Rules for working in this repo

Binding, for people and agents alike.

| Rule | Why |
|---|---|
| **`docs/` is the single source of truth.** `AGENTS.md`, `CLAUDE.md` and the root `README.md` only point to it. Pages follow [Writing docs](writing.md); run `mise run docs:check` | One place cannot contradict itself |
| **Safe to repeat.** Every step checks first and acts only if something is missing or wrong, through `change` in `tasks/lib.nu` | A second run must change nothing, and `--dry-run` must be exact |
| **Two native scripts, then nushell.** `bootstrap.sh` and `bootstrap.ps1` only get git and mise and start the run. Never a second implementation for one OS | A change reaches every OS at once |
| **Services run under pitchfork.** The OS's own service manager only where pitchfork cannot do it, with the reason written down | One way to run and inspect services |
| **Public repo, no secrets.** Nothing personal or secret is committed; `capture` enforces it for a config, `mise run secrets:scan` for the repo, and secrets follow [Secrets](concepts/secrets.md) | Anyone can read this repo |
| **Never destroy local state.** Back up before the first change, merge rather than overwrite, never copy or overwrite `~/.claude.json` | The machine is someone's |
| **Say where it was tested.** CI runners, a container, a UTM VM, the Mac and a real PC are different things: name the one used. Results go in [Findings](findings.md) | A reader acts on it |
| **A test must be able to fail.** When adding one, break the code once and see it fail | A test that cannot fail proves nothing |
| **Every ask from the owner goes into the [Backlog](plans/backlog.md)** when it is said, with a status | Nothing is dropped because the conversation moved on |
| **One item, one branch, one pull request,** merged only with CI green. The docs change in the same pull request | `main` always works |
| **Helpers work in their own worktree** under `../claude-rig.worktrees/<name>`, open a pull request, and never merge. They don't edit `docs/README.md`, `docs/rules.md` or `docs/plans/`; the lead does, after reading the diff | A report is a claim, not a result |

## Traps found so far

| Trap | What to do |
|---|---|
| nushell's `glob` on an absolute path fails on Windows backslashes | `cd` there and glob a relative pattern, or use `ls` |
| A regex with `(` inside a nushell interpolated string is read as code | Build the pattern with `+` |
| A helper named like a nushell built-in hides it (`skip` once broke `$list \| skip 1`) | Pick another name |
| `str downcase` is deprecated | `str lowercase` |
| A program started from an SSH connection on Windows is stopped when the connection closes | Start long-lived things through the Task Scheduler (`start-on-desktop` in `tasks/enroll.nu`) |
| Quoting a PowerShell script through cmd.exe over SSH goes wrong | Send the script on stdin to `powershell -Command -` |
| AppleScript, or Homebrew's `utmctl` link, launching UTM or reaching it in its first 0.3 s leaves it unable to start VMs | Open UTM, wait 2 s, use `/Applications/UTM.app/Contents/MacOS/utmctl` |
