---
title: Rig a Windows PC
nav_order: 1
parent: Guides
---

# Rig a Windows PC

For a Windows 10 or 11 PC or VM, x64 or ARM64, sitting in front of it. To rig one from your Mac instead, first turn on SSH (below), then use [Rig a machine over SSH](push.md).

## Rig it, at the PC

In PowerShell (no administrator rights needed):

```powershell
irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1 | iex
```

To only look:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1))) -DryRun
```

winget installs git and mise; everything after is the same run as on a Mac ([A run](../concepts/a-run.md)). Then log in once when asked.

## Let your Mac reach it

In PowerShell **as Administrator** on the PC, with your Mac's public key (`cat ~/.ssh/id_ed25519.pub` on the Mac) in place of `<your key>`:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0     # takes a few minutes the first time
Start-Service sshd; Set-Service sshd -StartupType Automatic
New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
Add-Content "$env:ProgramData\ssh\administrators_authorized_keys" '<your key>'
icacls "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F'
whoami; ipconfig | findstr IPv4                                    # the user and address for push
```

The key file is the one OpenSSH reads for an administrator account; it must be writable only by Administrators and SYSTEM. For a UTM VM made with `irgo-winvm`, `irgo-winvm vm-ssh-create -vm <name>` does all of this.

## Limits

- **The session starts at sign-in.** pitchfork cannot start at boot on Windows, so a file in the Startup folder starts it when the user signs in. A PC that reboots and waits at the sign-in screen stays offline until someone signs in.
- **Not tested:** a Windows account that is not an administrator, and a user name with a space in it.
