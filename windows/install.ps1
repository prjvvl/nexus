# Bootstraps Nexus on Windows: creates the venv, installs deps, builds the
# UI, seeds manifest.yaml, and registers a scheduled task ("Nexus") that
# starts it at logon and keeps it running (run-nexus.ps1 restart-loops it,
# mirroring systemd's Restart=always on Linux). Safe to re-run.
#
# Usage (from a checkout):
#   cd nexus
#   .\windows\install.ps1
#
# Unlike install.sh, this does not install Python/Node/Git/Docker for you -
# Windows has no single package manager every machine already has. Install
# them yourself first (see docs/install.md), then run this script.

$ErrorActionPreference = "Stop"
$RepoDir = (Resolve-Path "$PSScriptRoot\..").Path
Set-Location $RepoDir
. "$PSScriptRoot\common.ps1"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "python not found on PATH. Install Python 3: https://www.python.org/downloads/"
}

# Not just "is something named bash.exe on PATH" - Windows' own System32
# ships a bash.exe stub that launches WSL, which fails outright if the
# default WSL distro has no /bin/bash (e.g. Docker Desktop's internal
# distro). Nexus needs real Git Bash specifically (see common.ps1).
$GitBash = Find-GitBash
if (-not $GitBash) {
    throw "Git for Windows not found. Nexus runs service/job scripts through its bash.exe, not WSL's. Install it: https://git-scm.com/download/win"
}
Write-Host "==> Using bash: $GitBash"

if (-not (Test-Path "manifest.yaml")) {
    Write-Host "==> No manifest.yaml yet, seeding from manifest.example.yaml"
    Copy-Item manifest.example.yaml manifest.yaml
    Write-Host "    Edit $RepoDir\manifest.yaml for this machine's services/jobs before relying on it."
}

# $ErrorActionPreference = "Stop" only makes *PowerShell* errors terminating
# - a native exe (pip, npm) exiting non-zero doesn't throw on its own, so
# each one is checked explicitly rather than trusting that preference to
# catch a failed install/build before the task gets (re)started against it.
function Assert-LastExitCode($what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" }
}

Write-Host "==> Setting up Python venv"
python -m venv venv
& "$RepoDir\venv\Scripts\pip.exe" install --upgrade pip
Assert-LastExitCode "pip install --upgrade pip"
& "$RepoDir\venv\Scripts\pip.exe" install -r requirements.txt
Assert-LastExitCode "pip install -r requirements.txt"

if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "==> Building UI"
    Push-Location (Join-Path $RepoDir "ui")
    npm install
    Assert-LastExitCode "npm install"
    npm run build
    Assert-LastExitCode "npm run build"
    Pop-Location
} else {
    Write-Warning "npm not found on PATH - skipping UI build. Install Node.js (https://nodejs.org/) and re-run to get the dashboard."
}

Write-Host "==> Registering scheduled task 'Nexus' (starts at logon, restarts on exit)"
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$RepoDir\windows\run-nexus.ps1`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

# Stop any already-running instance (from a previous install) before
# swapping the task definition - otherwise the old process keeps running
# and Start-ScheduledTask below launches a second one fighting it for
# port 8787, unlike Linux's `systemctl restart` / macOS's bootout+bootstrap.
Stop-ScheduledTask -TaskName "Nexus" -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "Nexus" -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName "Nexus" -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal | Out-Null

Write-Host "==> Starting Nexus now"
Start-ScheduledTask -TaskName "Nexus"

Write-Host "==> Done. Dashboard should be at http://localhost:8787 shortly."
Write-Host "    Logs: $RepoDir\nexus.out.log / nexus.err.log"
Write-Host "    Manage the task: Get-ScheduledTask -TaskName Nexus, or via the Task Scheduler GUI."
Write-Host "    Uninstall: Unregister-ScheduledTask -TaskName Nexus -Confirm:`$false"
