#!/usr/bin/env bats
load helper

@test "repair refiles regular-file live auth into active account" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work"
  printf '{"token":"old"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  touch -t 200001010000 "$AGENTIC_DIR/codex/work/auth.json"
  printf '{"token":"new"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" repair codex --yes

  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_DIR/codex/work/auth.json")" = '{"token":"new"}' ]
}

@test "repair applies the live-auth recovery model to cursor" {
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME" "$AGENTIC_DIR/cursor/work"
  printf '{"token":"old"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  touch -t 200001010000 "$AGENTIC_DIR/cursor/work/auth.json"
  printf '{"token":"new"}\n' > "$AGENTIC_CURSOR_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/cursor/.current"

  run "$AGENTIC" repair cursor --yes

  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CURSOR_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_DIR/cursor/work/auth.json")" = '{"token":"new"}' ]
}

@test "use --force adopts a regular live credential into the former active account" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work" "$AGENTIC_DIR/codex/personal"
  printf '{"token":"old"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  touch -t 200001010000 "$AGENTIC_DIR/codex/work/auth.json"
  printf '{"token":"personal"}\n' > "$AGENTIC_DIR/codex/personal/auth.json"
  printf '{"token":"rotated"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" use codex personal --force

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/codex/work/auth.json")" = '{"token":"rotated"}' ]
  [ "$(readlink "$AGENTIC_CODEX_LIVE_HOME/auth.json")" = "$AGENTIC_DIR/codex/personal/auth.json" ]
}

@test "use --force does not overwrite newer stored auth with older live auth" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work" "$AGENTIC_DIR/codex/personal"
  printf '{"token":"stale"}\n' > "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  touch -t 200001010000 "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf '{"token":"newer"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  printf '{"token":"personal"}\n' > "$AGENTIC_DIR/codex/personal/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" use codex personal --force

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/codex/work/auth.json")" = '{"token":"newer"}' ]
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json.bak")" = '{"token":"stale"}' ]
}

@test "check validates stored JSON and runs a deep provider check" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  mkdir -p "$AGENTIC_DIR/codex/work"
  printf '{"token":"valid"}\n' > "$AGENTIC_DIR/codex/work/auth.json"

  run "$AGENTIC" check codex work --deep

  [ "$status" -eq 0 ]
  [[ "$output" == *"structure: valid"* ]]
  [[ "$output" == *"codex: ok"* ]]
}

@test "check rejects malformed stored JSON" {
  mkdir -p "$AGENTIC_DIR/cursor/work"
  printf '{"token":\n' > "$AGENTIC_DIR/cursor/work/auth.json"

  run "$AGENTIC" check cursor work

  [ "$status" -eq 1 ]
  [[ "$output" == *"structure: invalid JSON"* ]]
}

@test "rm detaches active auth to a backup and clears the marker" {
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME" "$AGENTIC_DIR/codex/work"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/codex/work/auth.json"
  ln -s "$AGENTIC_DIR/codex/work/auth.json" "$AGENTIC_CODEX_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/codex/.current"

  run "$AGENTIC" rm codex work --yes

  [ "$status" -eq 0 ]
  [[ "$output" == *"active account 'work'; live auth link will be backed up and removed"* ]]
  [ ! -d "$AGENTIC_DIR/codex/work" ]
  [ ! -e "$AGENTIC_DIR/codex/.current" ]
  [ ! -e "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_CODEX_LIVE_HOME/auth.json.bak")" = '{"token":"work"}' ]
}

@test "restore replaces the live link with its backup and clears the marker" {
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME" "$AGENTIC_DIR/cursor/work"
  printf '{"token":"work"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  printf '{"token":"backup"}\n' > "$AGENTIC_CURSOR_LIVE_HOME/auth.json.bak"
  ln -s "$AGENTIC_DIR/cursor/work/auth.json" "$AGENTIC_CURSOR_LIVE_HOME/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/cursor/.current"

  run "$AGENTIC" restore cursor

  [ "$status" -eq 0 ]
  [ ! -L "$AGENTIC_CURSOR_LIVE_HOME/auth.json" ]
  [ "$(cat "$AGENTIC_CURSOR_LIVE_HOME/auth.json")" = '{"token":"backup"}' ]
  [ ! -e "$AGENTIC_DIR/cursor/.current" ]
}
