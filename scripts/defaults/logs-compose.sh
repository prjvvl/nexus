#!/usr/bin/env bash
# Prints the tail of logs for a compose-based service.
# Usage: logs-compose.sh <app_dir> <lines>
set -euo pipefail
APP_DIR="$1"
LINES="${2:-200}"
cd "$APP_DIR"
docker compose logs --no-color --tail "$LINES"
