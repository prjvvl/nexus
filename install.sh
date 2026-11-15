#!/usr/bin/env bash
# Bootstraps Nexus on a machine: installs deps, builds the UI, generates
# and installs the systemd service for the current user, and starts it.
# Safe to re-run (e.g. after a git pull, or just re-running the one-liner
# below) to redeploy.
#
# Usage:
#   git clone https://github.com/prjvvl/nexus.git && cd nexus && ./install.sh
# or, without cloning first:
#   curl -fsSL https://raw.githubusercontent.com/prjvvl/nexus/main/install.sh | sh
set -euo pipefail

INSTALL_DIR="${NEXUS_INSTALL_DIR:-$HOME/infra/nexus}"
REPO_URL="${NEXUS_REPO_URL:-https://github.com/prjvvl/nexus.git}"

# ${BASH_SOURCE[0]} only names a real file when this script is run from a
# checkout (`./install.sh` or `bash install.sh`). Piped into a shell
# (`curl ... | sh`), there's no script file to point at, so REPO_DIR won't
# actually contain the repo - checking for main.py/nexus/ (not just that the
# path resolved) is what tells the two cases apart.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"

echo "==> Installing system dependencies"
sudo apt-get update -y

# Package name for the compose CLI plugin differs by source: Docker's own repo
# ships "docker-compose-plugin", plain Ubuntu archives ship "docker-compose-v2".
COMPOSE_PKG="docker-compose-plugin"
if ! apt-cache show docker-compose-plugin >/dev/null 2>&1; then
  COMPOSE_PKG="docker-compose-v2"
fi

sudo apt-get install -y git docker.io "$COMPOSE_PKG" python3 python3-venv python3-pip

if ! id -nG "$USER" | grep -qw docker; then
  echo "==> Adding $USER to the docker group (takes effect next login/session)"
  sudo usermod -aG docker "$USER"
fi

if ! command -v node >/dev/null 2>&1; then
  echo "==> Installing Node.js (via NodeSource)"
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if [ -f "$REPO_DIR/main.py" ] && [ -d "$REPO_DIR/nexus" ]; then
  # Running from a real checkout.
  if [ "$REPO_DIR" != "$INSTALL_DIR" ]; then
    echo "==> Copying repo to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    rsync -a --delete \
      --exclude '.git' --exclude 'ui/node_modules' --exclude 'ui/dist' \
      --exclude 'site/node_modules' --exclude 'site/dist' --exclude 'site/.astro' \
      --exclude 'state.db' --exclude 'manifest.yaml' \
      "$REPO_DIR"/ "$INSTALL_DIR"/
  fi
elif [ -d "$INSTALL_DIR/.git" ]; then
  echo "==> $INSTALL_DIR already exists, pulling latest"
  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "==> Cloning $REPO_URL to $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

if [ ! -f manifest.yaml ]; then
  echo "==> No manifest.yaml yet, seeding from manifest.example.yaml"
  cp manifest.example.yaml manifest.yaml
  echo "    Edit $INSTALL_DIR/manifest.yaml for this machine's services/jobs before relying on it."
fi

echo "==> Setting up Python venv"
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

echo "==> Building UI"
(cd ui && npm install && npm run build)

echo "==> Marking scripts executable"
chmod +x scripts/defaults/*.sh scripts/custom/*.sh 2>/dev/null || true

echo "==> Generating systemd unit for user=$USER dir=$INSTALL_DIR"
sed \
  -e "s|__NEXUS_USER__|$USER|g" \
  -e "s|__NEXUS_INSTALL_DIR__|$INSTALL_DIR|g" \
  systemd/nexus.service.template | sudo tee /etc/systemd/system/nexus.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable nexus.service
sudo systemctl restart nexus.service

echo "==> Done. Nexus running at http://$(hostname -I | awk '{print $1}'):8787"
sudo systemctl status nexus.service --no-pager
