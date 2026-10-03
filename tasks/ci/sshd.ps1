# sshd.ps1 — `mise run ci:sshd`: CI only. Sets this Windows machine up as an
# SSH server the way a real PC would be, for ci:push to push a rig to itself
# over localhost: OpenSSH Server from Windows' own optional features, a
# throwaway key in administrators_authorized_keys, and cmd.exe as the SSH
# shell. Needs an administrator, and changes the machine's SSH server, so it
# refuses to run outside CI.
$ErrorActionPreference = 'Stop'
if ($env:CI -ne 'true') { throw 'ci:sshd changes this machine''s SSH server: CI only' }

'OpenSSH Server'
if (Get-Service sshd -ErrorAction SilentlyContinue) {
    'sshd is already on this image'
} else {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}
# With no DefaultShell value, the SSH shell is cmd.exe.
Remove-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -ErrorAction SilentlyContinue
Start-Service sshd
Get-Service sshd
Get-Content "$env:ProgramData\ssh\sshd_config" | Where-Object { $_ -notmatch '^\s*(#|$)' }

'A throwaway key'
$ssh = "$HOME\.ssh"
New-Item -ItemType Directory -Force $ssh | Out-Null
if (-not (Test-Path "$ssh\push-test")) {
    ssh-keygen -q -t ed25519 -N '""' -f "$ssh\push-test"
    if ($LASTEXITCODE -ne 0) { throw 'could not make a key' }
}
$public = Get-Content "$ssh\push-test.pub"
Add-Content "$ssh\authorized_keys" $public -Encoding ascii
# An administrator's keys are read from this file, and only if nobody but
# Administrators and SYSTEM can touch it.
$admin = "$env:ProgramData\ssh\administrators_authorized_keys"
Set-Content $admin $public -Encoding ascii
icacls.exe $admin /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F'
if ($LASTEXITCODE -ne 0) { throw 'could not set the permissions' }
# The SSH session does not get this environment, and without a token mise hits
# GitHub's anonymous rate limit.
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $env:GITHUB_TOKEN, 'User')
'sshd is ready'
