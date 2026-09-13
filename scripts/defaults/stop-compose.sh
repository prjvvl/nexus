#!/usr/bin/env bash
# Default stopper for a service defined by a docker-compose.yml.
# Usage: stop-compose.sh <app_dir>
set -euo pipefail
APP_DIR="$1"
cd "$APP_DIR"
docker compose stop
