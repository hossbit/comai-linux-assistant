# shellcheck shell=bash disable=SC2154

comai_localai_helper() {
  local name="$1"

  if [[ -x "$COMAI_AI_DIR/bin/$name" ]]; then
    printf '%s\n' "$COMAI_AI_DIR/bin/$name"
  elif [[ -x "$COMAI_AI_DIR/$name" ]]; then
    printf '%s\n' "$COMAI_AI_DIR/$name"
  else
    return 1
  fi
}

comai_cmd_local_service() {
  local action="$1"
  local service_name="${COMAI_LOCALAI_SERVICE_NAME:-comai-localai.service}"
  local service_file="$HOME/.config/systemd/user/$service_name"
  local start_helper stop_helper

  case "$action" in
    start | stop | restart) ;;
    *)
      comai_error "usage: comai start|stop|restart"
      return 1
      ;;
  esac

  comai_log info service "$action requested service=$service_name ai_dir=$COMAI_AI_DIR"

  if comai_have systemctl && [[ -f "$service_file" ]]; then
    systemctl --user "$action" "$service_name"
    comai_log info service "$action ok service=$service_name method=systemctl"
    printf '%s: %s\n' "$service_name" "$action"
    return 0
  fi

  case "$action" in
    start)
      if ! start_helper="$(comai_localai_helper start.sh)"; then
        comai_log error service "start failed missing=$COMAI_AI_DIR/bin/start.sh"
        comai_error "start script not found or not executable: $COMAI_AI_DIR/bin/start.sh"
        return 1
      fi
      "$start_helper"
      ;;
    stop)
      if ! stop_helper="$(comai_localai_helper stop.sh)"; then
        comai_log error service "stop failed missing=$COMAI_AI_DIR/bin/stop.sh"
        comai_error "stop script not found or not executable: $COMAI_AI_DIR/bin/stop.sh"
        return 1
      fi
      "$stop_helper"
      ;;
    restart)
      if ! stop_helper="$(comai_localai_helper stop.sh)" || ! start_helper="$(comai_localai_helper start.sh)"; then
        comai_log error service "restart failed missing_start_or_stop ai_dir=$COMAI_AI_DIR"
        comai_error "restart requires executable scripts: $COMAI_AI_DIR/bin/stop.sh and $COMAI_AI_DIR/bin/start.sh"
        return 1
      fi
      "$stop_helper"
      "$start_helper"
      ;;
  esac

  comai_log info service "$action ok method=scripts ai_dir=$COMAI_AI_DIR"
  printf 'local service: %s\n' "$action"
}
