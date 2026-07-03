#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  COMAI_ROOT_DIR="$REPO_ROOT"
  source "$REPO_ROOT/lib/comai/config.sh"
}

@test "reads nested provider values from yaml" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat > "$config" << 'EOF'
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

@test "OpenAI API key command resolves lazily and tightens permissions" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  key_file="$BATS_TEST_TMPDIR/key"
  cat > "$config" << 'EOF'
provider: openai
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
EOF
  printf '    api_key_cmd: cat %s\n' "$key_file" >> "$config"
  printf 'cmd-key\n' > "$key_file"
  chmod 644 "$config"

  COMAI_CONFIG="$config"
  OPENAI_API_KEY=""
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  [ "$COMAI_OPENAI_API_KEY" = "" ]
  [ "$(stat -c %a "$config")" = "600" ]
  comai_ensure_openai_api_key
  [ "$COMAI_OPENAI_API_KEY" = "cmd-key" ]
}

@test "OPENAI_API_KEY overrides configured key command" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat > "$config" << 'EOF'
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

@test "load config accepts legacy top-level api_key_cmd fallback" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat > "$config" << 'EOF'
provider: openai
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
api_key_cmd: printf fallback-key
EOF

  COMAI_CONFIG="$config"
  OPENAI_API_KEY=""
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  comai_ensure_openai_api_key
  [ "$COMAI_OPENAI_API_KEY" = "fallback-key" ]
}

@test "local provider load does not run OpenAI API key command" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  marker="$BATS_TEST_TMPDIR/marker"
  cat > "$config" << EOF
provider: local
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
    api_key_cmd: touch $marker
EOF

  COMAI_CONFIG="$config"
  OPENAI_API_KEY=""
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  [ ! -e "$marker" ]
}

@test "OpenAI API key command failure is reported" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat > "$config" << 'EOF'
provider: openai
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
    api_key_cmd: false
EOF

  COMAI_CONFIG="$config"
  OPENAI_API_KEY=""
  COMAI_OPENAI_API_KEY=""
  comai_load_config

  if comai_ensure_openai_api_key; then
    return 1
  fi
  [ "$COMAI_OPENAI_API_KEY_STATUS" = "command_failed" ]
}

@test "config set api_key_cmd writes nested OpenAI provider key" {
  config="$BATS_TEST_TMPDIR/comai.yaml"
  cat > "$config" << 'EOF'
provider: local
providers:
  openai:
    api_base: https://api.openai.com
    model: test-model
    api_key:
EOF

  run env COMAI_CONFIG="$config" "$REPO_ROOT/bin/comai" config set api_key_cmd "pass show openai"

  [ "$status" -eq 0 ]
  [ "$(comai_yaml_provider_value openai api_key_cmd "$config")" = "pass show openai" ]
  ! grep -Eq '^api_key_cmd:' "$config"
}
