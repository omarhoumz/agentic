#!/usr/bin/env bats
load helper

@test "cursor login harvests live auth into account home and activates" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME"

  run "$AGENTIC" login cursor work

  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/cursor/work/auth.json" ]
  # Real Agent CLI writes auth to the live home, not CURSOR_CONFIG_DIR; login
  # copies it into the account, then activate symlinks the live path.
  [ -L "$AGENTIC_CURSOR_LIVE_HOME/auth.json" ]
  [ "$(resolve_path "$AGENTIC_CURSOR_LIVE_HOME/auth.json")" = "$(resolve_path "$AGENTIC_DIR/cursor/work/auth.json")" ]
}

@test "cursor run sets CURSOR_CONFIG_DIR and file store" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/env-dump.sh"
  mkdir -p "$AGENTIC_DIR/cursor/work"
  echo '{}' > "$AGENTIC_DIR/cursor/work/auth.json"
  run "$AGENTIC" run cursor work --
  [[ "$output" == *CURSOR_CONFIG_DIR="$AGENTIC_DIR/cursor/work"* ]] || [[ "$output" == *"cursor/work"* ]] || false
  [[ "$output" == *AGENT_CLI_CREDENTIAL_STORE=file* ]] || false
}

@test "second cursor login does not overwrite the active account" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME"
  FAKE_TOKEN=AAA run "$AGENTIC" login cursor work
  [ "$status" -eq 0 ]
  touch -t 200001010000 "$AGENTIC_DIR/cursor/work/auth.json"

  FAKE_TOKEN=BBB run "$AGENTIC" login cursor personal

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/cursor/work/auth.json")" = '{"token":"AAA"}' ]
  [ "$(cat "$AGENTIC_DIR/cursor/personal/auth.json")" = '{"token":"BBB"}' ]
  [ "$(resolve_path "$AGENTIC_CURSOR_LIVE_HOME/auth.json")" = "$(resolve_path "$AGENTIC_DIR/cursor/personal/auth.json")" ]
}

@test "cursor login adopts a pre-existing regular live auth into the active account" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME" "$AGENTIC_DIR/cursor/work"
  printf '{"token":"old"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  touch -t 200001010000 "$AGENTIC_DIR/cursor/work/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/cursor/.current"
  # A bare `agent login` replaced the live link with a regular file.
  printf '{"token":"bare"}\n' > "$AGENTIC_CURSOR_LIVE_HOME/auth.json"

  FAKE_TOKEN=NEW run "$AGENTIC" login cursor personal

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/cursor/work/auth.json")" = '{"token":"bare"}' ]
  [ "$(cat "$AGENTIC_DIR/cursor/personal/auth.json")" = '{"token":"NEW"}' ]
}

@test "deep check of a non-active cursor account is refused" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_DIR/cursor/work" "$AGENTIC_DIR/cursor/personal"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  printf '{"token":"personal"}\n' > "$AGENTIC_DIR/cursor/personal/auth.json"
  "$AGENTIC" use cursor work

  run "$AGENTIC" check cursor personal --deep

  [ "$status" -eq 1 ]
  [[ "$output" == *"only on the active account"* ]] || false
  [[ "$output" == *"work"* ]] || false
}

@test "deep check with no active cursor account says none is active" {
  mkdir -p "$AGENTIC_DIR/cursor/personal"
  printf '{"token":"personal"}\n' > "$AGENTIC_DIR/cursor/personal/auth.json"

  run "$AGENTIC" check cursor personal --deep

  [ "$status" -eq 1 ]
  [[ "$output" == *"none is active"* ]] || false
  [[ "$output" != *"('')"* ]] || false
}
