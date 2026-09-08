# shellcheck shell=bash
#
# Shared helpers for agentic.
#
# Sourced, never executed. Targets bash 3.2 (the version macOS still ships), so:
# no associative arrays, no ${var,,}, no `readlink -f`.
#
# Values defined here are consumed by the scripts that source this file, so a
# lint pass over the library alone cannot see them being used.
# shellcheck disable=SC2034

AGENTIC_VERSION="0.1.1"

# Where saved accounts live. Overridable so the test suite can use a scratch dir.
: "${AGENTIC_DIR:=$HOME/.agentic}"

# Repo root for provider scripts. bin/agentic sets this explicitly; derive when unset.
: "${AGENTIC_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"

PROVIDER_LIST="codex cursor"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# Colour only when stdout is a terminal, so piped output stays clean.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_RED=''; C_GREEN=''; C_YELLOW=''
fi

info() { printf '%s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

print_version() {
  printf '%s %s\n' "$1" "$AGENTIC_VERSION"
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Resolve a symlink chain to its final target. Replaces `readlink -f`, which
# stock macOS does not have.
resolve_path() {
  _rp_target="$1"
  _rp_guard=0
  while [ -L "$_rp_target" ]; do
    _rp_guard=$((_rp_guard + 1))
    [ "$_rp_guard" -gt 40 ] && die "symlink loop while resolving: $1"
    _rp_link=$(readlink "$_rp_target")
    case "$_rp_link" in
      /*) _rp_target="$_rp_link" ;;
      *)  _rp_target="$(dirname "$_rp_target")/$_rp_link" ;;
    esac
  done
  printf '%s\n' "$_rp_target"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Account names become path segments, so anything containing a slash or a dot
# could escape the store. Allow only characters that cannot traverse.
validate_name() {
  case "$1" in
    '') die "account name cannot be empty" ;;
    -*) die "account name cannot start with '-': $1" ;;
  esac
  case "$1" in
    *[!A-Za-z0-9_-]*)
      die "invalid account name: '$1' (allowed: letters, digits, '-', '_')" ;;
  esac
}

validate_provider() {
  case " $PROVIDER_LIST " in
    *" $1 "*) return 0 ;;
  esac
  die "unknown provider: '$1' (allowed: $PROVIDER_LIST)"
}
