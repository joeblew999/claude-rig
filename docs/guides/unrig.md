---
title: Take a machine out
nav_order: 6
parent: Guides
---

# Take a machine out of the fleet

On the machine, in `~/.claude-rig` (or the checkout on your Mac):

```sh
mise run unrig -- --dry-run    # look
mise run unrig                 # stop the session and remove what starts it
```

The machine leaves the Claude app. The tools, Claude Code, the config, the login, the work folder and its fleet-api token stay, and running the rig again puts the session back. To take it off your Mac's list too: `mise run fleet -- forget user@host`.

A machine cannot revoke its own fleet-api token: it has no Cloudflare credentials. `unrig` prints the command that does, with the machine's token name. Run it on your Mac, against fleet-api's checkout (`FLEET_API_DIR`):

```sh
mise -C ~/workspace/go/src/github.com/joeblew999/fleet-api run access:token -- revoke <name>   # Access refuses the machine's token from then on
```
