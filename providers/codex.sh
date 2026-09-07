# shellcheck shell=bash
#
# Codex provider contract (stub — login/use/run wired in later tasks).

provider_live_home() {
  printf '%s\n' "${AGENTIC_CODEX_LIVE_HOME:-${CODEX_HOME:-$HOME/.codex}}"
}

provider_account_home() {
  account_dir codex "$1"
}

provider_auth_artifact() {
  printf '%s\n' "$(provider_account_home "$1")/auth.json"
}

provider_live_auth() {
  printf '%s\n' "$(provider_live_home)/auth.json"
}

provider_run_env() {
  printf 'CODEX_HOME=%s\n' "$(provider_account_home "$1")"
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CODEX_BIN:-codex}"
}

provider_login() {
  :
}

provider_status() {
  :
}
