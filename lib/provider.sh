# shellcheck shell=bash
#
# Provider loader and the shared half of the provider contract.
#
# A provider file (providers/<p>.sh) declares facts only:
#   required: provider_live_home, provider_cli_bin, provider_account_env <home>
#   optional: provider_login_writes_live, provider_process_name,
#             provider_shared_config_files, provider_status_needs_active
# load_provider resets the optional facts to their defaults before every
# source, so one provider never inherits another's facts. Everything else
# (paths, env, login/status, running checks, shared config) lives here.
#
# Sourced after lib/common.sh and lib/store.sh. Targets bash 3.2.

_LOADED_PROVIDER=""

load_provider() {
  local provider="$1" file fn
  validate_provider "$provider"
  if [ "$_LOADED_PROVIDER" = "$provider" ]; then
    return 0
  fi
  unset -f provider_live_home provider_cli_bin provider_account_env 2>/dev/null || true
  # Fact defaults a provider file may override.
  # shellcheck disable=SC2329
  provider_login_writes_live() { return 1; }
  # shellcheck disable=SC2329
  provider_process_name() { :; }
  # shellcheck disable=SC2329
  provider_shared_config_files() { :; }
  # shellcheck disable=SC2329
  provider_status_needs_active() { return 1; }

  file="$AGENTIC_ROOT/providers/$provider.sh"
  [ -f "$file" ] || die "provider script not found: $provider"
  # shellcheck source=/dev/null
  . "$file"
  for fn in provider_live_home provider_cli_bin provider_account_env; do
    command -v "$fn" >/dev/null 2>&1 || die "provider $provider does not define $fn"
  done
  _LOADED_PROVIDER="$provider"
}

provider_account_home() {
  account_dir "$_LOADED_PROVIDER" "$1"
}

provider_auth_artifact() {
  printf '%s\n' "$(provider_account_home "$1")/auth.json"
}

provider_live_auth() {
  printf '%s\n' "$(provider_live_home)/auth.json"
}

# KEY=value lines a run of <name> needs.
provider_run_env() {
  provider_account_env "$(provider_account_home "$1")"
}

# Run <cmd...> in a subshell with <name>'s env exported.
provider_with_env() {
  local name="$1" assignment
  shift
  (
    while IFS= read -r assignment; do
      # shellcheck disable=SC2163
      [ -n "$assignment" ] && export "$assignment"
    done < <(provider_run_env "$name")
    "$@"
  )
}

provider_login() {
  provider_with_env "$1" "$(provider_cli_bin)" login
}

provider_status() {
  provider_with_env "$1" "$(provider_cli_bin)" login status
}

provider_is_running() {
  local process
  process=$(provider_process_name)
  [ -n "$process" ] || return 1
  command -v pgrep >/dev/null 2>&1 || return 1
  pgrep -x "$process" >/dev/null 2>&1
}

provider_running_pids() {
  local process
  process=$(provider_process_name)
  [ -n "$process" ] || return 0
  command -v pgrep >/dev/null 2>&1 || return 0
  pgrep -x "$process" 2>/dev/null | tr '\n' ' '
}

# Symlink each shared config file present in the live home into <name>'s
# home. An existing account copy (file or link) is left alone.
link_shared_config() {
  local home file live_file account_file
  home=$(provider_account_home "$1")
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    live_file="$(provider_live_home)/$file"
    account_file="$home/$file"
    [ -e "$account_file" ] || [ -L "$account_file" ] && continue
    [ -f "$live_file" ] || continue
    ln -s "$live_file" "$account_file" || die "cannot link $account_file"
  done < <(provider_shared_config_files)
}
