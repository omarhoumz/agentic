#!/usr/bin/env bats
load helper

@test "only lib/ touches the live auth path" {
  run grep -nE 'provider_live_auth|\.bak|ln -s' "$REPO_ROOT/bin/agentic"
  [ "$status" -eq 1 ]
}
