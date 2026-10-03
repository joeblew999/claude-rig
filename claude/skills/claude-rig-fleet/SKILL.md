---
name: claude-rig-fleet
description: "See the owner's rigged machines (Macs, Linux boxes, Windows PCs, UTM VMs set up by claude-rig) and hand pieces of work to them, so a job runs on several machines at once. Use when the user asks to run something on another machine, on Windows or Linux, on several or all machines, across the fleet, or to split a large job so it runs in parallel. Do NOT use for work that fits on this machine, or for setting up a new machine (that is claude-rig's push)."
---

# The fleet

Machines rigged with claude-rig each run Claude in their work folder (`~/work`) with the owner's settings. From the machine that rigged them (normally the owner's Mac), you can see them and give them work. The rig is at `~/.claude-rig` on every rigged machine.

## See what there is

```sh
mise -C ~/.claude-rig run fleet                # table: machine, where (user@host), OS, tools, logged in, session
mise -C ~/.claude-rig run fleet -- --json      # the same, as JSON
```

Only machines with `logged in: yes` can take work. The list lives on the machine that rigged them; on another machine it is usually just "this machine".

## Give work

```sh
mise -C ~/.claude-rig run fleet -- run <where> "<work>" --json   # one machine: <where> from the table, e.g. dev@192.168.64.55
mise -C ~/.claude-rig run fleet -- run --all "<work>" --json     # every machine, the same work, in parallel
```

Each call starts a fresh Claude there, runs the work in that machine's `~/work`, and returns `{machine, ok, seconds, answer}`. It blocks until the answer comes back.

## Split a job across machines

1. **Cut it into independent pieces.** Each piece must make sense on its own: the other machine knows nothing of this conversation.
2. **Write each piece as a complete brief:** the goal, the exact repo or files (clone URLs and paths under `~/work`, not paths on this machine), how to check the result, and what to report back, briefly.
3. **Pick machines by what the piece needs** (OS, tools) from the table, one piece per machine.
4. **Run the calls in parallel** (one background command each), then collect the answers.
5. **Check before you trust.** An answer is a claim: verify anything that matters (pull the branch, rerun the test) before reporting it to the user.

## Rules

- **Never put a secret in the work text.** It is sent over SSH and stored in that machine's Claude history.
- **The other machine acts without asking** if the owner's settings allow it there. Do not send destructive work (deleting data, force-pushing, changing other machines) unless the user asked for exactly that.
- **Results come back as text.** Have the other machine push a branch or open a pull request for anything bigger than a short answer.
- **A machine that is not logged in answers "Not logged in".** Say so to the user instead of retrying; logging in needs them.
