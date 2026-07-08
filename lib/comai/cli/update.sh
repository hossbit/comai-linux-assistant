# shellcheck shell=bash disable=SC2154

comai_install_meta_value() {
  local key="$1"
  local file="$2"

  LC_ALL=C awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "=" {
      value = substr($0, index($0, "=") + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      if (value ~ /^".*"$/) {
        value = substr(value, 2, length(value) - 2)
      }
      print value
      exit
    }
  ' "$file"
}

comai_cmd_update() {
  local temp_dir source_dir status source_url source_ref tarball_base tarball_sha256 archive_file extracted

  if [[ -d "$COMAI_ROOT_DIR/.git" ]]; then
    printf 'Updating git checkout: %s\n' "$COMAI_ROOT_DIR"
    git -C "$COMAI_ROOT_DIR" pull --ff-only
  else
    source_url="$COMAI_SOURCE_URL"
    source_ref="$COMAI_REF"
    tarball_base="$COMAI_TARBALL_BASE"
    tarball_sha256="$COMAI_TARBALL_SHA256"
    if [[ -f "$COMAI_ROOT_DIR/.install-meta" ]]; then
      source_url="$(comai_install_meta_value COMAI_INSTALL_SOURCE_URL "$COMAI_ROOT_DIR/.install-meta")"
      source_ref="$(comai_install_meta_value COMAI_INSTALL_SOURCE_REF "$COMAI_ROOT_DIR/.install-meta")"
      tarball_base="$(comai_install_meta_value COMAI_INSTALL_TARBALL_BASE "$COMAI_ROOT_DIR/.install-meta")"
      tarball_sha256="$(comai_install_meta_value COMAI_INSTALL_TARBALL_SHA256 "$COMAI_ROOT_DIR/.install-meta")"
      source_url="${source_url:-$COMAI_SOURCE_URL}"
      source_ref="${source_ref:-$COMAI_REF}"
      tarball_base="${tarball_base:-$COMAI_TARBALL_BASE}"
      tarball_sha256="${tarball_sha256:-$COMAI_TARBALL_SHA256}"
    fi
    temp_dir="$(mktemp -d)"
    source_dir="$temp_dir/source"

    printf 'This install is not a git checkout: %s\n' "$COMAI_ROOT_DIR"
    printf 'Creating a temporary source checkout from: %s (%s)\n' "$source_url" "$source_ref"
    printf 'Existing config values will be preserved by the installer.\n'
    if comai_have git; then
      if ! git clone --depth 1 --branch "$source_ref" "$source_url" "$source_dir"; then
        status=$?
        rm -rf "$temp_dir"
        return "$status"
      fi
    else
      if ! comai_have curl || ! comai_have tar; then
        comai_error "git, or curl and tar, are required to update ComAI."
        rm -rf "$temp_dir"
        return 1
      fi
      case "$source_ref" in
        v* | refs/tags/*)
          archive_file="$tarball_base/refs/tags/${source_ref#refs/tags/}.tar.gz"
          ;;
        refs/heads/*)
          archive_file="$tarball_base/$source_ref.tar.gz"
          ;;
        *)
          archive_file="$tarball_base/refs/heads/$source_ref.tar.gz"
          ;;
      esac
      if ! curl -fsSL "$archive_file" -o "$temp_dir/comai.tar.gz"; then
        status=$?
        rm -rf "$temp_dir"
        return "$status"
      fi
      if [[ -n "$tarball_sha256" ]]; then
        if ! comai_have sha256sum; then
          comai_error "sha256sum is required to verify COMAI_TARBALL_SHA256."
          rm -rf "$temp_dir"
          return 1
        fi
        if ! printf '%s  %s\n' "$tarball_sha256" "$temp_dir/comai.tar.gz" | sha256sum -c -; then
          status=$?
          rm -rf "$temp_dir"
          return "$status"
        fi
      else
        comai_error "No COMAI_TARBALL_SHA256 provided; tarball integrity was not verified."
      fi
      if ! tar -xzf "$temp_dir/comai.tar.gz" -C "$temp_dir"; then
        status=$?
        rm -rf "$temp_dir"
        return "$status"
      fi
      extracted="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d -name 'comai-linux-assistant-*' | head -n 1)"
      if [[ -z "${extracted:-}" ]]; then
        comai_error "could not find extracted ComAI source directory."
        rm -rf "$temp_dir"
        return 1
      fi
      rm -rf "$source_dir"
      mv "$extracted" "$source_dir"
    fi

    if [[ ! -f "$source_dir/scripts/install.sh" ]]; then
      comai_error "installer not found in cloned source: $source_dir/scripts/install.sh"
      rm -rf "$temp_dir"
      return 1
    fi

    COMAI_SOURCE_URL="$source_url" COMAI_REF="$source_ref" COMAI_TARBALL_BASE="$tarball_base" COMAI_TARBALL_SHA256="$tarball_sha256" \
      bash "$source_dir/scripts/install.sh" --dir "$COMAI_ROOT_DIR" --ai-dir "$COMAI_AI_DIR"
    status=$?
    rm -rf "$temp_dir"
    return "$status"
  fi
}

comai_cmd_uninstall() {
  local script="$COMAI_ROOT_DIR/scripts/uninstall.sh"

  if [[ ! -x "$script" ]]; then
    comai_error "uninstall script not found or not executable: $script"
    return 1
  fi
  exec "$script"
}
