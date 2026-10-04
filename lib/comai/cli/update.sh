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

# Resolve tags to commits before executing any new installer. Full commit SHAs can be selected explicitly.
comai_update_resolve() {
  local source="$1" ref="$2" listing
  if [[ "$ref" == latest ]]; then
    listing="$(git ls-remote --tags --refs "$source")" || return "$?"
    ref="$(printf '%s\n' "$listing" | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ {sub("refs/tags/", "", $2); print $2}' | sort -V | tail -n 1)"
    [[ -n "$ref" ]] || { comai_error 'no stable release tag found; specify update --ref TAG'; return 1; }
  fi
  if [[ "$ref" =~ ^[a-fA-F0-9]{40}$ ]]; then
    printf '%s %s\n' "$ref" "$ref"; return
  fi
  [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { comai_error 'update requires a release tag or full commit SHA'; return 1; }
  listing="$(git ls-remote "$source" "refs/tags/$ref" "refs/tags/$ref^{}")" || return "$?"
  local commit
  commit="$(printf '%s\n' "$listing" | awk '$2 ~ /\^\{\}$/ {print $1; found=1; exit} END {if (!found) print ""}')"
  [[ -n "$commit" ]] || commit="$(printf '%s\n' "$listing" | awk 'NR==1 {print $1}')"
  [[ "$commit" =~ ^[a-fA-F0-9]{40}$ ]] || { comai_error 'release tag could not be resolved'; return 1; }
  printf '%s %s\n' "$ref" "$commit"
}

comai_cmd_update() {
  local ref=latest check=0 source="$COMAI_SOURCE_URL" resolved commit old temp_dir status backup meta="${COMAI_ROOT_DIR}.rollback-path"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) check=1 ;;
      --ref) shift; ref="${1:-}" ;;
      --rollback)
        if [[ -e "$COMAI_ROOT_DIR/.git" ]]; then
          old="$(cat "$(git -C "$COMAI_ROOT_DIR" rev-parse --path-format=absolute --git-path comai-rollback)" 2>/dev/null)" || return 1
          [[ -z "$(git -C "$COMAI_ROOT_DIR" status --porcelain)" ]] || { comai_error 'commit or stash local changes before rollback'; return 1; }
          git -C "$COMAI_ROOT_DIR" switch --detach "$old"
        else
          backup="$(cat "$meta" 2>/dev/null)" || return 1
          [[ "$backup" == "$COMAI_ROOT_DIR".rollback.* && -d "$backup" ]] || { comai_error 'rollback backup unavailable'; return 1; }
          comai_error 'Restoring application snapshot; current configuration is preserved.'
          local stage
          stage="$(mktemp -d "${COMAI_ROOT_DIR}.restore.XXXXXX")" || return 1
          cp -a "$backup/app/." "$stage/" || { rm -rf "$stage"; return 1; }
          if [[ -d "$COMAI_ROOT_DIR/config" ]]; then
            rm -rf "$stage/config"
            cp -a "$COMAI_ROOT_DIR/config" "$stage/config" || { rm -rf "$stage"; return 1; }
          fi
          [[ ! -e "$backup/replaced-app" ]] || { comai_error 'this snapshot has already been restored'; rm -rf "$stage"; return 1; }
          mv "$COMAI_ROOT_DIR" "$backup/replaced-app" || { rm -rf "$stage"; return 1; }
          if ! mv "$stage" "$COMAI_ROOT_DIR"; then
            mv "$backup/replaced-app" "$COMAI_ROOT_DIR"
            rm -rf "$stage"; return 1
          fi
          printf 'Rollback complete. Replaced application retained in %s/replaced-app\n' "$backup"

        fi
        return "$?" ;;
      *) comai_error 'usage: update [--check] [--ref vX.Y.Z|COMMIT] [--rollback]'; return 2 ;;
    esac
    shift
  done
  if [[ -f "$COMAI_ROOT_DIR/.install-meta" ]]; then
    source="$(comai_install_meta_value COMAI_INSTALL_SOURCE_URL "$COMAI_ROOT_DIR/.install-meta")"
    source="${source:-$COMAI_SOURCE_URL}"
  fi
  if comai_have git; then
    [[ ! -e "$COMAI_ROOT_DIR/.git" ]] || source="$(git -C "$COMAI_ROOT_DIR" remote get-url origin)" || return "$?"
    resolved="$(comai_update_resolve "$source" "$ref")" || return "$?"
    read -r ref commit <<< "$resolved"
    printf 'Target release: %s\nVerified Git ref: %s\n' "$ref" "$commit"
    [[ "$check" == 0 ]] || return 0
    if [[ -e "$COMAI_ROOT_DIR/.git" ]]; then
      [[ -z "$(git -C "$COMAI_ROOT_DIR" status --porcelain)" ]] || { comai_error 'commit or stash local changes before update'; return 1; }
      old="$(git -C "$COMAI_ROOT_DIR" rev-parse HEAD)" || return "$?"
      git -C "$COMAI_ROOT_DIR" fetch origin "$commit" || return "$?"
      git -C "$COMAI_ROOT_DIR" merge-base --is-ancestor HEAD "$commit" || { comai_error 'release is not a fast-forward; checkout explicitly to change release tracks'; return 1; }
      (umask 077; printf '%s\n' "$old" > "$(git -C "$COMAI_ROOT_DIR" rev-parse --path-format=absolute --git-path comai-rollback)") || return 1
      git -C "$COMAI_ROOT_DIR" merge --ff-only "$commit"
      return "$?"
    fi
    temp_dir="$(mktemp -d)" || return 1
    git init -q "$temp_dir/source" && git -C "$temp_dir/source" remote add origin "$source" &&
      git -C "$temp_dir/source" fetch -q --depth 1 origin "$commit" &&
      git -C "$temp_dir/source" checkout -q --detach FETCH_HEAD
    status=$?
    if [[ "$status" -ne 0 ]]; then rm -rf "$temp_dir"; return "$status"; fi
  else
    [[ "$ref" =~ ^[a-fA-F0-9]{40}$ ]] || { comai_error 'without git, specify update --ref FULL_COMMIT_SHA and COMAI_TARBALL_SHA256'; return 1; }
    [[ "${COMAI_TARBALL_SHA256:-}" =~ ^[a-fA-F0-9]{64}$ ]] || { comai_error 'a trusted COMAI_TARBALL_SHA256 is required before downloading'; return 1; }
    if ! comai_have curl || ! comai_have tar || ! comai_have sha256sum; then comai_error 'curl, tar and sha256sum are required'; return 1; fi
    printf 'Target commit: %s\nExpected SHA256: %s\n' "$ref" "$COMAI_TARBALL_SHA256"
    [[ "$check" == 0 ]] || return 0
    commit="$ref"
    temp_dir="$(mktemp -d)" || return 1
    if ! curl -fsSL "${COMAI_TARBALL_BASE%/}/$commit.tar.gz" -o "$temp_dir/source.tar.gz"; then rm -rf "$temp_dir"; return 1; fi
    if ! printf '%s  %s\n' "$COMAI_TARBALL_SHA256" "$temp_dir/source.tar.gz" | sha256sum -c -; then rm -rf "$temp_dir"; return 1; fi
    # Only ordinary files and directories; refuse symlinks, hardlinks and traversal.
    if ! tar -tzf "$temp_dir/source.tar.gz" | awk '/^\// || /(^|\/)\.\.(\/|$)/ {bad=1} END {exit bad}'; then rm -rf "$temp_dir"; return 1; fi
    if tar -tvzf "$temp_dir/source.tar.gz" | awk 'substr($0,1,1)!="-" && substr($0,1,1)!="d" {bad=1} END {exit !bad}'; then comai_error 'archive contains unsupported links or special files'; rm -rf "$temp_dir"; return 1; fi
    mkdir "$temp_dir/source"
    tar -xzf "$temp_dir/source.tar.gz" --strip-components=1 -C "$temp_dir/source" || { rm -rf "$temp_dir"; return 1; }
  fi
  if [[ ! -f "$temp_dir/source/scripts/install.sh" ]]; then comai_error 'release installer missing'; rm -rf "$temp_dir"; return 1; fi
  backup="$(mktemp -d "${COMAI_ROOT_DIR}.rollback.XXXXXX")" || { rm -rf "$temp_dir"; return 1; }
  chmod 700 "$backup"
  cp -a "$COMAI_ROOT_DIR" "$backup/app" || { rm -rf "$temp_dir"; return 1; }
  (umask 077; printf '%s\n' "$backup" > "$meta") || { rm -rf "$temp_dir"; return 1; }
  printf 'Rollback snapshot: %s\n' "$backup"
  COMAI_SOURCE_URL="$source" COMAI_REF="$commit" bash "$temp_dir/source/scripts/install.sh" --dir "$COMAI_ROOT_DIR" --ai-dir "$COMAI_AI_DIR"
  status=$?
  rm -rf "$temp_dir"
  return "$status"
}

comai_cmd_uninstall() {
  local script="$COMAI_ROOT_DIR/scripts/uninstall.sh"

  if [[ ! -x "$script" ]]; then
    comai_error "uninstall script not found or not executable: $script"
    return 1
  fi
  exec "$script"
}
