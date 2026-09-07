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

adopt_live_auth() {
  _ala_provider="$1"
  _ala_live=$(provider_live_auth)
  [ -f "$_ala_live" ] || return 0
  [ -L "$_ala_live" ] && return 0

  _ala_active=$(get_active "$_ala_provider")
  [ -n "$_ala_active" ] || {
    warn "live auth is a regular file but no $_ala_provider account is active; it was backed up"
    return 0
  }
  _ala_auth=$(provider_auth_artifact "$_ala_active")
  [ -d "$(dirname "$_ala_auth")" ] || {
    warn "active $_ala_provider account '$_ala_active' is missing; live auth was not replaced"
    return 1
  }
  if [ -f "$_ala_auth" ] && [ ! "$_ala_live" -nt "$_ala_auth" ]; then
    info "live auth is not newer than '$_ala_active'; backup preserved it"
    return 0
  fi

  cp -p "$_ala_live" "$_ala_auth.tmp" || die "cannot update $_ala_auth"
  mv "$_ala_auth.tmp" "$_ala_auth" || die "cannot update $_ala_auth"
  harden_auth_file "$_ala_auth"
  info "adopted live auth into '$_ala_active'"
}

activate_account() {
  _aa_provider="$1"
  _aa_name="$2"
  _aa_live=$(provider_live_auth)
  _aa_auth=$(provider_auth_artifact "$_aa_name")

  mkdir -p "$(dirname "$_aa_live")" || die "cannot create live auth directory"
  backup_live_auth
  adopt_live_auth "$_aa_provider" || return 1
  ln -sfn "$_aa_auth" "$_aa_live" || die "cannot link $_aa_live"
  harden_auth_file "$_aa_auth"
  set_active "$_aa_provider" "$_aa_name"
}
