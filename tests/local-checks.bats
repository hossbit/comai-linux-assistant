#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$REPO_ROOT/lib/comai/config.sh"
  source "$REPO_ROOT/lib/comai/local-checks.sh"

  COMAI_ERROR_RE='error|failed|warn'
  COMAI_ERROR_INTENT_RE='error|warning|problem|check (this )?log'
  FILES=()
  cd "$BATS_TEST_TMPDIR"
}

@test "answers newest file fact from current directory" {
  touch -t 202001010000 old.txt
  touch -t 202101010000 new.txt

  run comai_answer_local_file_fact "newest file"

  [ "$status" -eq 0 ]
  [[ "$output" == *"newest file"* ]]
  [[ "$output" == *"./new.txt"* ]]
}

@test "answers whether a file contains a requested number" {
  printf 'ticket 12345\n' >log.txt
  FILES=(log.txt)

  run comai_answer_file_contains "does this file contain number 12345"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Yes."* ]]
  [[ "$output" == *"12345"* ]]
}

@test "reports possible issue lines in logs" {
  printf 'ok\nwarning: disk almost full\n' >app.log
  FILES=(app.log)

  run comai_answer_file_errors "check this log for warnings"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 1 possible issue line"* ]]
  [[ "$output" == *"warning: disk almost full"* ]]
}
