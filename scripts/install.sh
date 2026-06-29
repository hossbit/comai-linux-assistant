#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_INSTALL_DIR="$HOME/localcomai"
INSTALL_DIR="${COMAI_INSTALL_DIR:-}"
AI_DIR="${COMAI_AI_DIR:-}"
BIN_DIR="${HOME}/.local/bin"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SERVICE_NAME="comai-localai.service"
SERVICE_FILE="$SYSTEMD_USER_DIR/$SERVICE_NAME"
REQUIRED_COMMANDS=(bash curl jq find sort head sed awk grep wc tr readlink date systemctl)
OPTIONAL_COMMANDS=(file numfmt)
PATH_NOTE=""
SERVICE_NOTE=""

section() {
  printf '\n== %s ==\n' "$1"
}

expand_path() {
  local value="$1"
  if [[ "$value" == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ "${value:0:2}" == "~/" ]]; then
    printf '%s/%s\n' "$HOME" "${value:2}"
  else
    printf '%s\n' "$value"
  fi
}

usage() {
  cat <<EOF
Usage: $0 [--dir PATH] [--ai-dir PATH]

Installs ComAI into the selected app directory.

Options:
  --dir PATH      Install ComAI app files into PATH. Same as COMAI_INSTALL_DIR=PATH.
  --ai-dir PATH   Configure the optional LocalAI helper directory. Same as COMAI_AI_DIR=PATH.
  -h, --help      Show this help
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dir)
        [[ "$#" -ge 2 ]] || fail "missing path after --dir"
        INSTALL_DIR="$2"
        shift 2
        ;;
      --dir=*)
        INSTALL_DIR="${1#--dir=}"
        shift
        ;;
      --ai-dir)
        [[ "$#" -ge 2 ]] || fail "missing path after --ai-dir"
        AI_DIR="$2"
        shift 2
        ;;
      --ai-dir=*)
        AI_DIR="${1#--ai-dir=}"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
  done
}

validate_absolute_path() {
  local label="$1"
  local value="$2"

  case "$value" in
    /*) ;;
    *) fail "$label must be an absolute path or start with ~" ;;
  esac
}

validate_systemd_path() {
  local label="$1"
  local value="$2"

  case "$value" in
    *[[:space:]%]*) fail "$label cannot contain spaces or percent signs because it is used in a systemd service" ;;
  esac
}

prompt_install_dir() {
  local answer default_display

  if [[ -n "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$(expand_path "$INSTALL_DIR")"
    validate_absolute_path "install directory" "$INSTALL_DIR"
    validate_systemd_path "install directory" "$INSTALL_DIR"
    printf 'Using ComAI install directory: %s\n' "$INSTALL_DIR"
    return
  fi

  default_display="~/localcomai"
  if [[ -t 0 ]]; then
    printf 'ComAI installs its app files in one directory and command wrappers in %s.\n' "$BIN_DIR"
    printf 'Default app install directory: %s\n' "$default_display"
    printf 'Install directory [%s]: ' "$default_display"
    read -r answer
  else
    answer=""
    printf 'No interactive terminal detected. Using default install directory: %s\n' "$default_display"
  fi

  INSTALL_DIR="$(expand_path "${answer:-$DEFAULT_INSTALL_DIR}")"
  validate_absolute_path "install directory" "$INSTALL_DIR"
  validate_systemd_path "install directory" "$INSTALL_DIR"
}

prompt_ai_dir() {
  local answer default_display

  if [[ -n "$AI_DIR" ]]; then
    AI_DIR="$(expand_path "$AI_DIR")"
    validate_absolute_path "LocalAI directory" "$AI_DIR"
    printf 'Using LocalAI directory: %s\n' "$AI_DIR"
    return
  fi

  default_display="~/ai"
  if [[ -t 0 ]]; then
    printf 'Local mode can use any OpenAI-compatible local server.\n'
    printf 'This optional path is only for the bundled LocalAI start/stop helper service.\n'
    printf 'LocalAI directory [%s]: ' "$default_display"
    read -r answer
  else
    answer=""
    printf 'No interactive terminal detected. Using default LocalAI directory: %s\n' "$default_display"
  fi

  AI_DIR="$(expand_path "${answer:-$HOME/ai}")"
  validate_absolute_path "LocalAI directory" "$AI_DIR"
}

confirm_default_yes() {
  local prompt="$1"
  local answer

  if [[ ! -t 0 ]]; then
    return 0
  fi

  printf '%s [Y/n]: ' "$prompt"
  read -r answer
  case "${answer,,}" in
    n|no)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

missing_commands() {
  local cmd
  MISSING_COMMANDS=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || MISSING_COMMANDS+=("$cmd")
  done
}

package_for_command() {
  case "$1" in
    bash) printf 'bash' ;;
    curl) printf 'curl' ;;
    jq) printf 'jq' ;;
    find) printf 'findutils' ;;
    sort|head|wc|tr|readlink|numfmt) printf 'coreutils' ;;
    sed) printf 'sed' ;;
    awk) printf 'gawk' ;;
    grep) printf 'grep' ;;
    file) printf 'file' ;;
    systemctl) printf 'systemd' ;;
    *) printf '%s' "$1" ;;
  esac
}

install_packages_for_missing_commands() {
  local packages=()
  local cmd package

  for cmd in "${MISSING_COMMANDS[@]}"; do
    package="$(package_for_command "$cmd")"
    [[ " ${packages[*]} " == *" $package "* ]] || packages+=("$package")
  done

  [[ "${#packages[@]}" -gt 0 ]] || return 0

  printf 'Missing required commands: %s\n' "${MISSING_COMMANDS[*]}"
  printf 'The installer can install the matching OS packages when supported.\n'

  if command -v apt-get >/dev/null 2>&1; then
    printf 'Installing required packages with apt: %s\n' "${packages[*]}"
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    printf 'Installing required packages with dnf: %s\n' "${packages[*]}"
    sudo dnf install -y "${packages[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    printf 'Installing required packages with pacman: %s\n' "${packages[*]}"
    sudo pacman -S --needed "${packages[@]}"
  else
    printf 'Install them with your package manager, then rerun this installer.\n' >&2
    return 1
  fi
}

install_command_wrapper() {
  local target="$1"
  local command_path="$2"

  if [[ -L "$command_path" ]]; then
    printf 'Existing symlink found: %s\n' "$command_path"
    rm -f "$command_path"
  elif [[ -e "$command_path" ]]; then
    if grep -q 'Generated by ComAI installer' "$command_path" 2>/dev/null; then
      printf 'Existing ComAI wrapper found: %s\n' "$command_path"
    else
      printf 'Cannot install %s: path exists and is not managed by ComAI.\n' "$command_path" >&2
      return 1
    fi
  else
    printf 'Creating command wrapper: %s\n' "$command_path"
  fi

  if [[ ! -x "$target" ]]; then
    printf 'Cannot install %s: target is not executable: %s\n' "$command_path" "$target" >&2
    return 1
  fi

  cat > "$command_path" <<EOF
#!/usr/bin/env bash
# Generated by ComAI installer. Do not edit by hand.
exec "$target" "\$@"
EOF
  chmod +x "$command_path"
}

path_has_bin_dir() {
  case ":$PATH:" in
    *":$BIN_DIR:"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

shell_config_file() {
  case "${SHELL:-}" in
    */zsh)
      printf '%s\n' "$HOME/.zshrc"
      ;;
    */fish)
      printf '%s\n' "$HOME/.config/fish/config.fish"
      ;;
    *)
      printf '%s\n' "$HOME/.bashrc"
      ;;
  esac
}

ensure_path_config() {
  local config_file line fish_line

  if path_has_bin_dir; then
    PATH_NOTE="PATH already contains $BIN_DIR."
    return 0
  fi

  config_file="$(shell_config_file)"
  mkdir -p "$(dirname "$config_file")"

  if [[ "${SHELL:-}" == */fish ]]; then
    fish_line="fish_add_path -p $BIN_DIR"
    if ! grep -Fqx "$fish_line" "$config_file" 2>/dev/null; then
      printf '\n# Added by ComAI installer\n%s\n' "$fish_line" >> "$config_file"
    fi
  else
    line='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -Fqx "$line" "$config_file" 2>/dev/null; then
      printf '\n# Added by ComAI installer\n%s\n' "$line" >> "$config_file"
    fi
  fi

  PATH_NOTE="Added $BIN_DIR to $config_file. Restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
}

merge_missing_config_defaults() {
  local source_config="$1"
  local target_config="$2"
  local line block key added=()

  block=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]]; then
      block+="${line}"$'\n'
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*: ]]; then
      key="${BASH_REMATCH[1]}"
      if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*:" "$target_config"; then
        printf '\n%s%s\n' "$block" "$line" >> "$target_config"
        added+=("$key")
      fi
      block=""
    else
      block=""
    fi
  done < "$source_config"

  if [[ "${#added[@]}" -gt 0 ]]; then
    printf 'Merged new config key(s): %s\n' "${added[*]}"
  else
    printf 'Existing config already has all default keys.\n'
  fi
}

install_config() {
  local source_config="$ROOT_DIR/config/comai.yaml"
  local target_config="$INSTALL_DIR/config/comai.yaml"
  local default_copy="$INSTALL_DIR/config/comai.yaml.default"
  local backup_config

  mkdir -p "$INSTALL_DIR/config"

  if [[ -f "$target_config" ]]; then
    backup_config="$target_config.backup.$(date +%Y%m%d%H%M%S)"
    printf 'Existing config found: %s\n' "$target_config"
    printf 'Keeping your values and adding any missing release defaults.\n'
    cp "$target_config" "$backup_config"
    cp "$source_config" "$default_copy"
    printf 'Backup saved: %s\n' "$backup_config"
    printf 'Default config saved: %s\n' "$default_copy"
    merge_missing_config_defaults "$source_config" "$target_config"
  else
    printf 'Creating config: %s\n' "$target_config"
    cp "$source_config" "$target_config"
  fi
}

set_config_value() {
  local key="$1"
  local value="$2"
  local target_config="$INSTALL_DIR/config/comai.yaml"
  local escaped_value

  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//&/\\&}"
  escaped_value="${escaped_value//|/\\|}"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*:" "$target_config"; then
    sed -i "s|^[[:space:]]*${key}[[:space:]]*:.*|${key}: ${escaped_value}|" "$target_config"
  else
    printf '%s: %s\n' "$key" "$value" >> "$target_config"
  fi
}

configure_local_ai_dir() {
  set_config_value ai_dir "$AI_DIR"
  printf 'Configured local AI directory: %s\n' "$AI_DIR"
}

install_service() {
  if [[ -f "$SERVICE_FILE" ]]; then
    printf 'Existing user service found: %s\n' "$SERVICE_FILE"
  else
    printf 'Creating user service: %s\n' "$SERVICE_FILE"
  fi

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=ComAI local AI server
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/scripts/comai-localai-service.sh start
ExecStop=$INSTALL_DIR/scripts/comai-localai-service.sh stop

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  if confirm_default_yes "Enable and start the localai user service now?"; then
    systemctl --user enable --now "$SERVICE_NAME"
    SERVICE_NOTE="$SERVICE_NAME enabled and started."
  else
    SERVICE_NOTE="$SERVICE_NAME installed but not enabled. Start it later with: systemctl --user start $SERVICE_NAME"
  fi
}

parse_args "$@"

section "ComAI installer"
cat <<EOF
This installer will explain each section before it changes anything.

It installs:
  app files      -> one directory under your home folder
  commands       -> $BIN_DIR/comai and $BIN_DIR/comi
  config         -> config/comai.yaml inside the app directory
  user service   -> $SERVICE_FILE for the optional LocalAI helper

Existing ComAI files are updated. Existing config values are preserved.
EOF

section "Install location"
prompt_install_dir
printf 'Selected app directory: %s\n' "$INSTALL_DIR"
if [[ -d "$INSTALL_DIR" ]]; then
  printf 'Existing ComAI directory found and will be updated.\n'
else
  printf 'New ComAI directory will be created.\n'
fi

section "Optional LocalAI helper"
prompt_ai_dir
printf 'Selected LocalAI directory: %s\n' "$AI_DIR"

section "Dependencies"
printf 'Checking required commands: %s\n' "${REQUIRED_COMMANDS[*]}"
missing_commands "${REQUIRED_COMMANDS[@]}"
install_packages_for_missing_commands

missing_commands "${OPTIONAL_COMMANDS[@]}"
if [[ "${#MISSING_COMMANDS[@]}" -gt 0 ]]; then
  printf 'Optional commands not found: %s\n' "${MISSING_COMMANDS[*]}"
  printf 'ComAI still works, but file type detection and human-readable sizes may be less polished.\n'
else
  printf 'Optional commands are available.\n'
fi

section "App files"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$SYSTEMD_USER_DIR"
rm -rf "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/scripts"
mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/lib" "$INSTALL_DIR/scripts" "$INSTALL_DIR/logs"

printf 'Installing executable files into: %s/bin\n' "$INSTALL_DIR"
cp -R "$ROOT_DIR/bin/." "$INSTALL_DIR/bin/"

printf 'Installing library files into: %s/lib\n' "$INSTALL_DIR"
cp -R "$ROOT_DIR/lib/." "$INSTALL_DIR/lib/"

printf 'Installing helper scripts into: %s/scripts\n' "$INSTALL_DIR"
cp "$ROOT_DIR/scripts/comai-localai-service.sh" "$INSTALL_DIR/scripts/"
cp "$ROOT_DIR/scripts/uninstall.sh" "$INSTALL_DIR/scripts/"

install_config
configure_local_ai_dir

chmod +x "$INSTALL_DIR/bin/comai" "$INSTALL_DIR/scripts/comai-localai-service.sh" "$INSTALL_DIR/scripts/uninstall.sh"

section "Commands"
printf 'The command wrappers let you run ComAI from any terminal.\n'
install_command_wrapper "$INSTALL_DIR/bin/comai" "$BIN_DIR/comai"
install_command_wrapper "$INSTALL_DIR/bin/comai" "$BIN_DIR/comi"

section "LocalAI user service"
printf 'This optional service starts/stops the configured LocalAI directory.\n'
printf 'Other local providers can ignore it and use local_api_base in config/comai.yaml.\n'
install_service

section "Shell PATH"
ensure_path_config
printf '%s\n' "$PATH_NOTE"

cat <<EOF

Installed:
  $INSTALL_DIR
  $BIN_DIR/comai
  $BIN_DIR/comi
  $SERVICE_FILE
  $INSTALL_DIR/config/comai.yaml
  $INSTALL_DIR/lib/comai/
  $INSTALL_DIR/logs/
  LocalAI directory: $AI_DIR

Service:
  $SERVICE_NOTE

Try:
  comai hi
  comai ollama hi
  comai gpt hi
EOF
