# shellcheck shell=bash
#
# The command table: one row per verb drives usage, dispatch, flag parsing and
# shell completion. Row format: verb|args|flags|summary
#   args   positional synopsis, shown verbatim in usage
#   flags  space-separated; a flag that takes a value carries =METAVAR (--rc=FILE)
#
# Public functions:
#   usage                          print the help text
#   command_exists <verb>          0 when the verb is in the table
#   parse_flags <verb> "$@"        flags only; sets ARG_FLAGS (+ ARG_<NAME> for value flags)
#   parse_account_args <verb> "$@" <provider> <name> then flags; sets ARG_PROVIDER,
#                                  ARG_NAME, ARG_FLAGS, ARG_REST
#   has_flag <flag>                0 when the last parse saw <flag>
#   complete_words <cword> <words...>  completion candidates as value:description

COMMAND_TABLE=$(cat <<'EOF'
login|<provider> <name>|--force --existing|Sign in and save an account
relogin|<provider> <name>||Sign in again to an account
use|<provider> <name>|--force|Make an account active
run|<provider> <name> [--] <args...>||Run a CLI with an account
which|<provider>||Print the active account
list|[<provider>]|--names|List saved accounts
check|<provider> <name>|--deep|Check account credentials
repair|[<provider>]||Repair replaced live auth
rm|<provider> <name>|--yes|Delete an account
restore|<provider>||Restore backed-up live auth
migrate|||Copy codex-accounts data into agentic
shell-init||--remove --print --rc=FILE|Install shell wrappers
EOF
)

ARG_PROVIDER=""
ARG_NAME=""
ARG_FLAGS=" "
ARG_REST=()

# Sets ROW_ARGS and ROW_FLAGS for <verb>; returns 1 when absent.
command_row() {
  local verb args flags summary
  while IFS='|' read -r verb args flags summary; do
    if [ "$verb" = "$1" ]; then
      ROW_ARGS="$args"
      ROW_FLAGS="$flags"
      return 0
    fi
  done <<< "$COMMAND_TABLE"
  return 1
}

command_exists() {
  [ -n "$1" ] && command_row "$1"
}

# "<args> [--flag] [--rc=FILE]" for <verb>.
command_params() {
  local out="" flag
  command_row "$1" || return 1
  out="$ROW_ARGS"
  for flag in $ROW_FLAGS; do
    out="${out:+$out }[$flag]"
  done
  printf '%s\n' "$out"
}

usage() {
  local verb args flags summary params verb_width=0 width=0 rows=""
  while IFS='|' read -r verb args flags summary; do
    params=$(command_params "$verb")
    [ "${#verb}" -le "$verb_width" ] || verb_width=${#verb}
    [ "${#params}" -le "$width" ] || width=${#params}
  done <<< "$COMMAND_TABLE"

  while IFS='|' read -r verb args flags summary; do
    params=$(command_params "$verb")
    rows="$rows$(printf '  %-*s %-*s  %s' "$verb_width" "$verb" "$width" "$params" "$summary")
"
  done <<< "$COMMAND_TABLE"

  cat <<EOF
${C_BOLD}agentic${C_RESET} - multi-provider CLI account manager

${C_BOLD}USAGE${C_RESET}
  agentic <verb> <provider> <name> [options]

${C_BOLD}COMMANDS${C_RESET}
${rows}
${C_BOLD}GLOBAL OPTIONS${C_RESET}
  --help, -h     Show this help
  --version, -V  Print the version

Version $AGENTIC_VERSION
EOF
}

# Prints the row token for <flag> ("--force" or "--rc=FILE"); 1 when absent.
row_flag_spec() {
  local spec
  for spec in $ROW_FLAGS; do
    case "$spec" in
      "$1"|"$1="*) printf '%s\n' "$spec"; return 0 ;;
    esac
  done
  return 1
}

# --rc -> ARG_RC
flag_var_name() {
  printf 'ARG_%s\n' "$(printf '%s' "${1#--}" | tr 'a-z-' 'A-Z_')"
}

parse_flags() {
  local verb="$1" arg name value spec metavar
  shift
  command_row "$verb" || die "unknown command: $verb"

  ARG_FLAGS=" "
  for spec in $ROW_FLAGS; do
    case "$spec" in
      *=*) printf -v "$(flag_var_name "${spec%%=*}")" '%s' "" ;;
    esac
  done

  while [ $# -gt 0 ]; do
    arg="$1"
    [ "$arg" = "-y" ] && row_flag_spec --yes >/dev/null && arg="--yes"
    case "$arg" in
      --*=*)
        name="${arg%%=*}"
        value="${arg#*=}"
        spec=$(row_flag_spec "$name") || die "unknown option for $verb: $1"
        case "$spec" in
          *=*) ;;
          *) die "unknown option for $verb: $1" ;;
        esac
        ;;
      -*)
        name="$arg"
        spec=$(row_flag_spec "$name") || die "unknown option for $verb: $1"
        case "$spec" in
          *=*)
            metavar=$(printf '%s' "${spec#*=}" | tr '[:upper:]' '[:lower:]')
            shift
            [ $# -gt 0 ] || die "$name needs a $metavar"
            value="$1"
            ;;
        esac
        ;;
      *) die "unknown option for $verb: $1" ;;
    esac
    case "$spec" in
      *=*) printf -v "$(flag_var_name "$name")" '%s' "$value" ;;
    esac
    ARG_FLAGS="$ARG_FLAGS$name "
    shift
  done
}

# ARG_* are read by the cmd_* functions in bin/agentic.
# shellcheck disable=SC2034
parse_account_args() {
  local verb="$1"
  shift
  command_row "$verb" || die "unknown command: $verb"
  if [ $# -lt 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
    die "usage: agentic $verb $(command_params "$verb")"
  fi
  validate_provider "$1"
  validate_name "$2"
  ARG_PROVIDER="$1"
  ARG_NAME="$2"
  shift 2

  ARG_REST=()
  case "$ROW_ARGS" in
    *"<args...>"*)
      [ "${1:-}" = "--" ] && shift
      [ $# -eq 0 ] || ARG_REST=("$@")
      parse_flags "$verb"
      ;;
    *) parse_flags "$verb" "$@" ;;
  esac
}

has_flag() {
  case "$ARG_FLAGS" in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

complete_flags() {
  local spec
  for spec in $ROW_FLAGS; do
    printf '%s:option\n' "${spec%%=*}"
  done
}

complete_words() {
  local cword="${1:-1}" verb summary args flags provider prev spec
  shift || true
  # cword is used as an array index, which bash evaluates arithmetically.
  case "$cword" in
    '' | *[!0-9]*) return 0 ;;
  esac
  # Leading zeros would make 08 and 09 invalid octal.
  cword=$((10#$cword))

  if [ "$cword" -le 1 ]; then
    while IFS='|' read -r verb args flags summary; do
      printf '%s:%s\n' "$verb" "$summary"
    done <<< "$COMMAND_TABLE"
    printf '%s\n' 'help:Show this help' '--help:Show this help' '--version:Print the version'
    return 0
  fi

  verb="${1:-}"
  command_row "$verb" || return 0
  local -a words=("$@")

  # --rc=<partial>: the value is completed in place.
  case "${words[cword-1]:-}" in
    --*=*)
      if spec=$(row_flag_spec "${words[cword-1]%%=*}"); then
        case "$spec" in
          *=FILE) printf '%s\n' '__files__'; return 0 ;;
        esac
      fi
      ;;
  esac

  prev="${words[cword-2]:-}"
  if [ "$cword" -gt 2 ] && spec=$(row_flag_spec "$prev"); then
    case "$spec" in
      *=FILE) printf '%s\n' '__files__'; return 0 ;;
    esac
  fi

  case "$cword:$ROW_ARGS" in
    "2:<provider>"*)
      for provider in $PROVIDER_LIST; do printf '%s:provider\n' "$provider"; done
      return 0
      ;;
    "2:[<provider>]"*)
      for provider in $PROVIDER_LIST; do printf '%s:provider\n' "$provider"; done
      complete_flags
      return 0
      ;;
    "3:"*"<name>"*)
      provider="${words[1]:-}"
      case " $PROVIDER_LIST " in
        *" $provider "*) ;;
        *) return 0 ;;
      esac
      list_accounts "$provider" | while IFS= read -r args; do
        printf '%s:%s account\n' "$args" "$provider"
      done
      return 0
      ;;
  esac

  case "$ROW_ARGS" in
    *"<args...>"*) return 0 ;;
  esac
  complete_flags
}
