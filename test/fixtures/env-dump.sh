#!/usr/bin/env bash
#
# Prints provider env for run isolation tests.

set -eu

printf 'CURSOR_CONFIG_DIR=%s\n' "${CURSOR_CONFIG_DIR:-}"
printf 'AGENT_CLI_CREDENTIAL_STORE=%s\n' "${AGENT_CLI_CREDENTIAL_STORE:-}"
printf 'CLAUDE_CONFIG_DIR=%s\n' "${CLAUDE_CONFIG_DIR:-}"
printf 'ANTHROPIC_API_KEY=%s\n' "${ANTHROPIC_API_KEY:-}"
printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "${CLAUDE_CODE_OAUTH_TOKEN:-}"
exit 0
