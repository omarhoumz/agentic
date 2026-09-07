#!/usr/bin/env bash
#
# Prints provider env for run isolation tests.

set -eu

printf 'CURSOR_CONFIG_DIR=%s\n' "${CURSOR_CONFIG_DIR:-}"
printf 'AGENT_CLI_CREDENTIAL_STORE=%s\n' "${AGENT_CLI_CREDENTIAL_STORE:-}"
exit 0
