#!/usr/bin/env bash
#
# End-user simulation in a clean Linux container.
#
# Expanded in later tasks once install.sh and provider verbs exist.
# Task 1: smoke-check agentic --version in a bare container.
#
#   ./test/clean-env.sh            # default image
#   ./test/clean-env.sh alpine     # musl/busybox portability check

set -euo pipefail

IMAGE="${1:-debian:stable-slim}"
REPO="$(cd "$(dirname "$0")/.." && pwd -P)"

printf '\n=== clean-env test (task 1 stub): %s ===\n\n' "$IMAGE"

docker run --rm -i \
  -v "$REPO:/src:ro" \
  -e HOME=/home/tester \
  "$IMAGE" sh -s <<'SCRIPT'
set -eu

mkdir -p /home/tester
cp -r /src /home/tester/agentic
cd /home/tester/agentic

echo "--- environment ---"
echo "bash: $(command -v bash || echo 'ABSENT')"

echo
echo "--- agentic --version ---"
./bin/agentic --version | grep -q '^agentic 0.1.0$' \
  || { echo "FAIL: unexpected version output"; exit 1; }

echo
echo "=== ALL CLEAN-ENV CHECKS PASSED (task 1 stub) ==="
SCRIPT
