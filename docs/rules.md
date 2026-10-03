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
| **One source of truth.** Every fact has one owner and every interface one definition. Anything that talks to fleet-api goes through what charter generates from fleet-api's contract, never a hand-written copy (who owns what is in the table below) | A copy drifts; the owner wants a product, not an MVP |
| **Public repo, no secrets.** Nothing personal or secret is committed; `capture` enforces it for a config, `mise run secrets:scan` for the repo, and secrets follow [Secrets](concepts/secrets.md) | Anyone can read this repo |
| **Never destroy local state.** Back up before the first change, merge rather than overwrite, never copy or overwrite `~/.claude.json` | The machine is someone's |
| **Say where it was tested.** CI runners, a container, a UTM VM, the Mac and a real PC are different things: name the one used. Results go in [Findings](findings.md) | A reader acts on it |
| **A test must be able to fail.** When adding one, break the code once and see it fail | A test that cannot fail proves nothing |
| **Every ask from the owner becomes a GitHub issue** (label `plan`) in the repo that owns it, when it is said; the order of all the work is one pinned issue, [charter#44](https://github.com/joeblew999/charter/issues/44). Plans are never docs pages | Nothing is dropped because the conversation moved on |
| **One item, one branch, one pull request,** merged only with CI green. The docs change in the same pull request | `main` always works |
| **Helpers work in their own worktree** under `../claude-rig.worktrees/<name>`, open a pull request, and never merge. They don't edit `docs/README.md` or `docs/rules.md`, and don't file or close plan issues; the lead does, after reading the diff | A report is a claim, not a result |

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

## Who owns what

| What | The one source | Everyone else |
|---|---|---|
| What a report and every fleet-api route is | fleet-api's contract | uses what charter generates from it: the specs, the Go and TypeScript SDKs, the CLI |
| Talking to fleet-api | charter's generated client | never hand-writes HTTP or JSON for the API |
| A machine's host facts, rig facts and claims | claude-rig, the one thing on every machine | one report and one device id per machine |
| A Mac's VMs | the UTM keeper | hands them to claude-rig's report through a local file; does not post itself |
| What a repo depends on | the repo's own pin files | read, never re-declared |
| Tasks, docs, repo upkeep, releases, auth | charter, pinned by release | a repo keeps only what is its own |

