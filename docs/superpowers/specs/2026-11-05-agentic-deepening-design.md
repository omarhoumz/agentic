# agentic deepening — design

Date: 2026-11-05. Follows the architecture review of v0.1.1. Builds on
`2026-09-07-agentic-accounts-design.md`; where they disagree, this file wins.

## Bug: second cursor login clobbers the active account

Reproduced:

```text
TOKEN=AAA agentic login cursor work
TOKEN=BBB agentic login cursor personal
work/auth.json     -> {"token":"BBB"}   # wrong
personal/auth.json -> {"token":"BBB"}
```

Cursor `provider_login` leaves a fresh regular `~/.cursor/auth.json`.
`activate_account` then runs `adopt_live_auth`, which reads any regular live
file newer than the active account's auth as "the user replaced live auth" and
copies it into the active account (`work`). Login and adopt give one state two
meanings.

**Fix rule:** reconcile live auth _before_ the provider's login (so a
pre-existing foreign file is adopted or backed up exactly as `use` would), then
treat whatever the login produces as belonging to the account being logged in.
The post-login link step never adopts.

## Decisions

1. **Live-auth module (`lib/switch.sh`) owns every transition of the live auth
   path.** Interface:
   - `live_login <provider> <name>` — reconcile → provider login → harvest
     (if the provider writes live) → link → mark active. On login failure,
     re-link the previously active account.
   - `live_switch <provider> <name> <force>` — refusal checks (live is a
     regular file; provider running) unless `force=1`, then reconcile → link.
   - `live_repair <provider>`
   - `live_detach <provider> <name>` — used by `rm` when the account is active.
   - `live_restore <provider>`
   - Internal: `live_state` → `absent | linked | foreign-link | regular`.
     `linked` = symlink resolving into `$AGENTIC_DIR/<provider>/`;
     `foreign-link` = any other symlink. Before replacing a foreign link, copy
     its target's content to `auth.json.bak` and warn
     `replaced a symlink to <target>`. A dangling foreign link is replaced with
     the warning `replaced a broken symlink to <target>` and no backup.
   - The mtime rule in adopt stays for `use`/`repair`/the pre-login reconcile:
     a regular live file is adopted into the active account only when newer.
   - Invariant, enforced by a test in CI: nothing outside `lib/` names the
     live auth path or writes `.bak` files.
2. **Provider interface shrinks to declared facts.** A provider file defines
   `provider_live_home`, `provider_cli_bin`, `provider_account_env <home>`
   (KEY=value lines), and optionally overrides fact functions whose defaults
   `load_provider` defines before every source:
   `provider_login_writes_live` (default false), `provider_process_name`
   (default empty), `provider_shared_config_files` (default empty),
   `provider_status_needs_active` (default false). Paths, env application,
   login/status/run invocation, running checks and shared-config links are
   shared code. This replaces the 6-row contract table in the 2026-09-07 spec.
3. **Cursor `check --deep` on a non-active account is impossible** (the Agent
   CLI only reads `~/.cursor/auth.json`). It dies with a message naming the
   active account instead of silently checking it.
4. **One command table** (`lib/commands.sh`) drives usage, dispatch, flag
   parsing and a hidden `__complete` verb; both completion files call it.
   Bash 3.2 has no tuples, so `parse_account_args` sets globals
   `ARG_PROVIDER`, `ARG_NAME`, `ARG_FLAGS`, `ARG_REST`.
5. **rc-file editing moves to `lib/rc.sh`** unchanged in behaviour.
6. Rewritten functions use `local`; untouched functions keep `_xx_` prefixes.
7. Out of scope: `shell/agentic.sh` wrappers, `lib/migrate.sh` (codex-only by
   nature), IDE accounts, codex-accounts shims.

## Constraints

- bash 3.2 floor: no associative arrays, no `${var,,}`, no `readlink -f`.
- CI lint: `shellcheck -x -P bin:.:providers:lib bin/agentic lib/*.sh providers/*.sh shell/agentic.sh install.sh completions/agentic.bash`
- No user-visible change to existing command output except the cursor
  `check --deep` refusal and new error text naming the artifact file.
