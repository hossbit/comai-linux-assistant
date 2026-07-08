# shellcheck shell=bash disable=SC2154

comai_provider_model() {
  case "$1" in
    local) printf '%s\n' "$COMAI_LOCAL_MODEL" ;;
    ollama) printf '%s\n' "$COMAI_OLLAMA_MODEL" ;;
    lmstudio) printf '%s\n' "$COMAI_LMSTUDIO_MODEL" ;;
    openai) printf '%s\n' "$COMAI_OPENAI_MODEL" ;;
  esac
}

comai_provider_api_base() {
  case "$1" in
    local) printf '%s\n' "$COMAI_LOCAL_API_BASE" ;;
    ollama) printf '%s\n' "$COMAI_OLLAMA_API_BASE" ;;
    lmstudio) printf '%s\n' "$COMAI_LMSTUDIO_API_BASE" ;;
    openai) printf '%s\n' "$COMAI_OPENAI_API_BASE" ;;
  esac
}

comai_provider_status() {
  local provider="$1"
  local api_base

  api_base="$(comai_provider_api_base "$provider")"
  case "$provider" in
    local)
      curl --max-time 2 -fsS "${api_base}/v1/models" > /dev/null 2>&1
      ;;
    ollama)
      curl --max-time 2 -fsS "${api_base}/api/tags" > /dev/null 2>&1
      ;;
    lmstudio)
      curl --max-time 2 -fsS "${api_base}/v1/models" > /dev/null 2>&1
      ;;
    openai)
      if ! comai_ensure_openai_api_key; then
        case "${COMAI_OPENAI_API_KEY_STATUS:-missing}" in
          deferred) return 5 ;;
          command_failed) return 3 ;;
          untrusted_config) return 4 ;;
          *) return 2 ;;
        esac
      fi
      comai_curl_openai_auth "$COMAI_OPENAI_API_KEY" --max-time 5 -fsS "${api_base}/v1/models" > /dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

comai_provider_models() {
  local provider="$1"
  local api_base

  api_base="$(comai_provider_api_base "$provider")"
  case "$provider" in
    local)
      curl --max-time "$COMAI_TIMEOUT" -fsS "${api_base}/v1/models" | jq -r '.data[]?.id'
      ;;
    ollama)
      curl --max-time "$COMAI_TIMEOUT" -fsS "${api_base}/api/tags" | jq -r '.models[]?.name'
      ;;
    lmstudio)
      curl --max-time "$COMAI_TIMEOUT" -fsS "${api_base}/v1/models" | jq -r '.data[]?.id'
      ;;
    openai)
      comai_ensure_openai_api_key || {
        comai_error "OPENAI_API_KEY or openai_api_key is required for OpenAI."
        return 1
      }
      comai_curl_openai_auth "$COMAI_OPENAI_API_KEY" --max-time "$COMAI_TIMEOUT" -fsS "${api_base}/v1/models" | jq -r '.data[]?.id'
      ;;
  esac
}

comai_cmd_status_one() {
  local provider="$1"
  local model api_base

  model="$(comai_provider_model "$provider")"
  api_base="$(comai_provider_api_base "$provider")"
  printf 'Provider: %s%s\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf ' (active)')"
  printf 'Model: %s\n' "$model"
  printf 'API base: %s\n' "$api_base"

  if [[ "$provider" == "openai" ]]; then
    COMAI_ALLOW_OPENAI_KEY_CMD=1
  else
    COMAI_ALLOW_OPENAI_KEY_CMD=0
  fi
  if comai_provider_status "$provider"; then
    printf 'Connection: ok\n'
    comai_log info provider_status_check "provider=$provider status=ok"
  else
    case "$provider:$?" in
      openai:2)
        printf 'Connection: missing API key\n'
        comai_log warn provider_status_check "provider=$provider status=missing_api_key"
        ;;
      openai:3)
        printf 'Connection: API key command returned no key\n'
        comai_log warn provider_status_check "provider=$provider status=api_key_cmd_failed"
        ;;
      openai:4)
        printf 'Connection: API key command blocked by config permissions\n'
        comai_log warn provider_status_check "provider=$provider status=api_key_cmd_untrusted_config"
        ;;
      openai:5)
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
  local providers=(local ollama lmstudio openai)
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
    for i in "${!providers[@]}"; do
      provider="${providers[$i]}"
      outputs[i]="$tmp_dir/$provider.out"
      (
        COMAI_STATUS_EXPLICIT_PROVIDER=""
        comai_cmd_status_one "$provider"
      ) > "${outputs[$i]}" 2>&1 &
      pids[i]=$!
    done
    for i in "${!providers[@]}"; do
      if wait "${pids[$i]}"; then
        statuses[i]=0
      else
        statuses[i]=$?
      fi
    done
    for i in "${!providers[@]}"; do
      provider="${providers[$i]}"
      printf '\n'
      cat "${outputs[$i]}"
      if [[ "${statuses[$i]}" -ne 0 ]]; then
        failed=1
        [[ "$provider" == "$COMAI_PROVIDER" ]] && active_failed=1
      fi
    done
    [[ -n "$tmp_dir" ]] && rm -rf "$tmp_dir"
  else
    case "$1" in
      local | ollama | lmstudio | openai)
        COMAI_STATUS_EXPLICIT_PROVIDER="$1"
        if ! comai_cmd_status_one "$1"; then
          failed=1
          [[ "$1" == "$COMAI_PROVIDER" ]] && active_failed=1
        fi
        ;;
      *)
        comai_error "usage: comai status [all|local|ollama|lmstudio|openai]"
        return 1
        ;;
    esac
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
    for provider in local ollama lmstudio openai; do
      printf '%s%s:\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf ' (active)')"
      if [[ "$provider" == "openai" ]]; then
        COMAI_ALLOW_OPENAI_KEY_CMD=1
      fi
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
        fi
        printf '  %s\n' "$model_status"
      fi
      rm -f "$models_output"
      printf '\n'
    done
    return 0
  fi

  case "$1" in
    local | ollama | lmstudio | openai)
      comai_log info models "provider=$1"
      [[ "$1" == "openai" ]] && COMAI_ALLOW_OPENAI_KEY_CMD=1
      comai_provider_models "$1"
      ;;
    *)
      comai_error "usage: comai models [all|local|ollama|lmstudio|openai]"
      return 1
      ;;
  esac
}

comai_cmd_provider() {
  case "${1:-}" in
    "" | show | all)
      local provider status suffix tmp_dir i
      local providers=(local ollama lmstudio openai)
      local -a pids
      printf 'active: %s\n' "$COMAI_PROVIDER"
      tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-provider.XXXXXX")" || return 1
      for i in "${!providers[@]}"; do
        provider="${providers[$i]}"
        (
          [[ "$provider" == "openai" ]] && COMAI_ALLOW_OPENAI_KEY_CMD=1
          if comai_provider_status "$provider"; then
            printf 'ok\n'
          else
            case "$provider:$?" in
              openai:2) printf 'missing API key\n' ;;
              openai:3) printf 'API key command returned no key\n' ;;
              openai:4) printf 'API key command blocked by config permissions\n' ;;
              openai:5) printf 'api_key_cmd configured, not checked\n' ;;
              *) printf 'unavailable\n' ;;
            esac
          fi
        ) > "$tmp_dir/$provider.status" 2> /dev/null &
        pids[i]=$!
      done
      for i in "${!providers[@]}"; do
        wait "${pids[$i]}" || true
      done
      for provider in "${providers[@]}"; do
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
      printf 'local\nollama\nlmstudio\nopenai\n'
      ;;
    set)
      case "${2:-}" in
        local | ollama | lmstudio | openai)
          comai_set_config_value provider "$2"
          printf 'Set provider to %s in %s\n' "$2" "$COMAI_CONFIG_FILE"
          ;;
        *)
          comai_error "usage: comai provider set local|ollama|lmstudio|openai"
          return 1
          ;;
      esac
      ;;
    *)
      comai_error "usage: comai provider [show|all|list|set PROVIDER]"
      return 1
      ;;
  esac
}
