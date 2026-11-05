#!/usr/bin/env bats
load helper

@test "failed cursor login re-links the previous account" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME" "$AGENTIC_DIR/cursor/work"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  ln -s "$AGENTIC_DIR/cursor/work/auth.json" "$AGENTIC_CURSOR_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/cursor/.current"

  FAKE_LOGIN_FAIL=1 run "$AGENTIC" login cursor personal

  [ "$status" -ne 0 ]
  [ "$(resolve_path "$AGENTIC_CURSOR_LIVE_HOME/auth.json")" = "$AGENTIC_DIR/cursor/work/auth.json" ]
  [ "$("$AGENTIC" which cursor)" = "work" ]
}

@test "use refuses when live auth is a regular file" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work" "$AGENTIC_DIR/codex/personal"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  printf '{"token":"personal"}\n' > "$AGENTIC_DIR/codex/personal/auth.json"
  printf '{"token":"bare"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" use codex personal

  [ "$status" -eq 1 ]
  [[ "$output" == *"repair it first"* ]] || false
  [ -f "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ ! -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_DIR/codex/.current")" = "work" ]
}

@test "restore without a backup fails and leaves live auth alone" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME"
  printf '{"token":"keep"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"

  run "$AGENTIC" restore codex

  [ "$status" -eq 1 ]
  [[ "$output" == *"no backup"* ]] || false
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json")" = '{"token":"keep"}' ]
}

@test "rm of the active account backs up and unlinks live auth" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  ln -s "$AGENTIC_DIR/codex/work/auth.json" "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" rm codex work --yes

  [ "$status" -eq 0 ]
  [[ "$output" == *"active account 'work'; live auth link will be backed up and removed"* ]] || false
  [ ! -d "$AGENTIC_DIR/codex/work" ]
  [ ! -e "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ ! -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json.bak")" = '{"token":"work"}' ]
  run "$AGENTIC" which codex
  [[ "$output" == *"no account is active"* ]] || false
}

@test "use backs up a foreign live symlink before replacing it" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work" "$BATS_TEST_TMPDIR/dotfiles"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  printf '{"token":"mine"}\n' > "$BATS_TEST_TMPDIR/dotfiles/auth.json"
  ln -s "$BATS_TEST_TMPDIR/dotfiles/auth.json" "$AGENTIC_CODEX_LIVE_HOME/auth.json"

  run "$AGENTIC" use codex work

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json.bak")" = '{"token":"mine"}' ]
  [[ "$output" == *"replaced a symlink to"* ]] || false
  [ "$(resolve_path "$AGENTIC_CODEX_LIVE_HOME/auth.json")" = "$AGENTIC_DIR/codex/work/auth.json" ]
  [ "$(cat "$BATS_TEST_TMPDIR/dotfiles/auth.json")" = '{"token":"mine"}' ]
}

@test "use replaces a broken live symlink with a warning" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  ln -s "$BATS_TEST_TMPDIR/missing/auth.json" "$AGENTIC_CODEX_LIVE_HOME/auth.json"

  run "$AGENTIC" use codex work

  [ "$status" -eq 0 ]
  [[ "$output" == *"replaced a broken symlink"* ]] || false
  [ "$(resolve_path "$AGENTIC_CODEX_LIVE_HOME/auth.json")" = "$AGENTIC_DIR/codex/work/auth.json" ]
}
