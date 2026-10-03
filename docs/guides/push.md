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

`push` works out the OS on the other end, sends your config folder (`mise run config` shows which; with none, nothing is sent and the config step there is skipped), and runs the published bootstrap there. The config travels over the same SSH connection, so the machine needs no access to where you keep it ([Your config](../concepts/config.md#where-a-run-finds-it)). A dry run sends nothing. Run from a terminal, it passes the terminal through, so the login step on the machine can ask you for the code. When it succeeds, the machine is added to your machine list and shows in `mise run fleet`.

Then `push` gives the machine its own fleet-api token, so it reports: it asks the machine for its id, makes the token with fleet-api's own task in fleet-api's checkout, sends it over the same connection, on stdin, kept there readable by that user only, and has the machine report once. It prints the outcome, never the secret. A machine that already has a token keeps it. Which token, and what happens when one exists: [Reporting](../concepts/reporting.md#the-machines-token).

This needs fleet-api's checkout on your Mac, with its Cloudflare credentials in fnox (fleet-api's Access guide): `~/workspace/go/src/github.com/joeblew999/fleet-api`, or the folder in `FLEET_API_DIR`. Without it `push` stops before it changes anything and says so. A dry run makes no token.

```sh
mise run push -- user@host --new-token   # revoke the machine's token and give it a new one
mise run push -- user@host --no-report   # rig it without a token: it does not report
```

| Flag | What it does |
|---|---|
| `--dry-run` | Changes nothing on the machine |
| `--ref <branch>` | Rigs from a branch instead of `main` |
| `--port <n>` | An SSH port other than 22 |
| `--identity <key file>` | The private key to log in with |
| `--known-hosts <file>` | Keeps host keys out of `~/.ssh/known_hosts`: `/dev/null` for a throwaway VM (`NUL` from Windows) |
| `--new-token` | Makes the machine a new fleet-api token even if it has one; the old one is revoked |
| `--no-report` | Makes no fleet-api token, and needs no fleet-api checkout |

## Limits

- **Key login only.** The machine must accept your key without a password, and `sudo` on Linux must not ask for one, because nobody is there to type it.
- **Not tested:** pushing to another Mac.
- **Making a token tried only against a stand-in** for fleet-api's task (the tests, and CI pushing to a Windows runner), and its refusal of a name another machine holds against the real task: no machine has been pushed to with a real token yet ([Findings](../findings.md)).
