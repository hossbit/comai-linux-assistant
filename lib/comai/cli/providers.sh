# shellcheck shell=bash disable=SC2154

comai_cmd_status_one() {
  local provider="$1"
  local model api_base

  model="$(comai_provider_model "$provider")"
  api_base="$(comai_provider_api_base "$provider")"
  printf 'Provider: %s%s\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf ' (active)')"
  printf 'Model: %s\n' "$model"
  printf 'API base: %s\n' "$api_base"

  comai_provider_allow_key_cmd "$provider"
  if comai_provider_status "$provider"; then
    printf 'Connection: ok\n'
    comai_log info provider_status_check "provider=$provider status=ok"
  else
    case "$provider:$?" in
      openai:2 | gemini:2)
        printf 'Connection: missing API key\n'
        comai_log warn provider_status_check "provider=$provider status=missing_api_key"
        ;;
      openai:3 | gemini:3)
        printf 'Connection: API key command returned no key\n'
        comai_log warn provider_status_check "provider=$provider status=api_key_cmd_failed"
        ;;
      openai:4 | gemini:4)
        printf 'Connection: API key command blocked by config permissions\n'
        comai_log warn provider_status_check "provider=$provider status=api_key_cmd_untrusted_config"
        ;;
      openai:5 | gemini:5)
        printf 'Connection: API key command configured, not checked\n'
        comai_log info provider_status_check "provider=$provider status=api_key_cmd_deferred"
        ;;
      *)
        printf 'Connection: failed\n'
        comai_log warn provider_status_check "provider=$provider status=failed"
        ;;
    esac
    return 1
  fi
}

comai_cmd_status() {
  local provider failed=0 active_failed=0
  local tmp_dir i
  local -a pids outputs statuses

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required."
    return 1
  fi

  printf 'Config: %s\n' "$COMAI_CONFIG_FILE"
  if [[ "${1:-all}" == "all" ]]; then
    comai_log info provider_status_check "provider=all"
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-status.XXXXXX")" || return 1
    for i in "${!COMAI_PROVIDERS[@]}"; do
      provider="${COMAI_PROVIDERS[$i]}"
      outputs[i]="$tmp_dir/$provider.out"
      (
        COMAI_STATUS_EXPLICIT_PROVIDER=""
        comai_cmd_status_one "$provider"
      ) > "${outputs[$i]}" 2>&1 &
      pids[i]=$!
    done
    for i in "${!COMAI_PROVIDERS[@]}"; do
      if wait "${pids[$i]}"; then
        statuses[i]=0
      else
        statuses[i]=$?
      fi
    done
    for i in "${!COMAI_PROVIDERS[@]}"; do
      provider="${COMAI_PROVIDERS[$i]}"
      printf '\n'
      cat "${outputs[$i]}"
      if [[ "${statuses[$i]}" -ne 0 ]]; then
        failed=1
        [[ "$provider" == "$COMAI_PROVIDER" ]] && active_failed=1
      fi
    done
    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
  else
    if ! comai_provider_exists "$1"; then
      comai_error "usage: comai status [all|$(comai_provider_usage_list)]"
      return 1
    fi
    COMAI_STATUS_EXPLICIT_PROVIDER="$1"
    if ! comai_cmd_status_one "$1"; then
      failed=1
      [[ "$1" == "$COMAI_PROVIDER" ]] && active_failed=1
    fi
  fi

  if [[ "${1:-all}" == "all" && "$active_failed" -eq 0 ]]; then
    return 0
  fi
  return "$failed"
}

comai_cmd_models() {
  local provider model_status models_output

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required."
    return 1
  fi

  if [[ "${1:-all}" == "all" ]]; then
    for provider in "${COMAI_PROVIDERS[@]}"; do
      printf '%s%s:\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf ' (active)')"
      comai_provider_allow_key_cmd "$provider"
      models_output="$(mktemp "${TMPDIR:-/tmp}/comai-models.XXXXXX")" || return 1
      if comai_provider_models "$provider" > "$models_output" 2> /dev/null; then
        sed 's/^/  /' "$models_output"
      else
        model_status="unavailable"
        if [[ "$provider" == "openai" ]]; then
          case "${COMAI_OPENAI_API_KEY_STATUS:-missing}" in
            deferred) model_status="api_key_cmd configured, not checked" ;;
            command_failed) model_status="API key command returned no key" ;;
            untrusted_config) model_status="API key command blocked by config permissions" ;;
            missing) model_status="missing API key" ;;
          esac
        elif [[ "$provider" == "gemini" ]]; then
          case "${COMAI_GEMINI_API_KEY_STATUS:-missing}" in
            deferred) model_status="api_key_cmd configured, not checked" ;;
            command_failed) model_status="API key command returned no key" ;;
            untrusted_config) model_status="API key command blocked by config permissions" ;;
            missing) model_status="missing API key" ;;
          esac
        fi
        printf '  %s\n' "$model_status"
      fi
      rm -f "$models_output"
      printf '\n'
    done
    return 0
  fi

  if ! comai_provider_exists "$1"; then
    comai_error "usage: comai models [all|$(comai_provider_usage_list)]"
    return 1
  fi
  comai_log info models "provider=$1"
  comai_provider_allow_key_cmd "$1"
  comai_provider_models "$1"
}

comai_cmd_provider() {
  case "${1:-}" in
    "" | show | all)
      local provider status suffix tmp_dir i
      local -a pids
      printf 'active: %s\n' "$COMAI_PROVIDER"
      tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-provider.XXXXXX")" || return 1
      for i in "${!COMAI_PROVIDERS[@]}"; do
        provider="${COMAI_PROVIDERS[$i]}"
        (
          comai_provider_allow_key_cmd "$provider"
          if comai_provider_status "$provider"; then
            printf 'ok\n'
          else
            comai_provider_key_status_message "$provider" "$?"
          fi
        ) > "$tmp_dir/$provider.status" 2> /dev/null &
        pids[i]=$!
      done
      for i in "${!COMAI_PROVIDERS[@]}"; do
        wait "${pids[$i]}" || true
      done
      for provider in "${COMAI_PROVIDERS[@]}"; do
        suffix=""
        [[ "$provider" == "$COMAI_PROVIDER" ]] && suffix=" (active)"
        status="$(cat "$tmp_dir/$provider.status" 2> /dev/null || printf 'unavailable\n')"
        comai_log info provider_status "provider=$provider status=$status active=$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf yes || printf no)"
        printf '\n%s%s\n' "$provider" "$suffix"
        printf '  api_base: %s\n' "$(comai_provider_api_base "$provider")"
        printf '  model: %s\n' "$(comai_provider_model "$provider")"
        printf '  status: %s\n' "$status"
      done
      [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
      ;;
    list)
      comai_provider_names
      ;;
    set)
      if ! comai_provider_exists "${2:-}"; then
        comai_error "usage: comai provider set $(comai_provider_usage_list)"
        return 1
      fi
      comai_set_config_value provider "$2"
      printf 'Set provider to %s in %s\n' "$2" "$COMAI_CONFIG_FILE"
      ;;
    *)
      comai_error "usage: comai provider [show|all|list|set PROVIDER]"
      return 1
      ;;
  esac
}
