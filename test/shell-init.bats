#!/usr/bin/env bats
#
# shell-init writes into the user's shell rc file: idempotent, marker-delimited,
# and removable without disturbing anything else in there.

load helper

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  export REPO_ROOT

  TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
  export HOME="$TEST_HOME"

  export AGENTIC_DIR="$TEST_HOME/.agentic"
  mkdir -p "$AGENTIC_DIR"

  export NO_COLOR=1
  AGENTIC="$REPO_ROOT/bin/agentic"
  export AGENTIC

  RC="$BATS_TEST_TMPDIR/rc/.zshrc"
  export RC
  mkdir -p "$(dirname "$RC")"
  printf '# my shell config\nexport EDITOR=vim\n' > "$RC"

  export PATH="$BATS_TEST_TMPDIR/stub-bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/stub-bin"
}

stub_codex() {
  cat > "$BATS_TEST_TMPDIR/stub-bin/codex" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "login" ] && [ "\$2" = "status" ]; then exit ${1:-0}; fi
echo "stub-codex \$*"
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/stub-bin/codex"
}

stub_agent() {
  cat > "$BATS_TEST_TMPDIR/stub-bin/agent" <<'EOF'
#!/usr/bin/env bash
echo "stub-agent $*"
exit 0
EOF
  chmod +x "$BATS_TEST_TMPDIR/stub-bin/agent"
}

wrapped() {
  bash -c "set +e; . '$SNIPPET'; $*" 2>&1
}

@test "shell-init appends a marked block" {
  run "$AGENTIC" shell-init --rc "$RC"
  [ "$status" -eq 0 ]
  grep -q ">>> agentic shell-init >>>" "$RC"
  grep -q "shell/agentic.sh" "$RC"
  grep -q "<<< agentic shell-init <<<" "$RC"
}

@test "existing rc contents are preserved" {
  "$AGENTIC" shell-init --rc "$RC"
  grep -q "export EDITOR=vim" "$RC"
  grep -q "# my shell config" "$RC"
}

@test "shell-init is idempotent" {
  "$AGENTIC" shell-init --rc "$RC"
  run "$AGENTIC" shell-init --rc "$RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already present"* ]]
  [ "$(grep -c ">>> agentic shell-init >>>" "$RC")" -eq 1 ]
}

@test "the sourced path actually exists" {
  "$AGENTIC" shell-init --rc "$RC"
  path=$(grep -o '"[^"]*shell/agentic.sh"' "$RC" | tr -d '"')
  [ -f "$path" ]
}

@test "the appended block is valid shell" {
  "$AGENTIC" shell-init --rc "$RC"
  run bash -n "$RC"
  [ "$status" -eq 0 ]
}

@test "sourcing the rc file gives you the codex wrapper" {
  "$AGENTIC" shell-init --rc "$RC"
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run bash -c "set +e; . '$RC'; codex login"
  [[ "$output" == *"managed by agentic"* ]]
  [[ "$output" == *"agentic login codex"* ]]
}

@test "shell-init --remove takes out the block" {
  "$AGENTIC" shell-init --rc "$RC"
  run "$AGENTIC" shell-init --rc "$RC" --remove
  [ "$status" -eq 0 ]
  ! grep -q "agentic shell-init" "$RC"
  grep -q "export EDITOR=vim" "$RC"
}

@test "shell-init --remove on a clean rc is harmless" {
  run "$AGENTIC" shell-init --rc "$RC" --remove
  [ "$status" -eq 0 ]
  [[ "$output" == *"no shell integration"* ]]
}

@test "shell-init --remove preserves trailing blank lines" {
  original='# my shell config
export EDITOR=vim


'
  printf '%s' "$original" > "$RC"
  "$AGENTIC" shell-init --rc "$RC"
  "$AGENTIC" shell-init --rc "$RC" --remove
  printf '%s' "$original" | cmp -s - "$RC"
}

@test "shell-init --remove edits a symlinked rc target without replacing the link" {
  target="$BATS_TEST_TMPDIR/dotfiles/zshrc"
  mkdir -p "$(dirname "$target")"
  printf '# my shell config\nexport EDITOR=vim\n' > "$target"
  ln -sf "$target" "$RC"

  "$AGENTIC" shell-init --rc "$RC"
  grep -q ">>> agentic shell-init >>>" "$target"

  run "$AGENTIC" shell-init --rc "$RC" --remove
  [ "$status" -eq 0 ]
  [ -L "$RC" ]
  [ "$(readlink "$RC")" = "$target" ]
  ! grep -q "agentic shell-init" "$target"
  grep -q "export EDITOR=vim" "$target"
}

@test "shell-init --print reports the snippet path" {
  run "$AGENTIC" shell-init --print
  [ "$status" -eq 0 ]
  [ -f "$output" ]
  case "$output" in */shell/agentic.sh) ;; *) false ;; esac
}

@test "a missing rc file is created" {
  fresh="$BATS_TEST_TMPDIR/rc/.brand-new-rc"
  run "$AGENTIC" shell-init --rc "$fresh"
  [ "$status" -eq 0 ]
  grep -q "shell/agentic.sh" "$fresh"
}

# --- wrapper behaviour (shell/agentic.sh) -----------------------------------

@test "codex login is intercepted once a store exists" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "codex login; echo EXIT=\$?"
  [[ "$output" == *"managed by agentic"* ]]
  [[ "$output" == *"agentic login codex"* ]]
  [[ "$output" == *"EXIT=1"* ]]
  [[ "$output" != *"stub-codex"* ]]
}

@test "codex logout is intercepted" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "codex logout; echo EXIT=\$?"
  [[ "$output" == *"managed by agentic"* ]]
  [[ "$output" == *"EXIT=1"* ]]
  [[ "$output" != *"stub-codex"* ]]
}

@test "codex login status is allowed - it only reads" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "codex login status"
  [[ "$output" != *"managed by agentic"* ]]
}

@test "agent login is intercepted once a store exists" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/cursor/personal"
  stub_agent
  run wrapped "agent login; echo EXIT=\$?"
  [[ "$output" == *"managed by agentic"* ]]
  [[ "$output" == *"agentic login cursor"* ]]
  [[ "$output" == *"EXIT=1"* ]]
  [[ "$output" != *"stub-agent"* ]]
}

@test "sourcing the snippet selects Cursor's file credential store" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/cursor/personal"

  run wrapped 'printf "%s\n" "$AGENT_CLI_CREDENTIAL_STORE"'

  [ "$status" -eq 0 ]
  [ "$output" = "file" ]
}

@test "with no store the wrapper stays out of the way" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  rm -rf "$AGENTIC_DIR"
  stub_codex 0
  run wrapped "codex login"
  [[ "$output" != *"managed by agentic"* ]]
  [[ "$output" == *"stub-codex login"* ]]
}

@test "the documented bypass works" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "command codex login"
  [[ "$output" == *"stub-codex login"* ]]
  [[ "$output" != *"managed by agentic"* ]]
}
