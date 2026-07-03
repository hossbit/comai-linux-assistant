#!/usr/bin/env bash
set -euo pipefail

COMAI_REPO_URL="${COMAI_REPO_URL:-https://github.com/hossbit/comai-linux-assistant.git}"
COMAI_TARBALL_BASE="${COMAI_TARBALL_BASE:-https://github.com/hossbit/comai-linux-assistant/archive}"
COMAI_REF="${COMAI_REF:-main}"
COMAI_TARBALL_SHA256="${COMAI_TARBALL_SHA256:-}"
COMAI_INSTALL_DIR="${COMAI_INSTALL_DIR:-$HOME/localcomai}"
COMAI_AI_DIR="${COMAI_AI_DIR:-$HOME/ai}"

log() {
  printf 'comai-install: %s\n' "$*"
}

fail() {
  printf 'comai-install: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

archive_url() {
  case "$COMAI_REF" in
    v*|refs/tags/*)
      printf '%s/refs/tags/%s.tar.gz\n' "$COMAI_TARBALL_BASE" "${COMAI_REF#refs/tags/}"
      ;;
    refs/heads/*)
      printf '%s/%s.tar.gz\n' "$COMAI_TARBALL_BASE" "$COMAI_REF"
      ;;
    *)
      printf '%s/refs/heads/%s.tar.gz\n' "$COMAI_TARBALL_BASE" "$COMAI_REF"
      ;;
  esac
}

usage() {
  cat <<EOF
Usage: curl -fsSL https://hossbit.github.io/comai/install.sh | bash

Environment:
  COMAI_INSTALL_DIR   Install directory. Default: $HOME/localcomai
  COMAI_AI_DIR        Optional LocalAI helper directory. Default: $HOME/ai
  COMAI_REF           Git branch or tag to install. Default: main
  COMAI_TARBALL_SHA256  Expected SHA256 for tarball installs when git is unavailable
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

have bash || fail "bash is required."
have curl || fail "curl is required."
have mktemp || fail "mktemp is required."

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

source_dir="$tmp_dir/comai-source"

log "Installing ComAI from ${COMAI_REPO_URL} (${COMAI_REF})"
log "Install directory: ${COMAI_INSTALL_DIR}"
log "LocalAI helper directory: ${COMAI_AI_DIR}"

if have git; then
  git clone --depth 1 --branch "$COMAI_REF" "$COMAI_REPO_URL" "$source_dir"
else
  have tar || fail "git or tar is required."
  archive_file="$tmp_dir/comai.tar.gz"
  curl -fsSL "$(archive_url)" -o "$archive_file"
  if [[ -n "$COMAI_TARBALL_SHA256" ]]; then
    have sha256sum || fail "sha256sum is required to verify COMAI_TARBALL_SHA256."
    printf '%s  %s\n' "$COMAI_TARBALL_SHA256" "$archive_file" | sha256sum -c -
  else
    log "No COMAI_TARBALL_SHA256 provided; tarball integrity was not verified."
  fi
  mkdir -p "$source_dir"
  tar -xzf "$archive_file" -C "$tmp_dir"
  extracted="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -name 'comai-linux-assistant-*' | head -n 1)"
  [[ -n "${extracted:-}" ]] || fail "Could not find extracted ComAI source directory."
  rm -rf "$source_dir"
  mv "$extracted" "$source_dir"
fi

[[ -x "$source_dir/scripts/install.sh" ]] || fail "Installer not found: $source_dir/scripts/install.sh"

COMAI_SOURCE_URL="$COMAI_REPO_URL" COMAI_REF="$COMAI_REF" COMAI_TARBALL_BASE="$COMAI_TARBALL_BASE" \
  bash "$source_dir/scripts/install.sh" --dir "$COMAI_INSTALL_DIR" --ai-dir "$COMAI_AI_DIR"

log "Done. Try: comai status"
