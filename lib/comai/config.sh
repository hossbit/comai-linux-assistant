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

comai_load_config() {
  local config_file="${COMAI_CONFIG:-$COMAI_ROOT_DIR/config/comai.yaml}"
  local ai_dir model gpt_model openai_api_base openai_api_key max_tokens timeout file_max_bytes dir_context_max error_regex

  ai_dir="$(comai_yaml_value ai_dir "$config_file" || true)"
  model="$(comai_yaml_value model "$config_file" || true)"
  gpt_model="$(comai_yaml_value gpt_model "$config_file" || true)"
  openai_api_base="$(comai_yaml_value openai_api_base "$config_file" || true)"
  openai_api_key="$(comai_yaml_value openai_api_key "$config_file" || true)"
  max_tokens="$(comai_yaml_value max_tokens "$config_file" || true)"
  timeout="$(comai_yaml_value timeout "$config_file" || true)"
  file_max_bytes="$(comai_yaml_value file_max_bytes "$config_file" || true)"
  dir_context_max="$(comai_yaml_value dir_context_max "$config_file" || true)"
  error_regex="$(comai_yaml_value error_regex "$config_file" || true)"

  COMAI_PROVIDER="${COMAI_PROVIDER:-local}"
  COMAI_AI_DIR="${COMAI_AI_DIR:-$(comai_expand_home "${ai_dir:-~/ai}")}"
  COMAI_MODEL="${COMAI_MODEL:-${model:-Qwen2.5-Coder-7B-Instruct-Q4_K_M}}"
  COMAI_API_BASE="${COMAI_API_BASE:-http://127.0.0.1:$(cat "$COMAI_AI_DIR/port" 2>/dev/null || printf '11435')}"
  COMAI_OPENAI_MODEL="${COMAI_OPENAI_MODEL:-${gpt_model:-gpt-5.5}}"
  COMAI_OPENAI_API_BASE="${COMAI_OPENAI_API_BASE:-${openai_api_base:-https://api.openai.com}}"
  COMAI_OPENAI_API_KEY="${OPENAI_API_KEY:-${COMAI_OPENAI_API_KEY:-${openai_api_key}}}"
  COMAI_MAX_TOKENS="${COMAI_MAX_TOKENS:-${max_tokens:-420}}"
  COMAI_TIMEOUT="${COMAI_TIMEOUT:-${timeout:-120}}"
  COMAI_FILE_MAX_BYTES="${COMAI_FILE_MAX_BYTES:-${file_max_bytes:-24000}}"
  COMAI_DIR_CONTEXT_MAX="${COMAI_DIR_CONTEXT_MAX:-${dir_context_max:-120}}"
  COMAI_ERROR_RE="${COMAI_ERROR_RE:-${error_regex:-error|errors|failed|failure|exception|fatal|panic|timeout|warn|warning|traceback}}"
}

comai_usage() {
  cat <<EOF
Usage:
  comai hi
  comai what is /etc in linux?
  comai newest file
  comai biggest file here
  comai read this file and explain it -f script.sh
  comai compare these files --file old.conf --file new.conf
  comai how this command work -command "ls -lah"
  comai gpt hi
  comai --model=MODEL ask anything

Options:
  gpt, chatgpt                 Use OpenAI ChatGPT for this request
  --gpt, --chatgpt             Use OpenAI ChatGPT for this request
  --model MODEL, --model=MODEL   Use a different model for this request
  --api-base URL, --api-base=URL Use a different OpenAI-compatible API
  --max-tokens N                Limit answer length
  -f, --file PATH               Add a readable file as context
  --local                       Accepted for old commands; the request still goes to AI

Config:
  $COMAI_ROOT_DIR/config/comai.yaml

Environment:
  OPENAI_API_KEY               Overrides openai_api_key for: comai gpt ...
  COMAI_PROVIDER=$COMAI_PROVIDER
  COMAI_AI_DIR=$COMAI_AI_DIR
  COMAI_MODEL=$COMAI_MODEL
  COMAI_API_BASE=$COMAI_API_BASE
  COMAI_OPENAI_MODEL=$COMAI_OPENAI_MODEL
  COMAI_OPENAI_API_BASE=$COMAI_OPENAI_API_BASE
  COMAI_OPENAI_API_KEY=${COMAI_OPENAI_API_KEY:+set}
  COMAI_MAX_TOKENS=$COMAI_MAX_TOKENS
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
