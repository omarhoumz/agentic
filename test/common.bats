#!/usr/bin/env bats
load helper

@test "validate_name rejects slash" {
  run bash -c 'source lib/common.sh; validate_name "a/b"'
  [ "$status" -ne 0 ]
}

@test "validate_provider accepts codex, cursor and claude" {
  run bash -c 'source lib/common.sh; validate_provider codex; validate_provider cursor; validate_provider claude'
  [ "$status" -eq 0 ]
}

@test "validate_provider rejects unknown" {
  run bash -c 'source lib/common.sh; validate_provider gemini'
  [ "$status" -ne 0 ]
}
