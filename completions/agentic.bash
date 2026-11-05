# bash completion for agentic. Candidates come from `agentic __complete`,
# which reads the command table; this file only adapts them to bash.
#
# shellcheck shell=bash

_agentic_complete() {
  local cur line files=0
  local -a values=()
  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=()

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ "$line" = "__files__" ]; then
      files=1
    else
      values[${#values[@]}]="${line%%:*}"
    fi
  done < <(agentic __complete "$COMP_CWORD" "${COMP_WORDS[@]:1}" 2>/dev/null)

  if [ "$files" -eq 1 ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && COMPREPLY[${#COMPREPLY[@]}]="$line"
    done < <(compgen -f -- "$cur")
    return
  fi

  while IFS= read -r line; do
    [ -n "$line" ] && COMPREPLY[${#COMPREPLY[@]}]="$line"
  done < <(compgen -W "${values[*]-}" -- "$cur")
}

complete -F _agentic_complete agentic
