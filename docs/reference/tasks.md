---
title: Tasks
nav_order: 1
parent: Reference
---

# Tasks

Run as `mise run <task>`; flags go after `--` (`mise run doctor -- --json`).

| Task | Flags | What it does |
|---|---|---|
| `rig` | `--dry-run` | The run, on this machine ([A run](../concepts/a-run.md)) |
| `doctor` | `--json` | A report on this machine, then what a run would change. `--json`: the report alone |
| `push` | `<user@host>`, `--dry-run`, `--ref`, `--port`, `--identity`, `--known-hosts` | Rigs another machine over SSH ([guide](../guides/push.md)) |
| `fleet` | `--json`; `add <user@host> [--windows --port --identity]`; `forget <user@host>`; `run <machine> "<work>"` or `run --all "<work>"`, with `--wait --caller --label --json`; `claims <machine> [--json]`; `release <machine> <claim id> [--force --caller]`; `slots <machine> [<n>]` | Every rigged machine in one table, giving them work, and who is using them. `run` exits 6 when a machine is busy ([guide](../guides/fleet.md), [Claims](../concepts/claims.md)) |
| `vm` | `new <linux\|windows> <name> [--ref]`, `rm <name>` | Makes a UTM VM on this Mac, turns SSH on and rigs it; or deletes it ([guide](../guides/vm.md)) |
| `unrig` | `--dry-run` | Stops the session and removes what starts it ([guide](../guides/unrig.md)) |
| `capture` | | Copies your Mac's `~/.claude` into `claude/` ([guide](../guides/capture.md)) |
| `apply` | `--dry-run` | The config step of a run on its own |
| `test` | | The tests, against throwaway folders |
| `lint` | | shellcheck on `bootstrap.sh`, and nushell's checker on every task and test |
| `docs:setup` | | Writes the docs site's config, `docs/writing.md` and `docs/llms.txt` |
| `docs:lint`, `docs:check` | | Checks `docs/`; `docs:check` also fails if the generated files are stale |
| `docs:review` | | Has Claude bring `docs/` into line with `docs/writing.md` |
| `docs:pages` | | REMOTE, once: turns on GitHub Pages for `docs/` |

The one-line bootstraps take `--dry-run` (`bootstrap.sh`) and `-DryRun` (`bootstrap.ps1`).
