#!/usr/bin/env bash
#
# Stub CLI for provider tests. Writes auth on login; checks auth on status/whoami.

set -eu

case "${1:-}" in
  login)
    if [ -n "${CODEX_HOME:-}" ]; then
      mkdir -p "$CODEX_HOME"
      printf '{"token":"x"}\n' > "$CODEX_HOME/auth.json"
    elif [ -n "${CURSOR_CONFIG_DIR:-}" ]; then
      mkdir -p "$CURSOR_CONFIG_DIR"
      printf '{"token":"x"}\n' > "$CURSOR_CONFIG_DIR/auth.json"
    fi
    exit 0
    ;;
  status|whoami)
    if [ -n "${CODEX_HOME:-}" ] && [ -f "$CODEX_HOME/auth.json" ]; then
      printf 'ok\n'
      exit 0
    fi
    if [ -n "${CURSOR_CONFIG_DIR:-}" ] && [ -f "$CURSOR_CONFIG_DIR/auth.json" ]; then
      printf 'ok\n'
      exit 0
    fi
    exit 1
    ;;
esac

exec "$@"
