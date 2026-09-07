# shellcheck shell=bash
#
# Shared test setup. Every test runs against a scratch HOME so the suite can
# never read, write or delete a real credential.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  export REPO_ROOT

  TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
  export HOME="$TEST_HOME"

  export AGENTIC_DIR="$TEST_HOME/.agentic"
  mkdir -p "$AGENTIC_DIR"

  export NO_COLOR=1

  # shellcheck source=../lib/common.sh
  . "$REPO_ROOT/lib/common.sh"

  AGENTIC="$REPO_ROOT/bin/agentic"
  export AGENTIC
}
