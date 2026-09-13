#!/usr/bin/env bash
# Default starter for a service defined by a single Dockerfile (no compose file).
# Usage: run-container.sh <app_dir> <container_name> [port_mapping]
set -euo pipefail
APP_DIR="$1"
NAME="$2"
PORT_MAPPING="${3:-}"
cd "$APP_DIR"
docker build -t "$NAME" .
docker rm -f "$NAME" 2>/dev/null || true
if [ -n "$PORT_MAPPING" ]; then
  docker run -d --name "$NAME" --restart unless-stopped -p "$PORT_MAPPING" "$NAME"
else
  docker run -d --name "$NAME" --restart unless-stopped "$NAME"
fi
