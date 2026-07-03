#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  COMAI_ROOT_DIR="$REPO_ROOT"
  source "$REPO_ROOT/lib/comai/config.sh"
}

@test "reads nested provider values from yaml" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat >"$config" <<'EOF'
provider: openai
providers:
  openai:
    api_base: https://example.invalid
    model: test-model
EOF

  run comai_yaml_provider_value openai model "$config"

  [ "$status" -eq 0 ]
  [ "$output" = "test-model" ]
}

@test "load config resolves OpenAI API key from command and tightens permissions" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat >"$config" <<'EOF'
provider: openai
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
    api_key_cmd: printf cmd-key
EOF
  chmod 644 "$config"

  COMAI_CONFIG="$config"
  OPENAI_API_KEY=""
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  [ "$COMAI_OPENAI_API_KEY" = "cmd-key" ]
  [ "$(stat -c %a "$config")" = "600" ]
}

@test "OPENAI_API_KEY overrides configured key command" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat >"$config" <<'EOF'
provider: openai
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
    api_key_cmd: printf cmd-key
EOF

  COMAI_CONFIG="$config"
  OPENAI_API_KEY="env-key"
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  [ "$COMAI_OPENAI_API_KEY" = "env-key" ]
}
