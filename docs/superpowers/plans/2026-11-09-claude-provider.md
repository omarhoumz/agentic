# Claude provider Implementation Plan

> Executed natively (Omar: "no changes, fix for 8 and implement changes", 2026-11-09).

**Goal:** add a `claude` provider (env mode, one config dir per account) and make a failed first login of any provider remove the account it just created.

**Architecture:** a new provider fact `provider_switch_mode` (`link`|`env`). `lib/switch.sh` keeps every state transition: each `live_*` verb branches to an `env_*` twin in env mode. `lib/provider.sh` gains one env-application function used by `run` and every provider command, so unsetting and exporting live in one place.

**Spec:** `docs/superpowers/specs/2026-11-05-claude-provider-design.md`

## Global Constraints

- bash 3.2; shellcheck clean (`shellcheck -x -P bin:.:providers:lib bin/agentic lib/*.sh providers/*.sh shell/agentic.sh install.sh completions/agentic.bash`); `bats test/` green.
- agentic never names `.credentials.json` or calls the Keychain tool in `lib/`, `bin/`, `providers/`.
- agentic launches `claude` with `CLAUDE_CONFIG_DIR` unset **only** for a record holding `default-dir`. A non-default record without `config-path` dies; it never falls back to `~/.claude`.
- Every agentic-launched `claude` unsets `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CONFIG_DIR`, then exports the account's env.
- No push, tag or merge without Omar's go.

## Review Focus

1. Non-default record missing `config-path` → `run`, `check`, `rm` (logout) die; `~/.claude` sentinel untouched.
2. Caller shell exports `CLAUDE_CONFIG_DIR` → `run claude <default>` launches with it unset.
3. `.current` names a deleted record → wrapper warns and launches default.
4. `repair` with no provider skips claude instead of dying.
5. `relogin` failure on an existing account deletes nothing (all providers).

## Decisions left to the builder (spec "Left to the builder")

- `provider_live_home` for claude prints `$HOME/.claude`; used only for labels. `load_provider` keeps requiring it (simpler than relaxing it; every `live_*` verb branches before touching it).
- New optional facts: `provider_switch_mode` (default `link`), `provider_unset_env` (default none), `provider_login_args` (default `login`), `provider_status_args` (default `login status`), `provider_logout_args` (default none → no logout on rm).
- `check claude` runs `claude auth status --text` and prints it verbatim; exit 1 when logged out. No JSON parsing.
- List marker: human `list` (all-provider form and `list <provider>` without `--names`) appends ` *` to the active/selected account for every provider, and ` (~/.claude)` to the claude default record. `--names` stays bare.
- Wrapper: `claude()` reads `.current`; a valid record → `command agentic run claude <name> -- "$@"` (env logic stays in lib); none/missing → unset the four variables and `command claude "$@"`.
- `rm` prompt for a default record: `forget account '<name>'? ~/.claude and its login are kept [y/N]`.

## Task 1: failed first login removes the new account (all providers)

- Test (`test/switch.bats`): `login codex fresh` with `FAKE_LOGIN_FAIL=1` → exit 1, output has `was not created`, `$AGENTIC_DIR/codex/fresh` absent. `relogin codex work` failing → dir kept, `was not changed`. Cursor `FAKE_LOGIN_FAIL=write` new account → dir absent.
- Code: `cmd_login` captures `created` before `ensure_account_dir`; `live_login <provider> <name> <created>`; `live_login_failed` removes the account dir when created=1.

## Task 2: provider facts + env application

- Test (`test/provider.bats`): `load_provider claude` → `provider_switch_mode` = env; codex → link.
- Code: defaults in `load_provider`; `provider_apply_env <name>` (unset list, capture env or die, export); `provider_with_env` and `cmd_run` use it; `provider_login`/`provider_status`/`provider_logout` read the args facts. Seams allowlist extended.

## Task 3: claude provider + env-mode verbs

- Fake CLI: `auth login|status|logout` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.fake-login`; logout appends to `$FAKE_LOG` when set. `env-dump.sh` prints `CLAUDE_CONFIG_DIR` and `ANTHROPIC_API_KEY`.
- Tests (`test/claude.bats`): spec "Tests" list + Review Focus 1–4 + `which` fallbacks + login never writes `.current` + `--existing` refused for codex.
- Code: `providers/claude.sh`; `env_login`, `env_switch`, `env_detach`, `env_selected` in `lib/switch.sh`; `cmd_login --existing`, `cmd_which`, `cmd_check`, `cmd_list`, `cmd_repair`, `cmd_rm` prompt in `bin/agentic`; `--existing` in the command table; `PROVIDER_LIST` gains claude; seams guard for credentials.

## Task 4: wrapper + docs

- Tests (`test/shell-init.bats`): wrapper uses `.current`; no `.current` → default; missing record → warning + default; `claude auth login` not blocked.
- README: Claude section, shell integration line, owed manual check.
