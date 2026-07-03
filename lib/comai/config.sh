#!/usr/bin/env bash

comai_have() {
  command -v "$1" > /dev/null 2>&1
}

comai_yaml_value() {
  local key="$1"
  local file="$2"

  [[ -f "$file" ]] || return 1
  awk -v key="$key" '
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
    }
    line ~ "^" key "[[:space:]]*:" {
      value = substr(line, index(line, ":") + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      print value
      found = 1
      exit 0
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$file"
}

comai_yaml_provider_value() {
  local provider="$1"
  local key="$2"
  local file="$3"

  [[ -f "$file" ]] || return 1
  awk -v provider="$provider" -v key="$key" '
    /^[^[:space:]#][^:]*:/ {
      in_providers = ($0 ~ /^providers[[:space:]]*:/)
      in_provider = 0
    }
    in_providers && $0 ~ "^[[:space:]][[:space:]]" provider "[[:space:]]*:" {
      in_provider = 1
      next
    }
    in_provider && $0 ~ "^[[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:" {
      in_provider = 0
    }
    in_provider {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ "^" key "[[:space:]]*:") {
        value = substr(line, index(line, ":") + 1)
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        print value
        found = 1
        exit 0
      }
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$file"
}

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

comai_expand_config_path() {
  local value="$1"

  value="$(comai_expand_home "$value")"
  case "$value" in
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$COMAI_ROOT_DIR" "$value" ;;
  esac
}

comai_set_config_value() {
  local key="$1"
  local value="$2"
  local file="${3:-$COMAI_CONFIG_FILE}"
  local escaped_value

  [[ -n "$file" ]] || {
    comai_error "config file is not known."
    return 1
  }

  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || touch "$file"
  comai_secure_config_file "$file"

  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//&/\\&}"
  escaped_value="${escaped_value//|/\\|}"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*:" "$file"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*:.*|${key}: ${escaped_value}|" "$file"
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
  fi
  comai_secure_config_file "$file"
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
    *) return 1 ;;
  esac
}

comai_set_provider_config_value() {
  local provider="$1"
  local key="$2"
  local value="$3"
  local file="${4:-$COMAI_CONFIG_FILE}"
  local legacy_key

  legacy_key="$(comai_legacy_provider_config_key "$provider" "$key" || true)"
  if grep -Eq "^[[:space:]]{2}${provider}[[:space:]]*:" "$file" 2> /dev/null; then
    awk -v provider="$provider" -v key="$key" -v value="$value" '
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
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    comai_secure_config_file "$file"
    if [[ -n "$legacy_key" ]] && grep -Eq "^[[:space:]]*${legacy_key}[[:space:]]*:" "$file"; then
      comai_set_config_value "$legacy_key" "$value" "$file"
    fi
  elif [[ -n "$legacy_key" ]]; then
    comai_set_config_value "$legacy_key" "$value" "$file"
  else
    comai_set_config_value "$key" "$value" "$file"
  fi
}

comai_resolve_openai_api_key() {
  local key_cmd="${1:-}"
  local config_key="${2:-}"
  local resolved=""

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    printf '%s\n' "$OPENAI_API_KEY"
    return 0
  fi

  if [[ -n "${COMAI_OPENAI_API_KEY:-}" ]]; then
    printf '%s\n' "$COMAI_OPENAI_API_KEY"
    return 0
  fi

  if [[ -n "$key_cmd" ]]; then
    resolved="$(sh -c "$key_cmd" 2> /dev/null | head -n 1 || true)"
    if [[ -n "$resolved" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  printf '%s\n' "$config_key"
}

comai_load_config() {
  local config_file="${COMAI_CONFIG:-$COMAI_ROOT_DIR/config/comai.yaml}"
  local provider ai_dir api_base_url api_base_port model local_api_base local_model gpt_model ollama_api_base ollama_model lmstudio_api_base lmstudio_model openai_api_base openai_api_key openai_api_key_cmd
  local max_tokens timeout log_file file_max_bytes dir_context_max error_regex error_intent_regex

  COMAI_CONFIG_FILE="$config_file"
  comai_secure_config_file "$config_file"

  provider="$(comai_yaml_value provider "$config_file" || true)"
  ai_dir="$(comai_yaml_value ai_dir "$config_file" || true)"
  api_base_url="$(comai_yaml_value api_base_url "$config_file" || true)"
  api_base_port="$(comai_yaml_value api_base_port "$config_file" || true)"
  model="$(comai_yaml_value model "$config_file" || true)"
  local_api_base="$(comai_yaml_value local_api_base "$config_file" || comai_yaml_provider_value local api_base "$config_file" || true)"
  local_model="$(comai_yaml_value local_model "$config_file" || comai_yaml_provider_value local model "$config_file" || true)"
  gpt_model="$(comai_yaml_value gpt_model "$config_file" || comai_yaml_provider_value openai model "$config_file" || true)"
  ollama_api_base="$(comai_yaml_value ollama_api_base "$config_file" || comai_yaml_provider_value ollama api_base "$config_file" || true)"
  ollama_model="$(comai_yaml_value ollama_model "$config_file" || comai_yaml_provider_value ollama model "$config_file" || true)"
  lmstudio_api_base="$(comai_yaml_value lmstudio_api_base "$config_file" || comai_yaml_provider_value lmstudio api_base "$config_file" || true)"
  lmstudio_model="$(comai_yaml_value lmstudio_model "$config_file" || comai_yaml_provider_value lmstudio model "$config_file" || true)"
  openai_api_base="$(comai_yaml_value openai_api_base "$config_file" || comai_yaml_provider_value openai api_base "$config_file" || true)"
  openai_api_key="$(comai_yaml_value openai_api_key "$config_file" || comai_yaml_provider_value openai api_key "$config_file" || true)"
  openai_api_key_cmd="$(comai_yaml_value openai_api_key_cmd "$config_file" || comai_yaml_provider_value openai api_key_cmd "$config_file" || true)"
  max_tokens="$(comai_yaml_value max_tokens "$config_file" || true)"
  timeout="$(comai_yaml_value timeout "$config_file" || true)"
  log_file="$(comai_yaml_value log_file "$config_file" || true)"
  file_max_bytes="$(comai_yaml_value file_max_bytes "$config_file" || true)"
  dir_context_max="$(comai_yaml_value dir_context_max "$config_file" || true)"
  error_regex="$(comai_yaml_value error_regex "$config_file" || true)"
  error_intent_regex="$(comai_yaml_value error_intent_regex "$config_file" || true)"

  api_base_url="$(comai_trim_trailing_slashes "${api_base_url:-http://127.0.0.1}")"
  local_api_base="$(comai_trim_trailing_slashes "${local_api_base:-${api_base_url}:${api_base_port:-11435}}")"
  ollama_api_base="$(comai_trim_trailing_slashes "${ollama_api_base:-http://127.0.0.1:11434}")"
  lmstudio_api_base="$(comai_trim_trailing_slashes "${lmstudio_api_base:-http://127.0.0.1:1234}")"

  COMAI_PROVIDER="${COMAI_PROVIDER:-${provider:-local}}"
  COMAI_AI_DIR="${COMAI_AI_DIR:-$(comai_expand_home "${ai_dir:-~/ai}")}"
  COMAI_LOCAL_MODEL="${COMAI_LOCAL_MODEL:-${local_model:-${model:-Qwen2.5-Coder-7B-Instruct-Q4_K_M}}}"
  COMAI_LOCAL_API_BASE="${COMAI_LOCAL_API_BASE:-${local_api_base}}"
  COMAI_OPENAI_MODEL="${COMAI_OPENAI_MODEL:-${gpt_model:-gpt-5.5}}"
  COMAI_OLLAMA_MODEL="${COMAI_OLLAMA_MODEL:-${ollama_model:-qwen2.5-coder:7b}}"
  COMAI_LMSTUDIO_MODEL="${COMAI_LMSTUDIO_MODEL:-${lmstudio_model:-local-model}}"
  if [[ -z "${COMAI_MODEL:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_MODEL="$COMAI_OPENAI_MODEL"
        ;;
      ollama)
        COMAI_MODEL="$COMAI_OLLAMA_MODEL"
        ;;
      lmstudio)
        COMAI_MODEL="$COMAI_LMSTUDIO_MODEL"
        ;;
      *)
        COMAI_MODEL="$COMAI_LOCAL_MODEL"
        ;;
    esac
  fi
  COMAI_OPENAI_API_BASE="${COMAI_OPENAI_API_BASE:-${openai_api_base:-https://api.openai.com}}"
  COMAI_OLLAMA_API_BASE="${COMAI_OLLAMA_API_BASE:-${ollama_api_base}}"
  COMAI_LMSTUDIO_API_BASE="${COMAI_LMSTUDIO_API_BASE:-${lmstudio_api_base}}"
  if [[ -z "${COMAI_API_BASE:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_API_BASE="$COMAI_OPENAI_API_BASE"
        ;;
      ollama)
        COMAI_API_BASE="$COMAI_OLLAMA_API_BASE"
        ;;
      lmstudio)
        COMAI_API_BASE="$COMAI_LMSTUDIO_API_BASE"
        ;;
      *)
        COMAI_API_BASE="$COMAI_LOCAL_API_BASE"
        ;;
    esac
  fi
  COMAI_OPENAI_API_KEY_CMD="${COMAI_OPENAI_API_KEY_CMD:-${openai_api_key_cmd}}"
  COMAI_OPENAI_API_KEY="$(comai_resolve_openai_api_key "$COMAI_OPENAI_API_KEY_CMD" "$openai_api_key")"
  COMAI_MAX_TOKENS="${COMAI_MAX_TOKENS:-${max_tokens:-420}}"
  COMAI_TIMEOUT="${COMAI_TIMEOUT:-${timeout:-120}}"
  COMAI_LOG_FILE="${COMAI_LOG_FILE:-$(comai_expand_config_path "${log_file:-logs/comai.log}")}"
  COMAI_FILE_MAX_BYTES="${COMAI_FILE_MAX_BYTES:-${file_max_bytes:-24000}}"
  COMAI_DIR_CONTEXT_MAX="${COMAI_DIR_CONTEXT_MAX:-${dir_context_max:-120}}"
  COMAI_ERROR_RE="${COMAI_ERROR_RE:-${error_regex:-error|errors|failed|failure|exception|fatal|panic|timeout|warn|warning|traceback}}"
  COMAI_ERROR_INTENT_RE="${COMAI_ERROR_INTENT_RE:-${error_intent_regex:-error|errors|failed|failure|warning|warnings|problem|problems|issue|issues|wrong|bad|broken|fail|crash|crashed|panic|timeout|traceback|healthy|health|(^|[[:space:]])ok([[:space:]]|$)|okay|check (this )?log|scan (this )?log}}"
}

comai_usage() {
  cat << EOF
Usage:
  comai setup       Configure provider, API, and model
  comai ask         Ask one question
  comai chat        Start an interactive conversation
  comai explain     Explain a command, error, or output
  comai analyze     Analyze logs, files, or piped output
  comai status      Show provider status and connections
  comai provider    Show active and available providers
  comai models      List models from all providers
  comai config      View, get, or edit settings
  comai history     Show previous conversations
  comai start       Start the optional LocalAI helper service
  comai stop        Stop the optional LocalAI helper service
  comai restart     Restart the optional LocalAI helper service
  comai update      Update ComAI
  comai version     Show installed version
  comai uninstall   Remove ComAI

Examples:
  comai hi
  comai what is /etc in linux?
  comai newest file
  comai biggest file here
  comai read this file and explain it -f script.sh
  comai compare these files --file old.conf --file new.conf
  comai how this command work -command "ls -lah"
  comai gpt hi
  comai ollama hi
  comai lmstudio hi
  comai --model=MODEL ask anything

Options:
  gpt, chatgpt                 Use OpenAI ChatGPT for this request
  --gpt, --chatgpt             Use OpenAI ChatGPT for this request
  ollama                       Use Ollama for this request
  --ollama                     Use Ollama for this request
  lmstudio                     Use LM Studio for this request
  --lmstudio                   Use LM Studio for this request
  --model MODEL, --model=MODEL   Use a different model for this request
  --api-base URL, --api-base=URL Use a different provider API base
  --max-tokens N                Limit answer length
  -f, --file PATH               Add a readable file as context
  --local                       Accepted for old commands; the request still goes to AI

Config:
  $COMAI_ROOT_DIR/config/comai.yaml

Environment:
  OPENAI_API_KEY               Overrides openai_api_key for: comai gpt ...
  COMAI_OPENAI_API_KEY_CMD     Command that prints an OpenAI API key, for example: pass show openai
  COMAI_PROVIDER=$COMAI_PROVIDER
  COMAI_MODEL=$COMAI_MODEL
  COMAI_API_BASE=$COMAI_API_BASE
  COMAI_LOCAL_MODEL=$COMAI_LOCAL_MODEL
  COMAI_LOCAL_API_BASE=$COMAI_LOCAL_API_BASE
  COMAI_AI_DIR=$COMAI_AI_DIR
  COMAI_ERROR_INTENT_RE=$COMAI_ERROR_INTENT_RE
  COMAI_OPENAI_MODEL=$COMAI_OPENAI_MODEL
  COMAI_OPENAI_API_BASE=$COMAI_OPENAI_API_BASE
  COMAI_OPENAI_API_KEY=${COMAI_OPENAI_API_KEY:+set}
  COMAI_OLLAMA_MODEL=$COMAI_OLLAMA_MODEL
  COMAI_OLLAMA_API_BASE=$COMAI_OLLAMA_API_BASE
  COMAI_LMSTUDIO_MODEL=$COMAI_LMSTUDIO_MODEL
  COMAI_LMSTUDIO_API_BASE=$COMAI_LMSTUDIO_API_BASE
  COMAI_MAX_TOKENS=$COMAI_MAX_TOKENS
  COMAI_LOG_FILE=$COMAI_LOG_FILE
  COMAI_FILE_MAX_BYTES=$COMAI_FILE_MAX_BYTES
  COMAI_DIR_CONTEXT_MAX=$COMAI_DIR_CONTEXT_MAX
EOF
}

comai_error() {
  printf 'comai: %s\n' "$*" >&2
}

comai_join_args() {
  local IFS=' '
  printf '%s' "$*"
}

comai_local_ai_ready() {
  comai_have curl && curl --max-time 2 -fsS "${COMAI_API_BASE}/v1/models" > /dev/null 2>&1
}

comai_select_openai_provider() {
  COMAI_PROVIDER="openai"
  if [[ "${COMAI_MODEL_EXPLICIT:-0}" -ne 1 ]]; then
    COMAI_MODEL="$COMAI_OPENAI_MODEL"
  fi
  COMAI_API_BASE="$COMAI_OPENAI_API_BASE"
}

comai_select_ollama_provider() {
  COMAI_PROVIDER="ollama"
  if [[ "${COMAI_MODEL_EXPLICIT:-0}" -ne 1 ]]; then
    COMAI_MODEL="$COMAI_OLLAMA_MODEL"
  fi
  COMAI_API_BASE="$COMAI_OLLAMA_API_BASE"
}

comai_select_lmstudio_provider() {
  COMAI_PROVIDER="lmstudio"
  if [[ "${COMAI_MODEL_EXPLICIT:-0}" -ne 1 ]]; then
    COMAI_MODEL="$COMAI_LMSTUDIO_MODEL"
  fi
  COMAI_API_BASE="$COMAI_LMSTUDIO_API_BASE"
}

comai_select_local_provider() {
  COMAI_PROVIDER="local"
  if [[ "${COMAI_MODEL_EXPLICIT:-0}" -ne 1 ]]; then
    COMAI_MODEL="$COMAI_LOCAL_MODEL"
  fi
  COMAI_API_BASE="$COMAI_LOCAL_API_BASE"
}
