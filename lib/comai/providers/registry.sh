#!/usr/bin/env bash

COMAI_PROVIDERS=(local ollama lmstudio openai gemini openrouter)
COMAI_KEY_PROVIDERS=(openai gemini openrouter)

comai_provider_exists() {
  local provider="$1"
  local known

  for known in "${COMAI_PROVIDERS[@]}"; do
    [[ "$known" == "$provider" ]] && return 0
  done
  return 1
}

comai_provider_requires_key() {
  local provider="$1"
  local known

  for known in "${COMAI_KEY_PROVIDERS[@]}"; do
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

comai_key_status_code_to_label() {
  case "$1" in
    2) printf 'missing\n' ;;
    3) printf 'command_failed\n' ;;
    4) printf 'untrusted_config\n' ;;
    5) printf 'deferred\n' ;;
  esac
}

comai_key_status_label_message() {
  case "$1" in
    missing) printf 'missing API key\n' ;;
    command_failed) printf 'API key command returned no key\n' ;;
    untrusted_config) printf 'API key command blocked by config permissions\n' ;;
    deferred) printf 'api_key_cmd configured, not checked\n' ;;
    *) printf 'unavailable\n' ;;
  esac
}

comai_provider_key_status_message() {
  local provider="$1"
  local code="$2"

  comai_provider_requires_key "$provider" || { printf 'unavailable\n'; return; }
  comai_key_status_label_message "$(comai_key_status_code_to_label "$code")"
}

comai_provider_allow_key_cmd() {
  local target="$1"
  local known upper

  for known in "${COMAI_KEY_PROVIDERS[@]}"; do
    upper="${known^^}"
    if [[ "$known" == "$target" ]]; then
      printf -v "COMAI_ALLOW_${upper}_KEY_CMD" '%s' 1
    else
      printf -v "COMAI_ALLOW_${upper}_KEY_CMD" '%s' 0
    fi
  done
}
