# Install

Nexus is a Python service (FastAPI + APScheduler) plus a small React
dashboard, installed from source and run as a systemd service. There's no
packaged binary — `install.sh` builds the dashboard and sets up the service
on whatever machine you run it on.

## Requirements

- Linux with systemd (developed and run on Ubuntu).
- `sudo` access, interactively, to install packages and manage the service.
  Nexus itself runs unprivileged; only the installer and service
  start/stop/restart need `sudo`.
- Docker, if any of your services use `docker compose` (the installer sets
  this up for you).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/prjvvl/nexus/main/install.sh | sh
```

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
your own fork: `curl ... | NEXUS_REPO_URL=https://github.com/<you>/nexus.git sh`.)

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

## Upgrade

Run the same install command again — the one-liner `git pull`s an existing
install automatically. From a local checkout:

```sh
cd nexus
git pull
./install.sh
```

Re-running the installer picks up code changes, rebuilds the dashboard if
`ui/` changed, and restarts the service. `manifest.yaml` and `state.db` are
never touched by install — they're machine-specific and gitignored.

If you deploy to a separate machine from where you edit code (not required,
but how this project itself is run), see [Deploy](deploy.md) for the
`git archive | ssh` flow that keeps a remote checkout byte-for-byte in sync
with a local one.

## Uninstall

There's no uninstall script yet. By hand:

```sh
sudo systemctl disable --now nexus.service
sudo rm /etc/systemd/system/nexus.service
sudo systemctl daemon-reload
rm -rf ~/infra/nexus   # or wherever NEXUS_INSTALL_DIR pointed
```

This does not stop or remove any services Nexus was managing — their
`stop_script` needs to be run first if you want them stopped too.
