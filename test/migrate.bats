#!/usr/bin/env bats
load helper

@test "migrate copies codex-accounts into agentic/codex" {
  old="$AGENTIC_DIR/old-codex-accounts"
  mkdir -p "$old/work"
  echo '{"t":1}' > "$old/work/auth.json"
  echo work > "$old/.current"
  export CODEX_ACCOUNTS_DIR="$old"
  run bin/agentic migrate
  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/codex/work/auth.json" ]
  source lib/common.sh
  source lib/store.sh
  [ "$(get_active codex)" = "work" ] || [ "$(cat "$AGENTIC_DIR/codex/.current")" = "work" ]
}
