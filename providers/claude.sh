# shellcheck shell=bash
#
# Claude Code provider facts. Shared behaviour lives in lib/provider.sh.
#
# Claude keeps each login keyed to its config dir (the macOS Keychain, or a
# file inside the dir), so agentic never touches a credential: an account is
# a config dir, picked with CLAUDE_CONFIG_DIR at launch. The default account
# is ~/.claude, which Claude only uses with CLAUDE_CONFIG_DIR unset; its record
# holds a default-dir marker. Every other record holds config-path, the exact
# dir string its login is keyed to.

provider_switch_mode() {
  printf '%s\n' env
}

# The default config dir; labels only.
provider_live_home() {
  printf '%s\n' "$HOME/.claude"
}

provider_cli_bin() {
  printf '%s\n' "${AGENTIC_CLAUDE_BIN:-claude}"
}

# A record without default-dir must never fall back to ~/.claude, so a missing,
# unreadable or non-absolute config-path dies.
provider_account_env() {
  local config
  [ -f "$1/default-dir" ] && return 0
  if [ ! -f "$1/config-path" ] || ! config=$(cat "$1/config-path"); then
    die "claude account '$(basename "$1")' has no config-path; relogin it, or delete $1 by hand"
  fi
  case "$config" in
    /*) ;;
    *) die "claude account '$(basename "$1")' has a bad config-path; delete $1 by hand" ;;
  esac
  printf 'CLAUDE_CONFIG_DIR=%s\n' "$config"
}

# These would silently override the account's login.
provider_unset_env() {
  printf '%s\n' CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN
}

provider_login_args() {
  printf '%s\n' 'auth login'
}

provider_status_args() {
  printf '%s\n' 'auth status --text'
}

provider_logout_args() {
  printf '%s\n' 'auth logout'
}
