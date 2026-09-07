# shellcheck shell=bash
#
# Codex provider contract.

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

link_shared_config() {
  _lsc_account_home=$(provider_account_home "$1")
  _lsc_live_config="$(provider_live_home)/config.toml"
  _lsc_account_config="$_lsc_account_home/config.toml"
  [ -e "$_lsc_account_config" ] || [ -L "$_lsc_account_config" ] && return 0
  [ -f "$_lsc_live_config" ] || return 0
  ln -s "$_lsc_live_config" "$_lsc_account_config" || die "cannot link $_lsc_account_config"
}

provider_run_env() {
  printf 'CODEX_HOME=%s\n' "$(provider_account_home "$1")"
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CODEX_BIN:-codex}"
}

provider_login() {
  _pl_home=$(provider_account_home "$1")
  CODEX_HOME="$_pl_home" "$(provider_cli_bin)" login
}

provider_status() {
  _ps_home=$(provider_account_home "$1")
  CODEX_HOME="$_ps_home" "$(provider_cli_bin)" login status
}

provider_is_running() {
  command -v pgrep >/dev/null 2>&1 || return 1
  pgrep -x codex >/dev/null 2>&1
}

provider_running_pids() {
  command -v pgrep >/dev/null 2>&1 || return 0
  pgrep -x codex 2>/dev/null | tr '\n' ' '
}
