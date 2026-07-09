#!/usr/bin/env bash

COMAI_PROVIDERS=(local ollama lmstudio openai gemini)

comai_provider_exists() {
  local provider="$1"
  local known

  for known in "${COMAI_PROVIDERS[@]}"; do
    [[ "$known" == "$provider" ]] && return 0
  done
  return 1
}

comai_provider_names() {
  printf '%s\n' "${COMAI_PROVIDERS[@]}"
}

comai_provider_usage_list() {
  local IFS='|'
  printf '%s\n' "${COMAI_PROVIDERS[*]}"
}

comai_provider_call() {
  local provider="$1"
  local action="$2"
  local fn
  shift 2

  comai_provider_exists "$provider" || return 1
  fn="comai_${provider}_${action}"
  if ! declare -F "$fn" > /dev/null 2>&1; then
    comai_error "provider action is not implemented: ${provider}.${action}"
    return 1
  fi
  "$fn" "$@"
}

comai_provider_model() {
  comai_provider_call "$1" model
}

comai_provider_api_base() {
  comai_provider_call "$1" api_base
}

comai_provider_status() {
  comai_provider_call "$1" status
}

comai_provider_models() {
  comai_provider_call "$1" models
}

comai_provider_ask() {
  comai_provider_call "$COMAI_PROVIDER" ask "$@"
}

comai_provider_select() {
  local provider="$1"

  comai_provider_exists "$provider" || return 1
  COMAI_PROVIDER="$provider"
  if [[ "${COMAI_MODEL_EXPLICIT:-0}" -ne 1 ]]; then
    COMAI_MODEL="$(comai_provider_model "$provider")"
  fi
  COMAI_API_BASE="$(comai_provider_api_base "$provider")"
}

comai_provider_key_status_message() {
  case "$1:$2" in
    openai:2 | gemini:2) printf 'missing API key\n' ;;
    openai:3 | gemini:3) printf 'API key command returned no key\n' ;;
    openai:4 | gemini:4) printf 'API key command blocked by config permissions\n' ;;
    openai:5 | gemini:5) printf 'api_key_cmd configured, not checked\n' ;;
    *) printf 'unavailable\n' ;;
  esac
}

comai_provider_allow_key_cmd() {
  case "$1" in
    openai)
      COMAI_ALLOW_OPENAI_KEY_CMD=1
      COMAI_ALLOW_GEMINI_KEY_CMD=0
      ;;
    gemini)
      COMAI_ALLOW_OPENAI_KEY_CMD=0
      COMAI_ALLOW_GEMINI_KEY_CMD=1
      ;;
    *)
      COMAI_ALLOW_OPENAI_KEY_CMD=0
      COMAI_ALLOW_GEMINI_KEY_CMD=0
      ;;
  esac
}
