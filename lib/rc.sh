# shellcheck shell=bash
#
# rc-file editing for `agentic shell-init`: add or remove the marked block
# that sources the shell integration.
#
# Public functions:
#   default_rcfile                 rc file for the current $SHELL
#   rc_install <rcfile> <snippet>  append the block that sources <snippet> (idempotent)
#   rc_remove <rcfile>             delete the block
#
# Needs common.sh (die, info, resolve_path, colours).

_RC_MARK_START="# >>> agentic shell-init >>>"
_RC_MARK_END="# <<< agentic shell-init <<<"

default_rcfile() {
  case "${SHELL##*/}" in
    zsh)  printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash) printf '%s\n' "$HOME/.bashrc" ;;
    *)    printf '%s\n' "$HOME/.profile" ;;
  esac
}

_rc_path_owner() {
  stat -f '%Su' "$1" 2>/dev/null && return 0
  stat -c '%U' "$1" 2>/dev/null && return 0
  # shellcheck disable=SC2012
  ls -ld "$1" 2>/dev/null | awk '{print $3; exit}'
}

_rc_has_block() {
  [ -f "$1" ] || return 1
  grep -qF "$_RC_MARK_START" "$1"
}

# Where to write when the rc file is a symlink (~/.zshrc -> ~/dotfiles/zshrc).
_rc_write_target() {
  if [ -L "$1" ]; then
    resolve_path "$1"
  else
    printf '%s\n' "$1"
  fi
}

rc_install() {
  _rai_rc="$1"
  _rai_snippet="$2"
  _rai_write=$(_rc_write_target "$_rai_rc")

  if _rc_has_block "$_rai_rc"; then
    info "shell integration already present in $_rai_rc"
    return 0
  fi

  if [ -e "$_rai_rc" ]; then
    if [ ! -w "$_rai_write" ]; then
      die "cannot write $_rai_rc - it is not writable by you
  owned by '$(_rc_path_owner "$_rai_write")', you are '$(id -un)'
  take ownership:
    sudo chown $(id -un) $_rai_write

  or use a different file:
    agentic shell-init --rc ~/.zprofile

  or add this line yourself:
    source \"$_rai_snippet\""
    fi
  else
    _rai_dir=$(dirname "$_rai_rc")
    mkdir -p "$_rai_dir" || die "cannot create $_rai_dir"
    [ -w "$_rai_dir" ] || die "cannot create $_rai_rc - $_rai_dir is not writable
  owned by '$(_rc_path_owner "$_rai_dir")', you are '$(id -un)'
  add this line yourself instead:
    source \"$_rai_snippet\""
  fi

  {
    printf '\n%s\n' "$_RC_MARK_START"
    # shellcheck disable=SC2016
    printf '# Intercepts `codex login`/`logout` and `agent login`/`logout`.\n'
    printf '# Remove with: agentic shell-init --remove\n'
    printf 'source "%s"\n' "$_rai_snippet"
    printf '%s\n' "$_RC_MARK_END"
  } >> "$_rai_rc" || die "cannot write $_rai_rc"

  info "${C_GREEN}added${C_RESET} shell integration to $_rai_rc"
  info "${C_DIM}active in new shells; for this one:  source $_rai_rc${C_RESET}"
}

rc_remove() {
  _rri_rc="$1"
  if ! _rc_has_block "$_rri_rc"; then
    info "no shell integration in $_rri_rc"
    return 0
  fi

  _rri_write=$(_rc_write_target "$_rri_rc")

  [ -w "$_rri_write" ] || die "cannot edit $_rri_rc - it is not writable by you
  owned by '$(_rc_path_owner "$_rri_write")', you are '$(id -un)'
  take ownership with:  sudo chown $(id -un) $_rri_write
  or delete the block between the agentic shell-init markers by hand"

  _rri_tmp="${_rri_write}.agentic.tmp"
  awk -v s="$_RC_MARK_START" -v e="$_RC_MARK_END" '
    $0 == s {
      if (blanks > 0) { blanks-- }
      skip = 1
      next
    }
    !skip {
      if ($0 == "") { blanks++ }
      else { while (blanks > 0) { print ""; blanks-- }; print }
    }
    $0 == e { skip = 0 }
    END { while (blanks > 0) { print ""; blanks-- } }
  ' "$_rri_rc" > "$_rri_tmp" || die "cannot rewrite $_rri_rc"
  mv "$_rri_tmp" "$_rri_write" || die "cannot replace $_rri_write"

  info "${C_GREEN}removed${C_RESET} shell integration from $_rri_rc"
}
