#!/usr/bin/env bats
load helper

@test "codex login then use symlinks live auth" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME"

  run "$AGENTIC" login codex work

  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$("$AGENTIC" which codex)" = "work" ]
}

@test "codex run exports CODEX_HOME" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  mkdir -p "$AGENTIC_DIR/codex/work"
  printf '{"token":"x"}\n' > "$AGENTIC_DIR/codex/work/auth.json"

  run "$AGENTIC" run codex work -- status

  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "codex use backs up regular live auth before switching" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work"
  printf '{"token":"original"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"

  run "$AGENTIC" use codex work

  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json.bak")" = '{"token":"original"}' ]
}

@test "codex relogin refreshes an existing account and activates it" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_DIR/codex/work"

  run "$AGENTIC" relogin codex work

  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/codex/work/auth.json" ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$("$AGENTIC" which codex)" = "work" ]
}
