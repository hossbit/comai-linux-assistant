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

# shellcheck shell=bash disable=SC2154

# Only status codes and dependency names leave this diagnostic; never response bodies or URLs.
comai_cmd_doctor() {
  local format=human provider="${COMAI_PROVIDER}" model base_url route tmp http rc=0 state=ok plugins='[]' name result
  case "${1:-}" in --json) format=json; shift ;; esac
  [[ $# -eq 0 ]] || { comai_error 'usage: doctor [--json]'; return 2; }
  if ! comai_have jq; then
    [[ "$format" == json ]] && printf '{"schema_version":1,"ok":false,"status":"missing_dependency","dependency":"jq"}\n'
    comai_error 'doctor requires jq'; return 1
  fi
  if ! comai_have curl; then
    state=missing_dependency
  else
    model="$COMAI_MODEL"
    base_url="${COMAI_API_BASE%/}"
    if [[ ! "$base_url" =~ ^https?://[^/?#@]+(/[^?#]*)?$ ]]; then
      state=invalid_endpoint
    else
      route='/v1/models'
      [[ "$provider" == ollama ]] && route='/api/tags'
      [[ "$provider" == gemini ]] && route='/v1beta/models'
      tmp="$(mktemp)" || return 1
      chmod 600 "$tmp"
      comai_provider_allow_key_cmd "$provider"
      case "$provider" in
        openai|gemini|openrouter)
          if ! "comai_${provider}_ensure_api_key" 2>/dev/null; then
            name="COMAI_${provider^^}_API_KEY_STATUS"
            case "${!name:-missing}" in
              missing) state=missing_credentials ;;
              untrusted_config) state=untrusted_key_command ;;
              *) state=key_command_failed ;;
            esac
          fi ;;
      esac
      if [[ "$state" == ok ]]; then
        local -a transport=(curl)
        case "$provider" in
          openai|openrouter)
            name="COMAI_${provider^^}_API_KEY"
            transport=("comai_${provider}_curl_auth" "${!name}") ;;
          gemini) transport=(comai_gemini_curl_key "$COMAI_GEMINI_API_KEY") ;;
        esac
        http="$("${transport[@]}" --connect-timeout 3 --max-time 8 --max-filesize 1048576 -sS -o "$tmp" -w '%{http_code}' "$base_url$route" 2>/dev/null)" || rc=$?
        if [[ "$rc" -eq 28 ]]; then state=timeout
        elif [[ "$rc" -ne 0 ]]; then state=unreachable
        else
          case "$http" in
            401|403) state=bad_credentials ;;
            429) state=rate_limited ;;
            5??) state=server_unavailable ;;
            2??)
              local expression='.data | type == "array" and all(.[]; (.id | type == "string"))'
              [[ "$provider" == ollama ]] && expression='.models | type == "array" and all(.[]; (.name | type == "string"))'
              [[ "$provider" == gemini ]] && expression='.models | type == "array" and all(.[]; (.name | type == "string"))'
              if ! jq -e "$expression" "$tmp" >/dev/null 2>&1; then state=invalid_response
              elif ! jq -e --arg model "$model" 'any((.data // .models)[]; (.id // .name | sub("^models/"; "")) == ($model | sub("^models/"; "")))' "$tmp" >/dev/null 2>&1; then state=missing_model
              fi ;;
            *) state=endpoint_error ;;
          esac
        fi
      fi
      rm -f "$tmp"
    fi
  fi
  # Existing plugin doctor validates manifests, entrypoints, runtime and command conflicts without executing plugins.
  if declare -F comai_plugin_enabled_dir >/dev/null; then
    for result in "$(comai_plugin_enabled_dir)"/*; do
      [[ -f "$result" ]] || continue
      name="${result##*/}"
      if comai_cmd_plugin_doctor "$name" >/dev/null 2>&1; then result=ok; else result=dependency_error; fi
      plugins="$(jq -c --arg name "$name" --arg status "$result" '. + [{name:$name,status:$status}]' <<< "$plugins")"
    done
  fi
  result="$(jq -n --arg provider "$provider" --arg status "$state" --argjson plugins "$plugins" '{schema_version:1,ok:($status == "ok" and all($plugins[]; .status == "ok")),provider:$provider,status:$status,plugins:$plugins}')"
  if [[ "$format" == json ]]; then printf '%s\n' "$result"
  else jq -r '"Provider: \(.provider)\nHealth: \(.status)", (.plugins[] | "Plugin \(.name): \(.status)")' <<< "$result"; fi
  jq -e '.ok' <<< "$result" >/dev/null
}
