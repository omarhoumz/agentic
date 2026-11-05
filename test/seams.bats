#!/usr/bin/env bats
load helper

@test "only lib/ touches the live auth path" {
  run grep -nE 'provider_live_auth|\.bak|ln -s' "$REPO_ROOT/bin/agentic"
  [ "$status" -eq 1 ]
}

@test "providers declare facts and never touch files" {
  run grep -rnE 'provider_live_auth|ln -s|\.bak|cp |rm -f' "$REPO_ROOT/providers/"
  [ "$status" -eq 1 ]
}
