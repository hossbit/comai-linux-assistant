#!/usr/bin/env bash

comai_lmstudio_model() {
  printf '%s\n' "$COMAI_LMSTUDIO_MODEL"
}

comai_lmstudio_api_base() {
  printf '%s\n' "$COMAI_LMSTUDIO_API_BASE"
}

comai_lmstudio_status() {
  comai_openai_compatible_status "$COMAI_LMSTUDIO_API_BASE"
}

comai_lmstudio_models() {
  comai_openai_compatible_models "$COMAI_LMSTUDIO_API_BASE"
}

comai_lmstudio_ask() {
  comai_openai_compatible_ask "$@" "LM Studio" "You are ComAI, a terminal AI assistant running through LM Studio. Answer the actual request directly. Only give Linux commands when the user asks for a command or a command is clearly the best answer. Keep wording clean and avoid repetition."
}
