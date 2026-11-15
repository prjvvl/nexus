# Runs Nexus in a loop, restarting it if it exits - mirrors systemd's
# Restart=always / RestartSec=5 (see systemd/nexus.service.template).
# install.ps1 registers a scheduled task that runs this at logon.

. "$PSScriptRoot\common.ps1"

$RepoDir = (Resolve-Path "$PSScriptRoot\..").Path
$Python = Join-Path $RepoDir "venv\Scripts\python.exe"
$Main = Join-Path $RepoDir "main.py"

# Nexus shells out to plain `bash` for every service/job script - put real
# Git Bash ahead of anything else named bash.exe on PATH (see common.ps1)
# so the Python process and its subprocess calls resolve to it.
$GitBash = Find-GitBash
if (-not $GitBash) {
    throw "Git for Windows bash.exe not found. Run windows\install.ps1 first, or install Git for Windows: https://git-scm.com/download/win"
}
$env:PATH = "$(Split-Path $GitBash);$env:PATH"

Set-Location $RepoDir

# The scheduled task runs this hidden, with no console - without redirecting
# the process's own output somewhere, a crash is undiagnosable (unlike
# Linux's journalctl or macOS's nexus.out.log/nexus.err.log).
$OutLog = Join-Path $RepoDir "nexus.out.log"
$ErrLog = Join-Path $RepoDir "nexus.err.log"

while ($true) {
    & $Python $Main 1>> $OutLog 2>> $ErrLog
    Start-Sleep -Seconds 5
}
