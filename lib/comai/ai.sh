#!/usr/bin/env bash

comai_ai_prompt() {
  local request="$1"
  local dir_context="$2"
  local files="$3"

  if [[ -z "$dir_context" && -z "$files" ]]; then
    cat << EOF
User request:
${request}

Answer briefly and clearly. If the user asks a factual question, answer it directly.
Only give a Linux command when the user asks for a command or when a command is clearly the best answer.
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
  comai_provider_ask "$@"
}
