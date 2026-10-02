# bootstrap.ps1 — Windows: install git and mise with winget, fetch claude-rig, run it.
# The run itself is tasks/rig.nu, the same nushell code on every OS.
#
#   irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1 | iex
#
# To only look, without changing anything:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/joeblew999/claude-rig/main/bootstrap.ps1))) -DryRun
#
# Safe to repeat. Each step checks first and acts only if something is missing.
# Works in Windows PowerShell 5.1 and PowerShell 7. No administrator rights needed.
[CmdletBinding()]
param(
    # Report what would change and change nothing
    [switch]$DryRun
)

function Invoke-Bootstrap {
    param([switch]$DryRun)

    $ErrorActionPreference = 'Stop'

    $rigRepo = if ($env:RIG_REPO) { $env:RIG_REPO } else { 'https://github.com/joeblew999/claude-rig.git' }
    $rigRef = if ($env:RIG_REF) { $env:RIG_REF } else { 'main' }
    $rigDir = if ($env:RIG_DIR) { $env:RIG_DIR } else { Join-Path $HOME '.claude-rig' }

    function Say($message) { Write-Host "bootstrap: $message" }
    function Would($message) { Say "would    $message" }
    function Have($program) { [bool](Get-Command $program -ErrorAction SilentlyContinue) }

    # Run a program and stop if it fails.
    function Run {
        $program = $args[0]
        $rest = @($args | Select-Object -Skip 1)
        & $program @rest
        if ($LASTEXITCODE -ne 0) { throw "bootstrap: '$args' failed with exit code $LASTEXITCODE" }
    }

    # Pick up PATH changes made by an installer, without opening a new window.
    function Update-Path {
        $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
        $all = @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
            [Environment]::GetEnvironmentVariable('Path', 'User')
            $links
            $env:Path
        ) -join ';'
        $env:Path = (($all -split ';') | Where-Object { $_ } | Select-Object -Unique) -join ';'
    }

    # Where winget is, or nothing. In an SSH session the `winget` command is
    # often not there: Windows only sets it up for someone signed in at the
    # screen. The program itself is still in the App Installer folder, which
    # an administrator can read.
    function Find-Winget {
        $command = Get-Command winget -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
        $packaged = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe'
        $found = @(Get-Item $packaged -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
        if ($found.Count -gt 0) { return $found[-1].FullName }
        return $null
    }

    function Install-WithWinget($id, $program) {
        $winget = Find-Winget
        if (-not $winget) {
            # A fresh Windows install can have winget present but not yet registered.
            try {
                Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
            } catch { }
            Update-Path
            $winget = Find-Winget
        }
        if (-not $winget) {
            throw 'bootstrap: winget is missing. Install "App Installer" from the Microsoft Store, then run again.'
        }
        Say "installing $program with winget"
        & $winget install --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
        $code = $LASTEXITCODE
        Update-Path
        if (-not (Have $program)) { throw "bootstrap: winget could not install $id (exit code $code)" }
    }

    # --- 1. Base tools: git and mise ---------------------------------------

    Update-Path
    foreach ($tool in @(@{ Id = 'Git.Git'; Program = 'git' }, @{ Id = 'jdx.mise'; Program = 'mise' })) {
        if (Have $tool.Program) {
            Say "ok       $($tool.Program)"
        } elseif ($DryRun) {
            Would "install $($tool.Program) with winget"
        } else {
            Install-WithWinget $tool.Id $tool.Program
        }
    }

    # --- 2. The rig itself -------------------------------------------------

    # mise fetches the nushell version the tool list names, then nushell runs the rig.
    function Invoke-Rig($dir) {
        $toolList = Get-Content (Join-Path $dir 'mise\claude-rig.toml') -Raw
        if ($toolList -notmatch '(?m)^nu = "(.+)"') { throw "bootstrap: no nu version in $dir\mise\claude-rig.toml" }
        $nuVersion = $Matches[1]
        $nu = "nu@$nuVersion"
        $rigArgs = @()
        if ($DryRun) {
            $rigArgs = @('--dry-run')
            $ready = $false
            if (Have mise) {
                & cmd /c "mise where $nu >nul 2>&1"
                $ready = ($LASTEXITCODE -eq 0)
            }
            if (-not $ready) {
                Would "install nushell $nuVersion, then the tools, Claude Code and the Claude config"
                Say 'dry run finished. Nothing was changed.'
                return
            }
        }
        $env:MISE_YES = '1'
        & mise exec $nu '--' nu (Join-Path $dir 'tasks\rig.nu') @rigArgs
        if ($LASTEXITCODE -ne 0) { throw "bootstrap: the rig failed with exit code $LASTEXITCODE" }
    }

    # Run from a checkout (bootstrap.ps1 sitting next to tasks\rig.nu): use it as is.
    # Piped from irm: keep a clone in $rigDir and bring it up to date.
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'tasks\rig.nu'))) {
        Say "ok       rig checkout at $PSScriptRoot"
        Invoke-Rig $PSScriptRoot
    } elseif ($DryRun) {
        # Look at the rig without leaving a clone behind.
        Would "keep a clone of the rig in $rigDir"
        if (-not (Have git)) {
            Would 'then install nushell, the tools, Claude Code and the Claude config'
            Say 'dry run finished. Nothing was changed.'
            return
        }
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "claude-rig-$([Guid]::NewGuid().ToString('N'))"
        try {
            Run git clone -q --depth 1 --branch $rigRef $rigRepo $tmp
            Invoke-Rig $tmp
        } finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        if (Test-Path (Join-Path $rigDir '.git')) {
            Run git -C $rigDir fetch -q origin $rigRef
            $head = & git -C $rigDir rev-parse HEAD
            $fetched = & git -C $rigDir rev-parse FETCH_HEAD
            if ($head -eq $fetched) {
                Say "ok       rig clone at $rigDir"
            } elseif (& git -C $rigDir status --porcelain) {
                throw "bootstrap: $rigDir has local changes. Commit or discard them, then run again."
            } else {
                Say "updating $rigDir"
                Run git -C $rigDir merge -q --ff-only FETCH_HEAD
            }
        } else {
            Say "cloning the rig into $rigDir"
            Run git clone -q --branch $rigRef $rigRepo $rigDir
        }
        Invoke-Rig $rigDir
    }
}

Invoke-Bootstrap -DryRun:$DryRun
