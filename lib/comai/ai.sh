#!/usr/bin/env bash

comai_ai_prompt() {
  local request="$1"
  local dir_context="$2"
  local files="$3"

  if [[ -z "$dir_context" && -z "$files" ]]; then
    cat <<EOF
User request:
${request}

Answer briefly and clearly.
EOF
    return
  fi

  cat <<EOF
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
  sed -E '
    s/[[:space:]]+$//;
    s/`{2,}/`/g;
    s/[,،]{2,}/,/g;
    s/[.]{2,}/./g;
    s/[[:space:]]+([,.:;])/\1/g;
  ' | awk '
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

    NF == 0 {
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
  local prompt="$1"
  local response content

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required for local AI requests."
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
          {role: "system", content: "You are ComAI, a local Linux assistant. Do not use canned answers. Use the provided live context and answer the actual request. Keep wording clean and avoid repetition."},
          {role: "user", content: $prompt}
        ],
        temperature: 0,
        max_tokens: ($max_tokens | tonumber),
        stream: false
      }' \
      | curl --max-time "$COMAI_TIMEOUT" -fsS "${COMAI_API_BASE}/v1/chat/completions" \
          -H 'Content-Type: application/json' \
          --data-binary @-
  )"

  content="$(printf '%s' "$response" | jq -r '.choices[0].message.content // .error.message // empty' | comai_clean_ai_output)"
  if [[ -z "$content" ]]; then
    comai_error "local AI returned an empty response with model ${COMAI_MODEL}."
    return 1
  fi

  printf '%s\n' "$content"
}
