# Bootstraps Nexus on Windows: gets the code into a canonical install dir
# (mirroring install.sh's git-clone/pull/copy, not just operating wherever
# you happen to run this from), creates the venv, installs deps, builds the
# UI, seeds manifest.yaml, and drops a shortcut into the Startup folder so
# run-nexus.ps1 (which restart-loops it, mirroring systemd's
# Restart=always) launches at logon - then starts it immediately too.
#
# Deliberately not a scheduled task: Register-ScheduledTask with an AtLogOn
# trigger needs a privilege (SeCreateGlobalPrivilege) that Windows only
# grants to admin accounts, even for a task that just runs as yourself -
# confirmed failing with "Access is denied" on a standard (non-admin)
# account, in both an elevated-nothing terminal and here. The Startup
# folder needs no special privilege at all; it's how most consumer apps
# launch at login without asking for admin. Safe to re-run.
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

# Stop any already-running instance *before* touching $InstallDir at all -
# otherwise robocopy below can hang for a very long time (its default is
# ~1,000,000 retries, 30s apart, on a sharing violation) on
# nexus.out.log/nexus.err.log, which a running instance holds open for
# writing. Matched by command line/path since there's no task/service
# object to query; killing the wrapper (run-nexus.ps1's restart loop)
# before its python child stops it from just relaunching that child a
# moment later.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*run-nexus.ps1*" -and $_.CommandLine -like "*$InstallDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process python -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq (Join-Path $InstallDir "venv\Scripts\python.exe") } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

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
        # /R:2 /W:1 caps retries on any *other* locked file too - failing
        # fast beats hanging on robocopy's 1,000,000-retry default.
        robocopy $ScriptRepoDir $InstallDir /E /R:2 /W:1 `
            /XD ".git" "node_modules" "dist" ".astro" "venv" "__pycache__" `
            /XF "state.db" "manifest.yaml" "nexus.out.log" "nexus.err.log" `
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

$RunNexusArgs = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$RepoDir\windows\run-nexus.ps1`""

Write-Host "==> Adding a Startup shortcut (starts at logon, restarts on exit)"
$StartupDir = [Environment]::GetFolderPath("Startup")
$ShortcutPath = Join-Path $StartupDir "Nexus.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = (Get-Command powershell.exe).Source
$Shortcut.Arguments = $RunNexusArgs
$Shortcut.WorkingDirectory = $RepoDir
$Shortcut.Save()

Write-Host "==> Starting Nexus now"
Start-Process -FilePath "powershell.exe" -ArgumentList $RunNexusArgs -WorkingDirectory $RepoDir

Write-Host "==> Done. Dashboard should be at http://localhost:8787 shortly."
Write-Host "    Logs: $RepoDir\nexus.out.log / nexus.err.log"
Write-Host "    Manage: look for 'Nexus' among the running powershell.exe/python.exe processes."
Write-Host "    Uninstall: delete `"$ShortcutPath`" and stop the running processes."
