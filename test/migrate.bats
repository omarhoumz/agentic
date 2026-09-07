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

@test "migrate recovers incomplete destination account dir" {
  old="$AGENTIC_DIR/old-codex-accounts"
  mkdir -p "$old/work"
  echo '{"t":1}' > "$old/work/auth.json"
  mkdir -p "$AGENTIC_DIR/codex/work"
  export CODEX_ACCOUNTS_DIR="$old"
  run bin/agentic migrate
  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/codex/work/auth.json" ]
  [ ! -f "$AGENTIC_DIR/codex/work/work/auth.json" ]
}

@test "migrate is idempotent when destination already has auth" {
  old="$AGENTIC_DIR/old-codex-accounts"
  mkdir -p "$old/work"
  echo '{"t":1}' > "$old/work/auth.json"
  echo work > "$old/.current"
  mkdir -p "$AGENTIC_DIR/codex/work"
  echo '{"existing":1}' > "$AGENTIC_DIR/codex/work/auth.json"
  echo work > "$AGENTIC_DIR/codex/.current"
  export CODEX_ACCOUNTS_DIR="$old"
  run bin/agentic migrate
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to migrate"* ]]
  [ "$(cat "$AGENTIC_DIR/codex/work/auth.json")" = '{"existing":1}' ]
}

@test "migrate exits 1 when source missing" {
  export CODEX_ACCOUNTS_DIR="$AGENTIC_DIR/no-such-codex-accounts"
  run bin/agentic migrate
  [ "$status" -eq 1 ]
  [[ "$output" == *"nothing to migrate"* ]]
}
