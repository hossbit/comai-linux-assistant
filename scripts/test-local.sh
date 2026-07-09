#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWK_CANDIDATES=()

add_awk_candidate() {
  local name="$1"
  local path

  path="$(command -v "$name" 2> /dev/null || true)"
  [[ -n "$path" ]] || return 0
  AWK_CANDIDATES+=("$name:$path")
}

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

run_with_awk() {
  local label="$1"
  local awk_path="$2"
  local tmp_dir output

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/comai-test.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' RETURN
  ln -s "$awk_path" "$tmp_dir/awk"

  printf 'awk: %s (%s)\n' "$label" "$awk_path"

  PATH="$tmp_dir:$PATH" bash -n \
    "$ROOT_DIR/bin/comai" \
    "$ROOT_DIR/lib/comai/config.sh" \
    "$ROOT_DIR/lib/comai/config/yaml.sh" \
    "$ROOT_DIR/lib/comai/config/files.sh" \
    "$ROOT_DIR/lib/comai/config/write.sh" \
    "$ROOT_DIR/lib/comai/config/keys.sh" \
    "$ROOT_DIR/lib/comai/config/load.sh" \
    "$ROOT_DIR/lib/comai/args.sh" \
    "$ROOT_DIR/lib/comai/providers/registry.sh" \
    "$ROOT_DIR/lib/comai/providers/openai-compatible.sh" \
    "$ROOT_DIR/lib/comai/providers/local.sh" \
    "$ROOT_DIR/lib/comai/providers/ollama.sh" \
    "$ROOT_DIR/lib/comai/providers/lmstudio.sh" \
    "$ROOT_DIR/lib/comai/providers/openai.sh" \
    "$ROOT_DIR/lib/comai/providers/gemini.sh" \
    "$ROOT_DIR/lib/comai/context.sh" \
    "$ROOT_DIR/lib/comai/local-checks.sh" \
    "$ROOT_DIR/lib/comai/ai.sh" \
    "$ROOT_DIR/tests/core.sh" \
    "$ROOT_DIR/scripts/uninstall.sh"

  output="$(
    PATH="$tmp_dir:$PATH" bash -c '
      set -euo pipefail
      cd "$1"
      . ./lib/comai/config.sh
      comai_yaml_config_values ./config/comai.yaml
    ' bash "$ROOT_DIR"
  )"
  assert_contains "$output" $'provider\tlocal'
  assert_contains "$output" $'provider_openai_model\tgpt-4o-mini'
  assert_contains "$output" $'provider_gemini_model\tgemini-2.5-flash'

  output="$(
    PATH="$tmp_dir:$PATH" bash -c '
      set -euo pipefail
      cd "$1"
      . ./lib/comai/config.sh
      . ./lib/comai/ai.sh
      printf "Hello   ,,, world\nword word test\n\n\n" | comai_clean_ai_output
    ' bash "$ROOT_DIR"
  )"
  assert_contains "$output" 'Hello, world'
  assert_contains "$output" 'word test'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" config get provider)"
  [[ "$output" == "local" ]]

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" provider list)"
  assert_contains "$output" 'gemini'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" status 2>&1 || true)"
  assert_contains "$output" 'Provider: local (active)'
  assert_contains "$output" 'Provider: gemini'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --provider gemini hi 2>&1 || true)"
  assert_contains "$output" 'Gemini API key is required.'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --max-tokens=abc hi 2>&1 || true)"
  assert_contains "$output" '--max-tokens must be a positive integer.'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" --max-tokens -5 hi 2>&1 || true)"
  assert_contains "$output" '--max-tokens must be a positive integer.'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" -- ollama is first word 2>&1 || true)"
  assert_contains "$output" 'Local provider API is not responding'

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" newest file)"
  assert_contains "$output" 'The newest file'

  printf 'line one\nnumber 4242\n' > "$tmp_dir/my file.txt"
  output="$(
    PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 bash -c '
      cd "$1"
      "$2/bin/comai" does my file.txt contain number 4242
    ' bash "$tmp_dir" "$ROOT_DIR"
  )"
  assert_contains "$output" 'Yes. `4242` appears in my file.txt'

  output="$(
    PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 bash -c '
      cd "$1"
      printf "ok\nERROR bad\n" | "$2/bin/comai" analyze
    ' bash "$tmp_dir" "$ROOT_DIR"
  )"
  assert_contains "$output" 'Found 1 possible issue line'

  output="$(
    PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 bash -c '
      set -euo pipefail
      cfg="$1/comai.yaml"
      cp "$2/config/comai.yaml" "$cfg"
      . "$2/lib/comai/config.sh"
      COMAI_ROOT_DIR="$2"
      COMAI_CONFIG="$cfg"
      comai_load_config
      . "$2/lib/comai/providers/registry.sh"
      . "$2/lib/comai/cli/config.sh"
      comai_set_provider_config_value openai api_key_cmd "pass show openai"
      comai_cmd_config show
    ' bash "$tmp_dir" "$ROOT_DIR"
  )"
  assert_contains "$output" 'api_key_cmd: [set]'

  rm -rf "$tmp_dir"
  trap - RETURN
}

main() {
  local candidate label path seen=""

  add_awk_candidate awk
  add_awk_candidate mawk
  add_awk_candidate gawk

  if [[ "${#AWK_CANDIDATES[@]}" -eq 0 ]]; then
    printf 'No awk implementation found.\n' >&2
    return 1
  fi

  for candidate in "${AWK_CANDIDATES[@]}"; do
    label="${candidate%%:*}"
    path="${candidate#*:}"
    case "$seen" in
      *":$path:"*) continue ;;
    esac
    seen="${seen}:$path:"
    run_with_awk "$label" "$path"
  done

  if command -v shellcheck > /dev/null 2>&1; then
    shellcheck \
      "$ROOT_DIR/bin/comai" \
      "$ROOT_DIR/lib/comai/config/yaml.sh" \
      "$ROOT_DIR/lib/comai/config/files.sh" \
      "$ROOT_DIR/lib/comai/config/write.sh" \
      "$ROOT_DIR/lib/comai/config/keys.sh" \
      "$ROOT_DIR/lib/comai/config/load.sh" \
      "$ROOT_DIR/lib/comai/providers/registry.sh" \
      "$ROOT_DIR/lib/comai/providers/openai-compatible.sh" \
      "$ROOT_DIR/lib/comai/providers/local.sh" \
      "$ROOT_DIR/lib/comai/providers/ollama.sh" \
      "$ROOT_DIR/lib/comai/providers/lmstudio.sh" \
      "$ROOT_DIR/lib/comai/providers/openai.sh" \
      "$ROOT_DIR/lib/comai/providers/gemini.sh" \
      "$ROOT_DIR/lib/comai/config.sh" \
      "$ROOT_DIR/lib/comai/context.sh" \
      "$ROOT_DIR/lib/comai/local-checks.sh" \
      "$ROOT_DIR/lib/comai/ai.sh" \
      "$ROOT_DIR/tests/core.sh" \
      "$ROOT_DIR/scripts/uninstall.sh"
  else
    printf 'shellcheck: skipped (not installed)\n'
  fi

  "$ROOT_DIR/tests/core.sh"

  printf 'ok\n'
}

main "$@"
