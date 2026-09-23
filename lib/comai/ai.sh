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
  # Preserve code, paths, indentation, repeated lines, and Unicode verbatim.
  # Only remove terminal control bytes; prose heuristics corrupt shell output.
  comai_strip_terminal_controls
}

comai_ask_ai() {
  comai_provider_ask "$@"
}
