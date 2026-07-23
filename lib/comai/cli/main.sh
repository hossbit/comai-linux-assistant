# shellcheck shell=bash disable=SC2154

comai_parse_global_prefix() {
  local arg provider_flag

  COMAI_MAIN_ARGS=()

  while [[ "$#" -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --)
        COMAI_MAIN_ARGS+=("$@")
        return 0
        ;;
      gpt | chatgpt)
        comai_provider_select openai
        shift
        ;;
      ollama | lmstudio | gemini | local)
        comai_provider_select "$arg"
        shift
        ;;
      lm-studio)
        comai_provider_select lmstudio
        shift
        ;;
      opr)
        comai_provider_select openrouter
        shift
        ;;
      lms)
        comai_provider_select lmstudio
        shift
        ;;
      olm)
        comai_provider_select ollama
        shift
        ;;
      gem)
        comai_provider_select gemini
        shift
        ;;
      --gpt | --chatgpt)
        comai_provider_select openai
        shift
        ;;
      --opr | --openrouter)
        comai_provider_select openrouter
        shift
        ;;
      --lms)
        comai_provider_select lmstudio
        shift
        ;;
      --olm)
        comai_provider_select ollama
        shift
        ;;
      --gem)
        comai_provider_select gemini
        shift
        ;;
      --provider=*)
        provider_flag="${arg#--provider=}"
        if ! comai_provider_select "$provider_flag"; then
          comai_error "unknown provider: $provider_flag"
          return 1
        fi
        shift
        ;;
      --provider)
        if [[ -z "${2:-}" ]]; then
          comai_error "missing provider after --provider"
          return 1
        fi
        if ! comai_provider_select "$2"; then
          comai_error "unknown provider: $2"
          return 1
        fi
        shift 2
        ;;
      --model=*)
        COMAI_MODEL="${arg#--model=}"
        COMAI_MODEL_EXPLICIT=1
        shift
        ;;
      --model | -m)
        if [[ -z "${2:-}" ]]; then
          comai_error "missing model after --model"
          return 1
        fi
        COMAI_MODEL="$2"
        COMAI_MODEL_EXPLICIT=1
        shift 2
        ;;
      --api-base=*)
        COMAI_API_BASE="${arg#--api-base=}"
        shift
        ;;
      --api-base)
        if [[ -z "${2:-}" ]]; then
          comai_error "missing URL after --api-base"
          return 1
        fi
        COMAI_API_BASE="$2"
        shift 2
        ;;
      --max-tokens=*)
        comai_validate_max_tokens "${arg#--max-tokens=}" || return 1
        COMAI_MAX_TOKENS="${arg#--max-tokens=}"
        shift
        ;;
      --max-tokens)
        if [[ -z "${2:-}" ]]; then
          comai_error "missing number after --max-tokens"
          return 1
        fi
        comai_validate_max_tokens "$2" || return 1
        COMAI_MAX_TOKENS="$2"
        shift 2
        ;;
      --*)
        provider_flag="${arg#--}"
        provider_flag="${provider_flag//-/_}"
        if [[ "$provider_flag" == "lm_studio" ]]; then
          provider_flag="lmstudio"
        fi
        if comai_provider_exists "$provider_flag"; then
          comai_provider_select "$provider_flag"
          shift
        else
          break
        fi
        ;;
      *)
        break
        ;;
    esac
  done

  COMAI_MAIN_ARGS+=("$@")
}

comai_main() {
  local command stdin_text stdin_file status

  comai_load_config

  comai_parse_global_prefix "$@" || return 1
  set -- "${COMAI_MAIN_ARGS[@]}"

  if [[ "$#" -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    comai_usage
    return 0
  fi

  command="$1"
  shift

  case "$command" in
    setup)
      comai_cmd_setup "$@"
      ;;
    ask)
      comai_run_request "$@"
      ;;
    chat)
      comai_cmd_chat "$@"
      ;;
    explain)
      stdin_text="$(comai_read_stdin_if_piped)"
      if [[ -n "$stdin_text" ]]; then
        stdin_file="$(mktemp "${TMPDIR:-/tmp}/comai-stdin.XXXXXX")" || return 1
        chmod 600 "$stdin_file" 2> /dev/null || true
        printf '%s\n' "$stdin_text" > "$stdin_file"
        if comai_run_request "Explain clearly:" "$@" -f "$stdin_file"; then
          status=0
        else
          status="$?"
        fi
        rm -f "$stdin_file"
        return "$status"
      fi
      comai_run_request "Explain clearly:" "$@"
      ;;
    analyze)
      stdin_text="$(comai_read_stdin_if_piped)"
      if [[ -n "$stdin_text" ]]; then
        stdin_file="$(mktemp "${TMPDIR:-/tmp}/comai-stdin.XXXXXX")" || return 1
        chmod 600 "$stdin_file" 2> /dev/null || true
        printf '%s\n' "$stdin_text" > "$stdin_file"
        if comai_run_request "Analyze this for errors, warnings, issues, and important findings:" "$@" -f "$stdin_file"; then
          status=0
        else
          status="$?"
        fi
        rm -f "$stdin_file"
        return "$status"
      fi
      comai_run_request "Analyze this for errors, warnings, issues, and important findings:" "$@"
      ;;
    status)
      comai_cmd_status "$@"
      ;;
    provider)
      comai_cmd_provider "$@"
      ;;
    models)
      comai_cmd_models "$@"
      ;;
    config)
      comai_cmd_config "$@"
      ;;
    history)
      comai_cmd_history "$@"
      ;;
    start | stop | restart)
      comai_cmd_local_service "$command"
      ;;
    update)
      comai_cmd_update "$@"
      ;;
    version | --version | -V)
      comai_cmd_version
      ;;
    uninstall)
      comai_cmd_uninstall "$@"
      ;;
    *)
      comai_run_request "$command" "$@"
      ;;
  esac
}
