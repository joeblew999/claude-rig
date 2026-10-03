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
