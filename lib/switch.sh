# shellcheck shell=bash
#
# Live-auth module: the only code that reads or writes a provider's live auth
# path (the file the real CLI uses) or its .bak backups. A provider must be
# loaded before any of these functions are called.
#
# Public verbs (all die on error):
#   live_login   <provider> <name> <created:0|1>
#   live_switch  <provider> <name> <force:0|1>
#   live_repair  <provider>
#   live_detach  <provider> <name>
#   live_restore <provider>
#
# An env-mode provider (provider_switch_mode = env) has no live auth: each
# verb hands off to its env_* twin at the bottom of this file, which only
# runs the CLI with the account's env and keeps the .current marker.

harden_auth_file() {
  [ -f "$1" ] || return 0
  chmod 600 "$1" 2>/dev/null || true
}

artifact_basename() {
  basename "$(provider_auth_artifact "$1")"
}

# absent | linked | foreign-link | regular. linked = a symlink resolving into
# $AGENTIC_DIR/<provider>/; foreign-link = any other symlink.
live_state() {
  local provider="$1" live target
  live=$(provider_live_auth)
  if [ -L "$live" ]; then
    target=$(resolve_path "$live")
    case "$target" in
      "$AGENTIC_DIR/$provider/"*) echo linked ;;
      *) echo foreign-link ;;
    esac
  elif [ -e "$live" ]; then
    echo regular
  else
    echo absent
  fi
}

# Copy live auth content (a regular file, or a symlink's existing target) to
# <live>.bak when none exists yet, plus a timestamped copy; keep three stamps.
backup_live_auth() {
  local live stamp old
  live=$(provider_live_auth)
  [ -f "$live" ] || return 0

  if [ ! -e "$live.bak" ]; then
    cp -p "$live" "$live.bak" || die "backup failed"
    harden_auth_file "$live.bak"
  fi

  stamp=$(date +%Y%m%d-%H%M%S)
  cp -p "$live" "$live.$stamp.bak" || die "backup failed"
  harden_auth_file "$live.$stamp.bak"
  printf '%s\n' "$live".*.bak | sort -r | awk 'NR > 3' | while IFS= read -r old; do
    rm -f "$old"
  done
}

# A regular live file newer than the active account's auth is a credential the
# user refreshed outside agentic: copy it into the active account.
adopt_live_auth() {
  local provider="$1" live active auth
  live=$(provider_live_auth)
  [ -f "$live" ] || return 0
  [ -L "$live" ] && return 0

  active=$(get_active "$provider")
  [ -n "$active" ] || {
    warn "live auth is a regular file but no $provider account is active; it was backed up"
    return 0
  }
  auth=$(provider_auth_artifact "$active")
  [ -d "$(dirname "$auth")" ] || {
    warn "active $provider account '$active' is missing; live auth was backed up"
    return 0
  }
  if [ -f "$auth" ] && [ ! "$live" -nt "$auth" ]; then
    info "live auth is not newer than '$active'; backup preserved it"
    return 0
  fi

  cp -p "$live" "$auth.tmp" || die "cannot update $auth"
  mv "$auth.tmp" "$auth" || die "cannot update $auth"
  harden_auth_file "$auth"
  info "adopted live auth into '$active'"
}

# Make live auth safe to replace: back up and adopt a regular file; back up
# and remove a foreign symlink. Our own link is left for the caller.
live_reconcile() {
  local provider="$1" live target
  live=$(provider_live_auth)
  case "$(live_state "$provider")" in
    regular)
      backup_live_auth
      adopt_live_auth "$provider"
      ;;
    foreign-link)
      target=$(resolve_path "$live")
      if [ -e "$live" ]; then
        backup_live_auth
        warn "replaced a symlink to $target"
      else
        warn "replaced a broken symlink to $target"
      fi
      rm -f "$live" || die "cannot remove $live"
      ;;
  esac
}

# Point live auth at <name>'s artifact. Does not reconcile or mark active.
live_link() {
  local name="$1" live auth dir
  live=$(provider_live_auth)
  auth=$(provider_auth_artifact "$name")
  dir=$(dirname "$live")
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || die "cannot create live auth directory"
    chmod 700 "$dir" || die "cannot secure live auth directory"
  fi
  link_shared_config "$name"
  ln -sfn "$auth" "$live" || die "cannot link $live"
  harden_auth_file "$auth"
}

live_activate() {
  live_link "$2"
  set_active "$1" "$2"
}

live_login() {
  if provider_env_mode; then
    env_login "$@"
    return
  fi
  local provider="$1" name="$2" created="$3" previous live auth outcome
  live=$(provider_live_auth)
  auth=$(provider_auth_artifact "$name")
  previous=$(get_active "$provider")
  outcome="was not changed"
  [ "$created" -eq 1 ] && outcome="was not created"

  # Reconcile before the login replaces live auth; whatever the login then
  # writes belongs to <name>, never to the previously active account.
  live_reconcile "$provider"
  # Avoid write-through into a previously linked account.
  if provider_login_writes_live && [ -L "$live" ]; then
    rm -f "$live" || die "cannot remove $live"
  fi

  if provider_login "$name" && live_harvest "$name"; then
    [ -f "$auth" ] || live_login_failed "$provider" "$previous" "$name" "$created" \
      "login did not create an $(artifact_basename "$name") for '$name' - '$name' $outcome"
    live_activate "$provider" "$name"
  else
    live_login_failed "$provider" "$previous" "$name" "$created" "login failed - '$name' $outcome"
  fi
}

# Copy a login's live output into the account, for providers whose CLI can
# only write live auth.
live_harvest() {
  local name="$1" live auth
  provider_login_writes_live || return 0
  live=$(provider_live_auth)
  auth=$(provider_auth_artifact "$name")
  [ -f "$live" ] && [ ! -L "$live" ] || return 1
  mkdir -p "$(dirname "$auth")" || return 1
  cp -p "$live" "$auth" || return 1
  harden_auth_file "$auth"
}

# Put the previously active account back on live auth, remove <name> when this
# login created it, then die. A regular live file the failed login left behind
# is backed up before the re-link; the re-link runs in a subshell so its own
# failure cannot hide <message>.
live_login_failed() {
  local provider="$1" previous="$2" name="$3" created="$4" message="$5"
  if [ -n "$previous" ] && [ -f "$(provider_auth_artifact "$previous")" ]; then
    if [ "$(live_state "$provider")" = regular ] && ! (backup_live_auth); then
      die "$message (live auth could not be backed up, so it was left in place)"
    fi
    (live_link "$previous") || warn "could not re-link '$previous'"
  fi
  forget_created_account "$name" "$created"
  die "$message"
}

# Remove an account directory that the failing login itself created.
forget_created_account() {
  [ "$2" -eq 1 ] || return 0
  rm -rf "$(provider_account_home "$1")" || warn "could not remove '$1'"
}

live_switch() {
  if provider_env_mode; then
    set_active "$1" "$2"
    return
  fi
  local provider="$1" name="$2" force="$3" active
  [ -f "$(provider_auth_artifact "$name")" ] ||
    die "'$name' has no $(artifact_basename "$name") - relogin first"

  active=$(get_active "$provider")
  if [ "$force" -eq 0 ] && [ -n "$active" ] && [ "$(live_state "$provider")" = regular ]; then
    die "live auth is no longer linked to '$active' (a bare login may have replaced it)
  repair it first, or pass --force to preserve it as a backup and switch"
  fi

  if [ "$force" -eq 0 ] && provider_is_running; then
    die "$provider is currently running (pid $(provider_running_pids))
  quit it first, or pass --force"
  fi

  live_reconcile "$provider"
  live_activate "$provider" "$name"
}

live_repair() {
  provider_env_mode && env_no_live_auth "$1" repair
  local provider="$1" active
  [ "$(live_state "$provider")" = regular ] || return 0
  active=$(get_active "$provider")
  if [ -z "$active" ]; then
    warn "$provider live auth is a regular file but no account is active; leaving it in place"
    return 0
  fi
  if [ ! -d "$(account_dir "$provider" "$active")" ]; then
    warn "$provider active account '$active' is missing; clearing marker and leaving live auth in place"
    clear_active "$provider"
    return 0
  fi

  live_reconcile "$provider"
  live_activate "$provider" "$active"
  info "repaired $provider account '$active'"
}

live_detach() {
  if provider_env_mode; then
    env_detach "$@"
    return
  fi
  local provider="$1" name="$2" live
  [ "$(get_active "$provider")" = "$name" ] || return 0
  live=$(provider_live_auth)
  warn "active account '$name'; live auth link will be backed up and removed"
  if [ -L "$live" ]; then
    backup_live_auth
    rm -f "$live" || die "cannot remove $live"
  fi
  clear_active "$provider"
}

live_restore() {
  provider_env_mode && env_no_live_auth "$1" restore
  local provider="$1" live
  live=$(provider_live_auth)
  [ -f "$live.bak" ] || die "no backup at $live.bak"
  # .bak already exists, so this writes only a timestamped copy.
  [ "$(live_state "$provider")" = regular ] && backup_live_auth
  rm -f "$live" || die "cannot remove $live"
  cp -p "$live.bak" "$live" || die "restore failed"
  harden_auth_file "$live"
  clear_active "$provider"
  info "restored $live from backup"
}

# ---------------------------------------------------------------------------
# env mode
# ---------------------------------------------------------------------------

env_no_live_auth() {
  die "$1 has no live auth to $2; each account keeps its own login"
}

# The record that stands for the CLI's default home (holds default-dir).
env_default_account() {
  local name
  while IFS= read -r name; do
    [ -f "$(account_dir "$1" "$name")/default-dir" ] && { printf '%s\n' "$name"; return 0; }
  done < <(list_accounts "$1")
  return 0
}

# The account a plain launch opens: .current when its record exists, else the
# default record. Empty means the CLI's own default home, unregistered.
env_selected() {
  local provider="$1" current
  current=$(get_active "$provider")
  case "$current" in
    '' | *[!A-Za-z0-9_-]* | -*) ;;
    *)
      if [ -d "$AGENTIC_DIR/$provider/$current" ]; then
        printf '%s\n' "$current"
        return 0
      fi
      ;;
  esac
  env_default_account "$provider"
}

# Give a non-default account its own config dir, recorded once as the exact
# string its login is keyed to. Never moved afterwards.
env_prepare_config() {
  local home config
  home=$(provider_account_home "$1")
  [ -f "$home/default-dir" ] || [ -f "$home/config-path" ] && return 0
  config="$home/config"
  mkdir -p "$config" && chmod 700 "$config" || return 1
  (cd "$config" && pwd -P) > "$home/config-path.tmp" || return 1
  mv "$home/config-path.tmp" "$home/config-path"
}

# Log <name> in under its own env. Never changes .current.
env_login() {
  local name="$2" created="$3" outcome="was not changed"
  [ "$created" -eq 1 ] && outcome="was not created"
  if ! env_prepare_config "$name"; then
    forget_created_account "$name" "$created"
    die "cannot create a config dir for '$name' - '$name' $outcome"
  fi
  if ! provider_login "$name"; then
    forget_created_account "$name" "$created"
    die "login failed - '$name' $outcome"
  fi
}

# Register the CLI's default home as <name>; log it in only when it is logged
# out. <name>'s record already exists (created=1 when this call made it).
env_register_default() {
  local provider="$1" name="$2" created="$3" home owner outcome="was not changed"
  [ "$created" -eq 1 ] && outcome="was not created"
  home=$(provider_account_home "$name")
  owner=$(env_default_account "$provider")
  if [ -n "$owner" ] && [ "$owner" != "$name" ]; then
    forget_created_account "$name" "$created"
    die "account '$owner' already uses $(provider_home_label)"
  fi
  [ ! -f "$home/config-path" ] ||
    die "'$name' already has its own config dir; register $(provider_home_label) under another name"
  : > "$home/default-dir" || die "cannot write $home/default-dir"

  if provider_status "$name" >/dev/null 2>&1; then
    info "registered '$name' ($(provider_home_label), already logged in)"
    return 0
  fi
  if ! provider_login "$name"; then
    forget_created_account "$name" "$created"
    die "login failed - '$name' $outcome"
  fi
  info "registered '$name' ($(provider_home_label))"
}

# Before <name>'s record is deleted: log a non-default account out so its
# stored login is not orphaned, and stop plain launches from selecting it.
# The default home's login is never touched.
env_detach() {
  local provider="$1" name="$2"
  if [ ! -f "$(provider_account_home "$name")/default-dir" ]; then
    provider_logout "$name" || warn "could not log '$name' out; its stored login may remain"
  fi
  [ "$(get_active "$provider")" = "$name" ] && clear_active "$provider"
  return 0
}
