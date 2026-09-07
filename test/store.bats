#!/usr/bin/env bats
load helper

@test "account_dir nests under provider" {
  source lib/common.sh
  source lib/store.sh
  [ "$(account_dir codex work)" = "$AGENTIC_DIR/codex/work" ]
}

@test "set_active and get_active round-trip" {
  source lib/common.sh
  source lib/store.sh
  mkdir -p "$(account_dir cursor personal)"
  set_active cursor personal
  [ "$(get_active cursor)" = "personal" ]
}

@test "list_accounts returns only directories" {
  source lib/common.sh
  source lib/store.sh
  mkdir -p "$(account_dir codex a)" "$(account_dir codex b)"
  run list_accounts codex
  [ "$status" -eq 0 ]
  [[ "$output" == *a* ]]
  [[ "$output" == *b* ]]
}
