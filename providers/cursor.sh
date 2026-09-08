# shellcheck shell=bash
#
# Cursor Agent CLI provider contract.
#
# The Agent CLI file credential store always writes ~/.cursor/auth.json
# (homedir + ".cursor/auth.json"). CURSOR_CONFIG_DIR only relocates
# cli-config.json and friends — not the auth file. Login therefore harvests
# live auth into the account home; use/activate symlink the live path.

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
  _pl_live=$(provider_live_auth)
  _pl_auth=$(provider_auth_artifact "$1")

  # Avoid write-through into a previously linked account.
  if [ -L "$_pl_live" ]; then
    rm -f "$_pl_live" || return 1
  fi

  env CURSOR_CONFIG_DIR="$_pl_home" AGENT_CLI_CREDENTIAL_STORE=file \
    "$(provider_cli_bin)" login || return $?

  [ -f "$_pl_live" ] && [ ! -L "$_pl_live" ] || return 1
  mkdir -p "$_pl_home" || return 1
  cp -p "$_pl_live" "$_pl_auth" || return 1
  chmod 600 "$_pl_auth" 2>/dev/null || true
}

provider_status() {
  env AGENT_CLI_CREDENTIAL_STORE=file "$(provider_cli_bin)" login status
}
