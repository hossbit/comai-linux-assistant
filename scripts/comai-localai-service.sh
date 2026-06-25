#!/usr/bin/env bash
set -euo pipefail

AI_DIR="${COMAI_AI_DIR:-$HOME/ai}"
exec "$AI_DIR/start.sh"
