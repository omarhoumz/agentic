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
  [[ "$output" == *"already present"* ]] || false
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
  [[ "$output" == *"managed by agentic"* ]] || false
  [[ "$output" == *"agentic login codex"* ]] || false
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
  [[ "$output" == *"no shell integration"* ]] || false
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
  [[ "$output" == *"managed by agentic"* ]] || false
  [[ "$output" == *"agentic login codex"* ]] || false
  [[ "$output" == *"EXIT=1"* ]] || false
  [[ "$output" != *"stub-codex"* ]] || false
}

@test "codex logout is intercepted" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "codex logout; echo EXIT=\$?"
  [[ "$output" == *"managed by agentic"* ]] || false
  [[ "$output" == *"EXIT=1"* ]] || false
  [[ "$output" != *"stub-codex"* ]] || false
}

@test "codex login status is allowed - it only reads" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "codex login status"
  [[ "$output" != *"managed by agentic"* ]] || false
}

@test "agent login is intercepted once a store exists" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/cursor/personal"
  stub_agent
  run wrapped "agent login; echo EXIT=\$?"
  [[ "$output" == *"managed by agentic"* ]] || false
  [[ "$output" == *"agentic login cursor"* ]] || false
  [[ "$output" == *"EXIT=1"* ]] || false
  [[ "$output" != *"stub-agent"* ]] || false
}

@test "sourcing the snippet selects Cursor's file credential store" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/cursor/personal"

  run wrapped 'printf "%s\n" "$AGENT_CLI_CREDENTIAL_STORE"'

  [ "$status" -eq 0 ]
  [ "$output" = "file" ]
}

@test "Codex-only store does not force Cursor file credential store" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  unset AGENT_CLI_CREDENTIAL_STORE || true

  run wrapped 'printf "%s\n" "${AGENT_CLI_CREDENTIAL_STORE-}"'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "with no store the wrapper stays out of the way" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  rm -rf "$AGENTIC_DIR"
  stub_codex 0
  run wrapped "codex login"
  [[ "$output" != *"managed by agentic"* ]] || false
  [[ "$output" == *"stub-codex login"* ]] || false
}

@test "the documented bypass works" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  export SNIPPET
  mkdir -p "$AGENTIC_DIR/codex/personal"
  stub_codex 0
  run wrapped "command codex login"
  [[ "$output" == *"stub-codex login"* ]] || false
  [[ "$output" != *"managed by agentic"* ]] || false
}

@test "shell-init accepts --rc=FILE" {
  run "$AGENTIC" shell-init --rc="$RC"
  [ "$status" -eq 0 ]
  grep -q ">>> agentic shell-init >>>" "$RC"
}

@test "shell-init --rc without a file fails" {
  run "$AGENTIC" shell-init --rc
  [ "$status" -eq 1 ]
  [[ "$output" == *"--rc needs a file"* ]] || false
}

stub_claude() {
  cat > "$BATS_TEST_TMPDIR/stub-bin/claude" <<'EOF2'
#!/usr/bin/env bash
echo "stub-claude dir=${CLAUDE_CONFIG_DIR:-} key=${ANTHROPIC_API_KEY:-} $*"
EOF2
  chmod +x "$BATS_TEST_TMPDIR/stub-bin/claude"
  ln -sf "$AGENTIC" "$BATS_TEST_TMPDIR/stub-bin/agentic"
  mkdir -p "$AGENTIC_DIR/claude/work" "$AGENTIC_DIR/claude/personal/config"
  : > "$AGENTIC_DIR/claude/work/default-dir"
  printf '%s\n' "$AGENTIC_DIR/claude/personal/config" > "$AGENTIC_DIR/claude/personal/config-path"
}

@test "claude wrapper opens the default home when nothing is selected" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  stub_claude

  run wrapped "CLAUDE_CONFIG_DIR=/elsewhere ANTHROPIC_API_KEY=leak; export CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY; claude -p hi"

  [ "$output" = "stub-claude dir= key= -p hi" ]
}

@test "claude wrapper follows use, and back" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  stub_claude

  "$AGENTIC" use claude personal
  run wrapped "claude -p hi"
  [ "$output" = "stub-claude dir=$AGENTIC_DIR/claude/personal/config key= -p hi" ]

  "$AGENTIC" use claude work
  run wrapped "claude -p hi"
  [ "$output" = "stub-claude dir= key= -p hi" ]
}

@test "claude wrapper warns and opens the default when the selection is gone" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  stub_claude
  printf 'gone\n' > "$AGENTIC_DIR/claude/.current"

  run wrapped "claude"

  [ "$output" = "agentic: claude account 'gone' not found; using default (~/.claude)
stub-claude dir= key= " ]
}

@test "claude auth login is not blocked" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"
  stub_claude
  "$AGENTIC" use claude personal

  run wrapped "claude auth login"

  [ "$status" -eq 0 ]
  [ "$output" = "stub-claude dir=$AGENTIC_DIR/claude/personal/config key= auth login" ]
}

@test "without a claude store there is no claude wrapper" {
  SNIPPET="$REPO_ROOT/shell/agentic.sh"

  run wrapped "type claude"

  [[ "$output" != *function* ]] || false
}
