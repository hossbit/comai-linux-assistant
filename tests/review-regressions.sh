#!/usr/bin/env bash

# Config globals are consumed by separately sourced modules.
# shellcheck disable=SC2034
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT_DIR/lib/comai/config/keys.sh"
. "$ROOT_DIR/lib/comai/ai.sh"
. "$ROOT_DIR/lib/comai/cli/runtime.sh"
comai_error() { printf '%s\n' "$*" >&2; }
original=$'    echo ../path\nrepeat repeat\nrepeat repeat\nسلام، دنیا'
actual="$(printf '%s\n' "$original" | comai_clean_ai_output)"
[[ "$actual" == "$original" ]]
actual="$(printf '\033[31mhello\007\n' | comai_clean_ai_output)"
[[ "$actual" != *$'\033'* && "$actual" != *$'\007'* ]]
comai_provider_requires_key() { [[ "$1" == openai || "$1" == gemini || "$1" == openrouter ]]; }
FILES=()
COMAI_PROVIDER=openai
COMAI_ASSUME_YES=0
COMAI_CLOUD_FILE_CONFIRM=1
if comai_confirm_cloud_file_context 'private directory listing' < /dev/null 2>/dev/null; then
  printf 'Directory-only cloud context bypassed confirmation\n' >&2
  exit 1
fi
comai_confirm_cloud_file_context '' < /dev/null
COMAI_ASSUME_YES=1
comai_confirm_cloud_file_context 'approved listing' < /dev/null 2>/dev/null
COMAI_ASSUME_YES=0
COMAI_PROVIDER=local
comai_confirm_cloud_file_context 'local listing' < /dev/null
printf 'tests/review-regressions.sh: ok\n'

. "$ROOT_DIR/lib/comai/config/files.sh"
comai_api_base_is_loopback_http 'http://127.0.0.1:1234/v1'
comai_api_base_is_loopback_http 'http://[::1]:1234/v1'
if comai_api_base_is_loopback_http 'http://127.attacker.example'; then exit 1; fi
if comai_api_base_is_loopback_http 'http://localhost:1234@attacker.example'; then exit 1; fi
. "$ROOT_DIR/lib/comai/cli/update.sh"
test_update_dir="$(mktemp -d)"
trap 'rm -rf "$test_update_dir"' EXIT
COMAI_ROOT_DIR="$test_update_dir"
COMAI_SOURCE_URL='https://example.invalid/test'
COMAI_REF=main
COMAI_TARBALL_BASE='https://example.invalid/archive'
COMAI_TARBALL_SHA256=''
comai_have() { [[ "$1" == git ]]; }
git() { return 37; }
update_status=0
comai_cmd_update > /dev/null 2>&1 || update_status=$?
[[ "$update_status" == 37 ]]
mkdir "$test_update_dir/.git"
update_status=0
comai_cmd_update > /dev/null 2>&1 || update_status=$?
[[ "$update_status" == 37 ]]

printf 'preview fixture 9876\n' > "$test_update_dir/preview.txt"
preview="$(COMAI_LOG_ENABLED=0 COMAI_HISTORY_ENABLED=0 COMAI_SPINNER=0 "$ROOT_DIR/bin/comai" context -f "$test_update_dir/preview.txt")"
[[ "$preview" == *'Context preview only: no provider request.'* ]]
[[ "$preview" == *'preview fixture 9876'* ]]
