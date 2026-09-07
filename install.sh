#!/usr/bin/env bash
#
# Install agentic as a symlink so updates to this checkout are immediately used.

set -eu

PREFIX="${PREFIX:-$HOME/.local/bin}"
ACTION="install"
repo="$(cd "$(dirname "$0")" && pwd -P)"

usage() {
  cat <<EOF
Usage: ./install.sh [--prefix DIR] [--uninstall]

Install agentic as \$HOME/.local/bin/agentic by default.

Options:
  --prefix DIR  Directory where agentic is linked
  --uninstall   Remove this checkout's agentic link
  -h, --help    Show this help

Uninstalling removes only the link created from this checkout. It never
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
    ;;
esac
