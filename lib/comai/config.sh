#!/usr/bin/env bash

comai_have() {
  command -v "$1" >/dev/null 2>&1
}

comai_yaml_value() {
  local key="$1"
  local file="$2"

  [[ -f "$file" ]] || return 1
  awk -F ':' -v key="$key" '
    $1 == key {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      print $2
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
  local ai_dir model max_tokens timeout file_max_bytes dir_context_max error_regex

  ai_dir="$(comai_yaml_value ai_dir "$config_file" || true)"
  model="$(comai_yaml_value model "$config_file" || true)"
  max_tokens="$(comai_yaml_value max_tokens "$config_file" || true)"
  timeout="$(comai_yaml_value timeout "$config_file" || true)"
  file_max_bytes="$(comai_yaml_value file_max_bytes "$config_file" || true)"
  dir_context_max="$(comai_yaml_value dir_context_max "$config_file" || true)"
  error_regex="$(comai_yaml_value error_regex "$config_file" || true)"

  COMAI_AI_DIR="${COMAI_AI_DIR:-$(comai_expand_home "${ai_dir:-~/ai}")}"
  COMAI_MODEL="${COMAI_MODEL:-${model:-Qwen2.5-Coder-7B-Instruct-Q4_K_M}}"
  COMAI_API_BASE="${COMAI_API_BASE:-http://127.0.0.1:$(cat "$COMAI_AI_DIR/port" 2>/dev/null || printf '11435')}"
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
  comai --model=MODEL ask anything

Options:
  --model MODEL, --model=MODEL   Use a different model for this request
  --api-base URL, --api-base=URL Use a different OpenAI-compatible API
  --max-tokens N                Limit answer length
  -f, --file PATH               Add a readable file as context
  --local                       Accepted for old commands; the request still goes to AI

Config:
  $COMAI_ROOT_DIR/config/comai.yaml

Environment:
  COMAI_AI_DIR=$COMAI_AI_DIR
  COMAI_MODEL=$COMAI_MODEL
  COMAI_API_BASE=$COMAI_API_BASE
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
