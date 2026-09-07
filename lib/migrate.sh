# shellcheck shell=bash
#
# Migrate legacy ~/.codex-accounts store into ~/.agentic/codex.
#
# Sourced, never executed. Targets bash 3.2.

# ---------------------------------------------------------------------------
# Migrate
# ---------------------------------------------------------------------------

cmd_migrate() {
  _mg_src="${CODEX_ACCOUNTS_DIR:-$HOME/.codex-accounts}"
  _mg_dest="$AGENTIC_DIR/codex"

  if [ ! -d "$_mg_src" ]; then
    die "no codex-accounts store at $_mg_src (nothing to migrate)"
  fi

  _mg_copied=0
  mkdir -p "$_mg_dest"

  for _mg_entry in "$_mg_src"/*; do
    [ -e "$_mg_entry" ] || continue
    [ -d "$_mg_entry" ] || continue
    _mg_name=$(basename "$_mg_entry")
    case "$_mg_name" in
      .*) continue ;;
    esac

    _mg_account_dest="$_mg_dest/$_mg_name"
    if [ -f "$_mg_account_dest/auth.json" ]; then
      continue
    fi

    cp -R "$_mg_entry" "$_mg_account_dest"
    chmod 700 "$_mg_account_dest"
    _mg_copied=1
  done

  if [ -f "$_mg_src/.current" ] && [ ! -f "$_mg_dest/.current" ]; then
    cp "$_mg_src/.current" "$_mg_dest/.current"
    _mg_copied=1
  fi

  if [ "$_mg_copied" -eq 0 ]; then
    info "nothing to migrate"
    return 0
  fi

  info "migrated codex accounts from $_mg_src to $_mg_dest"
  _mg_active=""
  if [ -f "$_mg_dest/.current" ]; then
    _mg_active=$(cat "$_mg_dest/.current" 2>/dev/null || true)
  fi
  if [ -n "$_mg_active" ]; then
    info "next: agentic use codex $_mg_active"
  else
    info "next: agentic use codex <name>"
  fi
  info "next: agentic shell-init"
}
