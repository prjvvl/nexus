#!/usr/bin/env bash
# Exit 0 if the named container is running, non-zero otherwise.
# Usage: status-container.sh <app_dir> <container_name>
set -euo pipefail
NAME="$2"
[ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null || echo false)" = "true" ]
