---
title: Change the config everywhere
nav_order: 5
parent: Guides
---

# Change the config everywhere

Your Mac's `~/.claude` is the master copy. To send a change to every machine:

```sh
# on your Mac, in a checkout of this repo, after changing ~/.claude
mise run capture               # copies it into claude/, checked for secrets and Mac-only paths
git diff -- claude             # see what changed
```

Commit and push the change. Each machine picks it up on its next run (`mise run push -- user@host` from the Mac, or the one line on the machine).

What `capture` takes, what it leaves out, and what stops it: [Your config](../concepts/config.md).
