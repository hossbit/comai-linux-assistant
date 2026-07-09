#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  case "$haystack" in
    *"$needle"*) ;;
    *)
      printf 'Expected output to contain: %s\n' "$needle" >&2
      printf 'Actual output:\n%s\n' "$haystack" >&2
      return 1
      ;;
  esac
}

test_max_tokens_validation() {
  local output

  output="$(COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --max-tokens=abc hi 2>&1 || true)"
  assert_contains "$output" '--max-tokens must be a positive integer.'

  output="$(COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --max-tokens -5 hi 2>&1 || true)"
  assert_contains "$output" '--max-tokens must be a positive integer.'
}

test_global_flags_before_commands() {
  local output

  output="$(COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --local status 2>&1 || true)"
  assert_contains "$output" 'Provider: local (active)'

  output="$(COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --gpt version 2>&1)"
  assert_contains "$output" 'ComAI '

  output="$(COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --provider gemini --model gemini-2.5-flash status 2>&1 || true)"
  assert_contains "$output" 'Provider: gemini (active)'
  assert_contains "$output" 'Model: gemini-2.5-flash'
}

test_arg_parser_directly() {
  local output

  output="$(
    COMAI_ROOT_DIR="$ROOT_DIR" bash -c '
      set -euo pipefail
      . "$1/lib/comai/config.sh"
      . "$1/lib/comai/providers/registry.sh"
      . "$1/lib/comai/providers/openai-compatible.sh"
      . "$1/lib/comai/providers/local.sh"
      . "$1/lib/comai/providers/ollama.sh"
      . "$1/lib/comai/providers/lmstudio.sh"
      . "$1/lib/comai/providers/openai.sh"
      . "$1/lib/comai/providers/gemini.sh"
      . "$1/lib/comai/args.sh"
      COMAI_LOCAL_MODEL=local-test
      COMAI_LOCAL_API_BASE=http://127.0.0.1:11435
      COMAI_OPENAI_MODEL=gpt-4o-mini
      COMAI_OPENAI_API_BASE=https://api.openai.com
      COMAI_GEMINI_MODEL=gemini-2.5-flash
      COMAI_GEMINI_API_BASE=https://generativelanguage.googleapis.com
      COMAI_OLLAMA_MODEL=qwen2.5-coder:7b
      COMAI_OLLAMA_API_BASE=http://127.0.0.1:11434
      COMAI_LMSTUDIO_MODEL=local-model
      COMAI_LMSTUDIO_API_BASE=http://127.0.0.1:1234
      COMAI_PROVIDER=local
      COMAI_MAX_TOKENS=900
      comai_parse_args --provider gemini --max-tokens 321 --model gemini-2.5-flash hello
      printf "provider=%s\nmodel=%s\ntokens=%s\nrequest=%s\n" "$COMAI_PROVIDER" "$COMAI_MODEL" "$COMAI_MAX_TOKENS" "${REQUEST_ARGS[*]}"
    ' bash "$ROOT_DIR"
  )"
  assert_contains "$output" 'provider=gemini'
  assert_contains "$output" 'model=gemini-2.5-flash'
  assert_contains "$output" 'tokens=321'
  assert_contains "$output" 'request=hello'
}

test_spaced_file_detection() {
  local tmp_dir output

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-test.XXXXXX")"
  printf 'line one\nnumber 4242\n' > "$tmp_dir/my long file name.txt"

  output="$(
    COMAI_LOG_ENABLED=0 bash -c '
      cd "$1"
      "$2/bin/comai" does my long file name.txt contain number 4242
    ' bash "$tmp_dir" "$ROOT_DIR"
  )"
  assert_contains "$output" 'Yes. `4242` appears in my long file name.txt'
  rm -rf "$tmp_dir"
}

test_piped_analyze_uses_local_file_scan() {
  local tmp_dir output

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-test.XXXXXX")"
  output="$(
    COMAI_LOG_ENABLED=0 bash -c '
      cd "$1"
      printf "ok\nERROR bad\n" | "$2/bin/comai" analyze
    ' bash "$tmp_dir" "$ROOT_DIR"
  )"
  assert_contains "$output" 'Found 1 possible issue line'
  rm -rf "$tmp_dir"
}

test_config_redaction_and_backup_rotation() {
  local tmp_dir cfg output backups

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-test.XXXXXX")"
  cfg="$tmp_dir/comai.yaml"
  cp "$ROOT_DIR/config/comai.yaml" "$cfg"

  output="$(
    COMAI_LOG_ENABLED=0 COMAI_CONFIG="$cfg" bash -c '
      COMAI_ROOT_DIR="$1"
      . "$1/lib/comai/config.sh"
      comai_load_config
      . "$1/lib/comai/providers/registry.sh"
      . "$1/lib/comai/cli/config.sh"
      comai_set_provider_config_value openai api_key_cmd "pass show openai"
      comai_cmd_config show
    ' bash "$ROOT_DIR"
  )"
  assert_contains "$output" 'api_key_cmd: [set]'

  for n in 1 2 3 4 5 6 7; do
    printf 'backup %s\n' "$n" > "$cfg.backup.$n"
  done
  COMAI_ROOT_DIR="$ROOT_DIR" COMAI_CONFIG_BACKUP_KEEP=5 bash -c '
    . "$1/lib/comai/config.sh"
    comai_rotate_config_backups "$2"
  ' bash "$ROOT_DIR" "$cfg"
  backups="$(find "$tmp_dir" -maxdepth 1 -name 'comai.yaml.backup.*' | wc -l | tr -d '[:space:]')"
  [[ "$backups" == "5" ]]
  rm -rf "$tmp_dir"
}

test_yaml_provider_writer() {
  local tmp_dir cfg output

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-test.XXXXXX")"
  cfg="$tmp_dir/comai.yaml"
  cp "$ROOT_DIR/config/comai.yaml" "$cfg"

  output="$(
    COMAI_ROOT_DIR="$ROOT_DIR" COMAI_CONFIG="$cfg" bash -c '
      set -euo pipefail
      . "$1/lib/comai/config.sh"
      comai_load_config
      comai_set_provider_config_value gemini model gemini-2.5-pro
      comai_set_provider_config_value openai api_base https://api.openai.com
      comai_yaml_provider_value gemini model "$2"
      comai_yaml_provider_value openai api_base "$2"
    ' bash "$ROOT_DIR" "$cfg"
  )"
  assert_contains "$output" 'gemini-2.5-pro'
  assert_contains "$output" 'https://api.openai.com'
  rm -rf "$tmp_dir"
}

main() {
  test_max_tokens_validation
  test_global_flags_before_commands
  test_arg_parser_directly
  test_spaced_file_detection
  test_piped_analyze_uses_local_file_scan
  test_config_redaction_and_backup_rotation
  test_yaml_provider_writer
  printf 'tests/core.sh: ok\n'
}

main "$@"
