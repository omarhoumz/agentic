#!/usr/bin/env bats
load helper

@test "cursor login writes auth under account home and activates" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME"
  run "$AGENTIC" login cursor work
  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/cursor/work/auth.json" ]
  [ -L "$AGENTIC_CURSOR_LIVE_HOME/auth.json" ]
}

@test "cursor run sets CURSOR_CONFIG_DIR and file store" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/env-dump.sh"
  mkdir -p "$AGENTIC_DIR/cursor/work"
  echo '{}' > "$AGENTIC_DIR/cursor/work/auth.json"
  run "$AGENTIC" run cursor work --
  [[ "$output" == *CURSOR_CONFIG_DIR="$AGENTIC_DIR/cursor/work"* ]] || [[ "$output" == *"cursor/work"* ]]
  [[ "$output" == *AGENT_CLI_CREDENTIAL_STORE=file* ]]
}
