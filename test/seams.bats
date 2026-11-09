#!/usr/bin/env bats
load helper

@test "only lib/ touches the live auth path" {
  run grep -nE 'provider_live_auth|\.bak|ln -s' "$REPO_ROOT/bin/agentic"
  [ "$status" -eq 1 ]
}

@test "providers declare facts and never touch files" {
  run grep -rnE 'provider_live_auth|ln -s|\.bak|cp |rm -f' "$REPO_ROOT/providers/"
  [ "$status" -eq 1 ]
}

@test "providers define only the allowed fact functions" {
  local allowed=" provider_live_home provider_cli_bin provider_account_env provider_login_writes_live provider_process_name provider_shared_config_files provider_status_needs_active provider_switch_mode provider_unset_env provider_login_args provider_status_args provider_logout_args "
  local fn extra=""
  for fn in $(sed -nE 's/^[[:space:]]*(function[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(\).*/\2/p' "$REPO_ROOT"/providers/*.sh); do
    case "$allowed" in
      *" $fn "*) ;;
      *) extra="$extra $fn" ;;
    esac
  done
  [ -z "$extra" ] || { echo "not allowed in providers/:$extra"; false; }
}

@test "agentic never names a Claude credential or calls the Keychain tool" {
  # Claude's refresh tokens rotate; a copy held by agentic breaks the login.
  run grep -rnE '\.credentials\.json|(^|[^A-Za-z0-9_-])security([[:space:]"'"'"']|$)' \
    "$REPO_ROOT/bin" "$REPO_ROOT/lib" "$REPO_ROOT/providers" "$REPO_ROOT/shell"
  [ "$status" -eq 1 ]
}

@test "the claude wrapper unsets the same variables as the provider" {
  local provider wrapper
  provider=$(sed -n "/^provider_unset_env/,/^}/s/^ *printf '%s\\\\n' //p" "$REPO_ROOT/providers/claude.sh")
  wrapper=$(sed -n 's/^ *unset \(CLAUDE_CONFIG_DIR.*\)/\1/p' "$REPO_ROOT/shell/agentic.sh")
  [ -n "$provider" ]
  [ "$provider" = "$wrapper" ]
}

@test "every command table verb has a cmd_ function in bin/ or lib/" {
  . "$REPO_ROOT/lib/commands.sh"
  local verb rest missing=""
  while IFS='|' read -r verb rest; do
    grep -qh "^cmd_$(printf %s "$verb" | tr - _)()" "$REPO_ROOT/bin/agentic" "$REPO_ROOT"/lib/*.sh || missing="$missing $verb"
  done <<< "$COMMAND_TABLE"
  [ -z "$missing" ] || { echo "no cmd_ function for:$missing"; false; }
}

@test "every standalone [[ ]] assertion ends with || false" {
  # bash 3.2 does not fail a bats test on a false [[ ]] that is not its last command.
  run grep -nE '^[[:space:]]*\[\[.*\]\][[:space:]]*$' "$REPO_ROOT"/test/*.bats
  [ "$status" -eq 1 ]
}
