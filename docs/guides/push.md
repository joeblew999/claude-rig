---
title: Rig a machine over SSH
nav_order: 2
parent: Guides
---

# Rig a machine over SSH, from your Mac

For any machine your Mac can reach with an SSH key: Linux, Windows (set up as in [Rig a Windows PC](windows.md#let-your-mac-reach-it)), or a UTM VM.

```sh
mise run push -- user@host --dry-run     # look: what a run there would change
mise run push -- user@host               # rig it
```

`push` works out the OS on the other end and runs the published bootstrap there. Run from a terminal, it passes the terminal through, so the login step on the machine can ask you for the code. When it succeeds, the machine is added to your machine list and shows in `mise run fleet`.

| Flag | What it does |
|---|---|
| `--dry-run` | Changes nothing on the machine |
| `--ref <branch>` | Rigs from a branch instead of `main` |
| `--port <n>` | An SSH port other than 22 |
| `--identity <key file>` | The private key to log in with |
| `--known-hosts <file>` | Keeps host keys out of `~/.ssh/known_hosts`: `/dev/null` for a throwaway VM (`NUL` from Windows) |

## Limits

- **Key login only.** The machine must accept your key without a password, and `sudo` on Linux must not ask for one, because nobody is there to type it.
- **Not tested:** pushing to another Mac.
