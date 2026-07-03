#!/usr/bin/env bash
set -euo pipefail

COMAI_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
COMAI_ROOT_DIR="$(cd "$(dirname "$COMAI_SCRIPT_PATH")/.." && pwd)"

# shellcheck source=../lib/comai/config.sh
. "$COMAI_ROOT_DIR/lib/comai/config.sh"
comai_load_config

localai_helper() {
  local name="$1"

  if [[ -x "$COMAI_AI_DIR/bin/$name" ]]; then
    printf '%s\n' "$COMAI_AI_DIR/bin/$name"
  elif [[ -x "$COMAI_AI_DIR/$name" ]]; then
    printf '%s\n' "$COMAI_AI_DIR/$name"
  else
    printf 'ComAI LocalAI helper not found: %s/bin/%s or %s/%s\n' "$COMAI_AI_DIR" "$name" "$COMAI_AI_DIR" "$name" >&2
    exit 1
  fi
}

case "${1:-start}" in
  start)
    exec "$(localai_helper start.sh)"
    ;;
  stop)
    exec "$(localai_helper stop.sh)"
    ;;
  restart)
    "$(localai_helper stop.sh)"
    exec "$(localai_helper start.sh)"
    ;;
  *)
    printf 'Usage: %s [start|stop|restart]\n' "$0" >&2
    exit 2
    ;;
esac
