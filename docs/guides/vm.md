---
title: Make a VM worker
nav_order: 3
parent: Guides
---

# Make a VM worker on your Mac

For an Apple Silicon Mac with [UTM](https://mac.getutm.app). One command makes the VM, turns SSH on in it, and rigs it; the VM tool it uses (`irgo-winvm`) is pinned in `mise.toml`, so `mise install` brings it.

```sh
mise install                                  # once: brings the VM tool
mise run vm -- new linux build-1              # an Ubuntu 24.04 VM from Ubuntu's own image
mise run vm -- new windows win-1              # a clone of the Windows golden image (needs one: irgo-winvm vm-golden-create)
mise run vm -- rm build-1                     # delete it, and take it off the machine list
```

Then log it in once (`ssh -t <the user@address it printed>`, then `claude auth login`), and it shows in `mise run fleet` with a running session.

## Limits

- **The VM tool's quotas apply.** Its VMs here belong to `claude-rig`, which may hold 2 VMs and 16 GiB unless `IRGO_WINVM_QUOTA_VMS` and `IRGO_WINVM_QUOTA_GIB` say otherwise; `mise x -- irgo-winvm capacity` shows what fits.
- **A Windows clone needs about 7 to 10 minutes for SSH** the first time, while Windows installs OpenSSH Server, until the golden image has it built in.
