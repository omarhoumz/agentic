# Agentic Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `agentic`, a multi-provider CLI account manager for Codex and Cursor Agent CLI, with migrate-from-`codex-accounts` and dual shell-init, matching `docs/superpowers/specs/2026-09-07-agentic-accounts-design.md`.

**Architecture:** Shared bash verbs (`login|use|run|…`) dispatch to provider scripts that satisfy a small contract (`live_home`, `account_home`, `run_env`, `login`, `status`, `auth_artifact`, `cli_bin`). Store lives at `~/.agentic/<provider>/<account>/`. Codex ports `CODEX_HOME`/`auth.json` symlink switching; Cursor uses `CURSOR_CONFIG_DIR` + `AGENT_CLI_CREDENTIAL_STORE=file`.

**Tech Stack:** Bash 3.2+ (macOS), bats-core tests, shellcheck, optional `jq`, Homebrew/install.sh later.

**Spec:** `docs/superpowers/specs/2026-09-07-agentic-accounts-design.md`

## Global Constraints

- Bash 3.2 compatible (no associative arrays, no `${var,,}`, no `readlink -f`).
- Account names: letters, digits, `-`, `_` only; no leading `-`.
- Providers in v1: exactly `codex` and `cursor`.
- CLI shape: `agentic <verb> <provider> <name> …` (provider before name).
- Cursor always sets `AGENT_CLI_CREDENTIAL_STORE=file` for managed operations.
- Store root: `AGENTIC_DIR` (default `$HOME/.agentic`), overridable for tests.
- Port patterns from `/Users/omarh/git/codex-accounts` rather than inventing new switch/repair semantics for Codex.
- Do not implement `codex-accounts` shims in this plan (phase 2); document deprecation mapping in README only.
- IDE / `--user-data-dir` out of scope.

---

## File structure

```text
agentic/
  bin/agentic                 # single entry: parse verb, dispatch
  lib/common.sh               # version, colours, die/info, paths, validate
  lib/store.sh                # account dirs, markers, list/which helpers
  lib/switch.sh               # symlink activate, backup, repair primitives
  providers/codex.sh          # Codex contract implementation
  providers/cursor.sh         # Cursor Agent CLI contract implementation
  shell/agentic.sh            # shell-init sourceable wrappers
  completions/_agentic        # zsh
  completions/agentic.bash    # bash
  install.sh
  test/helper.bash
  test/clean-env.sh
  test/common.bats
  test/store.bats
  test/codex.bats
  test/cursor.bats
  test/migrate.bats
  test/shell-init.bats
  test/fixtures/fake-cli.sh   # stub login/status for provider tests
  README.md
  LICENSE
  .gitignore
  .github/workflows/ci.yml
```

Reference implementation to port from: `/Users/omarh/git/codex-accounts` (`lib/common.sh`, `bin/codex-switch`, `bin/codex-run`, `shell/codex-accounts.sh`, `test/*.bats`).

---

### Task 1: Repo scaffold + common helpers

**Files:**
- Create: `bin/agentic`, `lib/common.sh`, `test/helper.bash`, `test/clean-env.sh`, `test/common.bats`, `.gitignore`, `LICENSE`
- Test: `test/common.bats`

**Interfaces:**
- Produces: `AGENTIC_VERSION`, `AGENTIC_DIR`, `die`, `info`, `warn`, `validate_name`, `validate_provider`, `resolve_path`, `print_version`, `PROVIDER_LIST="codex cursor"`

- [ ] **Step 1: Init git repo and ignore noise**

```bash
cd /Users/omarh/git/agentic
git init
printf '%s\n' '.DS_Store' '*.bak' '/tmp/' > .gitignore
```

- [ ] **Step 2: Write failing tests for validation helpers**

Create `test/helper.bash` that sets `AGENTIC_DIR` to a temp dir and sources `lib/common.sh`. Create `test/common.bats`:

```bash
#!/usr/bin/env bats
load helper

@test "validate_name rejects slash" {
  run bash -c 'source lib/common.sh; validate_name "a/b"'
  [ "$status" -ne 0 ]
}

@test "validate_provider accepts codex and cursor" {
  run bash -c 'source lib/common.sh; validate_provider codex; validate_provider cursor'
  [ "$status" -eq 0 ]
}

@test "validate_provider rejects unknown" {
  run bash -c 'source lib/common.sh; validate_provider claude'
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 3: Run tests — expect fail (missing lib)**

Run: `cd /Users/omarh/git/agentic && bats test/common.bats`  
Expected: FAIL (cannot source `lib/common.sh` or functions undefined)

- [ ] **Step 4: Implement `lib/common.sh` and stub `bin/agentic`**

`lib/common.sh`: version `0.1.0`, `AGENTIC_DIR` default `$HOME/.agentic`, colour/`die`/`info`/`warn` as in codex-accounts, `validate_name` (same charset rules), `validate_provider` checking against `codex|cursor`, `resolve_path` (symlink walk), `print_version` printing `agentic 0.1.0`.

`bin/agentic`: shebang, resolve self → root, source `lib/common.sh`, `--help`/`--version` only for now; unknown verb → `die`.

- [ ] **Step 5: Re-run tests — expect pass**

Run: `bats test/common.bats`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add bin/agentic lib/common.sh test/helper.bash test/common.bats .gitignore
git commit -m "$(cat <<'EOF'
feat: scaffold agentic with shared validation helpers

EOF
)"
```

---

### Task 2: Store layout + markers

**Files:**
- Create: `lib/store.sh`, `test/store.bats`
- Modify: `bin/agentic` (wire `list` / `which` stubs that call store)

**Interfaces:**
- Consumes: `AGENTIC_DIR`, `validate_name`, `validate_provider`, `die` from `lib/common.sh`
- Produces:
  - `provider_dir(provider) -> path`
  - `account_dir(provider, name) -> path`
  - `ensure_account_dir(provider, name)`
  - `list_accounts(provider) -> names newline-separated`
  - `set_active(provider, name)` / `get_active(provider) -> name or empty`
  - Marker file: `$AGENTIC_DIR/<provider>/.current` containing the account name

- [ ] **Step 1: Write failing store tests**

```bash
#!/usr/bin/env bats
load helper

@test "account_dir nests under provider" {
  source lib/common.sh
  source lib/store.sh
  [ "$(account_dir codex work)" = "$AGENTIC_DIR/codex/work" ]
}

@test "set_active and get_active round-trip" {
  source lib/common.sh
  source lib/store.sh
  mkdir -p "$(account_dir cursor personal)"
  set_active cursor personal
  [ "$(get_active cursor)" = "personal" ]
}

@test "list_accounts returns only directories" {
  source lib/common.sh
  source lib/store.sh
  mkdir -p "$(account_dir codex a)" "$(account_dir codex b)"
  run list_accounts codex
  [ "$status" -eq 0 ]
  [[ "$output" == *a* ]]
  [[ "$output" == *b* ]]
}
```

- [ ] **Step 2: Run — expect fail**

Run: `bats test/store.bats`  
Expected: FAIL (missing `lib/store.sh`)

- [ ] **Step 3: Implement `lib/store.sh`**

Implement the functions above. `list_accounts` skips hidden entries (`.current`). `ensure_account_dir` creates `provider_dir` and account dir with `mkdir -p` and mode `700` on account dirs when creating.

- [ ] **Step 4: Wire `agentic list` and `agentic which`**

In `bin/agentic`:
- `list [<provider>]` — if provider omitted, print `codex:` / `cursor:` sections; if given, names only (or `--names` later).
- `which <provider>` — print active name or message that none is active (exit 0 with empty/clear text; non-zero only on bad provider).

- [ ] **Step 5: Run store + manual CLI smoke**

Run: `bats test/store.bats`  
Then: `AGENTIC_DIR=/tmp/agentic-t agentic which codex` (expect no active)  
Expected: bats PASS

- [ ] **Step 6: Commit**

```bash
git add lib/store.sh test/store.bats bin/agentic
git commit -m "$(cat <<'EOF'
feat: add per-provider account store and list/which

EOF
)"
```

---

### Task 3: Provider contract + dispatch

**Files:**
- Create: `lib/provider.sh`, `providers/codex.sh` (stub), `providers/cursor.sh` (stub), `test/fixtures/fake-cli.sh`, `test/provider.bats`
- Modify: `bin/agentic`, `lib/common.sh` (source provider loader)

**Interfaces:**
- Consumes: store helpers
- Produces: after `load_provider <name>`, these functions exist:
  - `provider_live_home` → path
  - `provider_account_home <name>` → path (delegates to `account_dir`)
  - `provider_auth_artifact <name>` → path to credential file inside account home
  - `provider_live_auth` → path to live credential file
  - `provider_run_env <name>` → prints `KEY=value` lines suitable for `eval`/`export`
  - `provider_cli_bin` → command name
  - `provider_login <name>` / `provider_status` → invoke underlying CLI (stubs may no-op in this task)
- `load_provider` sources `providers/<name>.sh` or dies

- [ ] **Step 1: Write failing dispatch test**

```bash
@test "load_provider codex defines provider_cli_bin" {
  source lib/common.sh
  source lib/store.sh
  source lib/provider.sh
  load_provider codex
  [ "$(provider_cli_bin)" = "codex" ]
}

@test "load_provider cursor defines run env keys" {
  source lib/common.sh
  source lib/store.sh
  source lib/provider.sh
  load_provider cursor
  run provider_run_env work
  [[ "$output" == *CURSOR_CONFIG_DIR=* ]]
  [[ "$output" == *AGENT_CLI_CREDENTIAL_STORE=file* ]]
}
```

- [ ] **Step 2: Run — expect fail**

Run: `bats test/provider.bats`  
Expected: FAIL

- [ ] **Step 3: Implement stubs**

`providers/codex.sh`: `CODEX_HOME`-style paths using `AGENTIC_DIR/codex/<name>` as account home; live home `${CODEX_HOME:-$HOME/.codex}` but when testing allow `AGENTIC_CODEX_LIVE_HOME`; auth artifact `auth.json`; `provider_run_env` prints `CODEX_HOME=...`; `provider_cli_bin` → `codex`.

`providers/cursor.sh`: live home `${AGENTIC_CURSOR_LIVE_HOME:-$HOME/.cursor}`; auth artifact `auth.json` under account home (file store); `provider_run_env` prints both required env vars; `provider_cli_bin` → `agent`.

`lib/provider.sh`: `load_provider` validates and sources file once.

- [ ] **Step 4: Re-run — expect pass**

Run: `bats test/provider.bats`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/provider.sh providers/ test/provider.bats test/fixtures/
git commit -m "$(cat <<'EOF'
feat: add provider load contract for codex and cursor

EOF
)"
```

---

### Task 4: Symlink switch primitives + Codex `use` / `login` / `run`

**Files:**
- Create: `lib/switch.sh`, `test/codex.bats`
- Modify: `providers/codex.sh`, `bin/agentic`
- Port logic from: `codex-accounts/lib/common.sh` (backup, activate symlink, running-session warn) and `bin/codex-switch` (`cmd_use`, `cmd_login`, `cmd_relogin`)

**Interfaces:**
- Consumes: provider + store
- Produces:
  - `backup_live_auth` — copy real (non-symlink) live auth to `.bak` + timestamped bak
  - `activate_account provider name` — symlink `provider_live_auth` → `provider_auth_artifact name`, `set_active`
  - `cmd` handlers: `login`, `relogin`, `use`, `run` for provider `codex`

Behaviour (Codex):
- `login`: `validate_*`, refuse if account exists unless `--force`, `ensure_account_dir`, run `CODEX_HOME=<account> codex login` (or `AGENTIC_CODEX_BIN`), then `activate_account`
- `use`: require account + auth file; backup live if regular file; symlink; set active; refuse if bare login already corrupted unless `--force`/`repair` path
- `run`: require account; eval `provider_run_env`; exec `provider_cli_bin` with remaining args (after optional `--`)

- [ ] **Step 1: Write failing Codex isolation tests using fake cli**

`test/fixtures/fake-cli.sh`: if `$1=login`, write `{"token":"x"}` to `$CODEX_HOME/auth.json` (or `$CURSOR_CONFIG_DIR/auth.json`); if `status|whoami`, print ok if auth exists.

```bash
@test "codex login then use symlinks live auth" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CODEX_LIVE_HOME="$AGENTIC_DIR/live-codex"
  mkdir -p "$AGENTIC_CODEX_LIVE_HOME"
  run bin/agentic login codex work
  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
  [ "$(bin/agentic which codex)" = "work" ]
}

@test "codex run exports CODEX_HOME" {
  export AGENTIC_CODEX_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  # after creating account with auth.json present...
  run bin/agentic run codex work -- status
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run — expect fail**

Run: `bats test/codex.bats`  
Expected: FAIL

- [ ] **Step 3: Implement switch + Codex verbs**

Implement `lib/switch.sh` and wire `login|relogin|use|run` in `bin/agentic` via `load_provider`. For login/status invocation, call `"${AGENTIC_CODEX_BIN:-codex}"` when provider is codex (provider script sets bin override env). Prefer putting the exec helper on the provider: `provider_exec login` / `provider_exec "$@"` for run.

- [ ] **Step 4: Run — expect pass**

Run: `bats test/codex.bats test/store.bats test/provider.bats`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/switch.sh providers/codex.sh bin/agentic test/codex.bats test/fixtures/fake-cli.sh
git commit -m "$(cat <<'EOF'
feat: implement codex login, use, and run with auth symlink switch

EOF
)"
```

---

### Task 5: Cursor provider `login` / `use` / `run`

**Files:**
- Modify: `providers/cursor.sh`, `bin/agentic` (generic verbs already; ensure cursor path works)
- Create: `test/cursor.bats`
- Spike note: confirm file credential path; default to `$CURSOR_CONFIG_DIR/auth.json` with `AGENT_CLI_CREDENTIAL_STORE=file`. If real CLI uses a different filename, update `provider_auth_artifact` only.

**Interfaces:**
- Same verb entrypoints as Task 4; cursor-specific env via `provider_run_env`
- Override bin: `AGENTIC_CURSOR_BIN` (default `agent`)
- Live home override: `AGENTIC_CURSOR_LIVE_HOME`

- [ ] **Step 1: Write failing cursor tests**

```bash
@test "cursor login writes auth under account home and activates" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME"
  run bin/agentic login cursor work
  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/cursor/work/auth.json" ]
  [ -L "$AGENTIC_CURSOR_LIVE_HOME/auth.json" ]
}

@test "cursor run sets CURSOR_CONFIG_DIR and file store" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/env-dump.sh"
  # env-dump.sh prints env and exits 0
  mkdir -p "$AGENTIC_DIR/cursor/work"
  echo '{}' > "$AGENTIC_DIR/cursor/work/auth.json"
  run bin/agentic run cursor work --
  [[ "$output" == *CURSOR_CONFIG_DIR="$AGENTIC_DIR/cursor/work"* ]] || [[ "$output" == *"cursor/work"* ]]
  [[ "$output" == *AGENT_CLI_CREDENTIAL_STORE=file* ]]
}
```

Create `test/fixtures/env-dump.sh` that prints `CURSOR_CONFIG_DIR` and `AGENT_CLI_CREDENTIAL_STORE`.

- [ ] **Step 2: Run — expect fail until cursor provider complete**

Run: `bats test/cursor.bats`  
Expected: FAIL or partial fail

- [ ] **Step 3: Complete cursor provider + shared activate path**

Ensure `provider_login` for cursor exports `CURSOR_CONFIG_DIR` + `AGENT_CLI_CREDENTIAL_STORE=file` then runs `"${AGENTIC_CURSOR_BIN:-agent}" login`. Reuse `activate_account` from `lib/switch.sh` so live `auth.json` is a symlink into the account home.

- [ ] **Step 4: Optional real-CLI smoke (manual, not CI)**

Document in `documentation/manual-smoke-test.md`:

```bash
agentic login cursor personal
agentic whoami   # via: agentic run cursor personal -- whoami
agent whoami     # after: agentic use cursor personal
```

- [ ] **Step 5: Run bats — expect pass**

Run: `bats test/cursor.bats test/codex.bats`  
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add providers/cursor.sh test/cursor.bats test/fixtures/env-dump.sh documentation/manual-smoke-test.md
git commit -m "$(cat <<'EOF'
feat: implement cursor agent login, use, and run isolation

EOF
)"
```

---

### Task 6: `migrate` from `~/.codex-accounts`

**Files:**
- Create: `lib/migrate.sh`, `test/migrate.bats`
- Modify: `bin/agentic`

**Interfaces:**
- Consumes: store
- Produces: `cmd_migrate`
  - Source: `${CODEX_ACCOUNTS_DIR:-$HOME/.codex-accounts}`
  - Dest: `$AGENTIC_DIR/codex`
  - Copy each account directory (not move) by default
  - Copy `.current` → `$AGENTIC_DIR/codex/.current` if present
  - Idempotent: if dest account exists with auth, skip; if migrate already done and nothing new, print "nothing to migrate"
  - Do not delete the old store
  - Do not touch cursor

- [ ] **Step 1: Write failing migrate test**

```bash
@test "migrate copies codex-accounts into agentic/codex" {
  old="$AGENTIC_DIR/old-codex-accounts"
  mkdir -p "$old/work"
  echo '{"t":1}' > "$old/work/auth.json"
  echo work > "$old/.current"
  export CODEX_ACCOUNTS_DIR="$old"
  run bin/agentic migrate
  [ "$status" -eq 0 ]
  [ -f "$AGENTIC_DIR/codex/work/auth.json" ]
  [ "$(get_active codex)" = "work" ] || [ "$(cat "$AGENTIC_DIR/codex/.current")" = "work" ]
}
```

- [ ] **Step 2: Run — expect fail**

Run: `bats test/migrate.bats`  
Expected: FAIL

- [ ] **Step 3: Implement migrate**

Implement copy loop with `cp -R`. After migrate, print next steps (`agentic use codex <name>`, `agentic shell-init`). If source missing, exit 0 with message (or exit 1 — prefer exit 1 with clear error so scripts notice).

- [ ] **Step 4: Run — expect pass**

Run: `bats test/migrate.bats`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/migrate.sh test/migrate.bats bin/agentic
git commit -m "$(cat <<'EOF'
feat: migrate ~/.codex-accounts into ~/.agentic/codex

EOF
)"
```

---

### Task 7: Remaining account verbs — `check`, `repair`, `rm`, `restore`

**Files:**
- Modify: `lib/switch.sh`, `bin/agentic`, `providers/codex.sh` (and cursor where applicable)
- Create: `test/repair.bats`
- Port from: `codex-accounts` `cmd_check`, `cmd_repair`, `cmd_rm`, `cmd_restore`

**Interfaces:**
- `check <provider> <name> [--deep]` — auth file present + parseable; `--deep` runs provider status
- `repair [<provider>]` — if live auth is a regular file while an account is marked active, move/re-file into the correct account or warn (Codex behaviour port); if provider omitted, run for both
- `rm <provider> <name> [--yes]` — delete account dir; if active, clear marker and leave live symlink broken only after warning — prefer detach symlink to backup first
- `restore <provider>` — restore `auth.json.bak` into live home

- [ ] **Step 1: Write failing repair/rm tests**

```bash
@test "repair refiles regular-file live auth into active account" {
  # setup: active work, but live auth is a regular file with new token
  ...
  run bin/agentic repair codex --yes
  [ "$status" -eq 0 ]
  [ -L "$AGENTIC_CODEX_LIVE_HOME/auth.json" ]
}
```

- [ ] **Step 2: Run — expect fail**

Run: `bats test/repair.bats`  
Expected: FAIL

- [ ] **Step 3: Port and implement verbs**

Keep Codex semantics; for Cursor use the same symlink model so repair applies.

- [ ] **Step 4: Run full unit suite**

Run: `bats test/`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/switch.sh bin/agentic test/repair.bats providers/
git commit -m "$(cat <<'EOF'
feat: add check, repair, rm, and restore for managed accounts

EOF
)"
```

---

### Task 8: Shell integration

**Files:**
- Create: `shell/agentic.sh`, `test/shell-init.bats`
- Modify: `bin/agentic` (`shell-init` subcommand)

**Interfaces:**
- `agentic shell-init` — append marked block to `~/.zshrc` or `~/.bashrc` (detect, allow `--rc FILE`)
- `agentic shell-init --print` — print path to `shell/agentic.sh`
- `agentic shell-init --remove` — remove marked block
- Sourced file defines `codex` and `agent` functions that intercept only `login`/`logout` (not `login status` for codex); if `AGENTIC_DIR` missing, pass through

- [ ] **Step 1: Write failing shell-init tests**

Port structure from `codex-accounts/test/shell-init.bats` and `shell-integration.bats`: temp rc file, install, assert markers, source wrappers, assert `codex login` fails with hint containing `agentic login`.

- [ ] **Step 2: Run — expect fail**

Run: `bats test/shell-init.bats`  
Expected: FAIL

- [ ] **Step 3: Implement `shell/agentic.sh` and `shell-init` command**

Marked block format:

```bash
# >>> agentic shell-init >>>
source "/absolute/path/to/shell/agentic.sh"
# <<< agentic shell-init <<<
```

Wrapper messages:
- `codex login` → `codex login is managed by agentic. Try: agentic login codex <name>`
- `agent login` → `agent login is managed by agentic. Try: agentic login cursor <name>`

- [ ] **Step 4: Run — expect pass**

Run: `bats test/shell-init.bats`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add shell/agentic.sh test/shell-init.bats bin/agentic
git commit -m "$(cat <<'EOF'
feat: add shell-init wrappers for codex and agent login

EOF
)"
```

---

### Task 9: Install, completions, CI, README

**Files:**
- Create: `install.sh`, `completions/_agentic`, `completions/agentic.bash`, `.github/workflows/ci.yml`, `README.md`
- Modify: `bin/agentic` (ensure `--help` lists all verbs)

**Interfaces:**
- `install.sh` symlinks `bin/agentic` into `~/.local/bin`; `--uninstall` removes link; never touches `~/.agentic`
- Completions: providers `codex cursor`; verbs from help; account names from `agentic list <provider> --names` if implemented (add `--names` to list if missing)
- CI: shellcheck + bats on ubuntu/macos if feasible
- README: install, migrate, examples for both providers, deprecation table mapping `codex-switch` → `agentic`, link to design spec, note IDE out of scope, note phase-2 shims not shipped yet

- [ ] **Step 1: Write install test (optional bats) or manual checklist in README**

- [ ] **Step 2: Implement install + completions + CI + README**

Help text must include every verb from the spec CLI surface.

Deprecation mapping in README:

| Old | New |
|---|---|
| `codex-switch use work` | `agentic use codex work` |
| `codex-run work …` | `agentic run codex work -- …` |
| `codex-accounts login work` | `agentic login codex work` |

- [ ] **Step 3: Run full suite + shellcheck**

```bash
shellcheck -x -P bin:.:providers:lib bin/agentic lib/*.sh providers/*.sh shell/agentic.sh
bats test/
```

Expected: PASS (shellcheck may need same disable patterns as codex-accounts)

- [ ] **Step 4: Commit**

```bash
git add install.sh completions/ .github/workflows/ci.yml README.md bin/agentic
git commit -m "$(cat <<'EOF'
docs: add install, completions, CI, and usage README

EOF
)"
```

---

### Task 10: Manual verification checklist (human)

**Files:** none (or update `documentation/manual-smoke-test.md`)

- [ ] **Step 1: Migrate real Codex accounts on a throwaway machine or after backup**

```bash
cp -R ~/.codex-accounts ~/.codex-accounts.bak
agentic migrate
agentic list codex
agentic use codex <name>
codex login status   # or equivalent
```

- [ ] **Step 2: Cursor account**

```bash
agentic login cursor personal
agentic run cursor personal -- whoami
agentic use cursor personal
agent whoami
```

- [ ] **Step 3: Shell-init**

```bash
agentic shell-init
# new shell
codex login    # must refuse
agent login    # must refuse
```

- [ ] **Step 4: Confirm IDE untouched** — opening Cursor.app still uses normal IDE login; no requirement that it follows `agentic use cursor`.

- [ ] **Step 5: Final commit if docs updated**

```bash
git add documentation/manual-smoke-test.md
git commit -m "$(cat <<'EOF'
docs: record manual smoke results and caveats

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|---|---|
| Per-provider pools + verb shape | 1–3 |
| `use` + `run` | 4–5 |
| Codex port behaviour | 4, 7 |
| Cursor CLI + file credential store | 5 |
| `migrate` from codex-accounts | 6 |
| Shell-init both CLIs | 8 |
| check/repair/rm/restore | 7 |
| Deprecation path documented | 9 (shims = later plan) |
| IDE non-goal | 9 README + Task 10 |
| Testing | each task + CI in 9 |

**Out of this plan (follow-up):** phase-2 `codex-accounts` exec shims + Homebrew tap formula; Cursor IDE profiles.

**Placeholder scan:** none intentional; Cursor auth filename defaulted to `auth.json` with explicit spike note in Task 5.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-07-agentic-accounts.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks  
2. **Inline Execution** — execute tasks in this session with checkpoints  

Which approach?
