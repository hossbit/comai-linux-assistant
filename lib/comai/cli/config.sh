# shellcheck shell=bash disable=SC2154

comai_cmd_config() {
  case "${1:-show}" in
    show)
      LC_ALL=C awk '
        /^[[:space:]]*openai_api_key[[:space:]]*:/ {
          value = substr($0, index($0, ":") + 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          if (value == "") {
            print "openai_api_key:"
          } else {
            print "openai_api_key: [set]"
          }
          next
        }
        /^[[:space:]]*api_key[[:space:]]*:/ {
          value = substr($0, index($0, ":") + 1)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          if (value == "") {
            print "    api_key:"
          } else {
            print "    api_key: [set]"
          }
          next
        }
        { print }
      ' "$COMAI_CONFIG_FILE"
      ;;
    path)
      printf '%s\n' "$COMAI_CONFIG_FILE"
      ;;
    get)
      if [[ -z "${2:-}" ]]; then
        comai_error "usage: comai config get KEY"
        return 1
      fi
      if [[ "$2" == "openai_api_key" ]]; then
        if [[ -n "$(comai_yaml_value "$2" "$COMAI_CONFIG_FILE" || true)" ]]; then
          printf '[set]\n'
        fi
      else
        comai_yaml_value "$2" "$COMAI_CONFIG_FILE"
      fi
      ;;
    edit)
      "${EDITOR:-nano}" "$COMAI_CONFIG_FILE"
      ;;
    set)
      if [[ -z "${2:-}" || -z "${3:-}" ]]; then
        comai_error "usage: comai config set KEY VALUE"
        return 1
      fi
      case "$2" in
        api_key_cmd | openai_api_key_cmd | openai.api_key_cmd | providers.openai.api_key_cmd)
          comai_set_provider_config_value openai api_key_cmd "$3"
          ;;
        openai_api_key | openai.api_key | providers.openai.api_key)
          comai_set_provider_config_value openai api_key "$3"
          ;;
        *)
          comai_set_config_value "$2" "$3"
          ;;
      esac
      printf 'Set %s in %s\n' "$2" "$COMAI_CONFIG_FILE"
      ;;
    *)
      comai_error "usage: comai config [show|path|get KEY|edit|set KEY VALUE]"
      return 1
      ;;
  esac
}

comai_cmd_history() {
  if [[ -f "$COMAI_HISTORY_FILE" ]]; then
    if comai_have tail; then
      tail -n "${1:-80}" "$COMAI_HISTORY_FILE" | comai_strip_terminal_controls
    else
      sed -n '1,220p' "$COMAI_HISTORY_FILE" | comai_strip_terminal_controls
    fi
  else
    printf 'No history yet.\n'
  fi
}
