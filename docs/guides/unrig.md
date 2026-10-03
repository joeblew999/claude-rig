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

The machine leaves the Claude app. The tools, Claude Code, the config, the login and the work folder stay, and running the rig again puts the session back. To take it off your Mac's list too: `mise run fleet -- forget user@host`.
