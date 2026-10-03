---
title: Settings
nav_order: 2
parent: Reference
---

# Settings: environment variables the rig reads

| Variable | Default | What it changes |
|---|---|---|
| `RIG_REF` | `main` | The branch the bootstraps fetch |
| `RIG_REPO` | this repo on GitHub | The repo the bootstraps clone |
| `RIG_DIR` | `~/.claude-rig` | Where the bootstraps keep the clone |
| `RIG_WORKDIR` | `~/work` | The work folder |
| `RIG_NAME` | the host name | The name the machine shows under in the Claude app |
| `RIG_CONFIG` | unset | Your Claude config for this run: a folder, or a git URL cloned into `~/.config/claude-rig/config/`. Wins over the folder in `config.toml`. Unset or empty: as described in [Your config](../concepts/config.md#where-a-run-finds-it) |
| `RIG_CONFIG_HOME` | `~/.config/claude-rig` | Where `config.toml`, the machine's copy of the config and the file `push` sends are kept (the tests use it) |
| `CLAUDE_HOME` | `~/.claude` | The Claude config folder the tasks read and write |
| `RIG_MACHINES` | `~/.config/claude-rig/machines.json` | The machine list `push` and `fleet` use |
| `RIG_CALLER` | `user@host` | On the machine giving work: the name `fleet run` and `fleet release` give as the caller, when `--caller` is not given ([Claims](../concepts/claims.md)) |
| `RIG_SLOTS` | the slots file, else `1` | On a machine taking work: how many jobs it runs at once. The slots file is `slots` in `RIG_CONFIG_HOME`, holding one number, written by `mise run fleet -- slots <machine> <n>`. The file is what work sent over SSH sees |
| `RIG_CLAIMS` | `~/.local/state/claude-rig/claims` | Where a machine keeps its claims (the tests use it) |
| `RIG_ASSUME_LOGGED_IN` | unset | `1` skips the login step and runs the session step anyway. For CI only |
| `FLEET_API_ACCESS_CLIENT_ID`, `FLEET_API_ACCESS_CLIENT_SECRET` | unset | The machine's own fleet-api token (a Cloudflare Access service token), both or neither. A run keeps them in `~/.config/claude-rig/fleet-api-access.json`; `report` posts and lists with them, before the file. Unset and no file: reporting is skipped ([Reporting](../concepts/reporting.md#the-machines-token)) |
| `FLEET_API_DIR` | `~/workspace/go/src/github.com/joeblew999/fleet-api` | On the Mac you push from: fleet-api's checkout, whose `access:token` task `push` runs to make a machine's token. Missing: `push` stops, unless `--no-report` |
| `FLEET_API_URL` | the SDK's own: `https://fleet-api.gedw99.workers.dev` | Where reports go (the tests point it at a closed port) |
| `FLEET_API_SDK` | where mise installed `github:joeblew999/fleet-api` | The folder of fleet-api's TypeScript SDK that `report` runs; set it to try a local build |

mise's own `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` are respected for where the tool list and the shims go.
