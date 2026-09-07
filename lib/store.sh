# shellcheck shell=bash
#
# Account store layout and active markers for agentic.
#
# Sourced, never executed. Targets bash 3.2.

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

active_marker() {
  validate_provider "$1"
  printf '%s\n' "$AGENTIC_DIR/$1/.current"
}

provider_dir() {
  validate_provider "$1"
  printf '%s\n' "$AGENTIC_DIR/$1"
}

account_dir() {
  validate_provider "$1"
  validate_name "$2"
  printf '%s\n' "$AGENTIC_DIR/$1/$2"
}

ensure_account_dir() {
  validate_provider "$1"
  validate_name "$2"
  _ead_parent=$(provider_dir "$1")
  _ead_dir=$(account_dir "$1" "$2")
  mkdir -p "$_ead_parent"
  if [ ! -d "$_ead_dir" ]; then
    mkdir -p "$_ead_dir"
    chmod 700 "$_ead_dir"
  fi
}

# ---------------------------------------------------------------------------
# Listing
# ---------------------------------------------------------------------------

list_accounts() {
  validate_provider "$1"
  _la_dir=$(provider_dir "$1")
  [ -d "$_la_dir" ] || return 0
  for _la_entry in "$_la_dir"/*; do
    [ -e "$_la_entry" ] || continue
    [ -d "$_la_entry" ] || continue
    _la_name=$(basename "$_la_entry")
    case "$_la_name" in
      .*) continue ;;
    esac
    printf '%s\n' "$_la_name"
  done
}

# ---------------------------------------------------------------------------
# Active account marker
# ---------------------------------------------------------------------------

set_active() {
  validate_provider "$1"
  validate_name "$2"
  _sa_marker=$(active_marker "$1")
  mkdir -p "$(provider_dir "$1")"
  printf '%s\n' "$2" > "$_sa_marker"
}

get_active() {
  validate_provider "$1"
  _ga_marker=$(active_marker "$1")
  if [ -f "$_ga_marker" ]; then
    cat "$_ga_marker" 2>/dev/null || true
  fi
}
