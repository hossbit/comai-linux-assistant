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
  local response

  comai_parse_args "$@" || return 1
  comai_detect_mentioned_files

  text="$(comai_join_args "${REQUEST_ARGS[@]}")"
  if [[ -z "$text" ]]; then
    text="Answer using the provided file and directory context."
  fi
  text_lc="${text,,}"
  comai_log info request_start "provider=$COMAI_PROVIDER model=$COMAI_MODEL chars=${#text} files=${#FILES[@]}"

  if [[ "$COMAI_PROVIDER" == "local" ]]; then
    if comai_answer_local_file_fact "$text" "$text_lc"; then
      comai_log info local_answer "kind=file_fact chars=${#text}"
      return 0
    fi

    if comai_answer_file_contains "$text" "$text_lc"; then
      comai_log info local_answer "kind=file_contains chars=${#text}"
      return 0
    fi

    if comai_answer_file_errors "$text" "$text_lc"; then
      comai_log info local_answer "kind=file_errors chars=${#text}"
      return 0
    fi

    if comai_answer_file_description "$text" "$text_lc"; then
      comai_log info local_answer "kind=file_description chars=${#text}"
      return 0
    fi
  fi

  if [[ "$COMAI_PROVIDER" == "local" ]] && ! comai_local_ai_ready; then
    comai_log error request_failed "provider=$COMAI_PROVIDER model=$COMAI_MODEL reason=local_api_unreachable api_base=$COMAI_API_BASE"
    comai_error "Local provider API is not responding at ${COMAI_API_BASE}."
    comai_error "Start your OpenAI-compatible local server, or edit: ${COMAI_CONFIG_FILE}"
    comai_error "For the bundled LocalAI helper, run: systemctl --user start comai-localai.service"
    return 1
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

comai_cmd_chat() {
  local line chat_context chat_prompt max_context

  printf 'ComAI chat. Type /exit to quit.\n'
  chat_context=""
  max_context="${COMAI_CHAT_CONTEXT_MAX:-12000}"
  while true; do
    printf '> '
    IFS= read -r line || break
    case "$line" in
      /exit | /quit) break ;;
      "") continue ;;
    esac
    if [[ -n "$chat_context" ]]; then
      chat_prompt="$(cat << EOF
Conversation so far:
${chat_context}

Latest user message:
${line}

Answer the latest user message using the conversation context when helpful.
EOF
)"
    else
      chat_prompt="$line"
    fi

    comai_run_request "$chat_prompt" || return 1
    chat_context="${chat_context}"$'\n'"User: ${line}"$'\n'"Assistant: ${COMAI_LAST_RESPONSE:-}"
    if [[ "${#chat_context}" -gt "$max_context" ]]; then
      chat_context="${chat_context: -$max_context}"
    fi
  done
}

comai_cmd_version() {
  printf 'ComAI %s\n' "$COMAI_VERSION"
}
