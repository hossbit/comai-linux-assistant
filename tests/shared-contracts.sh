#!/usr/bin/env bash
# Same contracts run against either edition; pass a repository root.
# shellcheck disable=SC2034,SC1090,SC1091
set -euo pipefail
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$root/lib/comai/context.sh"
. "$root/lib/comai/ai.sh"
. "$root/lib/comai/config/keys.sh"
. "$root/lib/comai/cli/runtime.sh"
. "$root/lib/comai/cli/providers.sh"
. "$root/lib/comai/cli/update.sh"
comai_error() { printf '%s\n' "$*" >&2; }
comai_have() { command -v "$1" >/dev/null; }
comai_provider_allow_key_cmd() { :; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
FILES=()
COMAI_PROVIDER=openai
COMAI_ASSUME_YES=0
COMAI_CLOUD_FILE_CONFIRM=1
comai_provider_requires_key() { [[ "$1" == openai || "$1" == gemini || "$1" == openrouter ]]; }
if comai_confirm_cloud_file_context 'private listing' < /dev/null 2>/dev/null; then exit 1; fi
comai_confirm_cloud_file_context '' < /dev/null
COMAI_ASSUME_YES=1
comai_confirm_cloud_file_context 'approved listing' < /dev/null 2>/dev/null
COMAI_ASSUME_YES=0
COMAI_PROVIDER=local
comai_confirm_cloud_file_context 'local listing' < /dev/null
COMAI_INPUT_MAX_BYTES=300
COMAI_FILE_MAX_BYTES=24000
COMAI_CONTEXT_REMAINING=300
FILES=("$tmp/first.txt" "$tmp/second.txt" "$tmp/third.txt")
for file in "${FILES[@]}"; do printf '%0500d' 7 > "$file"; done
context="$(comai_file_context 2> "$tmp/omissions")"
[[ "$(LC_ALL=C printf '%s' "$context" | wc -c)" -le 300 ]]
[[ "$(cat "$tmp/omissions")" == *'third.txt'* ]]
printf 'FIRST\n%s\nLAST\n' "$(printf '%0500d' 0)" > "$tmp/log.txt"
FILES=("$tmp/log.txt")
COMAI_CONTEXT_TAIL=1
context="$(comai_file_context 2>/dev/null)"
[[ "$context" == *LAST* && "$context" != *FIRST* ]]
comai_provider_ask() { printf 'request made'; }
if comai_ask_ai "$(printf '%0400d' 0)" > "$tmp/output" 2>/dev/null; then exit 1; fi
[[ ! -s "$tmp/output" ]]
stdin_text="$(printf '%0301d' 0 | comai_read_stdin_if_piped 2> "$tmp/stdin-warning")"
[[ "$(LC_ALL=C printf '%s' "$stdin_text" | wc -c)" -eq 300 ]]
[[ "$(cat "$tmp/stdin-warning")" == *'omitted bytes'* ]]
# Preserve trailing newline long enough to detect truncation.
stdin_text="$( { printf '%0300d' 0; printf '\n'; } | comai_read_stdin_if_piped 2> "$tmp/stdin-warning")"
[[ "$(cat "$tmp/stdin-warning")" == *'omitted bytes'* ]]
COMAI_PROVIDER=local
COMAI_MODEL=fixture
COMAI_API_BASE=http://localhost:9999
curl() {
 local path='' arg next=0
 for arg in "$@"; do
   if [[ "$next" == 1 ]]; then path="$arg"; next=0; fi
   [[ "$arg" != -o ]] || next=1
 done
 printf '%s' "${BODY:-}" > "$path"
 printf '%s' "${HTTP:-200}"
 return "${CURL_STATUS:-0}"
}
BODY='{"data":[{"id":"fixture"}]}'
output="$(comai_cmd_doctor --json)"
jq -e '.ok and .status == "ok"' <<< "$output" >/dev/null
for pair in '401 bad_credentials' '503 server_unavailable' '429 rate_limited'; do
 read -r HTTP expected <<< "$pair"
 output="$(comai_cmd_doctor --json || true)"
 jq -e --arg expected "$expected" '.status == $expected and (.ok|not)' <<< "$output" >/dev/null
done
HTTP=200
BODY='{"data":[{"id":"missing"}]}'
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "missing_model"' <<< "$output" >/dev/null
BODY='private credential response not JSON'
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "invalid_response"' <<< "$output" >/dev/null
[[ "$output" != *'private credential'* ]]
CURL_STATUS=28
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "timeout"' <<< "$output" >/dev/null
CURL_STATUS=7
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "unreachable"' <<< "$output" >/dev/null
CURL_STATUS=0
COMAI_PROVIDER=openai
comai_openai_ensure_api_key() { COMAI_OPENAI_API_KEY_STATUS=missing; return 1; }
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "missing_credentials"' <<< "$output" >/dev/null
COMAI_API_BASE='https://credential@example.test'
output="$(comai_cmd_doctor --json || true)"
jq -e '.status == "invalid_endpoint"' <<< "$output" >/dev/null
[[ "$output" != *credential* ]]
# Resolve annotated releases to their immutable object rather than a mutable branch.
git() { printf '%s\t%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa refs/tags/v1.2.0 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb 'refs/tags/v1.2.0^{}'; }
[[ "$(comai_update_resolve fixture v1.2.0)" == 'v1.2.0 bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' ]]
if comai_update_resolve fixture main >/dev/null 2>&1; then exit 1; fi
printf 'shared contracts: ok (%s)\n' "$root"
