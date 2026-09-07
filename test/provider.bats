#!/usr/bin/env bats
load helper

@test "load_provider codex defines provider_cli_bin" {
  source lib/common.sh
  source lib/store.sh
  source lib/provider.sh
  load_provider codex
  [ "$(provider_cli_bin)" = "codex" ]
}

@test "load_provider cursor defines run env keys" {
  source lib/common.sh
  source lib/store.sh
  source lib/provider.sh
  load_provider cursor
  run provider_run_env work
  [[ "$output" == *CURSOR_CONFIG_DIR=* ]]
  [[ "$output" == *AGENT_CLI_CREDENTIAL_STORE=file* ]]
}
