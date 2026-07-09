#!/usr/bin/env bash

comai_local_model() {
  printf '%s\n' "$COMAI_LOCAL_MODEL"
}

comai_local_api_base() {
  printf '%s\n' "$COMAI_LOCAL_API_BASE"
}

comai_local_status() {
  comai_openai_compatible_status "$COMAI_LOCAL_API_BASE"
}

comai_local_models() {
  comai_openai_compatible_models "$COMAI_LOCAL_API_BASE"
}

comai_local_ask() {
  comai_openai_compatible_ask "$@" "local provider" "You are ComAI, a local terminal AI assistant. Do not use canned answers. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition."
}
