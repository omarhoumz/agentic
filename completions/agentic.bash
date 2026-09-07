# bash completion for agentic.
#
# shellcheck shell=bash

_agentic_reply() {
  COMPREPLY=()
  while IFS= read -r _agentic_line; do
    [ -n "$_agentic_line" ] && COMPREPLY[${#COMPREPLY[@]}]="$_agentic_line"
  done < <(compgen -W "$1" -- "$2")
}

_agentic_accounts() {
  agentic list "$1" --names 2>/dev/null
}

_agentic_complete() {
  local cur prev verb provider verbs providers
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}
  verbs="login relogin use run which list check repair rm restore migrate shell-init help --help --version"
  providers="codex cursor"

  if [ "$COMP_CWORD" -eq 1 ]; then
    _agentic_reply "$verbs" "$cur"
    return
  fi

  verb=${COMP_WORDS[1]}
  case "$verb" in
    login|relogin|use|run|check|rm)
      if [ "$COMP_CWORD" -eq 2 ]; then
        _agentic_reply "$providers" "$cur"
      elif [ "$COMP_CWORD" -eq 3 ]; then
        provider=${COMP_WORDS[2]}
        _agentic_reply "$(_agentic_accounts "$provider")" "$cur"
      else
        case "$verb" in
          login|use) _agentic_reply "--force" "$cur" ;;
          check) _agentic_reply "--deep" "$cur" ;;
          rm) _agentic_reply "--yes" "$cur" ;;
        esac
      fi
      ;;
    which|restore)
      [ "$COMP_CWORD" -eq 2 ] && _agentic_reply "$providers" "$cur"
      ;;
    list)
      [ "$COMP_CWORD" -eq 2 ] && _agentic_reply "$providers --names" "$cur"
      [ "$COMP_CWORD" -gt 2 ] && _agentic_reply "--names" "$cur"
      ;;
    repair)
      [ "$COMP_CWORD" -eq 2 ] && _agentic_reply "$providers --yes" "$cur"
      [ "$COMP_CWORD" -gt 2 ] && _agentic_reply "--yes" "$cur"
      ;;
    shell-init)
      if [ "$prev" = "--rc" ]; then
        COMPREPLY=()
        while IFS= read -r _agentic_line; do
          [ -n "$_agentic_line" ] && COMPREPLY[${#COMPREPLY[@]}]="$_agentic_line"
        done < <(compgen -f -- "$cur")
      else
        _agentic_reply "--remove --print --rc" "$cur"
      fi
      ;;
  esac
}

complete -F _agentic_complete agentic
