#!/usr/bin/env bash

comai_gemini_model() {
  printf '%s\n' "$COMAI_GEMINI_MODEL"
}

comai_gemini_api_base() {
  printf '%s\n' "$COMAI_GEMINI_API_BASE"
}

comai_gemini_ensure_api_key() {
  comai_ensure_provider_api_key gemini GEMINI_API_KEY COMAI_GEMINI_API_KEY COMAI_GEMINI_API_KEY_CMD COMAI_GEMINI_CONFIG_API_KEY COMAI_ALLOW_GEMINI_KEY_CMD COMAI_GEMINI_API_KEY_STATUS
}

comai_gemini_curl_key() {
  local key="$1"
  shift

  curl "$@" --config /dev/fd/3 3<<< "header = \"x-goog-api-key: $(comai_curl_config_quote "$key")\""
}

comai_gemini_status() {
  comai_warn_insecure_api_base gemini "$COMAI_GEMINI_API_BASE"
  if ! comai_gemini_ensure_api_key; then
    case "${COMAI_GEMINI_API_KEY_STATUS:-missing}" in
      deferred) return 5 ;;
      command_failed) return 3 ;;
      untrusted_config) return 4 ;;
      *) return 2 ;;
    esac
  fi
  comai_gemini_curl_key "$COMAI_GEMINI_API_KEY" --max-time 5 -fsS "${COMAI_GEMINI_API_BASE}/v1beta/models" > /dev/null 2>&1
}

comai_gemini_models() {
  comai_warn_insecure_api_base gemini "$COMAI_GEMINI_API_BASE"
  comai_gemini_ensure_api_key || {
    comai_error "GEMINI_API_KEY or providers.gemini.api_key is required for Gemini."
    return 1
  }
  comai_gemini_curl_key "$COMAI_GEMINI_API_KEY" --max-time "$COMAI_TIMEOUT" -fsS "${COMAI_GEMINI_API_BASE}/v1beta/models" | jq -r '.models[]?.name | sub("^models/"; "")'
}

comai_gemini_ask() {
  local prompt="$1"
  local response content http_status response_body model_path api_base

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for Gemini requests."
    return 1
  fi
  comai_warn_insecure_api_base gemini "$COMAI_API_BASE"

  if ! comai_gemini_ensure_api_key; then
    case "${COMAI_GEMINI_API_KEY_STATUS:-missing}" in
      command_failed)
        comai_error "Gemini api_key_cmd did not print an API key."
        comai_error "Check api_key_cmd in: ${COMAI_CONFIG_FILE}"
        ;;
      untrusted_config)
        comai_error "Refusing to run Gemini api_key_cmd from an untrusted config file."
        comai_error "Fix ownership and permissions on: ${COMAI_CONFIG_FILE}"
        ;;
      *)
        comai_error "Gemini API key is required."
        comai_error "Set providers.gemini.api_key in config/comai.yaml or export GEMINI_API_KEY."
        ;;
    esac
    return 1
  fi

  model_path="$COMAI_MODEL"
  [[ "$model_path" == models/* ]] || model_path="models/$model_path"
  api_base="$(comai_trim_trailing_slashes "$COMAI_API_BASE")"

  response="$(
    jq -n \
      --arg prompt "$prompt" \
      --arg max_tokens "$COMAI_MAX_TOKENS" \
      '{
        systemInstruction: {
          parts: [
            {text: "You are ComAI, a terminal AI assistant running through Gemini. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition."}
          ]
        },
        contents: [
          {
            role: "user",
            parts: [
              {text: $prompt}
            ]
          }
        ],
        generationConfig: {
          temperature: 0,
          maxOutputTokens: ($max_tokens | tonumber)
        }
      }' |
      comai_gemini_curl_key "$COMAI_GEMINI_API_KEY" \
        --max-time "$COMAI_TIMEOUT" -sS -w '\n%{http_code}' "${api_base}/v1beta/${model_path}:generateContent" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  http_status="${response##*$'\n'}"
  response_body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^[0-9]{3}$ ]]; then
    comai_error "Gemini API request did not return an HTTP status."
    return 1
  fi
  if [[ "$http_status" == "000" ]]; then
    content="$(printf '%s' "$response_body" | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "Gemini API request failed before an HTTP response: ${content}"
    else
      comai_error "Gemini API request failed before an HTTP response."
    fi
    return 1
  fi
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    content="$(printf '%s' "$response_body" | jq -r '.error.message // empty' 2> /dev/null | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "Gemini API error ${http_status}: ${content}"
    else
      comai_error "Gemini API error ${http_status}."
    fi
    return 1
  fi

  content="$(
    printf '%s' "$response_body" |
      jq -r '([.candidates[]?.content.parts[]?.text] | join("\n")) // .error.message // empty' |
      comai_clean_ai_output
  )"
  if [[ -z "$content" ]]; then
    comai_error "Gemini returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}
