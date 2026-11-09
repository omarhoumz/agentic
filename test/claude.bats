#!/usr/bin/env bats
#
# Claude keeps one config dir per account and agentic never touches its
# credentials. The default account is ~/.claude, launched with
# CLAUDE_CONFIG_DIR unset; every other account gets its own dir.

load helper

fake_claude() {
  export AGENTIC_CLAUDE_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export FAKE_LOG="$BATS_TEST_TMPDIR/claude.log"
  : > "$FAKE_LOG"
}

# work = ~/.claude (already logged in), personal = its own dir.
two_accounts() {
  fake_claude
  "$AGENTIC" login claude personal
  mkdir -p "$HOME/.claude"
  printf 'w\n' > "$HOME/.claude/.fake-login"
  "$AGENTIC" login claude work --existing
  : > "$FAKE_LOG"
}

dump() {
  "$AGENTIC" run claude "$1" -- "$BATS_TEST_DIRNAME/fixtures/env-dump.sh"
}

@test "login records a canonical config dir and logs in there" {
  fake_claude

  run "$AGENTIC" login claude personal

  [ "$status" -eq 0 ]
  local config
  config=$(cd "$AGENTIC_DIR/claude/personal/config" && pwd -P)
  [ "$(cat "$AGENTIC_DIR/claude/personal/config-path")" = "$config" ]
  [ -f "$config/.fake-login" ]
  [ ! -e "$HOME/.claude/.fake-login" ]
}

@test "login never changes the account plain claude opens" {
  fake_claude

  "$AGENTIC" login claude personal

  [ ! -e "$AGENTIC_DIR/claude/.current" ]
  [ "$("$AGENTIC" which claude)" = "default (~/.claude)" ]
}

@test "login --existing registers ~/.claude without logging in again" {
  fake_claude
  mkdir -p "$HOME/.claude"
  printf 'w\n' > "$HOME/.claude/.fake-login"

  FAKE_LOGIN_FAIL=1 run "$AGENTIC" login claude work --existing

  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/claude/work/default-dir" ]
  [ ! -e "$AGENTIC_DIR/claude/work/config-path" ]
  [ "$(cat "$HOME/.claude/.fake-login")" = w ]
  [ "$("$AGENTIC" which claude)" = work ]
}

@test "login --existing logs ~/.claude in when it is logged out" {
  fake_claude

  run "$AGENTIC" login claude work --existing

  [ "$status" -eq 0 ]
  [ -f "$HOME/.claude/.fake-login" ]
}

@test "a second --existing account is refused" {
  two_accounts

  run "$AGENTIC" login claude other --existing

  [ "$status" -eq 1 ]
  [[ "$output" == *"account 'work' already uses ~/.claude"* ]] || false
  [ ! -e "$AGENTIC_DIR/claude/other" ]
}

@test "--existing is refused for a provider that links live auth" {
  run "$AGENTIC" login codex work --existing

  [ "$status" -eq 1 ]
  [[ "$output" == *"--existing works only for providers that keep their own login"* ]] || false
  [ ! -e "$AGENTIC_DIR/codex/work" ]
}

@test "run gives a non-default account its dir and drops override variables" {
  two_accounts
  export ANTHROPIC_API_KEY=leak CLAUDE_CODE_OAUTH_TOKEN=leak

  run dump personal

  [ "$status" -eq 0 ]
  [[ "$output" == *"CLAUDE_CONFIG_DIR=$(cat "$AGENTIC_DIR/claude/personal/config-path")"* ]] || false
  [[ "$output" == *$'ANTHROPIC_API_KEY=\n'* ]] || false
  [[ "$output" == *"CLAUDE_CODE_OAUTH_TOKEN="$'\n'* ]] || [[ "$output" == *"CLAUDE_CODE_OAUTH_TOKEN=" ]] || false
}

@test "run of the default account unsets an exported CLAUDE_CONFIG_DIR" {
  two_accounts
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/elsewhere"

  run dump work

  [ "$status" -eq 0 ]
  [[ "$output" == *$'CLAUDE_CONFIG_DIR=\n'* ]] || false
}

@test "use switches plain claude between accounts" {
  two_accounts

  "$AGENTIC" use claude personal
  [ "$("$AGENTIC" which claude)" = personal ]

  "$AGENTIC" use claude work
  [ "$("$AGENTIC" which claude)" = work ]
}

@test "which falls back to the default when .current names a deleted account" {
  two_accounts
  printf 'gone\n' > "$AGENTIC_DIR/claude/.current"

  [ "$("$AGENTIC" which claude)" = work ]
}

@test "rm of the default account forgets the record and keeps ~/.claude" {
  two_accounts
  "$AGENTIC" use claude work

  run "$AGENTIC" rm claude work --yes

  [ "$status" -eq 0 ]
  [ ! -e "$AGENTIC_DIR/claude/work" ]
  [ "$(cat "$HOME/.claude/.fake-login")" = w ]
  [ ! -s "$FAKE_LOG" ]
  [ ! -e "$AGENTIC_DIR/claude/.current" ]
}

@test "rm of another account logs it out, deletes it and clears .current" {
  two_accounts
  "$AGENTIC" use claude personal
  local config
  config=$(cat "$AGENTIC_DIR/claude/personal/config-path")

  run "$AGENTIC" rm claude personal --yes

  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_LOG")" = "logout $config" ]
  [ ! -e "$AGENTIC_DIR/claude/personal" ]
  [ ! -e "$AGENTIC_DIR/claude/.current" ]
  [ "$(cat "$HOME/.claude/.fake-login")" = w ]
}

@test "an account without config-path never falls back to ~/.claude" {
  two_accounts
  rm "$AGENTIC_DIR/claude/personal/config-path"

  run "$AGENTIC" rm claude personal --yes
  [ "$status" -eq 1 ]
  [[ "$output" == *"no config-path"* ]] || false

  run dump personal
  [ "$status" -eq 1 ]

  [ ! -s "$FAKE_LOG" ]
  [ "$(cat "$HOME/.claude/.fake-login")" = w ]
  [ -d "$AGENTIC_DIR/claude/personal" ]
}

@test "failed first login removes the new account; failed relogin keeps it" {
  fake_claude

  FAKE_LOGIN_FAIL=1 run "$AGENTIC" login claude personal
  [ "$status" -eq 1 ]
  [[ "$output" == *"'personal' was not created"* ]] || false
  [ ! -e "$AGENTIC_DIR/claude/personal" ]

  "$AGENTIC" login claude personal
  FAKE_LOGIN_FAIL=1 run "$AGENTIC" relogin claude personal
  [ "$status" -eq 1 ]
  [[ "$output" == *"'personal' was not changed"* ]] || false
  [ -f "$AGENTIC_DIR/claude/personal/config-path" ]
}

@test "check reports each account's own login" {
  two_accounts

  run "$AGENTIC" check claude personal
  [ "$status" -eq 0 ]
  [[ "$output" == *"Logged in via $(cat "$AGENTIC_DIR/claude/personal/config-path")"* ]] || false

  rm "$HOME/.claude/.fake-login"
  run "$AGENTIC" check claude work --deep
  [ "$status" -eq 1 ]
  [[ "$output" == *"not logged in"* ]] || false
}

@test "repair and restore refuse claude; repair of every provider skips it" {
  two_accounts

  run "$AGENTIC" repair claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude has no live auth to repair; each account keeps its own login"* ]] || false

  run "$AGENTIC" restore claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude has no live auth to restore"* ]] || false

  run "$AGENTIC" repair
  [ "$status" -eq 0 ]
}

@test "list marks the selected account and tags the default" {
  two_accounts
  "$AGENTIC" use claude personal

  run "$AGENTIC" list claude
  [ "$output" = $'personal *\nwork (~/.claude)' ]

  run "$AGENTIC" list claude --names
  [ "$output" = $'personal\nwork' ]
}
