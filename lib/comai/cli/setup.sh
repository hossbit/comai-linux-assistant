# shellcheck shell=bash disable=SC2154

comai_cmd_setup() {
  local provider api model key answer

  printf 'ComAI setup\n'
  printf 'Provider [%s] (%s): ' "$(comai_provider_usage_list | tr '|' '/')" "$COMAI_PROVIDER"
  read -r provider
  provider="${provider:-$COMAI_PROVIDER}"
  if ! comai_provider_exists "$provider"; then
    comai_error "provider must be one of: $(comai_provider_usage_list)"
    return 1
  fi

  comai_set_config_value provider "$provider"

  case "$provider" in
    local)
      printf 'Local API base (%s): ' "$COMAI_LOCAL_API_BASE"
      read -r api
      printf 'Local model (%s): ' "$COMAI_LOCAL_MODEL"
      read -r model
      comai_set_provider_config_value local api_base "${api:-$COMAI_LOCAL_API_BASE}"
      comai_set_provider_config_value local model "${model:-$COMAI_LOCAL_MODEL}"
      ;;
    ollama)
      printf 'Ollama API base (%s): ' "$COMAI_OLLAMA_API_BASE"
      read -r api
      printf 'Ollama model (%s): ' "$COMAI_OLLAMA_MODEL"
      read -r model
      comai_set_provider_config_value ollama api_base "${api:-$COMAI_OLLAMA_API_BASE}"
      comai_set_provider_config_value ollama model "${model:-$COMAI_OLLAMA_MODEL}"
      ;;
    lmstudio)
      printf 'LM Studio API base (%s): ' "$COMAI_LMSTUDIO_API_BASE"
      read -r api
      printf 'LM Studio model (%s): ' "$COMAI_LMSTUDIO_MODEL"
      read -r model
      comai_set_provider_config_value lmstudio api_base "${api:-$COMAI_LMSTUDIO_API_BASE}"
      comai_set_provider_config_value lmstudio model "${model:-$COMAI_LMSTUDIO_MODEL}"
      ;;
    openai)
      printf 'OpenAI API base (%s): ' "$COMAI_OPENAI_API_BASE"
      read -r api
      printf 'OpenAI model (%s): ' "$COMAI_OPENAI_MODEL"
      read -r model
      comai_set_provider_config_value openai api_base "${api:-$COMAI_OPENAI_API_BASE}"
      comai_set_provider_config_value openai model "${model:-$COMAI_OPENAI_MODEL}"
      if [[ -z "${COMAI_OPENAI_API_KEY:-}" ]]; then
        printf 'OpenAI API key (leave blank to use OPENAI_API_KEY later): '
        read -r key
        if [[ -n "$key" ]]; then
          comai_set_provider_config_value openai api_key "$key"
          comai_secure_config_file "$COMAI_CONFIG_FILE"
        fi
      fi
      ;;
    gemini)
      printf 'Gemini API base (%s): ' "$COMAI_GEMINI_API_BASE"
      read -r api
      printf 'Gemini model (%s): ' "$COMAI_GEMINI_MODEL"
      read -r model
      comai_set_provider_config_value gemini api_base "${api:-$COMAI_GEMINI_API_BASE}"
      comai_set_provider_config_value gemini model "${model:-$COMAI_GEMINI_MODEL}"
      if [[ -z "${COMAI_GEMINI_API_KEY:-}" ]]; then
        printf 'Gemini API key (leave blank to use GEMINI_API_KEY later): '
        read -r key
        if [[ -n "$key" ]]; then
          comai_set_provider_config_value gemini api_key "$key"
          comai_secure_config_file "$COMAI_CONFIG_FILE"
        fi
      fi
      ;;
  esac

  printf 'Saved setup to %s\n' "$COMAI_CONFIG_FILE"
  printf 'Run `comai status` to test the providers.\n'
}
