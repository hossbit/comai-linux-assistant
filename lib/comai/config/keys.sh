comai_run_api_key_cmd() {
  local provider="$1"
  local key_cmd="$2"
  local key_file stderr_file status resolved

  if ! comai_config_trusted_for_commands "$COMAI_CONFIG_FILE"; then
    return 4
  fi

  key_file="$(mktemp "${TMPDIR:-/tmp}/comai-${provider}-key.XXXXXX")" || return 3
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/comai-${provider}-key.err.XXXXXX")" || {
    rm -f "$key_file"
    return 3
  }
  chmod 600 "$key_file" "$stderr_file" 2> /dev/null || true

  if sh -c "$key_cmd" > "$key_file" 2> "$stderr_file"; then
    status=0
  else
    status=$?
  fi

  resolved="$(head -n 1 "$key_file" 2> /dev/null || true)"
  if [[ -s "$stderr_file" ]]; then
    while IFS= read -r line; do
      [[ -n "$line" ]] && comai_error "${provider} api_key_cmd stderr: $line"
    done < "$stderr_file"
  fi
  rm -f "$key_file" "$stderr_file"

  if [[ "$status" -ne 0 || -z "$resolved" ]]; then
    return 3
  fi

  printf '%s\n' "$resolved"
}

comai_ensure_provider_api_key() {
  local provider="$1"
  local env_var="$2"
  local key_var="$3"
  local key_cmd_var="$4"
  local config_key_var="$5"
  local allow_cmd_var="$6"
  local status_var="$7"
  local resolved key_value key_cmd config_key allow_cmd key_cmd_status

  printf -v "$status_var" '%s' "missing"
  key_value="${!key_var:-}"
  if [[ -n "$key_value" ]]; then
    printf -v "$status_var" '%s' "ok"
    return 0
  fi

  key_cmd="${!key_cmd_var:-}"
  allow_cmd="${!allow_cmd_var:-0}"
  if [[ -n "$key_cmd" && "${COMAI_PROVIDER:-}" != "$provider" && "$allow_cmd" != "1" ]]; then
    printf -v "$status_var" '%s' "deferred"
    return 1
  fi

  if [[ -n "$key_cmd" ]]; then
    if resolved="$(comai_run_api_key_cmd "$provider" "$key_cmd")"; then
      printf -v "$key_var" '%s' "$resolved"
      printf -v "$status_var" '%s' "ok"
      return 0
    else
      key_cmd_status=$?
    fi
    case "$key_cmd_status" in
      4) printf -v "$status_var" '%s' "untrusted_config" ;;
      *) printf -v "$status_var" '%s' "command_failed" ;;
    esac
  fi

  config_key="${!config_key_var:-}"
  if [[ -n "$config_key" ]]; then
    printf -v "$key_var" '%s' "$config_key"
    printf -v "$status_var" '%s' "ok"
    return 0
  fi

  if [[ -n "$env_var" && -n "${!env_var:-}" ]]; then
    printf -v "$key_var" '%s' "${!env_var}"
    printf -v "$status_var" '%s' "ok"
    return 0
  fi

  return 1
}

comai_curl_config_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

comai_strip_terminal_controls() {
  LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'
}
