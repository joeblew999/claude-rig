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
| `push` | `<user@host>`, `--dry-run`, `--ref`, `--port`, `--identity`, `--known-hosts` | Sends your config folder and rigs another machine over SSH ([guide](../guides/push.md)) |
| `fleet` | `--json`; `add <user@host> [--windows --port --identity]`; `forget <user@host>`; `run <machine> "<work>"` or `run --all "<work>"` | Every rigged machine in one table, and giving them work ([guide](../guides/fleet.md)) |
| `vm` | `new <linux\|windows> <name> [--ref]`, `rm <name>` | Makes a UTM VM on this Mac, turns SSH on and rigs it; or deletes it ([guide](../guides/vm.md)) |
| `unrig` | `--dry-run` | Stops the session and removes what starts it ([guide](../guides/unrig.md)) |
| `config` | `init <folder>` | Where this machine's config comes from. `init` makes `<folder>` the config folder, and captures `~/.claude` into it if it holds no config yet ([guide](../guides/capture.md)) |
| `capture` | | Copies this machine's `~/.claude` into your config folder ([guide](../guides/capture.md)) |
| `apply` | `--dry-run` | The config step of a run on its own ([Your config](../concepts/config.md)) |
| `test` | | The tests, against throwaway folders |
| `plugin:check` | | Claude Code's validator on the marketplace file and the plugin ([Plugin commands](plugin.md)); needs `claude` |
| `lint` | | shellcheck on `bootstrap.sh`, and nushell's checker on every task and test |
| `docs:setup` | | Writes the docs site's config, `docs/writing.md` and `docs/llms.txt` |
| `docs:lint`, `docs:check` | | Checks `docs/`; `docs:check` also fails if the generated files are stale |
| `docs:review` | | Has Claude bring `docs/` into line with `docs/writing.md` |
| `docs:pages` | | REMOTE, once: turns on GitHub Pages for `docs/` |

The one-line bootstraps take `--dry-run` (`bootstrap.sh`) and `-DryRun` (`bootstrap.ps1`), and read `RIG_CONFIG` ([Settings](settings.md)).
