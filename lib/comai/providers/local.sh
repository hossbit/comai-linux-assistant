#!/usr/bin/env bash

comai_local_model() {
  printf '%s\n' "$COMAI_LOCAL_MODEL"
}

comai_local_api_base() {
  printf '%s\n' "$COMAI_LOCAL_API_BASE"
}

# comai_local_ensure_api_key: best-effort key resolution (config, api_key_cmd,
# or LOCALAI_API_KEY). Unlike comai_{openai,gemini,openrouter}_ensure_api_key,
# an unresolved key is NOT an error and always returns 0 -- a local server
# with no active keys (the default, e.g. before `localai key create`) is
# expected to work completely unauthenticated.
comai_local_ensure_api_key() {
  comai_ensure_provider_api_key local LOCALAI_API_KEY COMAI_LOCAL_API_KEY COMAI_LOCAL_API_KEY_CMD COMAI_LOCAL_CONFIG_API_KEY COMAI_ALLOW_LOCAL_KEY_CMD COMAI_LOCAL_API_KEY_STATUS || true
}

# comai_local_curl: attaches Authorization only when a key resolved; plain
# curl otherwise, so an unauthenticated local server behaves exactly as
# before this feature existed.
comai_local_curl() {
  if [[ -n "${COMAI_LOCAL_API_KEY:-}" ]]; then
    curl "$@" --config /dev/fd/3 3<<< "header = \"Authorization: Bearer $(comai_curl_config_quote "$COMAI_LOCAL_API_KEY")\""
  else
    curl "$@"
  fi
}

comai_local_status() {
  comai_local_ensure_api_key
  comai_openai_compatible_status "$COMAI_LOCAL_API_BASE" comai_local_curl
}

comai_local_models() {
  comai_local_ensure_api_key
  comai_openai_compatible_models "$COMAI_LOCAL_API_BASE" comai_local_curl
}

comai_local_ask() {
  comai_local_ensure_api_key
  comai_openai_compatible_ask "$@" "local provider" "You are ComAI, a local terminal AI assistant. Do not use canned answers. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition." comai_local_curl
}
