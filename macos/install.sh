#!/usr/bin/env bash
# Bootstraps Nexus on macOS: creates the venv, builds the UI, seeds
# manifest.yaml, and installs a launchd LaunchAgent that starts Nexus at
# login and keeps it running (KeepAlive, mirroring systemd's Restart=always
# on Linux - see systemd/nexus.service.template). Safe to re-run.
#
# Usage (from a checkout):
#   cd nexus
#   ./macos/install.sh
#
# Unlike install.sh (Linux), this does not install Python/Node/Docker for
# you - macOS has no single package manager every machine already has.
# Homebrew (https://brew.sh) is the de facto standard: `brew install python
# node`, plus Docker Desktop or `brew install --cask docker` if any of your
# services use docker compose. Install what you need, then run this script.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

command -v python3 >/dev/null 2>&1 || {
  echo "python3 not found. Install it (e.g. 'brew install python') and re-run." >&2
  exit 1
}

if [ ! -f manifest.yaml ]; then
  echo "==> No manifest.yaml yet, seeding from manifest.example.yaml"
  cp manifest.example.yaml manifest.yaml
  echo "    Edit $REPO_DIR/manifest.yaml for this machine's services/jobs before relying on it."
fi

echo "==> Setting up Python venv"
python3 -m venv venv
./venv/bin/pip install --upgrade pip
./venv/bin/pip install -r requirements.txt

if command -v npm >/dev/null 2>&1; then
  echo "==> Building UI"
  (cd ui && npm install && npm run build)
else
  echo "==> npm not found, skipping UI build (install Node.js to get the dashboard)" >&2
fi

echo "==> Marking scripts executable"
chmod +x scripts/defaults/*.sh scripts/custom/*.sh 2>/dev/null || true

LABEL="com.prjvvl.nexus"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Library/LaunchAgents"

# Homebrew lands in different places on Apple Silicon vs Intel, and launchd
# agents get a minimal PATH by default - pin one wide enough that service
# and job scripts can still find docker/node/git however they were
# installed. That alone misses a version manager (nvm/volta/asdf), which
# puts node/npm somewhere else on PATH that isn't a fixed location -
# so also capture wherever *this shell* actually resolves them right now
# and fold those directories in too, instead of only the Homebrew/system
# defaults that worked for the install-time checks above but wouldn't for
# the service once it's running under launchd's own minimal PATH.
NEXUS_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
for cmd in node npm docker; do
  resolved="$(command -v "$cmd" 2>/dev/null || true)"
  if [ -n "$resolved" ]; then
    dir="$(cd "$(dirname "$resolved")" && pwd)"
    case ":$NEXUS_PATH:" in
      *":$dir:"*) ;;
      *) NEXUS_PATH="$NEXUS_PATH:$dir" ;;
    esac
  fi
done

echo "==> Installing launchd agent for dir=$REPO_DIR"
sed \
  -e "s|__NEXUS_INSTALL_DIR__|$REPO_DIR|g" \
  -e "s|__NEXUS_PATH__|$NEXUS_PATH|g" \
  macos/com.prjvvl.nexus.plist.template > "$PLIST"

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "==> Done. Nexus running at http://localhost:8787"
echo "    Logs: $REPO_DIR/nexus.out.log / nexus.err.log"
echo "    Manage: launchctl print gui/$(id -u)/$LABEL"
