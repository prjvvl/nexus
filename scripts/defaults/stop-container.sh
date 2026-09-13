#!/usr/bin/env bash
# Default stopper for a single-container service started by run-container.sh.
# Usage: stop-container.sh <app_dir> <container_name>
set -euo pipefail
NAME="$2"
docker stop "$NAME"
