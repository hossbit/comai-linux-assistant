#!/usr/bin/env bash

if [[ -n "${COMAI_ROOT_DIR:-}" ]]; then
  COMAI_CONFIG_MODULE_DIR="$COMAI_ROOT_DIR/lib/comai/config"
else
  COMAI_CONFIG_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/config" && pwd)"
fi

# shellcheck source=/dev/null
. "$COMAI_CONFIG_MODULE_DIR/yaml.sh"
# shellcheck source=/dev/null
. "$COMAI_CONFIG_MODULE_DIR/files.sh"
# shellcheck source=/dev/null
. "$COMAI_CONFIG_MODULE_DIR/write.sh"
# shellcheck source=/dev/null
. "$COMAI_CONFIG_MODULE_DIR/keys.sh"
# shellcheck source=/dev/null
. "$COMAI_CONFIG_MODULE_DIR/load.sh"
