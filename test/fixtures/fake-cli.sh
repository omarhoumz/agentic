#!/usr/bin/env bash
#
# Stub CLI for provider tests. Writes auth on login; checks auth on status/whoami.
#
# Codex: auth under $CODEX_HOME (matches real CODEX_HOME isolation).
# Cursor: auth under the live cursor home (matches real Agent CLI file store,
# which ignores CURSOR_CONFIG_DIR for credentials).
# Claude: `auth login|status|logout` keep a .fake-login sentinel under
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude}; logout appends to $FAKE_LOG when set.

set -eu

case "${1:-}" in
  auth)
    _fc_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    case "${2:-}" in
      login)
        [ "${FAKE_LOGIN_FAIL:-0}" = 1 ] && exit 1
        mkdir -p "$_fc_dir"
        printf '%s\n' "${FAKE_TOKEN:-x}" > "$_fc_dir/.fake-login"
        [ -z "${FAKE_LOG:-}" ] || printf 'login %s\n' "$_fc_dir" >> "$FAKE_LOG"
        exit 0
        ;;
      status)
        if [ -f "$_fc_dir/.fake-login" ]; then
          printf 'Logged in via %s\n' "$_fc_dir"
          exit 0
        fi
        printf 'Not logged in\n'
        exit 1
        ;;
      logout)
        [ -z "${FAKE_LOG:-}" ] || printf 'logout %s\n' "$_fc_dir" >> "$FAKE_LOG"
        rm -f "$_fc_dir/.fake-login"
        exit 0
        ;;
    esac
    exit 2
    ;;
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

    [ "${FAKE_LOGIN_FAIL:-0}" = 1 ] && exit 1

    if [ -n "${CODEX_HOME:-}" ]; then
      mkdir -p "$CODEX_HOME"
      printf '{"token":"%s"}\n' "${FAKE_TOKEN:-x}" > "$CODEX_HOME/auth.json"
    else
      _fc_live_home="${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}"
      mkdir -p "$_fc_live_home"
      printf '{"token":"%s"}\n' "${FAKE_TOKEN:-x}" > "$_fc_live_home/auth.json"
      if [ -n "${CURSOR_CONFIG_DIR:-}" ]; then
        mkdir -p "$CURSOR_CONFIG_DIR"
        printf '{}\n' > "$CURSOR_CONFIG_DIR/cli-config.json"
      fi
    fi
    # write: the CLI saved a credential, then failed.
    [ "${FAKE_LOGIN_FAIL:-0}" = write ] && exit 1
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
