#!/usr/bin/env bash
# Exit 0 if any compose service in this app is running, non-zero otherwise.
# Usage: status-compose.sh <app_dir>
set -euo pipefail
APP_DIR="$1"
cd "$APP_DIR"
[ -n "$(docker compose ps --status running -q)" ]
