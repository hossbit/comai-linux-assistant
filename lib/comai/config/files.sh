comai_expand_home() {
  local value="$1"
  if [[ "$value" == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ "${value:0:2}" == "~/" ]]; then
    printf '%s/%s\n' "$HOME" "${value:2}"
  else
    printf '%s\n' "$value"
  fi
}

comai_trim_trailing_slashes() {
  local value="$1"
  while [[ "$value" == */ && "$value" != "http://" && "$value" != "https://" ]]; do
    value="${value%/}"
  done
  printf '%s\n' "$value"
}

comai_secure_config_file() {
  local file="${1:-${COMAI_CONFIG_FILE:-}}"

  [[ -n "$file" && -f "$file" ]] || return 0
  chmod 600 "$file" 2> /dev/null || true
}

comai_rotate_config_backups() {
  local file="${1:-${COMAI_CONFIG_FILE:-}}"
  local keep="${COMAI_CONFIG_BACKUP_KEEP:-5}"
  local dir base backup count=0

  [[ -n "$file" ]] || return 0
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=5
  dir="$(dirname "$file")"
  base="$(basename "$file")"
  [[ -d "$dir" ]] || return 0

  while IFS= read -r backup; do
    chmod 600 "$backup" 2> /dev/null || true
    count=$((count + 1))
    if [[ "$count" -gt "$keep" ]]; then
      rm -f "$backup"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name "${base}.backup.*" -printf '%T@ %p\n' 2> /dev/null | sort -nr | awk '{ $1=""; sub(/^ /, ""); print }')
}

comai_path_component_trusted_for_commands() {
  local path="$1"
  local mode group_write other_write

  mode="$(stat -c '%a' "$path" 2> /dev/null || true)"
  [[ -n "$mode" ]] || return 1

  group_write=$(((10#$mode / 10) % 10 & 2))
  other_write=$((10#$mode % 10 & 2))
  [[ "$group_write" -eq 0 && "$other_write" -eq 0 ]]
}

comai_config_trusted_for_commands() {
  local file="${1:-${COMAI_CONFIG_FILE:-}}"
  local dir parent owner current_uid

  [[ -n "$file" && -f "$file" ]] || return 1
  owner="$(stat -c '%u' "$file" 2> /dev/null || true)"
  current_uid="$(id -u 2> /dev/null || true)"
  [[ -n "$owner" && -n "$current_uid" && "$owner" == "$current_uid" ]] || return 1
  comai_path_component_trusted_for_commands "$file" || return 1

  dir="$(cd "$(dirname "$file")" 2> /dev/null && pwd -P)" || return 1
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    comai_path_component_trusted_for_commands "$dir" || return 1
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done
  comai_path_component_trusted_for_commands "/" || return 1
}

comai_validate_config_key() {
  local key="$1"

  [[ "$key" =~ ^[A-Za-z0-9_.-]+$ ]] || {
    comai_error "invalid config key: $key"
    return 1
  }
}

comai_validate_config_value() {
  local value="$1"

  case "$value" in
    *$'\n'* | *$'\r'*)
      comai_error "config values cannot contain newlines."
      return 1
      ;;
  esac
}

comai_secure_temp_for() {
  local file="$1"
  local dir base tmp

  dir="$(dirname "$file")"
  base="$(basename "$file")"
  tmp="$(mktemp "$dir/.${base}.tmp.XXXXXX")" || return 1
  chmod 600 "$tmp" 2> /dev/null || true
  printf '%s\n' "$tmp"
}

comai_expand_config_path() {
  local value="$1"

  value="$(comai_expand_home "$value")"
  case "$value" in
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$COMAI_ROOT_DIR" "$value" ;;
  esac
}

comai_api_base_is_loopback_http() {
  case "$1" in
    http://127.* | http://localhost | http://localhost:* | http://0.0.0.0 | http://0.0.0.0:* | http://[::1] | http://[::1]:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

comai_warn_insecure_api_base() {
  local provider="$1"
  local api_base="$2"

  case "$api_base" in
    https://*) return 0 ;;
    http://*)
      if comai_api_base_is_loopback_http "$api_base"; then
        return 0
      fi
      comai_error "warning: ${provider} api_base uses non-loopback HTTP and may leak prompts: ${api_base}"
      return 0
      ;;
    *)
      comai_error "warning: ${provider} api_base should use https:// or loopback http://: ${api_base}"
      return 0
      ;;
  esac
}
