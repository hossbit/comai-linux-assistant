#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  COMAI_ROOT_DIR="$REPO_ROOT"
  source "$REPO_ROOT/lib/comai/config.sh"
  source "$REPO_ROOT/lib/comai/args.sh"
  source "$REPO_ROOT/lib/comai/context.sh"

  COMAI_LOCAL_MODEL="local-model"
  COMAI_LOCAL_API_BASE="http://local.invalid"
  COMAI_OPENAI_MODEL="openai-model"
  COMAI_OPENAI_API_BASE="https://api.openai.com"
  COMAI_OLLAMA_MODEL="ollama-model"
  COMAI_OLLAMA_API_BASE="http://ollama.invalid"
  COMAI_LMSTUDIO_MODEL="lmstudio-model"
  COMAI_LMSTUDIO_API_BASE="http://lmstudio.invalid"
  COMAI_MODEL_EXPLICIT=0
}

@test "routes leading gpt shortcut to OpenAI provider" {
  comai_parse_args gpt "hello"

  [ "$COMAI_PROVIDER" = "openai" ]
  [ "$COMAI_MODEL" = "openai-model" ]
  [ "${REQUEST_ARGS[*]}" = "hello" ]
}

@test "keeps provider words inside the request after the first argument" {
  comai_parse_args "explain" "local" "networking"

  [ "${REQUEST_ARGS[*]}" = "explain local networking" ]
}

@test "requires a path after --file" {
  run comai_parse_args --file

  [ "$status" -eq 1 ]
  [[ "$output" == *"missing path after --file/-f"* ]]
}

@test "does not implicitly attach mentioned files for remote providers" {
  touch "$BATS_TEST_TMPDIR/secret.txt"
  cd "$BATS_TEST_TMPDIR"
  COMAI_PROVIDER="openai"
  REQUEST_ARGS=("please read secret.txt")
  FILES=()

  comai_detect_mentioned_files

  [ "${#FILES[@]}" -eq 0 ]
}

@test "still detects mentioned files for local provider shortcuts" {
  touch "$BATS_TEST_TMPDIR/note.txt"
  cd "$BATS_TEST_TMPDIR"
  COMAI_PROVIDER="local"
  REQUEST_ARGS=("please read note.txt")
  FILES=()

  comai_detect_mentioned_files

  [ "${#FILES[@]}" -eq 1 ]
  [ "${FILES[0]}" = "note.txt" ]
}
