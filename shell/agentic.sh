# shellcheck shell=bash
#
# agentic shell integration - source this from ~/.zshrc or ~/.bashrc
#
# Wraps `codex` and `agent` so bare login/logout cannot overwrite stored accounts.

# Only force the file credential store when Cursor accounts are managed here.
# Codex-only users keep the Agent CLI's default (Keychain on macOS).
if [ -d "${AGENTIC_DIR:-$HOME/.agentic}/cursor" ]; then
  export AGENT_CLI_CREDENTIAL_STORE=file
fi

# ---------------------------------------------------------------------------
# codex wrapper
# ---------------------------------------------------------------------------

codex() {
  if [ ! -d "${AGENTIC_DIR:-$HOME/.agentic}" ]; then
    command codex "$@"
    return
  fi

  case "${1:-}" in
    login)
      if [ "${2:-}" != "status" ]; then
        printf 'codex login is managed by agentic. Try: agentic login codex <name>\n' >&2
        return 1
      fi
      ;;
    logout)
      printf 'codex logout is managed by agentic. Try: agentic relogin codex <name>\n' >&2
      return 1
      ;;
  esac

  command codex "$@"
}

# ---------------------------------------------------------------------------
# agent wrapper
# ---------------------------------------------------------------------------

agent() {
  if [ ! -d "${AGENTIC_DIR:-$HOME/.agentic}" ]; then
    command agent "$@"
    return
  fi

  case "${1:-}" in
    login)
      printf 'agent login is managed by agentic. Try: agentic login cursor <name>\n' >&2
      return 1
      ;;
    logout)
      printf 'agent logout is managed by agentic. Try: agentic relogin cursor <name>\n' >&2
      return 1
      ;;
  esac

  command agent "$@"
}
