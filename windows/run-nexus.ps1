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
#
# Not `& $Python $Main 1>> ... 2>> ...` - PowerShell wraps every line a
# native process writes to stderr as a NativeCommandError object (even
# when just redirecting to a file, not displaying it), so uvicorn's normal
# INFO-on-stderr logging would turn into unreadable "At ... CategoryInfo
# ... FullyQualifiedErrorId: NativeCommandError" noise around every line,
# defeating the point of having a log at all. Start-Process redirects at
# the OS process level instead, bypassing that entirely - confirmed clean
# by comparison. Its redirect parameters truncate the target file each
# call, though, so each iteration writes to a fresh temp file and gets
# appended onto the real log afterward, preserving history across restarts
# instead of only ever showing the latest attempt.
$OutLog = Join-Path $RepoDir "nexus.out.log"
$ErrLog = Join-Path $RepoDir "nexus.err.log"

while ($true) {
    $TmpOut = [System.IO.Path]::GetTempFileName()
    $TmpErr = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath $Python -ArgumentList "`"$Main`"" -WorkingDirectory $RepoDir `
        -NoNewWindow -PassThru -RedirectStandardOutput $TmpOut -RedirectStandardError $TmpErr
    Wait-Process -Id $proc.Id -ErrorAction SilentlyContinue
    Get-Content $TmpOut -ErrorAction SilentlyContinue | Add-Content $OutLog
    Get-Content $TmpErr -ErrorAction SilentlyContinue | Add-Content $ErrLog
    Remove-Item $TmpOut, $TmpErr -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
}
