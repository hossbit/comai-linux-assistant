#!/usr/bin/env bash

comai_ollama_model() {
  printf '%s\n' "$COMAI_OLLAMA_MODEL"
}

comai_ollama_api_base() {
  printf '%s\n' "$COMAI_OLLAMA_API_BASE"
}

comai_ollama_status() {
  curl --max-time 2 -fsS "${COMAI_OLLAMA_API_BASE}/api/tags" > /dev/null 2>&1
}

comai_ollama_models() {
  curl --max-time "$COMAI_TIMEOUT" -fsS "${COMAI_OLLAMA_API_BASE}/api/tags" | jq -r '.models[]?.name'
}

comai_ollama_ask() {
  local prompt="$1"
  local response content http_status response_body

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for Ollama requests."
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
          {role: "system", content: "You are ComAI, a terminal AI assistant running through Ollama. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition."},
          {role: "user", content: $prompt}
        ],
        options: {
          temperature: 0,
          num_predict: ($max_tokens | tonumber)
        },
        stream: false
      }' |
      curl --max-time "$COMAI_TIMEOUT" -sS -w '\n%{http_code}' "${COMAI_API_BASE}/api/chat" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  http_status="${response##*$'\n'}"
  response_body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^[0-9]{3}$ ]]; then
    comai_error "Ollama API request did not return an HTTP status."
    return 1
  fi
  if [[ "$http_status" == "000" ]]; then
    content="$(printf '%s' "$response_body" | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "Ollama API request failed before an HTTP response: ${content}"
    else
      comai_error "Ollama API request failed before an HTTP response."
    fi
    return 1
  fi
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    content="$(printf '%s' "$response_body" | jq -r '.error // empty' 2> /dev/null | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "Ollama API error ${http_status}: ${content}"
    else
      comai_error "Ollama API error ${http_status}."
    fi
    return 1
  fi

  content="$(printf '%s' "$response_body" | jq -r '.message.content // .error // empty' | comai_clean_ai_output)"
  if [[ -z "$content" ]]; then
    comai_error "Ollama returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}
