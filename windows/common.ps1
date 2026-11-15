# Shared helper for install.ps1 and run-nexus.ps1.
#
# Windows ships its own bash.exe in System32 that launches WSL - and on a
# machine whose default WSL distro has no /bin/bash (e.g. Docker Desktop's
# internal distro), that stub fails outright. `Get-Command bash` can resolve
# to that broken stub even when a working Git-for-Windows bash.exe is also
# installed, if System32 comes first on PATH. Nexus needs the real one, so
# this locates Git Bash specifically rather than trusting whatever `bash`
# happens to resolve to.

function Find-GitBash {
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
        $candidate = Join-Path $gitRoot "bin\bash.exe"
        if (Test-Path $candidate) { return $candidate }
    }
    foreach ($p in @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    )) {
        if (Test-Path $p) { return $p }
    }
    return $null
}
