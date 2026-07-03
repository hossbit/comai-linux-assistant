#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "installer refuses a non-empty directory without a ComAI marker" {
  install_dir="$BATS_TEST_TMPDIR/not-comai"
  mkdir -p "$install_dir"
  printf 'user file\n' >"$install_dir/notes.txt"

  run bash "$REPO_ROOT/scripts/install.sh" --dir "$install_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to update non-empty directory without a ComAI install marker"* ]]
  [ -f "$install_dir/notes.txt" ]
}
