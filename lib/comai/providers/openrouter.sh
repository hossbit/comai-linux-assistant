#!/usr/bin/env bash

comai_openrouter_model() {
  printf '%s\n' "$COMAI_OPENROUTER_MODEL"
}

comai_openrouter_api_base() {
  printf '%s\n' "$COMAI_OPENROUTER_API_BASE"
}

comai_openrouter_ensure_api_key() {
  comai_ensure_provider_api_key openrouter OPENROUTER_API_KEY COMAI_OPENROUTER_API_KEY COMAI_OPENROUTER_API_KEY_CMD COMAI_OPENROUTER_CONFIG_API_KEY COMAI_ALLOW_OPENROUTER_KEY_CMD COMAI_OPENROUTER_API_KEY_STATUS
}

comai_openrouter_curl_auth() {
  local key="$1"
  shift

  curl "$@" --config /dev/fd/3 3<<< "header = \"Authorization: Bearer $(comai_curl_config_quote "$key")\""
}

comai_openrouter_status() {
  comai_warn_insecure_api_base openrouter "$COMAI_OPENROUTER_API_BASE"
  if ! comai_openrouter_ensure_api_key; then
    case "${COMAI_OPENROUTER_API_KEY_STATUS:-missing}" in
      deferred) return 5 ;;
      command_failed) return 3 ;;
      untrusted_config) return 4 ;;
      *) return 2 ;;
    esac
  fi
  comai_openrouter_curl_auth "$COMAI_OPENROUTER_API_KEY" --max-time 5 -fsS "${COMAI_OPENROUTER_API_BASE}/v1/models" > /dev/null 2>&1
}

comai_openrouter_models() {
  comai_warn_insecure_api_base openrouter "$COMAI_OPENROUTER_API_BASE"
  comai_openrouter_ensure_api_key || {
    comai_error "OPENROUTER_API_KEY or openrouter_api_key is required for OpenRouter."
    return 1
  }
  comai_openrouter_curl_auth "$COMAI_OPENROUTER_API_KEY" --max-time "$COMAI_TIMEOUT" -fsS "${COMAI_OPENROUTER_API_BASE}/v1/models" | jq -r '.data[]?.id'
}

comai_openrouter_ask() {
  local prompt="$1"
  local response content http_status response_body

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for OpenRouter requests."
    return 1
  fi
  comai_warn_insecure_api_base openrouter "$COMAI_API_BASE"

  if ! comai_openrouter_ensure_api_key; then
    case "${COMAI_OPENROUTER_API_KEY_STATUS:-missing}" in
      command_failed)
        comai_error "OpenRouter api_key_cmd did not print an API key."
        comai_error "Check api_key_cmd in: ${COMAI_CONFIG_FILE}"
        ;;
      untrusted_config)
        comai_error "Refusing to run OpenRouter api_key_cmd from an untrusted config file."
        comai_error "Fix ownership and permissions on: ${COMAI_CONFIG_FILE}"
        ;;
      *)
        comai_error "OpenRouter API key is required."
        comai_error "Set providers.openrouter.api_key in config/comai.yaml or export OPENROUTER_API_KEY."
        ;;
    esac
    return 1
  fi

  response="$(
    jq -n \
      --arg model "$COMAI_MODEL" \
      --arg prompt "$prompt" \
      --arg max_tokens "$COMAI_MAX_TOKENS" \
      '{
        model: $model,
        messages: [
          {role: "system", content: "You are ComAI, a terminal AI assistant running through OpenRouter. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition."},
          {role: "user", content: $prompt}
        ],
        temperature: 0,
        max_tokens: ($max_tokens | tonumber),
        stream: false
      }' |
      comai_openrouter_curl_auth "$COMAI_OPENROUTER_API_KEY" \
        --max-time "$COMAI_TIMEOUT" -sS -w '\n%{http_code}' "${COMAI_API_BASE}/v1/chat/completions" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  http_status="${response##*$'\n'}"
  response_body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^[0-9]{3}$ ]]; then
    comai_error "OpenRouter API request did not return an HTTP status."
    return 1
  fi
  if [[ "$http_status" == "000" ]]; then
    content="$(printf '%s' "$response_body" | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "OpenRouter API request failed before an HTTP response: ${content}"
    else
      comai_error "OpenRouter API request failed before an HTTP response."
    fi
    return 1
  fi
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    content="$(
      printf '%s' "$response_body" |
        jq -r '(.error | if type == "object" then .message else . end) // empty' 2> /dev/null |
        comai_clean_ai_output
    )"
    if [[ -n "$content" ]]; then
      comai_error "OpenRouter API error ${http_status}: ${content}"
    else
      comai_error "OpenRouter API error ${http_status}."
    fi
    return 1
  fi

  content="$(
    printf '%s' "$response_body" |
      jq -r '.choices[0].message.content // (.error | if type == "object" then .message else . end) // empty' |
      comai_clean_ai_output
  )"
  if [[ -z "$content" ]]; then
    comai_error "OpenRouter returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}
