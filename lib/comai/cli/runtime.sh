# shellcheck shell=bash disable=SC2154

comai_log() {
  local level="$1"
  local event="$2"
  shift 2

  [[ "${COMAI_LOG_ENABLED:-1}" != "0" ]] || return 0
  [[ -n "${COMAI_LOG_FILE:-}" ]] || return 0
  mkdir -p "$(dirname "$COMAI_LOG_FILE")"
  chmod 700 "$(dirname "$COMAI_LOG_FILE")" 2> /dev/null || true
  {
    umask 077
    printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$event" "$*" >> "$COMAI_LOG_FILE"
  }
  chmod 600 "$COMAI_LOG_FILE" 2> /dev/null || true
}

comai_history_add() {
  local request="$1"
  local response="$2"

  [[ "${COMAI_HISTORY_ENABLED:-1}" != "0" ]] || return 0
  mkdir -p "$(dirname "$COMAI_HISTORY_FILE")"
  chmod 700 "$(dirname "$COMAI_HISTORY_FILE")" 2> /dev/null || true
  {
    umask 077
    printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$COMAI_PROVIDER/$COMAI_MODEL" "$request"
    printf '%s\n\n' "$response"
  } >> "$COMAI_HISTORY_FILE"
  chmod 600 "$COMAI_HISTORY_FILE" 2> /dev/null || true
}

comai_read_stdin_if_piped() {
  if [[ ! -t 0 ]]; then
    cat
  fi
}

comai_confirm_cloud_file_context() {
  local answer

  [[ "${#FILES[@]}" -gt 0 ]] || return 0
  comai_provider_requires_key "$COMAI_PROVIDER" || return 0

  comai_error "notice: ${#FILES[@]} file(s) will be sent to the ${COMAI_PROVIDER} cloud provider as prompt context."
  if [[ "${COMAI_ASSUME_YES:-0}" == "1" || "${COMAI_CLOUD_FILE_CONFIRM:-1}" == "0" ]]; then
    return 0
  fi
  if [[ -t 0 && -t 1 ]]; then
    printf 'Continue? [y/N] ' >&2
    IFS= read -r answer
    case "$answer" in
      y | Y | yes | YES) return 0 ;;
      *)
        comai_error "cancelled before sending file context."
        return 1
        ;;
    esac
  fi
  comai_error "non-interactive shell; set COMAI_ASSUME_YES=1 to allow cloud file context."
  return 1
}

comai_spinner_enabled() {
  case "${COMAI_SPINNER:-auto}" in
    0 | false | no) return 1 ;;
    1 | true | yes) return 0 ;;
  esac
  [[ -t 2 ]]
}

comai_color_enabled() {
  [[ -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]] || return 1
  case "${COMAI_COLOR:-auto}" in
    0 | false | no) return 1 ;;
    1 | true | yes) return 0 ;;
  esac
  [[ -z "${NO_COLOR:-}" && -t 1 ]]
}

comai_color_cache() {
  if comai_color_enabled; then
    COMAI_COLOR=1
  else
    COMAI_COLOR=0
  fi
}

comai_color() {
  local code="$1"
  shift
  if comai_color_enabled; then
    printf '\033[%sm%s\033[0m' "$code" "$*"
  else
    printf '%s' "$*"
  fi
}

comai_color_ok() {
  comai_color '32' "$@"
}

comai_color_warn() {
  comai_color '33' "$@"
}

comai_color_fail() {
  comai_color '31' "$@"
}

comai_color_dim() {
  comai_color '2' "$@"
}

comai_format_status_text() {
  local text="$1"

  case "$text" in
    ok) comai_color_ok "$text" ;;
    *"not checked"*) comai_color_warn "$text" ;;
    *) comai_color_fail "$text" ;;
  esac
}

comai_spinner_frames() {
  if [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *UTF-8* || "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *utf8* ]]; then
    printf '⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏\n'
  else
    printf -- '- \\ | /\n'
  fi
}

comai_run_with_spinner_capture() {
  local result_var="$1"
  local message="$2"
  local output_file status_file pid spinner_pid status interrupted
  local captured
  shift 2

  output_file="$(mktemp "${TMPDIR:-/tmp}/comai-output.XXXXXX")" || return 1
  status_file="$(mktemp "${TMPDIR:-/tmp}/comai-status.XXXXXX")" || {
    rm -f "$output_file"
    return 1
  }
  chmod 600 "$output_file" "$status_file" 2> /dev/null || true

  if ! comai_spinner_enabled; then
    if "$@" > "$output_file"; then
      status=0
    else
      status="$?"
    fi
    captured="$(cat "$output_file" 2> /dev/null || true)"
    printf -v "$result_var" '%s' "$captured"
    rm -f "$output_file" "$status_file"
    return "$status"
  fi

  (
    set +e
    "$@" > "$output_file"
    printf '%s\n' "$?" > "$status_file"
  ) &
  pid=$!
  spinner_pid=""
  interrupted=0

  trap '[[ -n "${pid:-}" ]] && kill "$pid" 2> /dev/null || true; [[ -n "${spinner_pid:-}" ]] && kill "$spinner_pid" 2> /dev/null || true; printf "\r\033[K" >&2; rm -f "$output_file" "$status_file"' EXIT
  trap 'interrupted=1; [[ -n "${pid:-}" ]] && kill "$pid" 2> /dev/null || true; [[ -n "${spinner_pid:-}" ]] && kill "$spinner_pid" 2> /dev/null || true; printf "\r\033[K" >&2' INT TERM

  (
    local frames frame
    read -r -a frames <<< "$(comai_spinner_frames)"
    while kill -0 "$pid" 2> /dev/null; do
      for frame in "${frames[@]}"; do
        printf '\r\033[K%s  %s' "$frame" "$message" >&2
        sleep 0.12
        kill -0 "$pid" 2> /dev/null || break
      done
    done
  ) &
  spinner_pid=$!

  wait "$pid" || true
  kill "$spinner_pid" 2> /dev/null || true
  wait "$spinner_pid" 2> /dev/null || true
  printf '\r\033[K' >&2
  trap - INT TERM EXIT

  if [[ "$interrupted" -eq 1 ]]; then
    rm -f "$output_file" "$status_file"
    return 130
  fi

  status="$(cat "$status_file" 2> /dev/null || printf '1\n')"
  captured="$(cat "$output_file" 2> /dev/null || true)"
  printf -v "$result_var" '%s' "$captured"
  rm -f "$output_file" "$status_file"
  return "$status"
}

comai_run_request() {
  local text text_lc dir_context files prompt
  local response ready_status local_handler

  COMAI_LAST_RESPONSE=""
  COMAI_FILES_SEEN=()

  comai_parse_args "$@" || return 1
  comai_detect_mentioned_files

  text="$(comai_join_args "${REQUEST_ARGS[@]}")"
  if [[ -z "$text" ]]; then
    text="Answer using the provided file and directory context."
  fi
  text_lc="${text,,}"
  comai_log info request_start "provider=$COMAI_PROVIDER model=$COMAI_MODEL chars=${#text} files=${#FILES[@]}"

  if [[ "$COMAI_PROVIDER" == "local" ]]; then
    for local_handler in comai_answer_local_file_fact comai_answer_file_contains comai_answer_file_errors comai_answer_file_description; do
      if response="$("$local_handler" "$text" "$text_lc")"; then
        printf '%s\n' "$response" | comai_strip_terminal_controls
        COMAI_LAST_RESPONSE="$response"
        comai_history_add "$text" "$response"
        comai_log info local_answer "kind=$local_handler chars=${#text}"
        return 0
      fi
    done
  fi

  if [[ "$COMAI_PROVIDER" == "local" ]]; then
    ready_status=0
    comai_local_ai_ready || ready_status=$?
    case "$ready_status" in
      0) ;;
      2)
        comai_log error request_failed "provider=$COMAI_PROVIDER model=$COMAI_MODEL reason=local_api_unauthorized api_base=$COMAI_API_BASE"
        comai_error "Local provider API at ${COMAI_API_BASE} returned 401 Unauthorized."
        comai_error "Set providers.local.api_key in ${COMAI_CONFIG_FILE}, or export LOCALAI_API_KEY."
        return 1
        ;;
      *)
        comai_log error request_failed "provider=$COMAI_PROVIDER model=$COMAI_MODEL reason=local_api_unreachable api_base=$COMAI_API_BASE"
        comai_error "Local provider API is not responding at ${COMAI_API_BASE}."
        comai_error "Start your OpenAI-compatible local server, or edit: ${COMAI_CONFIG_FILE}"
        comai_error "For the bundled LocalAI helper, run: systemctl --user start comai-localai.service"
        return 1
        ;;
    esac
  fi

  comai_confirm_cloud_file_context || return 1

  dir_context=""
  if comai_wants_directory_context "$text" "$text_lc"; then
    dir_context="$(comai_directory_context)"
  fi

  files="$(comai_file_context)"
  prompt="$(comai_ai_prompt "$text" "$dir_context" "$files")"
  if ! comai_run_with_spinner_capture response "ComAI Thinking ( ${COMAI_PROVIDER} )" comai_ask_ai "$prompt"; then
    comai_log error request_failed "provider=$COMAI_PROVIDER model=$COMAI_MODEL"
    return 1
  fi
  printf '%s\n' "$response" | comai_strip_terminal_controls
  COMAI_LAST_RESPONSE="$response"
  comai_history_add "$text" "$response"
  comai_log info request_ok "provider=$COMAI_PROVIDER model=$COMAI_MODEL response_chars=${#response}"
}

comai_chat_status() {
  printf 'Provider: %s | Model: %s | Context: %s/%s characters\n' \
    "$COMAI_PROVIDER" "$COMAI_MODEL" "$1" "$2" | comai_strip_terminal_controls
}

comai_chat_help() {
  printf '%s\n' \
    '/help    Show chat commands' \
    '/status  Show provider, model, and context usage' \
    '/clear   Start a fresh conversation (saved history is unchanged)' \
    '/exit    Leave chat (also /quit or Ctrl-D)' \
    'Use // to send a message beginning with /.'
}

comai_cmd_chat() {
  local line chat_context="" chat_prompt max_context turn interactive=0 chat_status=0
  local -a turns=() chat_files=() request_options=()

  max_context="${COMAI_CHAT_CONTEXT_MAX:-12000}"
  if [[ ! "$max_context" =~ ^[1-9][0-9]{0,8}$ ]]; then
    comai_error 'COMAI_CHAT_CONTEXT_MAX must be a positive integer below 1000000000.'
    return 1
  fi
  comai_parse_args "$@" || return 1
  if [[ "${#REQUEST_ARGS[@]}" -gt 0 ]]; then
    comai_error 'usage: comai chat [--provider NAME] [--model MODEL] [--max-tokens N] [-f FILE]'
    return 1
  fi
  chat_files=("${FILES[@]}")
  for line in "${chat_files[@]}"; do request_options+=(-f "$line"); done
  [[ -t 0 && -t 1 ]] && interactive=1

  if [[ "$interactive" -eq 1 ]]; then
    comai_color '1;36' 'ComAI Chat'
    printf '\n'
    comai_chat_status 0 "$max_context"
    printf 'Type /help for commands, /clear to reset, /exit to quit.\n\n'
  fi
  while true; do
    if [[ "$interactive" -eq 1 ]]; then
      IFS= read -e -r -p 'You > ' line || break
    else
      IFS= read -r line || [[ -n "$line" ]] || break
    fi
    case "$line" in
      /exit | /quit) break ;;
      /help) comai_chat_help; continue ;;
      /status) comai_chat_status "${#chat_context}" "$max_context"; continue ;;
      /clear)
        turns=(); chat_context=""; COMAI_LAST_RESPONSE=""
        printf 'Conversation cleared.\n'
        continue
        ;;
      //*) line="${line:1}" ;;
      /*) comai_error 'unknown chat command; use /help or // to send a literal slash.'; continue ;;
      "") continue ;;
    esac
    if [[ -n "$chat_context" ]]; then
      chat_prompt="Conversation so far:
${chat_context}

Latest user message:
${line}

Answer the latest user message using the conversation context when helpful."
    else
      chat_prompt="$line"
    fi
    if [[ "$interactive" -eq 1 ]]; then
      comai_color '1;36' 'ComAI >'
      printf '\n'
    fi
    # A typed message is data, never provider selection or a CLI option.
    if comai_run_request "${request_options[@]}" -- "$chat_prompt"; then
      chat_status=0
    else
      chat_status=$?
      comai_error 'Message failed; conversation kept. Try again or use /exit.'
      continue
    fi
    [[ "$interactive" -eq 0 ]] || printf '\n'
    turns+=("User: ${line}"$'\n'"Assistant: ${COMAI_LAST_RESPONSE:-}"$'\n')
    chat_context=""
    for turn in "${turns[@]}"; do chat_context+="$turn"; done
    # Drop complete turns instead of slicing through code or role labels.
    while [[ "${#chat_context}" -gt "$max_context" && "${#turns[@]}" -gt 0 ]]; do
      turns=("${turns[@]:1}")
      chat_context=""
      for turn in "${turns[@]}"; do chat_context+="$turn"; done
    done
  done
  return "$chat_status"
}

comai_cmd_version() {
  printf 'ComAI %s\n' "$COMAI_VERSION"
}
