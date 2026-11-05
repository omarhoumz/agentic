#!/usr/bin/env bats
#
# One command table drives usage, flag parsing and completion. These pin the
# table-derived behaviour and the two completion shims that read it.

load helper

@test "__complete lists every verb" {
  run "$AGENTIC" __complete 1 ""
  [ "$status" -eq 0 ]
  for verb in login relogin use run which list check repair rm restore migrate shell-init; do
    [[ "$output" == *"$verb:"* ]] || false
  done
}

@test "__complete offers providers then account names" {
  mkdir -p "$AGENTIC_DIR/codex/work"

  run "$AGENTIC" __complete 2 use ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"codex:"* ]] || false
  [[ "$output" == *"cursor:"* ]] || false

  run "$AGENTIC" __complete 3 use codex ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"work"* ]] || false
}

@test "__complete offers per-verb flags" {
  run "$AGENTIC" __complete 4 check codex work ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"--deep"* ]] || false
  [[ "$output" != *"--force"* ]] || false
}

@test "__complete asks for a file after --rc" {
  run "$AGENTIC" __complete 3 shell-init --rc ""
  [ "$status" -eq 0 ]
  [ "$output" = "__files__" ]
}

@test "help lists every table verb" {
  run "$AGENTIC" --help
  [ "$status" -eq 0 ]
  for summary in "Sign in and save an account" "Sign in again to an account" \
    "Make an account active" "Run a CLI with an account" "Print the active account" \
    "List saved accounts" "Check account credentials" "Repair replaced live auth" \
    "Delete an account" "Restore backed-up live auth" \
    "Copy codex-accounts data into agentic" "Install shell wrappers"; do
    [[ "$output" == *"$summary"* ]] || false
  done
  [[ "$output" != *"__complete"* ]] || false
}

@test "bash completion shim loads" {
  run bash -c "source '$REPO_ROOT/completions/agentic.bash' && complete -p agentic"
  [ "$status" -eq 0 ]
}

@test "bash completion shim completes verbs through __complete" {
  run bash -c "
    agentic() { '$AGENTIC' \"\$@\"; }
    source '$REPO_ROOT/completions/agentic.bash'
    COMP_WORDS=(agentic che); COMP_CWORD=1
    _agentic_complete
    printf '%s\n' \"\${COMPREPLY[@]}\""
  [ "$status" -eq 0 ]
  [ "$output" = "check" ]
}

@test "zsh completion shim loads" {
  command -v zsh || skip "zsh not installed"
  run zsh -c "fpath=('$REPO_ROOT/completions' \$fpath); autoload -Uz compinit && compinit -u && autoload -Uz _agentic && whence -w _agentic"
  [ "$status" -eq 0 ]
}

@test "unknown flag is rejected per verb" {
  mkdir -p "$AGENTIC_DIR/codex/work"
  run "$AGENTIC" use codex work --deep
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option for use: --deep"* ]] || false
}

@test "missing account args print the table-built usage" {
  run "$AGENTIC" check codex
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: agentic check <provider> <name> [--deep]"* ]] || false
}
