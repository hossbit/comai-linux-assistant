#!/usr/bin/env bats
setup() {
  COMAI_ROOT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$COMAI_ROOT_DIR/lib/comai/config.sh"
  source "$COMAI_ROOT_DIR/lib/comai/ai.sh"
  source "$COMAI_ROOT_DIR/lib/comai/args.sh"
  source "$COMAI_ROOT_DIR/lib/comai/cli/runtime.sh"
  COMAI_PROVIDER=local
  COMAI_MODEL=test
  COMAI_LOG_ENABLED=0
  COMAI_HISTORY_ENABLED=0
}
@test "response cleanup preserves executable code, paths, Unicode and repeated text" {
  local sample=$'```python\nif True:\n    print("word word")\n\n\n```\ncd ../..\nprintf "hello  世界..."\nsame\nsame'
  [ "$(printf '%s' "$sample" | comai_clean_ai_output)" = "$sample" ]
}
@test "response cleanup removes terminal control bytes" {
  [ "$(printf 'one\007two\033three' | comai_clean_ai_output)" = onetwothree ]
}
@test "NO_COLOR overrides forced color" {
  NO_COLOR=1 COMAI_COLOR=1 run comai_color 32 hello
  [ "$output" = hello ]
}
@test "chat context limit rejects arithmetic and invalid values" {
  COMAI_CHAT_CONTEXT_MAX='1+2' run comai_cmd_chat
  [ "$status" -ne 0 ]
  [[ "$output" == *'positive integer'* ]]
}
@test "chat passes messages literally and preserves final line without newline" {
  comai_run_request() { printf 'arg:%s\n' "$@"; COMAI_LAST_RESPONSE=ok; }
  run comai_cmd_chat <<< $'--model=do-not-select\n/exit'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'arg:--\narg:--model=do-not-select'* ]]
  run bash -c 'source "$1/lib/comai/args.sh"; source "$1/lib/comai/cli/runtime.sh"; comai_run_request() { echo "$*"; }; printf hello | comai_cmd_chat' bash "$COMAI_ROOT_DIR"
  [[ "$output" == *hello* ]]
}
@test "chat clear removes prior turns" {
  comai_run_request() { printf '%s\n' "$*"; COMAI_LAST_RESPONSE=reply; }
  run comai_cmd_chat <<< $'first\n/clear\nsecond\n/exit'
  [ "$status" -eq 0 ]
  [[ "$output" != *'Conversation so far'* ]]
  [[ "$output" == *'Conversation cleared.'* ]]
}
@test "chat failed request keeps session available and excludes failed turn" {
  comai_run_request() { [[ "$*" != *fail* ]] || return 1; printf '%s\n' "$*"; COMAI_LAST_RESPONSE=reply; }
  run comai_cmd_chat <<< $'fail\nsuccess\n/exit'
  [ "$status" -eq 0 ]
  [[ "$output" == *'Message failed'* ]]
  [[ "$output" == *'success'* ]]
  [[ "$output" != *'Conversation so far'* ]]
}
@test "chat drops whole oversized turns" {
  COMAI_CHAT_CONTEXT_MAX=5
  comai_run_request() { printf '%s\n' "$*"; COMAI_LAST_RESPONSE=long; }
  run comai_cmd_chat <<< $'first\nsecond\n/exit'
  [[ "$output" != *'Conversation so far'* ]]
}
@test "chat help and status make no model request" {
  comai_run_request() { return 99; }
  run comai_cmd_chat <<< $'/help\n/status\n/exit'
  [ "$status" -eq 0 ]
  [[ "$output" == *'/clear'* ]]
  [[ "$output" == *'Provider: local | Model: test'* ]]
}
@test "chat startup rejects stray prompt text" {
  comai_provider_exists() { return 1; }
  run comai_cmd_chat unexpected
  [ "$status" -ne 0 ]
  [[ "$output" == *usage* ]]
}
@test "local answers update last response and reset file deduplication for each request" {
  declare -A COMAI_FILES_SEEN=([stale]=1)
  comai_detect_mentioned_files() { [[ -z "${COMAI_FILES_SEEN[stale]+x}" ]]; }
  comai_join_args() { printf '%s' "$*"; }
  comai_answer_local_file_fact() { printf fresh; }
  COMAI_LAST_RESPONSE=stale
  comai_run_request -- newest > "$BATS_TEST_TMPDIR/out"
  [ "$COMAI_LAST_RESPONSE" = fresh ]
  [ "$(cat "$BATS_TEST_TMPDIR/out")" = fresh ]
}
