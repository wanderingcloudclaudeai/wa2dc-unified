# ISO-8601 timestamp (file created): 2026-11-15T01:28:16Z
# ==============================================================================
# install-windows.ps1 - install and run a wa2dc-unified bridge on Windows
# Version: 1.0.0
#
# Version history:
#   1.0.0  2026-11-15T01:28:16Z  Initial release (winget prerequisites, three
#                                bridges, optional start-at-boot scheduled task).
#
# Run from an elevated PowerShell in the root of an extracted release or checkout:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\deploy\windows\install-windows_v1.0.0_<timestamp>.ps1 -Bridge main
# Parameters:
#   -Bridge main|osdc-wa|hummus   which bridge to install (default: main)
#   -NoTask                       build only; do not register a scheduled task
# Supported: Windows 10 22H2+, Windows 11, Windows Server 2022/2025 (winget required).
# ==============================================================================
[CmdletBinding(SupportsShouldProcess = $true)]   # enables -WhatIf as a dry-run
param(
    [ValidateSet('main', 'osdc-wa', 'hummus')]
    [string]$Bridge = 'main',                    # bridge to install
    [switch]$NoTask                              # skip the scheduled task
)

$ErrorActionPreference = 'Stop'                  # treat every error as fatal
Set-StrictMode -Version Latest                   # catch typos in variable names

function Write-Step([string]$Message) { Write-Host "[wa2dc-unified] $Message" -ForegroundColor Cyan }

# --- locate the repository and the selected bridge ----------------------------
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path   # deploy\windows -> repo root
if (-not (Test-Path (Join-Path $RepoRoot 'bridges'))) { throw 'Run this from a wa2dc-unified checkout.' }
switch ($Bridge) {
    'main'    { $WorkDir = $RepoRoot;                               $Exe = 'node.exe'; $ExeArgs = 'src\runner.js' }
    'osdc-wa' { $WorkDir = Join-Path $RepoRoot 'bridges\osdc-wa';   $Exe = 'node.exe'; $ExeArgs = 'src\index.js' }
    'hummus'  { $WorkDir = Join-Path $RepoRoot 'bridges\hummus';    $Exe = Join-Path $WorkDir 'hummus.exe'; $ExeArgs = '' }
}

# --- must be elevated: winget machine installs and task registration need it --
$Principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open PowerShell with "Run as administrator" and try again.'
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is missing. Install "App Installer" from the Microsoft Store (or aka.ms/getwinget) first.'
}

# --- prerequisites via winget -------------------------------------------------
function Install-WingetPackage([string]$Id, [string[]]$Extra = @()) {
    # Idempotent: winget exits non-zero when the package is already current, so check first.
    winget list --id $Id --exact --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Step "$Id already installed"; return }
    Write-Step "Installing $Id"
    if ($PSCmdlet.ShouldProcess($Id, 'winget install')) {
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements @Extra
        if ($LASTEXITCODE -ne 0) { throw "winget failed to install $Id (exit $LASTEXITCODE)" }
    }
}
Install-WingetPackage 'Git.Git'                                    # needed for npm git dependencies and updates
if ($Bridge -eq 'hummus') {
    Install-WingetPackage 'GoLang.Go'                              # Go toolchain
    Install-WingetPackage 'BrechtSanders.WinLibs.POSIX.UCRT'       # gcc: go-sqlite3 is a cgo package
} else {
    Install-WingetPackage 'OpenJS.NodeJS.LTS'                # current Node.js LTS line
    Install-WingetPackage 'Gyan.FFmpeg'                            # media conversion (voice notes, stickers)
}
# Make the freshly installed tools visible to this session without reopening the shell.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# The main bridge enforces Node ^24.22.1 || >=26.12.1 (package.json "engines"); fail early with a clear message.
if ($Bridge -eq 'main' -and (Get-Command node -ErrorAction SilentlyContinue)) {
    $NodeVersion = [version]((node -p 'process.versions.node') | Select-Object -First 1)
    $Supported = ($NodeVersion.Major -eq 24 -and $NodeVersion -ge [version]'24.22.1') -or ($NodeVersion -ge [version]'26.12.1')
    if (-not $Supported) { throw "Node $NodeVersion is not supported; install Node 24.22.1+ (24.x) or 26.12.1+ and re-run." }
}

# --- build the selected bridge ------------------------------------------------
Push-Location $WorkDir
try {
    if ($Bridge -eq 'hummus') {
        $env:CGO_ENABLED = '1'                               # required by go-sqlite3
        if ($PSCmdlet.ShouldProcess('hummus.exe', 'go build')) {
            go build -trimpath -o hummus.exe .
            if ($LASTEXITCODE -ne 0) { throw 'go build failed' }
        }
    } elseif ($PSCmdlet.ShouldProcess($WorkDir, 'npm ci')) {
        npm ci --omit=dev                                    # exact, reproducible dependency install
        if ($LASTEXITCODE -ne 0) { throw 'npm ci failed' }
    }
    # Create the configuration file from the template without overwriting an existing one.
    if (-not (Test-Path '.env') -and (Test-Path '.env.example')) {
        Copy-Item '.env.example' '.env'
        # Restrict the token file to the current user and Administrators.
        icacls '.env' /inheritance:r /grant:r "$($env:USERNAME):F" 'Administrators:F' | Out-Null
    }
} finally {
    Pop-Location
}

# --- start at boot (scheduled task, restarts on failure) -----------------------
$TaskName = "wa2dc-unified-$Bridge"
if (-not $NoTask -and $PSCmdlet.ShouldProcess($TaskName, 'Register-ScheduledTask')) {
    $ExePath = if ($Exe -eq 'node.exe') { (Get-Command node.exe).Source } else { $Exe }
    $ActionArgs = @{ Execute = $ExePath; WorkingDirectory = $WorkDir }
    if ($ExeArgs) { $ActionArgs.Argument = $ExeArgs }
    $Action   = New-ScheduledTaskAction @ActionArgs
    $Trigger  = New-ScheduledTaskTrigger -AtStartup
    $Settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
    # Runs as the installing user without storing a password (S4U); the task stays disabled until linked.
    $User     = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings `
        -Principal $User -Force | Out-Null
    Disable-ScheduledTask -TaskName $TaskName | Out-Null
}

# --- next steps ---------------------------------------------------------------
$StartLine = if ($ExeArgs) { "node $ExeArgs" } else { '.\hummus.exe' }
Write-Step 'Done. Next steps:'
Write-Step "  1. Edit $WorkDir\.env and set the Discord token (and chat mapping for osdc-wa/hummus)."
Write-Step "  2. Link WhatsApp interactively once:  cd `"$WorkDir`"; $StartLine"
Write-Step "  3. Press Ctrl+C when linked, then:  Enable-ScheduledTask $TaskName; Start-ScheduledTask $TaskName"
# ISO-8601 timestamp (end of file): 2026-11-15T01:28:16Z
