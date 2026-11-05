# shellcheck shell=bash
#
# Provider loader and dispatch contract for agentic.
#
# Sourced after lib/common.sh and lib/store.sh. Targets bash 3.2.

_LOADED_PROVIDER=""

load_provider() {
  validate_provider "$1"
  if [ "$_LOADED_PROVIDER" = "$1" ]; then
    return 0
  fi
  # Drop optional Codex-only helpers so a later cursor load does not inherit them.
  unset -f link_shared_config 2>/dev/null || true
  # Defaults a provider file may override; lib/switch.sh calls them.
  # shellcheck disable=SC2329
  provider_login_writes_live() { return 1; }
  _lp_file="$AGENTIC_ROOT/providers/$1.sh"
  [ -f "$_lp_file" ] || die "provider script not found: $1"
  # shellcheck source=/dev/null
  . "$_lp_file"
  _LOADED_PROVIDER="$1"
}
