comai_set_config_value() {
  local key="$1"
  local value="$2"
  local file="${3:-$COMAI_CONFIG_FILE}"
  local tmp

  comai_validate_config_key "$key" || return 1
  comai_validate_config_value "$value" || return 1
  [[ -n "$file" ]] || {
    comai_error "config file is not known."
    return 1
  }

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"
  comai_secure_config_file "$file"

  if grep -Eq "^[[:space:]]*${key}[[:space:]]*:" "$file"; then
    tmp="$(comai_secure_temp_for "$file")" || return 1
    LC_ALL=C awk -v key="$key" -v value="$value" '
      $0 ~ "^[[:space:]]*" key "[[:space:]]*:" {
        print key ": " value
        next
      }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
    if [[ -e "${tmp:-}" ]]; then
      rm -f "$tmp"
    fi
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
  fi
  comai_secure_config_file "$file"
  comai_rotate_config_backups "$file"
}

comai_legacy_provider_config_key() {
  local provider="$1"
  local key="$2"

  case "$provider:$key" in
    local:api_base) printf 'local_api_base\n' ;;
    local:model) printf 'local_model\n' ;;
    ollama:api_base) printf 'ollama_api_base\n' ;;
    ollama:model) printf 'ollama_model\n' ;;
    lmstudio:api_base) printf 'lmstudio_api_base\n' ;;
    lmstudio:model) printf 'lmstudio_model\n' ;;
    openai:api_base) printf 'openai_api_base\n' ;;
    openai:model) printf 'gpt_model\n' ;;
    openai:api_key) printf 'openai_api_key\n' ;;
    openai:api_key_cmd) printf 'openai_api_key_cmd\n' ;;
    gemini:api_base) printf 'gemini_api_base\n' ;;
    gemini:model) printf 'gemini_model\n' ;;
    gemini:api_key) printf 'gemini_api_key\n' ;;
    gemini:api_key_cmd) printf 'gemini_api_key_cmd\n' ;;
    *) return 1 ;;
  esac
}

comai_set_provider_config_value() {
  local provider="$1"
  local key="$2"
  local value="$3"
  local file="${4:-$COMAI_CONFIG_FILE}"
  local legacy_key tmp

  comai_validate_config_key "$provider" || return 1
  comai_validate_config_key "$key" || return 1
  comai_validate_config_value "$value" || return 1

  legacy_key="$(comai_legacy_provider_config_key "$provider" "$key" || true)"
  if grep -Eq "^[[:space:]]{2}${provider}[[:space:]]*:" "$file" 2> /dev/null; then
    tmp="$(comai_secure_temp_for "$file")" || return 1
    LC_ALL=C awk -v provider="$provider" -v key="$key" -v value="$value" '
      BEGIN { in_providers = 0; in_provider = 0; changed = 0 }
      /^[^[:space:]#][^:]*:/ {
        in_providers = ($0 ~ /^providers[[:space:]]*:/)
        in_provider = 0
      }
      in_providers && $0 ~ "^[[:space:]][[:space:]]" provider "[[:space:]]*:" {
        in_provider = 1
        print
        next
      }
      in_provider && $0 ~ "^[[:space:]][[:space:]][[:space:]][[:space:]]" key "[[:space:]]*:" {
        print "    " key ": " value
        changed = 1
        next
      }
      in_provider && $0 ~ "^[[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:" {
        if (!changed) {
          print "    " key ": " value
          changed = 1
        }
        in_provider = 0
      }
      { print }
      END {
        if (in_provider && !changed) {
          print "    " key ": " value
        }
      }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
    if [[ -e "${tmp:-}" ]]; then
      rm -f "$tmp"
    fi
    comai_secure_config_file "$file"
    comai_rotate_config_backups "$file"
    if [[ -n "$legacy_key" ]] && grep -Eq "^[[:space:]]*${legacy_key}[[:space:]]*:" "$file"; then
      comai_set_config_value "$legacy_key" "$value" "$file"
    fi
  elif [[ -n "$legacy_key" ]]; then
    comai_set_config_value "$legacy_key" "$value" "$file"
  else
    comai_set_config_value "$key" "$value" "$file"
  fi
}
