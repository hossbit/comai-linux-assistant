#!/usr/bin/env bash
set -euo pipefail

COMAI_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
COMAI_ROOT_DIR="$(cd "$(dirname "$COMAI_SCRIPT_PATH")/.." && pwd)"

# shellcheck source=../lib/comai/config.sh
. "$COMAI_ROOT_DIR/lib/comai/config.sh"
comai_load_config

case "${1:-start}" in
  start)
    exec "$COMAI_AI_DIR/start.sh"
    ;;
  stop)
    exec "$COMAI_AI_DIR/stop.sh"
    ;;
  restart)
    "$COMAI_AI_DIR/stop.sh"
    exec "$COMAI_AI_DIR/start.sh"
    ;;
  *)
    printf 'Usage: %s [start|stop|restart]\n' "$0" >&2
    exit 2
    ;;
esac
