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

@test "load_provider cursor drops Codex-only link_shared_config" {
  source lib/common.sh
  source lib/store.sh
  source lib/provider.sh
  load_provider codex
  command -v link_shared_config >/dev/null
  load_provider cursor
  if command -v link_shared_config >/dev/null 2>&1; then
    return 1
  fi
}
