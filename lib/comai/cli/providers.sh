# shellcheck shell=bash disable=SC2154

comai_cmd_status_one() {
  local provider="$1"
  local model api_base code label message slug level

  model="$(comai_provider_model "$provider")"
  api_base="$(comai_provider_api_base "$provider")"
  printf 'Provider: %s%s\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && comai_color_dim ' (active)')"
  printf 'Model: %s\n' "$model"
  printf 'API base: %s\n' "$api_base"

  comai_provider_allow_key_cmd "$provider"
  if comai_provider_status "$provider"; then
    printf 'Connection: %s\n' "$(comai_color_ok ok)"
    comai_log info provider_status_check "provider=$provider status=ok"
    return 0
  else
    code=$?
  fi

  label=""
  comai_provider_requires_key "$provider" && label="$(comai_key_status_code_to_label "$code")"
  if [[ -n "$label" ]]; then
    message="$(comai_key_status_label_message "$label")"
    level="warn"
    case "$label" in
      missing) slug="missing_api_key" ;;
      command_failed) slug="api_key_cmd_failed" ;;
      untrusted_config) slug="api_key_cmd_untrusted_config" ;;
      deferred)
        slug="api_key_cmd_deferred"
        level="info"
        ;;
    esac
  else
    message="failed"
    slug="failed"
    level="warn"
  fi
  printf 'Connection: %s\n' "$(comai_format_status_text "$message")"
  comai_log "$level" provider_status_check "provider=$provider status=$slug"
  return 1
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
    comai_color_cache
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-status.XXXXXX")" || return 1
    for i in "${!COMAI_PROVIDERS[@]}"; do
      provider="${COMAI_PROVIDERS[$i]}"
      outputs[i]="$tmp_dir/$provider.out"
      (
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
  local provider="all" filter="" arg model_status models_output status_var matched

  if ! comai_have curl || ! comai_have jq; then
    comai_error "curl and jq are required."
    return 1
  fi

  while [[ "$#" -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --filter=*)
        filter="${arg#--filter=}"
        ;;
      --filter | -F)
        if [[ -z "${2:-}" ]]; then
          comai_error "missing text after --filter"
          return 1
        fi
        filter="$2"
        shift
        ;;
      *)
        provider="$arg"
        ;;
    esac
    shift
  done

  if [[ "$provider" == "all" ]]; then
    for provider in "${COMAI_PROVIDERS[@]}"; do
      printf '%s%s:\n' "$provider" "$([[ "$provider" == "$COMAI_PROVIDER" ]] && comai_color_dim ' (active)')"
      comai_provider_allow_key_cmd "$provider"
      models_output="$(mktemp "${TMPDIR:-/tmp}/comai-models.XXXXXX")" || return 1
      if comai_provider_models "$provider" > "$models_output" 2> /dev/null; then
        if [[ -n "$filter" ]]; then
          matched="$(grep -i -- "$filter" "$models_output" || true)"
          if [[ -n "$matched" ]]; then
            printf '%s\n' "$matched" | sed 's/^/  /'
          else
            printf '  %s\n' "$(comai_color_dim "(no models match \"$filter\")")"
          fi
        else
          sed 's/^/  /' "$models_output"
        fi
      else
        model_status="unavailable"
        if comai_provider_requires_key "$provider"; then
          status_var="COMAI_${provider^^}_API_KEY_STATUS"
          model_status="$(comai_key_status_label_message "${!status_var:-missing}")"
        fi
        printf '  %s\n' "$(comai_format_status_text "$model_status")"
      fi
      rm -f "$models_output"
      printf '\n'
    done
    return 0
  fi

  if ! comai_provider_exists "$provider"; then
    comai_error "usage: comai models [all|$(comai_provider_usage_list)] [--filter TEXT]"
    return 1
  fi
  comai_log info models "provider=$provider filter=$filter"
  comai_provider_allow_key_cmd "$provider"
  if [[ -n "$filter" ]]; then
    if ! comai_provider_models "$provider" | grep -i -- "$filter"; then
      comai_error "no models match \"$filter\" for $provider."
      return 1
    fi
  else
    comai_provider_models "$provider"
  fi
}

comai_cmd_provider() {
  case "${1:-}" in
    "" | show | all)
      local provider status suffix tmp_dir i
      local -a pids
      printf 'active: %s\n' "$COMAI_PROVIDER"
      comai_color_cache
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
        [[ "$provider" == "$COMAI_PROVIDER" ]] && suffix="$(comai_color_dim ' (active)')"
        status="$(cat "$tmp_dir/$provider.status" 2> /dev/null || printf 'unavailable\n')"
        comai_log info provider_status "provider=$provider status=$status active=$([[ "$provider" == "$COMAI_PROVIDER" ]] && printf yes || printf no)"
        printf '\n%s%s\n' "$provider" "$suffix"
        printf '  api_base: %s\n' "$(comai_provider_api_base "$provider")"
        printf '  model: %s\n' "$(comai_provider_model "$provider")"
        printf '  status: %s\n' "$(comai_format_status_text "$status")"
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
