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
| `CLAUDE_HOME` | `~/.claude` | The Claude config folder the tasks read and write |
| `RIG_MACHINES` | `~/.config/claude-rig/machines.json` | The machine list `push` and `fleet` use |
| `RIG_CALLER` | `user@host` | On the machine giving work: the name `fleet run` and `fleet release` give as the caller, when `--caller` is not given ([Claims](../concepts/claims.md)) |
| `RIG_SLOTS` | the slots file, else `1` | On a machine taking work: how many jobs it runs at once. The slots file is `~/.config/claude-rig/slots`, holding one number, written by `mise run fleet -- slots <machine> <n>`. The file is what work sent over SSH sees |
| `RIG_CLAIMS` | `~/.local/state/claude-rig/claims` | Where a machine keeps its claims (the tests use it) |
| `RIG_CAPTURE_DEST` | `claude/` | Where `capture` writes (the tests use it) |
| `RIG_ASSUME_LOGGED_IN` | unset | `1` skips the login step and runs the session step anyway. For CI only |

mise's own `MISE_CONFIG_DIR`, `MISE_DATA_DIR`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` are respected for where the tool list and the shims go.
