# shellcheck shell=bash
#
# Codex provider facts. Shared behaviour lives in lib/provider.sh.

provider_live_home() {
  printf '%s\n' "${AGENTIC_CODEX_LIVE_HOME:-${CODEX_HOME:-$HOME/.codex}}"
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CODEX_BIN:-codex}"
}

provider_account_env() {
  printf 'CODEX_HOME=%s\n' "$1"
}

provider_process_name() {
  printf '%s\n' codex
}

provider_shared_config_files() {
  printf '%s\n' config.toml
}
