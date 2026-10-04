#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034
set -euo pipefail
root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
. "$root/lib/comai/cli/update.sh"
comai_error() { printf '%s\n' "$*" >&2; }
comai_have() { command -v "$1" >/dev/null; }
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
git init -q "$workspace/source"
git -C "$workspace/source" config user.email fixture@example.invalid
git -C "$workspace/source" config user.name Fixture
mkdir -p "$workspace/source/scripts"
cat > "$workspace/source/scripts/install.sh" <<'INSTALL'
#!/usr/bin/env bash
set -eu
while [[ $# -gt 0 ]]; do
  case "$1" in --dir) shift; dest="$1" ;; esac
  shift
done
mkdir -p "$dest/bin"
printf 'updated\n' > "$dest/bin/app"
printf 'new file\n' > "$dest/new-file"
printf '%s\n' "$COMAI_REF" > "$dest/pinned-ref"
INSTALL
printf old > "$workspace/source/fixture"
git -C "$workspace/source" add .
git -C "$workspace/source" commit -qm first
git -C "$workspace/source" tag v1.0.0
old="$(git -C "$workspace/source" rev-parse HEAD)"
printf new > "$workspace/source/fixture"
git -C "$workspace/source" commit -qam second
git -C "$workspace/source" tag v1.1.0
new="$(git -C "$workspace/source" rev-parse HEAD)"
COMAI_SOURCE_URL="$workspace/source"
COMAI_ROOT_DIR="$workspace/install"
COMAI_AI_DIR="$workspace/models"
COMAI_REF=main
COMAI_TARBALL_BASE=https://example.invalid/archive
COMAI_TARBALL_SHA256=''
mkdir -p "$COMAI_ROOT_DIR/bin" "$COMAI_ROOT_DIR/config"
printf original > "$COMAI_ROOT_DIR/bin/app"
printf private > "$COMAI_ROOT_DIR/config/setting"
comai_cmd_update --check > "$workspace/preview"
[[ "$(cat "$workspace/preview")" == *v1.1.0* && ! -e "$COMAI_ROOT_DIR/new-file" ]]
comai_cmd_update > "$workspace/update"
[[ "$(cat "$COMAI_ROOT_DIR/pinned-ref")" == "$new" ]]
[[ "$(cat "$COMAI_ROOT_DIR/bin/app")" == updated ]]
printf changed > "$COMAI_ROOT_DIR/config/setting"
comai_cmd_update --rollback >/dev/null
[[ "$(cat "$COMAI_ROOT_DIR/bin/app")" == original ]]
[[ "$(cat "$COMAI_ROOT_DIR/config/setting")" == changed ]]
[[ ! -e "$COMAI_ROOT_DIR/new-file" ]]
# Git updates stay on the current branch and refuse dirty checkouts; rollback retains history.
git clone -q "$workspace/source" "$workspace/checkout"
git -C "$workspace/checkout" switch -q --detach "$old"
COMAI_ROOT_DIR="$workspace/checkout"
comai_cmd_update >/dev/null
[[ "$(git -C "$COMAI_ROOT_DIR" rev-parse HEAD)" == "$new" ]]
comai_cmd_update --rollback >/dev/null
[[ "$(git -C "$COMAI_ROOT_DIR" rev-parse HEAD)" == "$old" ]]
printf dirty > "$COMAI_ROOT_DIR/fixture"
if comai_cmd_update >/dev/null 2>&1; then exit 1; fi
# No unchecked archive may be fetched or executed.
comai_have() { [[ "$1" != git ]] && command -v "$1" >/dev/null; }
curl() { touch "$workspace/download-attempted"; return 1; }
COMAI_ROOT_DIR="$workspace/install"
if comai_cmd_update --ref "$new" >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$workspace/download-attempted" ]]
printf 'update provenance and rollback: ok\n'
