# Install

Nexus is a Python service (FastAPI + APScheduler) plus a small React
dashboard, installed from source. There's no packaged binary — the
installer builds the dashboard and sets Nexus up to run in the background
on whatever machine you run it on: as a systemd service on Linux, a
launchd agent on macOS, or a restart-on-exit scheduled task on Windows.

## Requirements

**Linux** (the primary, daily-used target — developed and run on Ubuntu):

- systemd.
- `sudo` access, interactively, to install packages and manage the service.
  Nexus itself runs unprivileged; only the installer and service
  start/stop/restart need `sudo`.
- Docker, if any of your services use `docker compose` (the installer sets
  this up for you).

**macOS:**

- Python 3 on `PATH` — Homebrew (`brew install python`) is the easiest
  route; macOS doesn't ship a current one.
- Node.js (`brew install node`), to build the dashboard — optional, the
  installer skips the UI build and warns if it's missing.
- Docker Desktop, or `brew install --cask docker`, if any of your services
  use `docker compose`.
- `bash` needs nothing extra — macOS ships a real one at `/bin/bash`.
- No sudo needed — it installs a per-user launchd agent, not a
  system-wide daemon.

**Windows:**

- Python 3 on `PATH` ([python.org](https://www.python.org/downloads/)).
- Git for Windows on `PATH`, specifically its `bash.exe`
  ([git-scm.com](https://git-scm.com/download/win)) — Nexus runs every
  service/job script through `bash`, same as on Linux/macOS; the
  installer's default options put it on `PATH`. Watch out for Windows'
  own `bash.exe` in `System32` (a WSL launcher) shadowing it on `PATH` —
  the installer checks for Git Bash specifically, not just anything named
  `bash`.
- Node.js ([nodejs.org](https://nodejs.org/)), to build the dashboard —
  optional, the installer skips the UI build and warns if it's missing.
- Docker Desktop, if any of your services use `docker compose`.
- No admin rights needed — the scheduled task it registers runs as your
  own user.

## Install

### Linux

```sh
curl -fsSL https://raw.githubusercontent.com/prjvvl/nexus/main/install.sh | bash
```

(`bash`, not `sh` — the script needs real bash, not just a POSIX shell; piping
into `sh` fails immediately on Debian/Ubuntu, where it's dash.)

This clones [prjvvl/nexus](https://github.com/prjvvl/nexus) into
`~/infra/nexus` (override with `NEXUS_INSTALL_DIR`) and runs the installer
from there. If you'd rather clone it yourself first — to read the code, pin
a branch, or point it at a fork — that works the same way:

```sh
git clone https://github.com/prjvvl/nexus.git
cd nexus
./install.sh
```

(`NEXUS_REPO_URL` overrides where the one-liner clones from, e.g. to install
your own fork: `curl ... | NEXUS_REPO_URL=https://github.com/<you>/nexus.git bash`.)

Either way, `install.sh` is safe to re-run. Each run:

1. Installs system packages (`git`, `docker.io`, the compose plugin, Python,
   and Node.js if missing).
2. Gets the code into `~/infra/nexus`: clones it fresh, `git pull`s if it's
   already there, or copies a local checkout in if you ran the script from
   one elsewhere.
3. Seeds `manifest.yaml` from `manifest.example.yaml` the first time, so a
   fresh install has a real, working demo service and job to verify against.
4. Creates a Python virtualenv and installs `requirements.txt`.
5. Builds the dashboard (`ui/`).
6. Generates and installs `nexus.service` (systemd) for your user, then
   enables and starts it.

When it finishes, the dashboard is at `http://<this machine>:8787`.

### macOS

Clone the repo yourself first (there's no `curl | bash` one-liner on macOS
— see Requirements above for what to install beforehand):

```sh
git clone https://github.com/prjvvl/nexus.git
cd nexus
./macos/install.sh
```

`install.sh` is safe to re-run. Each run:

1. Seeds `manifest.yaml` from `manifest.example.yaml` the first time.
2. Creates a Python virtualenv and installs `requirements.txt`.
3. Builds the dashboard (`ui/`), unless `npm` is missing.
4. Installs `com.prjvvl.nexus.plist` to `~/Library/LaunchAgents/`,
   `bootstrap`s it as your user's launchd agent, and kickstarts it. `RunAtLoad`
   + `KeepAlive` start it at login and restart it (after a 5-second
   throttle) if it ever exits — the same behavior `Restart=always` /
   `RestartSec=5` gives it on Linux.

When it finishes, the dashboard is at `http://localhost:8787`. Logs go to
`nexus.out.log` / `nexus.err.log` in the install directory.

### Windows

Clone the repo yourself first (there's no `curl | bash` one-liner on
Windows — see Requirements above for what needs to already be on `PATH`):

```powershell
git clone https://github.com/prjvvl/nexus.git
cd nexus
.\windows\install.ps1
```

`install.ps1` is safe to re-run. Each run:

1. Seeds `manifest.yaml` from `manifest.example.yaml` the first time.
2. Creates a Python virtualenv and installs `requirements.txt`.
3. Builds the dashboard (`ui/`), unless `npm` is missing.
4. Registers a scheduled task named `Nexus` that starts at logon and runs
   `windows/run-nexus.ps1` — a loop that restarts the process 5 seconds
   after it exits, the same behavior `Restart=always` / `RestartSec=5`
   gives it on Linux (see `systemd/nexus.service.template`) — then starts
   it immediately.

When it finishes, the dashboard is at `http://localhost:8787`. Logs go to
`nexus.out.log` / `nexus.err.log` in the install directory.

## Upgrade

Run the same install command again.

Linux: the one-liner `git pull`s an existing install automatically, or from
a local checkout:

```sh
cd nexus
git pull
./install.sh
```

macOS, from a local checkout:

```sh
cd nexus
git pull
./macos/install.sh
```

Windows, from a local checkout:

```powershell
cd nexus
git pull
.\windows\install.ps1
```

Re-running the installer picks up code changes, rebuilds the dashboard if
`ui/` changed, and restarts the service/agent/task. `manifest.yaml` and
`state.db` are never touched by install — they're machine-specific and
gitignored.

If you deploy to a separate machine from where you edit code (not required,
but how this project itself is run), see [Deploy](deploy.md) for the
`git archive | ssh` flow that keeps a remote checkout byte-for-byte in sync
with a local one.

## Uninstall

There's no uninstall script yet. By hand:

**Linux:**

```sh
sudo systemctl disable --now nexus.service
sudo rm /etc/systemd/system/nexus.service
sudo systemctl daemon-reload
rm -rf ~/infra/nexus   # or wherever NEXUS_INSTALL_DIR pointed
```

**macOS:**

```sh
launchctl bootout gui/$(id -u)/com.prjvvl.nexus
rm ~/Library/LaunchAgents/com.prjvvl.nexus.plist
rm -rf venv ui/dist   # or the whole checkout
```

**Windows:**

```powershell
Unregister-ScheduledTask -TaskName Nexus -Confirm:$false
Remove-Item -Recurse -Force .\venv, .\ui\dist   # or the whole checkout
```

Either way, this does not stop or remove any services Nexus was managing —
their `stop_script` needs to be run first if you want them stopped too.
