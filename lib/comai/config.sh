#!/usr/bin/env bash

comai_have() {
  command -v "$1" >/dev/null 2>&1
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
      exit
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

  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//&/\\&}"
  escaped_value="${escaped_value//|/\\|}"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*:" "$file"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*:.*|${key}: ${escaped_value}|" "$file"
  else
    printf '%s: %s\n' "$key" "$value" >> "$file"
  fi
}

comai_load_config() {
  local config_file="${COMAI_CONFIG:-$COMAI_ROOT_DIR/config/comai.yaml}"
  local provider ai_dir api_base_url api_base_port model local_api_base local_model gpt_model ollama_api_base ollama_model openai_api_base openai_api_key
  local max_tokens timeout log_file file_max_bytes dir_context_max error_regex error_intent_regex

  COMAI_CONFIG_FILE="$config_file"

  provider="$(comai_yaml_value provider "$config_file" || true)"
  ai_dir="$(comai_yaml_value ai_dir "$config_file" || true)"
  api_base_url="$(comai_yaml_value api_base_url "$config_file" || true)"
  api_base_port="$(comai_yaml_value api_base_port "$config_file" || true)"
  model="$(comai_yaml_value model "$config_file" || true)"
  local_api_base="$(comai_yaml_value local_api_base "$config_file" || true)"
  local_model="$(comai_yaml_value local_model "$config_file" || true)"
  gpt_model="$(comai_yaml_value gpt_model "$config_file" || true)"
  ollama_api_base="$(comai_yaml_value ollama_api_base "$config_file" || true)"
  ollama_model="$(comai_yaml_value ollama_model "$config_file" || true)"
  openai_api_base="$(comai_yaml_value openai_api_base "$config_file" || true)"
  openai_api_key="$(comai_yaml_value openai_api_key "$config_file" || true)"
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

  COMAI_PROVIDER="${COMAI_PROVIDER:-${provider:-local}}"
  COMAI_AI_DIR="${COMAI_AI_DIR:-$(comai_expand_home "${ai_dir:-~/ai}")}"
  COMAI_LOCAL_MODEL="${COMAI_LOCAL_MODEL:-${local_model:-${model:-Qwen2.5-Coder-7B-Instruct-Q4_K_M}}}"
  COMAI_LOCAL_API_BASE="${COMAI_LOCAL_API_BASE:-${local_api_base}}"
  COMAI_OPENAI_MODEL="${COMAI_OPENAI_MODEL:-${gpt_model:-gpt-5.5}}"
  COMAI_OLLAMA_MODEL="${COMAI_OLLAMA_MODEL:-${ollama_model:-qwen2.5-coder:7b}}"
  if [[ -z "${COMAI_MODEL:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_MODEL="$COMAI_OPENAI_MODEL"
        ;;
      ollama)
        COMAI_MODEL="$COMAI_OLLAMA_MODEL"
        ;;
      *)
        COMAI_MODEL="$COMAI_LOCAL_MODEL"
        ;;
    esac
  fi
  COMAI_OPENAI_API_BASE="${COMAI_OPENAI_API_BASE:-${openai_api_base:-https://api.openai.com}}"
  COMAI_OLLAMA_API_BASE="${COMAI_OLLAMA_API_BASE:-${ollama_api_base}}"
  if [[ -z "${COMAI_API_BASE:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_API_BASE="$COMAI_OPENAI_API_BASE"
        ;;
      ollama)
        COMAI_API_BASE="$COMAI_OLLAMA_API_BASE"
        ;;
      *)
        COMAI_API_BASE="$COMAI_LOCAL_API_BASE"
        ;;
    esac
  fi
  COMAI_OPENAI_API_KEY="${OPENAI_API_KEY:-${COMAI_OPENAI_API_KEY:-${openai_api_key}}}"
  COMAI_MAX_TOKENS="${COMAI_MAX_TOKENS:-${max_tokens:-420}}"
  COMAI_TIMEOUT="${COMAI_TIMEOUT:-${timeout:-120}}"
  COMAI_LOG_FILE="${COMAI_LOG_FILE:-$(comai_expand_config_path "${log_file:-logs/comai.log}")}"
  COMAI_FILE_MAX_BYTES="${COMAI_FILE_MAX_BYTES:-${file_max_bytes:-24000}}"
  COMAI_DIR_CONTEXT_MAX="${COMAI_DIR_CONTEXT_MAX:-${dir_context_max:-120}}"
  COMAI_ERROR_RE="${COMAI_ERROR_RE:-${error_regex:-error|errors|failed|failure|exception|fatal|panic|timeout|warn|warning|traceback}}"
  COMAI_ERROR_INTENT_RE="${COMAI_ERROR_INTENT_RE:-${error_intent_regex:-error|errors|failed|failure|warning|warnings|problem|problems|issue|issues|wrong|bad|broken|fail|crash|crashed|panic|timeout|traceback|healthy|health|(^|[[:space:]])ok([[:space:]]|$)|okay|check (this )?log|scan (this )?log}}"
}

comai_usage() {
  cat <<EOF
Usage:
  comai setup       Configure provider, API, and model
  comai ask         Ask one question
  comai chat        Start an interactive conversation
  comai explain     Explain a command, error, or output
  comai analyze     Analyze logs, files, or piped output
  comai status      Show provider status and connections
  comai provider    Show active and available providers
  comai models      List models from all providers
  comai config      View or edit settings
  comai history     Show previous conversations
  comai start       Start the bundled LocalAI helper service
  comai stop        Stop the bundled LocalAI helper service
  comai restart     Restart the bundled LocalAI helper service
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
  comai --model=MODEL ask anything

Options:
  gpt, chatgpt                 Use OpenAI ChatGPT for this request
  --gpt, --chatgpt             Use OpenAI ChatGPT for this request
  ollama                       Use Ollama for this request
  --ollama                     Use Ollama for this request
  --model MODEL, --model=MODEL   Use a different model for this request
  --api-base URL, --api-base=URL Use a different provider API base
  --max-tokens N                Limit answer length
  -f, --file PATH               Add a readable file as context
  --local                       Accepted for old commands; the request still goes to AI

Config:
  $COMAI_ROOT_DIR/config/comai.yaml

Environment:
  OPENAI_API_KEY               Overrides openai_api_key for: comai gpt ...
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
  comai_have curl && curl --max-time 2 -fsS "${COMAI_API_BASE}/v1/models" >/dev/null 2>&1
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
