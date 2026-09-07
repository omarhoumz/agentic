# shellcheck shell=bash
#
# Cursor Agent CLI provider contract.

provider_live_home() {
  printf '%s\n' "${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}"
}

provider_account_home() {
  account_dir cursor "$1"
}

provider_auth_artifact() {
  printf '%s\n' "$(provider_account_home "$1")/auth.json"
}

provider_live_auth() {
  printf '%s\n' "$(provider_live_home)/auth.json"
}

provider_run_env() {
  _pc_account_home=$(provider_account_home "$1")
  printf 'CURSOR_CONFIG_DIR=%s\n' "$_pc_account_home"
  printf 'AGENT_CLI_CREDENTIAL_STORE=file\n'
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CURSOR_BIN:-agent}"
}

provider_login() {
  _pl_home=$(provider_account_home "$1")
  CURSOR_CONFIG_DIR="$_pl_home" AGENT_CLI_CREDENTIAL_STORE=file "$(provider_cli_bin)" login
}

provider_status() {
  _ps_home=$(provider_account_home "$1")
  CURSOR_CONFIG_DIR="$_ps_home" AGENT_CLI_CREDENTIAL_STORE=file "$(provider_cli_bin)" login status
}
