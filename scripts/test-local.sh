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
    "$ROOT_DIR/lib/comai/context.sh" \
    "$ROOT_DIR/lib/comai/local-checks.sh" \
    "$ROOT_DIR/lib/comai/ai.sh" \
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
  assert_contains "$output" $'provider_openai_model\tgpt-5.5'

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

  output="$(PATH="$tmp_dir:$PATH" COMAI_LOG_ENABLED=0 "$ROOT_DIR/bin/comai" newest file)"
  assert_contains "$output" 'The newest file'

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
      "$ROOT_DIR/lib/comai/config.sh" \
      "$ROOT_DIR/lib/comai/context.sh" \
      "$ROOT_DIR/lib/comai/local-checks.sh" \
      "$ROOT_DIR/lib/comai/ai.sh" \
      "$ROOT_DIR/scripts/uninstall.sh"
  else
    printf 'shellcheck: skipped (not installed)\n'
  fi

  printf 'ok\n'
}

main "$@"
