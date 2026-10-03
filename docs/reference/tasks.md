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
| `push` | `<user@host>`, `--dry-run`, `--ref`, `--port`, `--identity`, `--known-hosts`, `--new-token`, `--no-report` | Sends your config folder, rigs another machine over SSH, and gives it its own fleet-api token, made with fleet-api's `access:token` task. `--new-token` rotates the token; `--no-report` makes none ([guide](../guides/push.md)) |
| `fleet` | `--json`; `add <user@host> [--windows --port --identity]`; `forget <user@host>`; `run <machine> "<work>"` or `run --all "<work>"`, with `--wait --caller --label --json`; `claims <machine> [--json]`; `release <machine> <claim id> [--force --caller]`; `slots <machine> [<n>]` | Every rigged machine in one table, giving them work, and who is using them. `run` exits 6 when a machine is busy ([guide](../guides/fleet.md), [Claims](../concepts/claims.md)) |
| `report` | `--print`, `--check`, `--doctor <file>`, `--reason <reason>`; `--list [--json]`; `--whoami` | Posts this machine's report to fleet-api now, through fleet-api's generated SDK. `--print` shows it and posts nothing; `--check` checks it against fleet-api's schema and posts nothing; `--doctor` takes doctor's facts from a file of `doctor --json` output; `--list` prints the fleet as fleet-api has it; `--whoami` prints the machine id (made if missing), its token's name and whether it has one, for `push` ([Reporting](../concepts/reporting.md)) |
| `vm` | `new <linux\|windows> <name> [--ref]`, `rm <name>` | Makes a UTM VM on this Mac, turns SSH on and rigs it; or deletes it ([guide](../guides/vm.md)) |
| `unrig` | `--dry-run` | Stops the session and removes what starts it, and prints the fleet-api command that revokes the machine's token ([guide](../guides/unrig.md)) |
| `config` | `init <folder>` | Where this machine's config comes from. `init` makes `<folder>` the config folder, and captures `~/.claude` into it if it holds no config yet ([guide](../guides/capture.md)) |
| `capture` | | Copies this machine's `~/.claude` into your config folder ([guide](../guides/capture.md)) |
| `apply` | `--dry-run` | The config step of a run on its own ([Your config](../concepts/config.md)) |
| `test` | | The tests, against throwaway folders: the config merge, capture, where the config comes from, the claims, and the report |
| `plugin:check` | | Claude Code's validator on the marketplace file and the plugin ([Plugin commands](plugin.md)); needs `claude` |
| `lint` | | shellcheck on `bootstrap.sh`, and nushell's checker on every task and test |
| `secrets:scan` | | `fnox scan` on every file git would commit; fails on anything that looks like a secret ([Secrets](../concepts/secrets.md)) |
| `github:setup`, `github:check` | | Writes the issue forms and `.github/labels.tsv` from charter, keeping this repo's bug form and extra labels; `github:check` fails if they differ |
| `release` | `vX.Y.Z`, `--dry-run` | Checks the working tree is clean, HEAD is `main` on GitHub, the tag is new and CI passed on HEAD; then tags and pushes the tag. `--dry-run`: the checks and what it would do ([Cut a release](../contributing.md#cut-a-release)) |
| `release:publish` | `[vX.Y.Z]` | The GitHub Release for the tag the workflow runs on: notes from the commits since the previous tag, a link to Findings, pre-release while `README.md` says so. Not on a tag: prints the notes, publishes nothing |
| `ci:bootstrap` | `[<first run's output>]` | After the bootstrap's first run, with no config: that run skipped the config; claude and every tool is on PATH; a run with `tests/fixtures/config` applies it; `doctor --json` reports the tools, the config, Claude's version and no login; a second run changes nothing; dry runs against an empty throwaway home, with mise hidden (not on Windows) and with it, make nothing there (on Windows nushell keeps the user's profile folder as its home, so the dry run sees the throwaway through `CLAUDE_HOME`, `RIG_CONFIG_HOME`, `RIG_WORKDIR` and `MISE_CONFIG_DIR`). Defaults to `first-run.log`. CI, or a throwaway `HOME` ([How CI runs](../contributing.md#how-ci-runs)) |
| `ci:windows-session` | | Windows: a run with `RIG_ASSUME_LOGGED_IN=1` writes the sign-in entry, the session and its keep-awake come up within a minute, and a second run changes nothing |
| `ci:sshd` | | CI only, Windows: installs and starts OpenSSH Server with cmd.exe as its shell, and authorizes a throwaway key for an administrator (`tasks/ci/sshd.ps1`) |
| `ci:push` | | CI only, Windows, after `ci:sshd`: the key logs in and the shell is cmd.exe; `push` to this machine over localhost as a dry run (makes nothing), a first run that makes the machine's fleet-api token with a stand-in for fleet-api's `access:token` task (a made-up token, for the machine id made first, kept readable by this user only, not printed; Claude Code and the config in place), a second run (changes nothing, keeps the token), and a dry run with PowerShell as the SSH shell. Rigs `RIG_TEST_REF`, default the current branch |
| `ci:plugin` | | `plugin:check`, installing Claude Code first if it is missing in CI |
| `docs:setup` | | Writes the docs site's config, `docs/writing.md` and `docs/llms.txt` |
| `docs:lint`, `docs:check` | | Checks `docs/`; `docs:check` also fails if the generated files are stale |
| `docs:review` | | Has Claude bring `docs/` into line with `docs/writing.md` |
| `docs:pages` | | REMOTE, once: turns on GitHub Pages for `docs/` |

The one-line bootstraps take `--dry-run` (`bootstrap.sh`) and `-DryRun` (`bootstrap.ps1`), and read `RIG_CONFIG` ([Settings](settings.md)).
