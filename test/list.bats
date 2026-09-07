#!/usr/bin/env bats
load helper

@test "list --names prints names from every provider" {
  mkdir -p "$AGENTIC_DIR/codex/work" "$AGENTIC_DIR/cursor/personal"

  run "$AGENTIC" list --names

  [ "$status" -eq 0 ]
  [ "$output" = $'work\npersonal' ]
}
