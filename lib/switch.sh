# shellcheck shell=bash
#
# Shared account activation primitives. A provider must be loaded before these
# functions are called.

harden_auth_file() {
  [ -f "$1" ] || return 0
  chmod 600 "$1" 2>/dev/null || true
}

backup_live_auth() {
  _bla_live=$(provider_live_auth)
  [ -f "$_bla_live" ] || return 0
  [ -L "$_bla_live" ] && return 0

  if [ ! -e "$_bla_live.bak" ]; then
    cp -p "$_bla_live" "$_bla_live.bak" || die "backup failed"
    harden_auth_file "$_bla_live.bak"
  fi

  _bla_stamp=$(date +%Y%m%d-%H%M%S)
  cp -p "$_bla_live" "$_bla_live.$_bla_stamp.bak" || die "backup failed"
  harden_auth_file "$_bla_live.$_bla_stamp.bak"
}

activate_account() {
  _aa_provider="$1"
  _aa_name="$2"
  _aa_live=$(provider_live_auth)
  _aa_auth=$(provider_auth_artifact "$_aa_name")

  mkdir -p "$(dirname "$_aa_live")" || die "cannot create live auth directory"
  backup_live_auth
  ln -sfn "$_aa_auth" "$_aa_live" || die "cannot link $_aa_live"
  harden_auth_file "$_aa_auth"
  set_active "$_aa_provider" "$_aa_name"
}
