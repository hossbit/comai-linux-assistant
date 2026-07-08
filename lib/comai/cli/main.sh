# shellcheck shell=bash disable=SC2154

comai_main() {
  local command stdin_text

  comai_load_config

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
      comai_run_request "Explain clearly:" "$@" "$stdin_text"
      ;;
    analyze)
      stdin_text="$(comai_read_stdin_if_piped)"
      comai_run_request "Analyze this and report important findings:" "$@" "$stdin_text"
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
