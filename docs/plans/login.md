---
title: Login
nav_order: 5
parent: Plans
grand_parent: This repository
---

# Login: fully automatic, for every developer

The owner (3 Oct 2026): "We need this fully self automatic. I want all devs, not just me, to have the mostly pleasant experience so that things just work." Decided by the lead, as delegated.

## What is known

| Fact | Source |
|---|---|
| A machine shows in the Claude app only with a full claude.ai login; a `claude setup-token` token cannot do Remote Control | Claude Code's documentation |
| Claude Code renews its access token by itself, with a refresh token. On the owner's Mac the access token lasts about 6 hours and the refresh token until a fixed date about 30 days after login | The Mac's keychain record, read as shapes and hashes only (3 Oct 2026) |
| `claude auth login` with no terminal prints its link and reads the code from a pipe | Run on an Ubuntu VM (3 Oct 2026) |
| Whether a renewal replaces the refresh token | Being measured: a watcher records hashes of the Mac's tokens every 10 minutes across a renewal |

## The design

1. **Every machine watches its own login.** The session checks `claude auth status` on each loop and puts the login state and the refresh token's expiry date (never a token) in its report to fleet-api. fleet-api raises `login-expiring` (under 3 days left) and `login-lost`.
2. **Heal automatically, in this order:**
   1. **Copy a fresh login** from another machine of the same developer that has one, normally their own Mac: `push` (or the control plane asking the Mac) carries it over SSH and writes it where Claude Code keeps it on that OS, readable by the user only. Never in a repo, the config, or a VM image. **Only if the measurement shows that sharing a login does not log out the machine it came from.**
   2. **Otherwise, the login inbox.** The machine runs `claude auth login` with its input on a pipe, posts its link to fleet-api, and waits. The developer gets one notification and one page listing every waiting machine; approving and pasting the code there sends it to the machine, which finishes by itself. No terminal anywhere.
3. **Before expiry, not after:** `login-expiring` starts step 2 three days early.
4. **The developer's own Mac** renews itself while it is used. If its refresh token's date only moves at a fresh login, the inbox covers it too, ahead of time.

## What is built in which order

1. The login state and expiry in the machine's report (with the reporting work).
2. The measurement's result, recorded in [Findings](../findings.md), and the decision between 2.1 and 2.2.
3. The chosen heal path, then the warning ahead of expiry.
