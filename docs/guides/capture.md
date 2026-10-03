---
title: Change the config everywhere
nav_order: 5
parent: Guides
---

# Make your config folder, and change the config everywhere

Your Mac's `~/.claude` is the master copy, and your config folder is where it is kept for the other machines. Run these on your Mac, in a checkout of this repo.

## Make the folder, once

```sh
mise run config -- init ~/claude-config     # makes the folder and captures ~/.claude into it
mise run config                             # shows where the config comes from
```

To keep it in a private git repo, make the repo and push the folder to it. If you already have one, clone it and give `init` the clone instead: a folder that holds a config already is used as it is, not overwritten.

## Send a change to every machine

```sh
mise run capture                            # copies ~/.claude into the folder, checked for secrets and Mac-only paths
git -C ~/claude-config diff                 # see what changed, if the folder is a git repo
```

Then, for each machine:

| The machine got its config from | To update it |
|---|---|
| `push` | `mise run push -- user@host`: it sends the folder again |
| A git URL in `RIG_CONFIG` | Commit and push the folder; the machine's next run pulls it (the one line on the machine, or `mise run rig` in `~/.claude-rig`) |

What `capture` takes, what it leaves out, what stops it, and where a run looks for the config: [Your config](../concepts/config.md).
