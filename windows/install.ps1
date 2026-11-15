# Bootstraps Nexus on Windows: gets the code into a canonical install dir
# (mirroring install.sh's git-clone/pull/copy, not just operating wherever
# you happen to run this from), creates the venv, installs deps, builds the
# UI, seeds manifest.yaml, and registers a scheduled task ("Nexus") that
# starts it at logon and keeps it running (run-nexus.ps1 restart-loops it,
# mirroring systemd's Restart=always on Linux). Safe to re-run.
#
# Usage - either clone it yourself first:
#   git clone https://github.com/prjvvl/nexus.git
#   cd nexus
#   .\windows\install.ps1
# or run it from any checkout and let it clone/copy into $NEXUS_INSTALL_DIR
# (default $env:USERPROFILE\infra\nexus) for you - same as install.sh.
# $NEXUS_REPO_URL overrides where a fresh clone comes from.
#
# Unlike install.sh, this does not install Python/Node/Git/Docker for you -
# Windows has no single package manager every machine already has. Install
# them yourself first (see docs/install.md), then run this script.

$ErrorActionPreference = "Stop"
$ScriptRepoDir = (Resolve-Path "$PSScriptRoot\..").Path
. "$PSScriptRoot\common.ps1"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "python not found on PATH. Install Python 3: https://www.python.org/downloads/"
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found on PATH. Install Git for Windows: https://git-scm.com/download/win"
}

# $ErrorActionPreference = "Stop" only makes *PowerShell* errors terminating
# - a native exe (git, pip, npm) exiting non-zero doesn't throw on its own,
# so each one below is checked explicitly rather than trusting that
# preference to catch a failed clone/install/build before the task gets
# (re)started against it.
function Assert-LastExitCode($what) {
    if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)" }
}

$InstallDir = if ($env:NEXUS_INSTALL_DIR) { $env:NEXUS_INSTALL_DIR } else { Join-Path $env:USERPROFILE "infra\nexus" }
$RepoUrl = if ($env:NEXUS_REPO_URL) { $env:NEXUS_REPO_URL } else { "https://github.com/prjvvl/nexus.git" }

if ((Test-Path (Join-Path $ScriptRepoDir "main.py")) -and (Test-Path (Join-Path $ScriptRepoDir "nexus"))) {
    # Running from a real checkout.
    if ($ScriptRepoDir -ne $InstallDir) {
        Write-Host "==> Copying repo to $InstallDir"
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        # /E copies subdirs (incl. empty); deliberately no /MIR or /PURGE -
        # unlike install.sh's `rsync --delete`, this never deletes anything
        # already in $InstallDir, so a stale file lingers instead of risking
        # robocopy's exclude-vs-purge interaction nuking manifest.yaml/
        # state.db. venv is excluded too (regenerated next anyway, and a
        # Windows venv copied from a different path is needless weight).
        robocopy $ScriptRepoDir $InstallDir /E `
            /XD ".git" "node_modules" "dist" ".astro" "venv" "__pycache__" `
            /XF "state.db" "manifest.yaml" `
            /NFL /NDL /NJH /NJS | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "robocopy failed copying repo to $InstallDir (exit $LASTEXITCODE)" }
    }
} elseif (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "==> $InstallDir already exists, pulling latest"
    git -C $InstallDir pull --ff-only
    Assert-LastExitCode "git pull"
} else {
    Write-Host "==> Cloning $RepoUrl to $InstallDir"
    git clone $RepoUrl $InstallDir
    Assert-LastExitCode "git clone"
}

$RepoDir = $InstallDir
Set-Location $RepoDir

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

Write-Host "==> Setting up Python venv"
python -m venv venv
# Must be `python -m pip`, not `pip.exe` directly - pip.exe refuses to
# upgrade itself on Windows (its own running executable can't be replaced
# mid-execution) and exits non-zero telling you to do exactly this.
& "$RepoDir\venv\Scripts\python.exe" -m pip install --upgrade pip
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
