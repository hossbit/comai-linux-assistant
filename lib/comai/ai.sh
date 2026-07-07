#!/usr/bin/env bash

comai_ai_prompt() {
  local request="$1"
  local dir_context="$2"
  local files="$3"

  if [[ -z "$dir_context" && -z "$files" ]]; then
    cat << EOF
User request:
${request}

Answer briefly and clearly.
EOF
    return
  fi

  cat << EOF
User request:
${request}

${dir_context}

${files}

Answer the user's actual request. For direct factual local questions, answer first in one or two plain sentences.
Use the current directory context when the user asks about files here, newest files, largest files, scripts, logs, project contents, or similar local information.
If the user asks for a Linux command, explain the command clearly and prefer safe read-only commands unless they clearly ask to change the system.
If file content is provided, use it as context and say when the answer depends on only the included excerpt.
EOF
}

comai_clean_ai_output() {
  LC_ALL=C awk '
    function norm_word(word) {
      word = tolower(word)
      gsub(/^[^[:alnum:]_]+|[^[:alnum:]_]+$/, "", word)
      return word
    }

    function dedupe_words(line,    count, parts, out, i, word, prev) {
      count = split(line, parts, /[[:space:]]+/)
      out = ""
      prev = ""
      for (i = 1; i <= count; i++) {
        word = norm_word(parts[i])
        if (word != "" && word == prev) {
          continue
        }
        out = out (out == "" ? "" : " ") parts[i]
        if (word != "") {
          prev = word
        }
      }
      return out
    }

    {
      gsub(/[\001-\010\013\014\016-\037\177]/, "")
      sub(/[[:space:]]+$/, "")
      gsub(/`{2,}/, "`")
      gsub(/[,،]{2,}/, ",")
      gsub(/[.]{2,}/, ".")
      while (match($0, /[[:space:]]+[,.:;]/)) {
        $0 = substr($0, 1, RSTART - 1) substr($0, RSTART + RLENGTH - 1, 1) substr($0, RSTART + RLENGTH)
      }
    }
    $0 == "" {
      if (!blank) {
        print
        blank = 1
      }
      next
    }
    {
      blank = 0
      $0 = dedupe_words($0)
      if ($0 != prev) {
        print
      }
      prev = $0
    }
  '
}

comai_ask_ai() {
  case "$COMAI_PROVIDER" in
    openai)
      comai_ask_openai "$@"
      ;;
    ollama)
      comai_ask_ollama "$@"
      ;;
    lmstudio)
      comai_ask_openai_compatible "$@" "LM Studio" "You are ComAI, a Linux command assistant running through LM Studio. Use the provided live context and answer the actual request. Keep wording clean and avoid repetition."
      ;;
    *)
      comai_ask_local_ai "$@"
      ;;
  esac
}

comai_ask_local_ai() {
  comai_ask_openai_compatible "$@" "local provider" "You are ComAI, a local Linux assistant. Do not use canned answers. Use the provided live context and answer the actual request. Keep wording clean and avoid repetition."
}

comai_ask_openai_compatible() {
  local prompt="$1"
  local label="$2"
  local system_prompt="$3"
  local response content http_status response_body

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for ${label} requests."
    return 1
  fi

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

comai_ask_ollama() {
  local prompt="$1"
  local response content

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
          {role: "system", content: "You are ComAI, a Linux command assistant running through Ollama. Use the provided live context and answer the actual request. Keep wording clean and avoid repetition."},
          {role: "user", content: $prompt}
        ],
        options: {
          temperature: 0,
          num_predict: ($max_tokens | tonumber)
        },
        stream: false
      }' |
      curl --max-time "$COMAI_TIMEOUT" -fsS "${COMAI_API_BASE}/api/chat" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  content="$(printf '%s' "$response" | jq -r '.message.content // .error // empty' | comai_clean_ai_output)"
  if [[ -z "$content" ]]; then
    comai_error "Ollama returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}

comai_ask_openai() {
  local prompt="$1"
  local response content http_status response_body

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for OpenAI requests."
    return 1
  fi

  if ! comai_ensure_openai_api_key; then
    case "${COMAI_OPENAI_API_KEY_STATUS:-missing}" in
      command_failed)
        comai_error "OpenAI api_key_cmd did not print an API key."
        comai_error "Check api_key_cmd in: ${COMAI_CONFIG_FILE}"
        ;;
      untrusted_config)
        comai_error "Refusing to run OpenAI api_key_cmd from an untrusted config file."
        comai_error "Fix ownership and permissions on: ${COMAI_CONFIG_FILE}"
        ;;
      *)
        comai_error "OpenAI API key is required for ChatGPT requests."
        comai_error "Set openai_api_key in config/comai.yaml or export OPENAI_API_KEY."
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
        input: [
          {role: "system", content: "You are ComAI, a Linux command assistant. Use the provided live context and answer the actual request. Keep wording clean and avoid repetition."},
          {role: "user", content: $prompt}
        ],
        max_output_tokens: ($max_tokens | tonumber)
      }' |
      comai_curl_openai_auth "$COMAI_OPENAI_API_KEY" \
        --max-time "$COMAI_TIMEOUT" -sS -w '\n%{http_code}' "${COMAI_API_BASE}/v1/responses" \
        -H 'Content-Type: application/json' \
        --data-binary @-
  )"

  http_status="${response##*$'\n'}"
  response_body="${response%$'\n'*}"
  if [[ ! "$http_status" =~ ^[0-9]{3}$ ]]; then
    comai_error "OpenAI API request did not return an HTTP status."
    return 1
  fi
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    content="$(printf '%s' "$response_body" | jq -r '.error.message // empty' 2> /dev/null | comai_clean_ai_output)"
    if [[ -n "$content" ]]; then
      comai_error "OpenAI API error ${http_status}: ${content}"
    else
      comai_error "OpenAI API error ${http_status}."
    fi
    return 1
  fi

  content="$(
    printf '%s' "$response_body" |
      jq -r '.output_text // ([.output[]?.content[]? | select(.type == "output_text") | .text] | join("\n")) // .error.message // empty' |
      comai_clean_ai_output
  )"
  if [[ -z "$content" ]]; then
    comai_error "OpenAI returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}
