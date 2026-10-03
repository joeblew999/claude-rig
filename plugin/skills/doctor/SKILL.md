---
name: doctor
description: "Report what claude-rig has set up on this machine and what a run would change. Changes nothing."
disable-model-invocation: true
allowed-tools: Bash(ls ~/.claude-rig/mise.toml) Bash(mise -C ~/.claude-rig run doctor)
---

# Check this machine

1. Run `ls ~/.claude-rig/mise.toml`. If it is missing, claude-rig is not installed on this machine: use the `rig:setup` skill (it asks the user first), then stop.
2. Run `mise -C ~/.claude-rig run doctor`. It changes nothing.
3. Sum it up in a few lines: tools installed, config applied, logged in, session running, and each `would` line (what a run of the rig would change). If something is missing, say how to fix it: running the bootstrap again (`/rig:setup`) fixes most; a login needs the user to run `claude auth login`.
