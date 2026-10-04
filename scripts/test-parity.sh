#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $# -eq 1 ]] || { printf 'usage: %s OTHER_REPOSITORY\n' "$0" >&2; exit 2; }
other="$1"
cmp "$root/tests/shared-contracts.sh" "$other/tests/shared-contracts.sh" || { printf 'shared fixtures have drifted\n' >&2; exit 1; }
bash "$root/tests/shared-contracts.sh" "$root"
bash "$root/tests/shared-contracts.sh" "$other"
cmp "$root/tests/update-provenance.sh" "$other/tests/update-provenance.sh"
bash "$root/tests/update-provenance.sh" "$root"
bash "$root/tests/update-provenance.sh" "$other"
