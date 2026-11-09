# shellcheck shell=bash
#
# agentic shell integration - source this from ~/.zshrc or ~/.bashrc
#
# Wraps `codex` and `agent` so bare login/logout cannot overwrite stored
# accounts, and `claude` so it opens the account picked with `agentic use`.

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

# ---------------------------------------------------------------------------
# claude wrapper - defined only when Claude accounts are managed here
# ---------------------------------------------------------------------------
#
# Opens the account `agentic use claude <name>` selected; with none selected,
# the default home (~/.claude). Login and logout pass through: each account
# keeps its own login, so they only touch the selected one.

if [ -d "${AGENTIC_DIR:-$HOME/.agentic}/claude" ]; then
  claude() {
    local store name
    store="${AGENTIC_DIR:-$HOME/.agentic}/claude"
    name=""
    if [ -f "$store/.current" ]; then
      name=$(cat "$store/.current" 2>/dev/null)
    fi
    case "$name" in
      *[!A-Za-z0-9_-]* | -*) name="?$name" ;;
    esac
    if [ -n "$name" ] && [ ! -d "$store/$name" ]; then
      printf "agentic: claude account '%s' not found; using default (~/.claude)\n" "$name" >&2
      name=""
    fi

    if [ -n "$name" ]; then
      command agentic run claude "$name" -- "$@"
      return
    fi
    (
      # Same list as provider_unset_env in providers/claude.sh (seams.bats).
      unset CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN
      command claude "$@"
    )
  }
fi
