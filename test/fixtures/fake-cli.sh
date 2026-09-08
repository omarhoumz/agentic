#!/usr/bin/env bash
#
# Stub CLI for provider tests. Writes auth on login; checks auth on status/whoami.
#
# Codex: auth under $CODEX_HOME (matches real CODEX_HOME isolation).
# Cursor: auth under the live cursor home (matches real Agent CLI file store,
# which ignores CURSOR_CONFIG_DIR for credentials).

set -eu

case "${1:-}" in
  login)
    if [ "${2:-}" = "status" ]; then
      if [ -n "${CODEX_HOME:-}" ] && [ -f "$CODEX_HOME/auth.json" ]; then
        printf 'ok\n'
        exit 0
      fi
      _fc_live="${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}/auth.json"
      if [ -f "$_fc_live" ]; then
        printf 'ok\n'
        exit 0
      fi
      exit 1
    fi

    if [ -n "${CODEX_HOME:-}" ]; then
      mkdir -p "$CODEX_HOME"
      printf '{"token":"x"}\n' > "$CODEX_HOME/auth.json"
    else
      _fc_live_home="${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}"
      mkdir -p "$_fc_live_home"
      printf '{"token":"x"}\n' > "$_fc_live_home/auth.json"
      if [ -n "${CURSOR_CONFIG_DIR:-}" ]; then
        mkdir -p "$CURSOR_CONFIG_DIR"
        printf '{}\n' > "$CURSOR_CONFIG_DIR/cli-config.json"
      fi
    fi
    exit 0
    ;;
  status|whoami)
    if [ -n "${CODEX_HOME:-}" ] && [ -f "$CODEX_HOME/auth.json" ]; then
      printf 'ok\n'
      exit 0
    fi
    _fc_live="${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}/auth.json"
    if [ -f "$_fc_live" ]; then
      printf 'ok\n'
      exit 0
    fi
    exit 1
    ;;
esac

exec "$@"
