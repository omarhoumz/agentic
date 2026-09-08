#!/usr/bin/env bash
#
# Install agentic as a symlink so updates to this checkout are immediately used.
# Also links zsh/bash completions into the usual user or Homebrew dirs.

set -eu

PREFIX="${PREFIX:-$HOME/.local/bin}"
ACTION="install"
repo="$(cd "$(dirname "$0")" && pwd -P)"

usage() {
  cat <<EOF
Usage: ./install.sh [--prefix DIR] [--uninstall]

Install agentic as \$HOME/.local/bin/agentic by default, and link shell
completions when a writable completion directory is found.

Options:
  --prefix DIR  Directory where agentic is linked
  --uninstall   Remove this checkout's agentic link and completion links
  -h, --help    Show this help

Uninstalling removes only the links created from this checkout. It never
touches ~/.agentic, so saved accounts remain intact.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

resolve_path() {
  target="$1"
  guard=0
  while [ -L "$target" ]; do
    guard=$((guard + 1))
    [ "$guard" -le 40 ] || die "symlink loop resolving $1"
    link=$(readlink "$target")
    case "$link" in
      /*) target="$link" ;;
      *) target="$(dirname "$target")/$link" ;;
    esac
  done
  printf '%s\n' "$target"
}

# Prefer Homebrew's completion dirs when present (already on fpath for many
# macOS zsh setups); otherwise use XDG-style user dirs.
zsh_completion_dir() {
  if command -v brew >/dev/null 2>&1; then
    _zcd="$(brew --prefix 2>/dev/null)/share/zsh/site-functions"
    if [ -d "$_zcd" ] && [ -w "$_zcd" ]; then
      printf '%s\n' "$_zcd"
      return 0
    fi
  fi
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
}

bash_completion_dir() {
  if command -v brew >/dev/null 2>&1; then
    _bcd="$(brew --prefix 2>/dev/null)/etc/bash_completion.d"
    if [ -d "$_bcd" ] && [ -w "$_bcd" ]; then
      printf '%s\n' "$_bcd"
      return 0
    fi
  fi
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
}

link_completion() {
  _lc_src="$1"
  _lc_dest="$2"
  [ -f "$_lc_src" ] || return 0
  mkdir -p "$(dirname "$_lc_dest")" || die "cannot create $(dirname "$_lc_dest")"
  if [ -e "$_lc_dest" ] && [ ! -L "$_lc_dest" ]; then
    printf 'warning: left %s alone (not a symlink)\n' "$_lc_dest" >&2
    return 0
  fi
  ln -sfn "$_lc_src" "$_lc_dest" || die "cannot link $_lc_dest"
  printf 'installed %s -> %s\n' "$_lc_dest" "$_lc_src"
}

unlink_completion() {
  _uc_src="$1"
  _uc_dest="$2"
  if [ -L "$_uc_dest" ] && [ "$(resolve_path "$_uc_dest")" = "$_uc_src" ]; then
    rm -f "$_uc_dest"
    printf 'removed %s\n' "$_uc_dest"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) shift; [ $# -gt 0 ] || die "--prefix needs a directory"; PREFIX="$1" ;;
    --prefix=*) PREFIX="${1#--prefix=}" ;;
    --uninstall) ACTION="uninstall" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

target="$PREFIX/agentic"
source="$repo/bin/agentic"
zsh_src="$repo/completions/_agentic"
bash_src="$repo/completions/agentic.bash"
zsh_dest="$(zsh_completion_dir)/_agentic"
bash_dest="$(bash_completion_dir)/agentic"

case "$ACTION" in
  install)
    [ -f "$source" ] || die "missing $source - run from the repository root"
    mkdir -p "$PREFIX" || die "cannot create $PREFIX"
    chmod +x "$source"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      die "$target exists and is not a symlink - remove it first"
    fi
    if [ -L "$target" ]; then
      existing=$(resolve_path "$target")
      [ "$existing" = "$source" ] || die "$target already links to $existing - remove it first"
    fi

    ln -sfn "$source" "$target" || die "cannot link $target"
    printf 'installed %s -> %s\n' "$target" "$source"
    case ":$PATH:" in
      *":$PREFIX:"*) ;;
      *) printf 'warning: %s is not on your PATH\n' "$PREFIX" >&2 ;;
    esac

    link_completion "$zsh_src" "$zsh_dest"
    link_completion "$bash_src" "$bash_dest"

    case "$zsh_dest" in
      */.local/share/zsh/site-functions/_agentic)
        printf 'note: add this to ~/.zshrc if completions do not load:\n\n'
        printf '  fpath=(%s \$fpath)\n' "$(dirname "$zsh_dest")"
        printf '  autoload -Uz compinit && compinit\n\n'
        ;;
    esac
    printf 'open a new shell (or run: exec zsh) so completions refresh\n'
    ;;
  uninstall)
    if [ ! -L "$target" ]; then
      printf 'nothing to uninstall in %s\n' "$PREFIX"
    elif [ "$(resolve_path "$target")" = "$source" ]; then
      rm -f "$target"
      printf 'removed %s\n' "$target"
    else
      printf 'warning: left %s alone (points outside this repository)\n' "$target" >&2
    fi
    unlink_completion "$zsh_src" "$zsh_dest"
    unlink_completion "$bash_src" "$bash_dest"
    ;;
esac
