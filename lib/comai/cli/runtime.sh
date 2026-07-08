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

  dir_context=""
  if comai_wants_directory_context "$text" "$text_lc"; then
    dir_context="$(comai_directory_context)"
  fi

  files="$(comai_file_context)"
  prompt="$(comai_ai_prompt "$text" "$dir_context" "$files")"
  comai_model_note
  if ! response="$(comai_ask_ai "$prompt")"; then
    comai_log error request_failed "provider=$COMAI_PROVIDER model=$COMAI_MODEL"
    return 1
  fi
  printf '%s\n' "$response" | comai_strip_terminal_controls
  comai_history_add "$text" "$response"
  comai_log info request_ok "provider=$COMAI_PROVIDER model=$COMAI_MODEL response_chars=${#response}"
}

comai_cmd_chat() {
  local line

  printf 'ComAI chat. Type /exit to quit.\n'
  while true; do
    printf '> '
    IFS= read -r line || break
    case "$line" in
      /exit | /quit) break ;;
      "") continue ;;
    esac
    comai_run_request "$line" || return 1
  done
}

comai_cmd_version() {
  printf 'ComAI %s\n' "$COMAI_VERSION"
}
