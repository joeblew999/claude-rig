---
title: A run
nav_order: 1
parent: Concepts
---

# A run: what it does, and why it is safe to repeat

## The steps

| Step | What happens | Where |
|---|---|---|
| Base tools | git and mise, if missing: the Command Line Tools and the mise installer on macOS, the package manager and the mise installer on Linux, winget on Windows | `bootstrap.sh`, `bootstrap.ps1` |
| The rig | A clone in `~/.claude-rig`, brought up to date; then mise fetches the pinned nushell and runs `tasks/rig.nu` | the bootstraps |
| Tools | `mise/claude-rig.toml` copied to `~/.config/mise/conf.d/`, then `mise install`. The tools work in every folder; the machine's own mise config is left alone | `tasks/rig.nu` |
| Shell | `~/.local/bin` and the mise shims on PATH for new shells | `tasks/rig.nu` |
| Claude Code | Claude's native installer, if `claude` is missing. It updates itself after that | `tasks/rig.nu` |
| The rig link | `~/.claude-rig` made to lead to the rig, when the rig runs from a checkout elsewhere (a link; a junction on Windows). Skills and docs can then always say `~/.claude-rig`. A bootstrap never moves a linked checkout | `tasks/rig.nu` |
| Config | `claude/` merged into `~/.claude` ([Your config](config.md)) | `tasks/apply.nu` |
| Login | `claude auth login`, if not logged in ([Login and the session](login-and-session.md)) | `tasks/enroll.nu` |
| Session | The always-on session, started and kept running | `tasks/enroll.nu`, `tasks/session.nu` |

## Why it is safe to repeat

Every step checks first and changes something only if it is missing or wrong, and every change goes through one function (`change` in `tasks/lib.nu`). That gives three things:

- **A second run changes nothing.** CI fails if it does, on every platform.
- **A run that stopped halfway is fixed by running it again.**
- **`--dry-run` is exact.** The same checks run, and each change is printed as `would` instead of made.

## Why only the first step is per OS

The bootstraps only get git and mise onto the machine. Everything after is nushell, run by mise, the same code on macOS, Linux and Windows, so a change reaches all three at once and there is nothing to compile.
