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
| `RIG_ASSUME_LOGGED_IN` | unset | `1` skips the login step and runs the session step anyway. For CI only |

mise's own `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` are respected for where the tool list and the shims go.
