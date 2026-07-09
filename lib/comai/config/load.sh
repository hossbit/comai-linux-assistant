comai_load_config() {
  local config_file="${COMAI_CONFIG:-$COMAI_ROOT_DIR/config/comai.yaml}"
  local provider ai_dir api_base_url api_base_port model local_api_base local_model gpt_model ollama_api_base ollama_model lmstudio_api_base lmstudio_model openai_api_base openai_api_key openai_api_key_cmd
  local gemini_api_base gemini_model gemini_api_key gemini_api_key_cmd
  local provider_local_api_base provider_local_model provider_openai_api_base provider_openai_model provider_openai_api_key provider_openai_api_key_cmd
  local provider_gemini_api_base provider_gemini_model provider_gemini_api_key provider_gemini_api_key_cmd
  local provider_ollama_api_base provider_ollama_model provider_lmstudio_api_base provider_lmstudio_model
  local max_tokens timeout log_file file_max_bytes dir_context_max error_regex error_intent_regex
  local config_key config_value

  COMAI_CONFIG_FILE="$config_file"

  while IFS=$'\t' read -r config_key config_value; do
    case "$config_key" in
      provider) provider="$config_value" ;;
      ai_dir) ai_dir="$config_value" ;;
      api_base_url) api_base_url="$config_value" ;;
      api_base_port) api_base_port="$config_value" ;;
      model) model="$config_value" ;;
      local_api_base) local_api_base="$config_value" ;;
      local_model) local_model="$config_value" ;;
      gpt_model) gpt_model="$config_value" ;;
      ollama_api_base) ollama_api_base="$config_value" ;;
      ollama_model) ollama_model="$config_value" ;;
      lmstudio_api_base) lmstudio_api_base="$config_value" ;;
      lmstudio_model) lmstudio_model="$config_value" ;;
      openai_api_base) openai_api_base="$config_value" ;;
      openai_api_key) openai_api_key="$config_value" ;;
      openai_api_key_cmd) openai_api_key_cmd="$config_value" ;;
      api_key_cmd) [[ -n "${openai_api_key_cmd:-}" ]] || openai_api_key_cmd="$config_value" ;;
      gemini_api_base) gemini_api_base="$config_value" ;;
      gemini_model) gemini_model="$config_value" ;;
      gemini_api_key) gemini_api_key="$config_value" ;;
      gemini_api_key_cmd) gemini_api_key_cmd="$config_value" ;;
      max_tokens) max_tokens="$config_value" ;;
      timeout) timeout="$config_value" ;;
      log_file) log_file="$config_value" ;;
      file_max_bytes) file_max_bytes="$config_value" ;;
      dir_context_max) dir_context_max="$config_value" ;;
      error_regex) error_regex="$config_value" ;;
      error_intent_regex) error_intent_regex="$config_value" ;;
      provider_local_api_base) provider_local_api_base="$config_value" ;;
      provider_local_model) provider_local_model="$config_value" ;;
      provider_openai_api_base) provider_openai_api_base="$config_value" ;;
      provider_openai_model) provider_openai_model="$config_value" ;;
      provider_openai_api_key) provider_openai_api_key="$config_value" ;;
      provider_openai_api_key_cmd) provider_openai_api_key_cmd="$config_value" ;;
      provider_gemini_api_base) provider_gemini_api_base="$config_value" ;;
      provider_gemini_model) provider_gemini_model="$config_value" ;;
      provider_gemini_api_key) provider_gemini_api_key="$config_value" ;;
      provider_gemini_api_key_cmd) provider_gemini_api_key_cmd="$config_value" ;;
      provider_ollama_api_base) provider_ollama_api_base="$config_value" ;;
      provider_ollama_model) provider_ollama_model="$config_value" ;;
      provider_lmstudio_api_base) provider_lmstudio_api_base="$config_value" ;;
      provider_lmstudio_model) provider_lmstudio_model="$config_value" ;;
    esac
  done < <(comai_yaml_config_values "$config_file")

  local_api_base="${local_api_base:-${provider_local_api_base:-}}"
  local_model="${local_model:-${provider_local_model:-}}"
  gpt_model="${gpt_model:-${provider_openai_model:-}}"
  ollama_api_base="${ollama_api_base:-${provider_ollama_api_base:-}}"
  ollama_model="${ollama_model:-${provider_ollama_model:-}}"
  lmstudio_api_base="${lmstudio_api_base:-${provider_lmstudio_api_base:-}}"
  lmstudio_model="${lmstudio_model:-${provider_lmstudio_model:-}}"
  openai_api_base="${openai_api_base:-${provider_openai_api_base:-}}"
  openai_api_key="${openai_api_key:-${provider_openai_api_key:-}}"
  openai_api_key_cmd="${openai_api_key_cmd:-${provider_openai_api_key_cmd:-}}"
  gemini_api_base="${gemini_api_base:-${provider_gemini_api_base:-}}"
  gemini_model="${gemini_model:-${provider_gemini_model:-}}"
  gemini_api_key="${gemini_api_key:-${provider_gemini_api_key:-}}"
  gemini_api_key_cmd="${gemini_api_key_cmd:-${provider_gemini_api_key_cmd:-}}"

  api_base_url="${api_base_url:-http://127.0.0.1}"
  while [[ "$api_base_url" == */ && "$api_base_url" != "http://" && "$api_base_url" != "https://" ]]; do
    api_base_url="${api_base_url%/}"
  done
  local_api_base="${local_api_base:-${api_base_url}:${api_base_port:-11435}}"
  while [[ "$local_api_base" == */ && "$local_api_base" != "http://" && "$local_api_base" != "https://" ]]; do
    local_api_base="${local_api_base%/}"
  done
  ollama_api_base="${ollama_api_base:-http://127.0.0.1:11434}"
  while [[ "$ollama_api_base" == */ && "$ollama_api_base" != "http://" && "$ollama_api_base" != "https://" ]]; do
    ollama_api_base="${ollama_api_base%/}"
  done
  lmstudio_api_base="${lmstudio_api_base:-http://127.0.0.1:1234}"
  while [[ "$lmstudio_api_base" == */ && "$lmstudio_api_base" != "http://" && "$lmstudio_api_base" != "https://" ]]; do
    lmstudio_api_base="${lmstudio_api_base%/}"
  done

  COMAI_PROVIDER="${COMAI_PROVIDER:-${provider:-local}}"
  ai_dir="${ai_dir:-~/ai}"
  if [[ "$ai_dir" == "~" ]]; then
    ai_dir="$HOME"
  elif [[ "${ai_dir:0:2}" == "~/" ]]; then
    ai_dir="$HOME/${ai_dir:2}"
  fi
  COMAI_AI_DIR="${COMAI_AI_DIR:-$ai_dir}"
  COMAI_LOCAL_MODEL="${COMAI_LOCAL_MODEL:-${local_model:-${model:-Qwen2.5-Coder-7B-Instruct-Q4_K_M}}}"
  COMAI_LOCAL_API_BASE="${COMAI_LOCAL_API_BASE:-${local_api_base}}"
  COMAI_OPENAI_MODEL="${COMAI_OPENAI_MODEL:-${gpt_model:-gpt-4o-mini}}"
  COMAI_GEMINI_MODEL="${COMAI_GEMINI_MODEL:-${gemini_model:-gemini-2.5-flash}}"
  COMAI_OLLAMA_MODEL="${COMAI_OLLAMA_MODEL:-${ollama_model:-qwen2.5-coder:7b}}"
  COMAI_LMSTUDIO_MODEL="${COMAI_LMSTUDIO_MODEL:-${lmstudio_model:-local-model}}"
  if [[ -z "${COMAI_MODEL:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_MODEL="$COMAI_OPENAI_MODEL"
        ;;
      gemini)
        COMAI_MODEL="$COMAI_GEMINI_MODEL"
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
  COMAI_GEMINI_API_BASE="${COMAI_GEMINI_API_BASE:-${gemini_api_base:-https://generativelanguage.googleapis.com}}"
  COMAI_OLLAMA_API_BASE="${COMAI_OLLAMA_API_BASE:-${ollama_api_base}}"
  COMAI_LMSTUDIO_API_BASE="${COMAI_LMSTUDIO_API_BASE:-${lmstudio_api_base}}"
  if [[ -z "${COMAI_API_BASE:-}" ]]; then
    case "$COMAI_PROVIDER" in
      openai)
        COMAI_API_BASE="$COMAI_OPENAI_API_BASE"
        ;;
      gemini)
        COMAI_API_BASE="$COMAI_GEMINI_API_BASE"
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
  COMAI_OPENAI_CONFIG_API_KEY="${COMAI_OPENAI_CONFIG_API_KEY:-${openai_api_key}}"
  COMAI_OPENAI_API_KEY="${COMAI_OPENAI_API_KEY:-${OPENAI_API_KEY:-${COMAI_OPENAI_CONFIG_API_KEY}}}"
  COMAI_GEMINI_API_KEY_CMD="${COMAI_GEMINI_API_KEY_CMD:-${gemini_api_key_cmd}}"
  COMAI_GEMINI_CONFIG_API_KEY="${COMAI_GEMINI_CONFIG_API_KEY:-${gemini_api_key}}"
  COMAI_GEMINI_API_KEY="${COMAI_GEMINI_API_KEY:-${GEMINI_API_KEY:-${COMAI_GEMINI_CONFIG_API_KEY}}}"
  COMAI_MAX_TOKENS="${COMAI_MAX_TOKENS:-${max_tokens:-900}}"
  COMAI_TIMEOUT="${COMAI_TIMEOUT:-${timeout:-120}}"
  log_file="${log_file:-logs/comai.log}"
  if [[ "$log_file" == "~" ]]; then
    log_file="$HOME"
  elif [[ "${log_file:0:2}" == "~/" ]]; then
    log_file="$HOME/${log_file:2}"
  elif [[ "$log_file" != /* ]]; then
    log_file="$COMAI_ROOT_DIR/$log_file"
  fi
  COMAI_LOG_FILE="${COMAI_LOG_FILE:-$log_file}"
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
  comai gemini hi
  comai --model=MODEL ask anything
  comai --provider gemini --model gemini-2.5-flash hi
  comai -- ollama is a provider name, but treat this as my question

Options:
  gpt, chatgpt                 Use OpenAI ChatGPT for this request
  --gpt, --chatgpt             Use OpenAI ChatGPT for this request
  ollama                       Use Ollama for this request
  --ollama                     Use Ollama for this request
  lmstudio                     Use LM Studio for this request
  --lmstudio                   Use LM Studio for this request
  gemini                       Use Gemini for this request
  --gemini                     Use Gemini for this request
  --model MODEL, --model=MODEL   Use a different model for this request
  --api-base URL, --api-base=URL Use a different provider API base
  --max-tokens N                Limit answer length; N must be a positive integer
  -f, --file PATH               Add a readable file as context
  --                            Treat the remaining words as the request, not options/providers
  --local                       Accepted for old commands; the request still goes to AI

Config:
  $COMAI_ROOT_DIR/config/comai.yaml

Environment:
  OPENAI_API_KEY               Overrides openai_api_key for: comai gpt ...
  COMAI_OPENAI_API_KEY_CMD     Command that prints an OpenAI API key, for example: pass show openai
  GEMINI_API_KEY               Overrides providers.gemini.api_key for: comai gemini ...
  COMAI_GEMINI_API_KEY_CMD     Command that prints a Gemini API key, for example: pass show gemini
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
  COMAI_GEMINI_MODEL=$COMAI_GEMINI_MODEL
  COMAI_GEMINI_API_BASE=$COMAI_GEMINI_API_BASE
  COMAI_GEMINI_API_KEY=${COMAI_GEMINI_API_KEY:+set}
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
  comai_provider_select openai
}

comai_select_gemini_provider() {
  comai_provider_select gemini
}

comai_select_ollama_provider() {
  comai_provider_select ollama
}

comai_select_lmstudio_provider() {
  comai_provider_select lmstudio
}

comai_select_local_provider() {
  comai_provider_select local
}
