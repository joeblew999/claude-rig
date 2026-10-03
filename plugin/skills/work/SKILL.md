---
name: work
description: "Give a machine rigged with claude-rig a piece of work: Claude runs it there and the answer comes back here."
argument-hint: "<user@host | --all> <work>"
disable-model-invocation: true
allowed-tools: Bash(ls ~/.claude-rig/mise.toml) Bash(mise -C ~/.claude-rig run fleet)
---

# Give a machine work

Arguments: "$ARGUMENTS". The first word is the machine (`user@host`, as the fleet table shows it) or `--all` for every machine; the rest is the work.

1. If the machine or the work is missing, run `mise -C ~/.claude-rig run fleet`, show which machines can take work, and ask for what is missing.
2. Run `ls ~/.claude-rig/mise.toml`. If it is missing, claude-rig is not installed on this machine: use the `rig:setup` skill (it asks the user first), then continue.
3. Check the work text. It is sent over SSH and kept in that machine's Claude history, so it must hold no secret. That machine knows nothing of this conversation: if the work refers to it ("this repo", "the bug above"), rewrite it as a complete brief (clone URL, paths under `~/work`, how to check, what to report) and show the user before sending.
4. Run `mise -C ~/.claude-rig run fleet -- run <machine> "<work>" --json` (or `run --all "<work>" --json`). It blocks until the answer comes back, and returns `{machine, ok, seconds, answer}` for each machine.
5. Give the answer, saying which machine it came from. An answer is a claim: say so if it matters, and offer to check it. A machine that answers "Not logged in" needs the user to log it in once (`ssh -t user@host`, then `claude auth login`): say that, do not retry.

To split a bigger job across machines, the `rig:claude-rig-fleet` skill has the steps.
