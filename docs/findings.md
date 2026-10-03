---
title: Findings
nav_order: 2
parent: This repository
---

# Findings: what has been verified, where and when

Newest last. Only what was run.

| Date | What | Where | Result |
|---|---|---|---|
| 2026-10-02 | `capture` | the owner's Mac | Captured `settings.json` and two skills; a second run reported no change |
| 2026-10-02 | The bootstrap on macOS and Linux | fresh GitHub runners (macOS, Ubuntu x64 and ARM64); Ubuntu 24.04 and Debian 12 containers; the owner's Mac | Dry run changed nothing; first run rigged; second run changed nothing |
| 2026-10-02 | The bootstrap on Windows | fresh GitHub runners (Windows Server x64, Windows 11 ARM64) | The same three runs, winget installing git and mise |
| 2026-10-02 | The session on macOS | the owner's Mac | Started under pitchfork, connected, shown in the Claude app; the rig restarted it after `pitchfork stop`. Not rebooted |
| 2026-10-02 | `claude remote-control` with no terminal | the owner's Mac | Exits at "Enable Remote Control? (y/n)" with nothing answered; runs when `y` is piped in; later starts ask nothing. In an unapproved folder it exits with "Workspace not trusted"; approved in `~/.claude.json`, it runs |
| 2026-10-02 | `push` to Windows | a Windows 11 ARM64 VM in UTM, set up like an office PC (OpenSSH Server, key in `administrators_authorized_keys`, cmd as the SSH shell) | From nothing: git, mise, 15 tools, Claude Code, the config. Second run changed nothing |
| 2026-10-02 | The Windows session over SSH | the same VM | Started through the Task Scheduler it runs in the desktop session and survives the SSH connection closing; started directly from SSH it was stopped when the connection closed |
| 2026-10-02 | The Windows session after a reboot | the same VM | It signed in by itself and the session loop came back. The server could not connect: the VM is not logged in |
| 2026-10-02 | `push` from Windows | GitHub Windows runners (x64, ARM64), pushing to their own SSH server | Dry run, first run, second run; also a dry run with PowerShell as the SSH shell |
| 2026-10-02 | `doctor`, `fleet` | the owner's Mac, the Windows VM, an Ubuntu VM | All three machines in one table with the right state |
| 2026-10-02 | `unrig` | the owner's Mac and the Windows VM | Unrig, unrig again (nothing to do), rig again (session back) |
| 2026-10-02 | The tests | the owner's Mac and every CI runner | Pass. Each was checked to fail with the code broken on purpose |
| 2026-10-02 | `fleet run` | the owner's Mac | Answered in 4.9 s. To an Ubuntu VM that is not logged in: "Not logged in", as expected |
| 2026-10-02 | `push` to Linux in UTM | an Ubuntu 24.04 VM made with `irgo-winvm vm-create -os linux` | Dry run, first run, second run with no changes. Stops at the login step, as designed |
| 2026-10-03 | The rig link, and a bootstrap with a linked checkout | the owner's Mac | The run made `~/.claude-rig` a link to the checkout (dry run, run, second run `ok`). The piped bootstrap then said the link is the owner's checkout and left its branch alone |
| 2026-10-03 | The `claude-rig-fleet` skill's command | the owner's Mac | `mise -C ~/.claude-rig run fleet -- run <this machine> "..." --json` answered in 2.8 s |
| 2026-10-03 | `vm new linux`, `vm rm` | the owner's Mac (UTM, VM tool 0.7.0) | One command made an Ubuntu VM, turned SSH on and rigged it in 1 min 55 s; it showed in `fleet`. `vm rm` deleted it (4.2 GB back) and took it off the list. `vm new windows` not run yet |
| 2026-10-03 | The plugin `rig` and the marketplace file, with `claude plugin validate` | the owner's Mac (Claude Code 2.1.288) | Both pass, with one warning: no `version`, left out on purpose. The name `claude-rig` for the plugin fails: `Plugin name "claude-rig" is reserved`. A broken skill header and that name each made it exit 1 |
| 2026-10-03 | The plugin installed from a local checkout | the owner's Mac (Claude Code 2.1.288) | `claude plugin marketplace add <checkout>`, `claude plugin install rig@claude-rig`: `claude plugin details rig` listed the 7 skills. `claude -p "/rig:fleet"` showed the fleet table (3 machines) in 23 s, with no permission prompt. `claude plugin marketplace remove claude-rig` uninstalled it again; it left a copy in `~/.claude/plugins/cache/claude-rig/`, marked to be deleted in 14 days |
| 2026-10-03 | The plugin installed from GitHub | the owner's Mac (Claude Code 2.1.288) | `claude plugin marketplace add 'joeblew999/claude-rig#feat/plugin'` cloned over HTTPS; `claude plugin install rig@claude-rig` installed the 7 skills. `claude -p "/rig:doctor"` ran the doctor and summed it up. Removed again with `claude plugin marketplace remove claude-rig` |
| 2026-10-03 | The owner's config moved out | the owner's Mac | `claude/` copied to the private repo `joeblew999/claude-rig-config`, without `claude-rig-fleet`. `config init` on its clone used it as it was; `apply` then changed nothing (`~/.claude/settings.json` byte for byte the same, skills the same), twice. `rig --dry-run` from the branch's checkout: config `ok`. A real `rig` from that checkout was not run: it would move the session service to the checkout's `session.nu` |
| 2026-10-03 | A run with no config, then with a config in `RIG_CONFIG` | fresh GitHub runners (macOS, Ubuntu x64 and ARM64, Windows Server x64, Windows 11 ARM64) | The first run said `skip config: none chosen`, applied nothing and still installed the tools and Claude Code; the run with the tests' config applied it; the second run changed nothing |
| 2026-10-03 | `push` sending a config | a GitHub Windows runner pushing to its own SSH server (cmd.exe as the SSH shell) | The config was sent with scp and taken in by the run there; the second push sent it again and changed nothing; dry runs sent nothing |
| 2026-10-03 | The tests for no config, `config init`, what push sends, a git URL, and capture keeping a README and `.git` | the owner's Mac and every CI runner | Pass. Each was checked to fail with the code broken on purpose (on the Mac). `push` to a Linux VM not run: no room for a VM on the Mac that day; this Mac has no SSH server for a push to itself |
| 2026-10-03 | Why UTM stopped twice | the owner's Mac (`pmset -g log`) | The first stop was at the minute the Mac entered maintenance sleep (10:25:41); only short `caffeinate -t 300` holds from other tools were keeping it awake. After the session was put under `caffeinate -i -s`, `pmset -g assertions` shows it holding off idle and system sleep on behalf of `claude` |
| 2026-10-03 | Claims: `tests/claims.nu` | the owner's Mac | Eight callers racing for one slot: one got it, seven were told busy. Expiry, release and `--force`, two slots, the job folder, renewal past the first expiry, and `--wait` all pass. Each check failed with the code broken on purpose (no lock, no clearing, no owner check, `--force` ignored, no job folder, no renewal, no waiting, the claim not let go) |
| 2026-10-03 | Claims: two `fleet run` to this machine at once, one slot | the owner's Mac | The first answered `pong` in 4.8 s; the second, 2 s later, came back at once: `busy: apples-MacBook-Pro is held by caller-one (job "Reply with the single word: pong", claim 20261003-104539-377984) since 10:45:39, until 10:47:39`, exit 6. With `--wait`, the second ran after the first and answered in 9.3 s. Each ran in its own `~/work/jobs/<claim id>`; no claim was left. Not run over SSH or on Windows |
