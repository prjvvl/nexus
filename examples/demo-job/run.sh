#!/usr/bin/env bash
# Demo job: appends a timestamped line to output.log every time it runs.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "demo job ran at $(date -u +%FT%TZ)" >> "$DIR/output.log"
