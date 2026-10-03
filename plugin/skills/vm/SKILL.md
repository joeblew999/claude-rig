---
name: vm
description: "Make a UTM virtual machine on this Mac and rig it with claude-rig in one step, or delete one."
argument-hint: "new <linux|windows> <name> | rm <name>"
disable-model-invocation: true
allowed-tools: Bash(ls ~/.claude-rig/mise.toml)
---

# Make a VM worker

Arguments: "$ARGUMENTS". For an Apple Silicon Mac with UTM (https://mac.getutm.app) installed.

1. If the arguments are not `new linux <name>`, `new windows <name>` or `rm <name>`, say what they can be and stop. If this is not a Mac, say the command needs one and stop.
2. Run `ls ~/.claude-rig/mise.toml`. If it is missing, claude-rig is not installed on this machine: use the `rig:setup` skill (it asks the user first), then continue.
3. Run `mise -C ~/.claude-rig install` once, so the VM tool the task uses is there.
4. For `rm`, confirm with the user first: it deletes the VM and its disk.
5. Run `mise -C ~/.claude-rig run vm -- <the arguments>`. A Linux VM takes about two minutes. `new windows` needs a Windows golden image made first (`irgo-winvm vm-golden-create`), and its first start takes 7 to 10 minutes for SSH.
6. Report the address it printed. The new VM is not logged in to Claude: tell the user to log it in once, from a terminal: `ssh -t <user@address>`, then `claude auth login`. It then shows in `/rig:fleet` with a running session.
