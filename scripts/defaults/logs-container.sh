#!/usr/bin/env bash
# Prints the tail of logs for a single container.
# Usage: logs-container.sh <app_dir> <container_name> <lines>
set -euo pipefail
NAME="$2"
LINES="${3:-200}"
docker logs --tail "$LINES" "$NAME" 2>&1
