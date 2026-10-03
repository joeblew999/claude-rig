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

`push` works out the OS on the other end, sends your config folder (`mise run config` shows which; with none, nothing is sent and the config step there is skipped), and runs the published bootstrap there. The config travels over the same SSH connection, so the machine needs no access to where you keep it ([Your config](../concepts/config.md#where-a-run-finds-it)). A dry run sends nothing. Run from a terminal, it passes the terminal through, so the login step on the machine can ask you for the code. When it succeeds, the machine is added to your machine list and shows in `mise run fleet`. The task runs under `fnox exec`, so the secrets this repo declares are in its environment when your keychain has them ([Secrets](../concepts/secrets.md)).

To have the machine report to fleet-api, set `FLEET_API_WRITE_TOKEN` where you run `push`: it is sent over the same connection, on stdin, and kept there readable by that user only ([Reporting](../concepts/reporting.md#the-write-token)). Without it, `push` says the machine will not report. A dry run sends no token.

```sh
# the token from the keychain, through fleet-api's fnox config (a clone of fleet-api next to this repo)
FLEET_API_WRITE_TOKEN="$(cd ../fleet-api && fnox get WRITE_TOKEN)" mise run push -- user@host
```

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
