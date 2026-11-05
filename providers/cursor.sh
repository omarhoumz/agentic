# shellcheck shell=bash
#
# Cursor Agent CLI provider facts. Shared behaviour lives in lib/provider.sh.
#
# The Agent CLI file credential store always writes ~/.cursor/auth.json
# (homedir + ".cursor/auth.json"). CURSOR_CONFIG_DIR only relocates
# cli-config.json and friends — not the auth file. Login therefore writes
# live auth (lib/switch.sh harvests it), and status can only check the
# active account.

provider_live_home() {
  printf '%s\n' "${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}"
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CURSOR_BIN:-agent}"
}

provider_account_env() {
  printf 'CURSOR_CONFIG_DIR=%s\n' "$1"
  printf 'AGENT_CLI_CREDENTIAL_STORE=file\n'
}

provider_login_writes_live() {
  return 0
}

provider_status_needs_active() {
  return 0
}
