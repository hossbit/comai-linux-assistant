#!/usr/bin/env bash

comai_openai_compatible_ask() {
  local prompt="$1"
  local label="$2"
  local system_prompt="$3"
  local response content http_status response_body

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for ${label} requests."
    return 1
  fi
  comai_warn_insecure_api_base "$label" "$COMAI_API_BASE"

  response="$(
    jq -n \
      --arg model "$COMAI_MODEL" \
      --arg prompt "$prompt" \
      --arg system_prompt "$system_prompt" \
      --arg max_tokens "$COMAI_MAX_TOKENS" \
      '{
        model: $model,
        messages: [
          {role: "system", content: $system_prompt},
          {role: "user", content: $prompt}
        ],
        temperature: 0,
        max_tokens: ($max_tokens | tonumber),
        stream: false
      }' |
      curl --max-time "$COMAI_TIMEOUT" -sS -w '\n%{http_code}' "${COMAI_API_BASE}/v1/chat/completions" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  http_status="${response##*$'\n'}"
  response_body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^[0-9]{3}$ ]]; then
    comai_error "${label} API request did not return an HTTP status."
    return 1
  fi
  if [[ "$http_status" == "000" ]]; then
    content="$(printf '%s' "$response_body" | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "${label} API request failed before an HTTP response: ${content}"
    else
      comai_error "${label} API request failed before an HTTP response."
    fi
    return 1
  fi
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    content="$(
      printf '%s' "$response_body" |
        jq -r '(.error | if type == "object" then .message else . end) // empty' 2> /dev/null |
        comai_clean_ai_output
    )"
    if [[ "$http_status" == "404" && "$content" == *"no router for requested model"* ]]; then
      comai_error "${label} is running, but the configured model was not found:"
      comai_error "  $COMAI_MODEL"
      comai_error "Check the provider model and api_base in: ${COMAI_CONFIG_FILE}"
      return 1
    fi
    if [[ -n "$content" ]]; then
      comai_error "${label} API error ${http_status}: ${content}"
    else
      comai_error "${label} API error ${http_status}."
    fi
    return 1
  fi

  content="$(
    printf '%s' "$response_body" |
      jq -r '.choices[0].message.content // (.error | if type == "object" then .message else . end) // empty' |
      comai_clean_ai_output
  )"
  if [[ -z "$content" ]]; then
    comai_error "${label} returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}

comai_openai_compatible_models() {
  local api_base="$1"

  comai_warn_insecure_api_base "OpenAI-compatible provider" "$api_base"
  curl --max-time "$COMAI_TIMEOUT" -fsS "${api_base}/v1/models" | jq -r '.data[]?.id'
}

comai_openai_compatible_status() {
  local api_base="$1"

  comai_warn_insecure_api_base "OpenAI-compatible provider" "$api_base"
  curl --max-time 2 -fsS "${api_base}/v1/models" > /dev/null 2>&1
}
