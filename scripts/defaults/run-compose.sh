#!/usr/bin/env bash
# Default starter for a service defined by a docker-compose.yml.
# Usage: run-compose.sh <app_dir>
set -euo pipefail
APP_DIR="$1"
cd "$APP_DIR"
docker compose up -d
