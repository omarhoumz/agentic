# agentic Deepening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the cursor second-login credential clobber, then deepen the live-auth module, the provider interface, the command surface and rc-file editing.

**Architecture:** `lib/switch.sh` becomes the only module that touches live auth. Providers shrink to declared facts that `lib/provider.sh` turns into paths, env and invocations. A command table in `lib/commands.sh` drives usage, dispatch, parsing and completion. Shell-profile editing moves to `lib/rc.sh`.

**Tech Stack:** bash 3.2+, bats-core, shellcheck, GitHub Actions.

**Execution (decided 2026-11-05):** Task 1 is implemented inline on branch `fix/cursor-login-clobber`, PR to `main`; Omar merges; tag `v0.1.2` only on Omar's go. Tasks 2–6 run subagent-driven on a separate branch cut from the merged `main`.

**Spec:** `docs/superpowers/specs/2026-11-05-agentic-deepening-design.md` (decisions), `docs/superpowers/specs/2026-09-07-agentic-accounts-design.md` (original model).

## Global Constraints

- bash 3.2: no associative arrays, no `${var,,}`, no `readlink -f`.
- Every task ends green on both:
  - `bats test/` → no `not ok` lines
  - `shellcheck -x -P bin:.:providers:lib bin/agentic lib/*.sh providers/*.sh shell/agentic.sh install.sh completions/agentic.bash` → no output
- Tests run through `$AGENTIC` (the binary) unless the task says otherwise; scratch `HOME` via `test/helper.bash`.
- Any test that relies on adopt's mtime rule sets the older file with `touch -t 200001010000`. Never `sleep`.
- Rewritten functions use `local`. Untouched functions keep their `_xx_` prefixes.
- Commit after each task; conventional prefixes (`fix:`, `refactor:`, `test:`).

## Review Focus

1. A regular (foreign) `~/.cursor/auth.json` already exists before `login cursor`. Expect it to be adopted into the active account or backed up, never silently overwritten. → Task 1
2. Cursor login fails after the live symlink was removed. Expect the previously active account to be linked again. → Task 2
3. `use` while live auth is a regular file, without `--force`. Expect a refusal naming `repair` and no state change. → Task 2
4. `use codex` while codex is running. Expect a refusal with the pid. → Task 3
5. A live symlink that points outside `~/.agentic`. Expect its target's content to be backed up before it is replaced. → Task 2
6. `restore` with no backup. Expect a non-zero exit with "no backup" and live auth untouched. → Task 2

---

### Task 1: Fix the cursor second-login clobber

**Files:**

- Modify: `test/fixtures/fake-cli.sh` (cursor and codex login write `{"token":"${FAKE_TOKEN:-x}"}`)
- Modify: `lib/switch.sh` (`activate_account`)
- Modify: `bin/agentic:111-141` (`cmd_login`)
- Modify: `test/clean-env.sh:33` (match `^agentic [0-9]+\.[0-9]+\.[0-9]+$` instead of `0.1.0`)
- Test: `test/cursor.bats`

**Interfaces:**

- Produces: `activate_account <provider> <name> [fresh]`. Pass the literal `fresh` to skip `backup_live_auth` and `adopt_live_auth`. Task 2 replaces this function.

- [ ] **Step 1: Write the failing tests** in `test/cursor.bats`:

```bash
@test "second cursor login does not overwrite the active account" {
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME"
  FAKE_TOKEN=AAA run "$AGENTIC" login cursor work
  [ "$status" -eq 0 ]
  touch -t 200001010000 "$AGENTIC_DIR/cursor/work/auth.json"

  FAKE_TOKEN=BBB run "$AGENTIC" login cursor personal

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/cursor/work/auth.json")" = '{"token":"AAA"}' ]
  [ "$(cat "$AGENTIC_DIR/cursor/personal/auth.json")" = '{"token":"BBB"}' ]
  [ "$(resolve_path "$AGENTIC_CURSOR_LIVE_HOME/auth.json")" = "$(resolve_path "$AGENTIC_DIR/cursor/personal/auth.json")" ]
}

@test "cursor login preserves a pre-existing regular live auth" {
  # active account 'work' with old auth; live replaced by a bare login
  export AGENTIC_CURSOR_BIN="$BATS_TEST_DIRNAME/fixtures/fake-cli.sh"
  export AGENTIC_CURSOR_LIVE_HOME="$AGENTIC_DIR/live-cursor"
  mkdir -p "$AGENTIC_CURSOR_LIVE_HOME" "$AGENTIC_DIR/cursor/work"
  printf '{"token":"old"}\n' > "$AGENTIC_DIR/cursor/work/auth.json"
  touch -t 200001010000 "$AGENTIC_DIR/cursor/work/auth.json"
  printf 'work\n' > "$AGENTIC_DIR/cursor/.current"
  printf '{"token":"bare"}\n' > "$AGENTIC_CURSOR_LIVE_HOME/auth.json"

  FAKE_TOKEN=NEW run "$AGENTIC" login cursor personal

  [ "$status" -eq 0 ]
  [ "$(cat "$AGENTIC_DIR/cursor/work/auth.json")" = '{"token":"bare"}' ]
  [ "$(cat "$AGENTIC_DIR/cursor/personal/auth.json")" = '{"token":"NEW"}' ]
}
```

- [ ] **Step 2: Run them and confirm they fail on current source**

Run: `bats test/cursor.bats`
Expected: test 1 is `not ok` because `work/auth.json` contains `BBB`. Test 2 is `not ok` because `work/auth.json` contains `old`: the bare token is overwritten by the login and is never adopted.

- [ ] **Step 3: Implement**

In `cmd_login`, before `provider_login`, call `backup_live_auth` and then `adopt_live_auth "$_cl_provider"`. This reconciles the pre-existing live state. After the login, call `activate_account "$_cl_provider" "$_cl_name" fresh`. In `activate_account`, skip backup and adopt when `$3 = fresh`.

- [ ] **Step 4: Run the full suite and shellcheck.** Both stay green. Then run `bash test/clean-env.sh` if Docker is available; otherwise note that it was skipped.

- [ ] **Step 5: Bump the version.** Set `AGENTIC_VERSION="0.1.2"` in `lib/common.sh`. `release.yml` checks that it matches the tag.

- [ ] **Step 6: Commit** `fix(login): stop second cursor login overwriting the active account`

- [ ] **Step 7: Open a PR to `main`.** Wait for CI to go green (shellcheck plus bats on ubuntu and macos). Omar merges it. After the merge, and only on Omar's go, run `git tag v0.1.2 && git push origin v0.1.2`.

---

### Task 2: Deepen the live-auth module

**Files:**

- Modify: `lib/switch.sh` (rewrite)
- Modify: `bin/agentic`:
  - `cmd_login`, `cmd_use`, `repair_provider`/`cmd_repair`, `cmd_rm` and `cmd_restore` delegate to the module.
  - Delete `repair_provider`.
- Modify: `providers/cursor.sh` (`provider_login` stops touching the live path; it only runs the CLI)
- Create: `test/seams.bats`
- Test: `test/switch.bats` (new; drives verbs through `$AGENTIC`)

**Interfaces:**

- Consumes: provider functions as today (`provider_live_auth`, `provider_auth_artifact`, `provider_login`, the optional `provider_is_running`/`provider_running_pids`/`link_shared_config`). Cursor still needs a harvest step. Until Task 3 lands, expose it as `provider_login_writes_live() { return 0; }` in `providers/cursor.sh`. In `load_provider`, define a default `return 1` version before sourcing.
- Produces (all `die` on error; the provider must already be loaded):
  - `live_login <provider> <name>`: reconcile, run `provider_login <name>`, then harvest if `provider_login_writes_live`, then link and `set_active`. If the login fails, re-link the previous active account, then `die "login failed - '<name>' was not changed"`.
  - `live_switch <provider> <name> <force>`: `force` is `0|1`. The refusal messages are unchanged from the current `cmd_use`.
  - `live_repair <provider>`: behaviour of the current `repair_provider`.
  - `live_detach <provider> <name>`: no-op unless `<name>` is active. Otherwise back up, remove the link and `clear_active`.
  - `live_restore <provider>`: dies `"no backup at <path>.bak"` when the backup is absent.
  - Internal: `live_state` prints `absent|linked|foreign-link|regular`, with the definitions in spec decision 1. Also internal: `backup_live_auth` (it now also backs up a foreign link's target content) and `adopt_live_auth <provider>`. `activate_account` is deleted.

- [ ] **Step 1: Write the failing tests** in `test/switch.bats`, through `$AGENTIC`:
  - `"failed cursor login re-links the previous account"`: active `work` is linked. The fake CLI exits 1 on login when `FAKE_LOGIN_FAIL=1` (add this to the fixture). Assert status ≠ 0, live resolves to `cursor/work/auth.json`, `which cursor` = `work`.
  - `"use refuses when live auth is a regular file"`: active `work`, live is a regular file. `use codex personal` → status 1, output contains `repair it first`. Live is still a regular file and `.current` = `work`.
  - `"restore without a backup fails and leaves live auth alone"`: live is a regular file with `{"token":"keep"}`. `restore codex` → status 1, output contains `no backup`, file content unchanged.
  - `"rm of the active account backs up and unlinks live auth"`: `rm codex work --yes` → `live.bak` exists with work's token, no live link, `which codex` reports no active account.
  - `"use backs up a foreign live symlink before replacing it"`: live is a symlink to `$BATS_TEST_TMPDIR/dotfiles/auth.json`, which contains `{"token":"mine"}`. `use codex work` → status 0, `live.bak` contains `mine`, output contains `replaced a symlink to`, and live resolves to `codex/work/auth.json`.
  - `"use replaces a broken live symlink with a warning"`: live is a symlink to a missing path. `use codex work` → status 0, output contains `replaced a broken symlink`, live resolves to `codex/work/auth.json`.

  And in `test/seams.bats`:

```bash
@test "only lib/ touches the live auth path" {
  run grep -nE 'provider_live_auth|\.bak|ln -s' "$REPO_ROOT/bin/agentic"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run them.** Expected: the failed-login test is `not ok` (live is left unlinked), and the seam test is `not ok` (it lists `bin/agentic` lines). Then check the other three. Any that pass on current source are characterization tests and are kept only because Step 3 rewrites the code they cover. Say so in the commit body.

- [ ] **Step 3: Implement the module per the Interfaces block.**
  - Move the backup and harden logic out of `cmd_rm`/`cmd_restore`.
  - Cursor's `provider_login` becomes `env CURSOR_CONFIG_DIR=… AGENT_CLI_CREDENTIAL_STORE=file "$(provider_cli_bin)" login`.
  - The symlink removal and the copy into the account move into `live_login`'s harvest.
  - Error text that says `auth.json` uses `$(basename "$(provider_auth_artifact "$name")")`.

- [ ] **Step 4: Full suite and shellcheck green.** Both are required, including the existing `repair.bats` and `cursor.bats`.

- [ ] **Step 5: Ratchet note.** Write the memory file `/Users/omarh/.claude/projects/-Users-omarh-git-agentic/memory/project_live_auth_seam.md`, and add a pointer to it in `MEMORY.md`:
  - **Fact:** live-auth bugs recurred 4× (43ec6c3, 2354d80, 4cd7f50, cursor clobber) wherever live-auth logic sat outside `lib/switch.sh`.
  - **Guard:** `test/seams.bats`, run by the CI `bats` job.

- [ ] **Step 6: Commit** `refactor(switch): one module owns live auth transitions`

---

### Task 3: Shrink the provider interface

**Files:**

- Modify: `lib/provider.sh`, `providers/codex.sh`, `providers/cursor.sh`, `lib/switch.sh` (drop `command -v` probes), `bin/agentic` (`cmd_check`, `cmd_run`, `cmd_repair:266`)
- Modify: `test/provider.bats` (replace the `unset` test), `test/seams.bats`
- Modify: `docs/superpowers/specs/2026-09-07-agentic-accounts-design.md` provider-contract table → point to the new spec
- Create: `test/fixtures/bin/pgrep` (prints `4242` and exits 0)

**Interfaces:**

- Consumes: the `live_*` functions from Task 2.
- Produces, in `lib/provider.sh` (shared; defined once):
  - Path functions:
    - `provider_account_home <name>` → `$AGENTIC_DIR/<provider>/<name>`
    - `provider_auth_artifact <name>` → `<account_home>/auth.json`
    - `provider_live_auth` → `$(provider_live_home)/auth.json`
  - `provider_with_env <name> <cmd...>`: runs `cmd` in a subshell, with every line of `provider_account_env <account_home>` exported.
  - `provider_run_env <name>`: prints the `provider_account_env` lines.
  - `provider_login <name>` and `provider_status <name>`: run `provider_with_env` with `"$(provider_cli_bin)" login` and `… login status`.
  - Running checks: `provider_is_running` and `provider_running_pids`. Both use `pgrep -x "$(provider_process_name)"`. They return 1 or print nothing when the name is empty.
  - `link_shared_config <name>`: symlinks each file from `provider_shared_config_files` that exists in the live home into the account home. Existing account copies are left alone.
- A provider file defines exactly:
  - Required: `provider_live_home`, `provider_cli_bin`, `provider_account_env <home>`
  - Optional fact overrides: `provider_login_writes_live`, `provider_process_name`, `provider_shared_config_files`, `provider_status_needs_active`
- `load_provider <provider>`:
  1. Unsets the 3 required functions.
  2. Redefines the 4 fact defaults: `return 1`, empty, empty, `return 1`.
  3. Sources the provider file.
  4. Dies with `"provider <p> does not define <fn>"` if a required function is missing.
- Codex facts: process name `codex`; shared config files `config.toml`.
- Cursor facts: `provider_login_writes_live` and `provider_status_needs_active` return 0.

- [ ] **Step 1: Write the failing tests:**
  - `test/codex.bats` → `"use refuses while codex is running"`: run with `PATH="$BATS_TEST_DIRNAME/fixtures/bin:$PATH"`. Two accounts. `use codex personal` → status 1, output contains `pid 4242`.
  - `test/cursor.bats` → `"deep check of a non-active cursor account is refused"`: `work` is active and `personal` exists. `check cursor personal --deep` → status 1, output contains `only the active account` and `work`.
  - `test/provider.bats` → replace the third test with `"cursor loaded after codex reports no running process"`. Use the same fake `pgrep` on `PATH`. Run `load_provider codex`, then `load_provider cursor`, then `run provider_is_running`, and assert status 1.
  - `test/seams.bats`: extend the grep to `providers/` with the pattern `ln -s|\.bak|cp |rm -f` (status 1).

- [ ] **Step 2: Run them.** Expected `not ok`:
  - the deep-check test: cursor checks the live account and passes;
  - the provider test: codex's `provider_is_running` is inherited;
  - the seams test: `providers/codex.sh` has `ln -s`.

  The running test may already pass. Keep it as Review Focus 4 coverage.

- [ ] **Step 3: Implement per the Interfaces block.**
  - `cmd_check --deep`: when `provider_status_needs_active` holds and `<name>` ≠ the active account, die with `"<provider> deep check works only on the active account ('<active>'); run 'agentic use <provider> <name>' first"`.
  - `cmd_run`: `exec` via the exported `provider_run_env` lines, as today.
  - `cmd_repair`: replace `codex|cursor)` with `validate_provider`.

- [ ] **Step 4: Full suite and shellcheck green.**
- [ ] **Step 5: Commit** `refactor(provider): providers declare facts; shared code derives the rest`

---

### Task 4: One command table

**Files:**

- Create: `lib/commands.sh`
- Modify: `bin/agentic` (usage, dispatch, the 5 argument preambles; `cmd_relogin` keeps its `--force` forwarding)
- Modify: `completions/agentic.bash`, `completions/_agentic` (thin shims over `agentic __complete`)
- Test: `test/complete.bats` (new)

**Interfaces:**

- `lib/commands.sh` defines `COMMAND_TABLE`, a heredoc with one line per verb in the format `verb|args|flags|summary`.
  - `flags` is space-separated. A flag that takes a value carries a `=FILE` suffix (`--rc=FILE`).
  - Every row, verbatim from the current usage text:
    - `login|<provider> <name>|--force|Sign in and save an account`
    - `relogin|<provider> <name>||Sign in again to an account`
    - `use|<provider> <name>|--force|Make an account active`
    - `run|<provider> <name> [--] <args...>||Run a CLI with an account`
    - `which|<provider>||Print the active account`
    - `list|[<provider>]|--names|List saved accounts`
    - `check|<provider> <name>|--deep|Check account credentials`
    - `repair|[<provider>]||Repair replaced live auth`
    - `rm|<provider> <name>|--yes|Delete an account`
    - `restore|<provider>||Restore backed-up live auth`
    - `migrate|||Copy codex-accounts data into agentic`
    - `shell-init||--remove --print --rc=FILE|Install shell wrappers`
- Functions:
  - `usage`: generates the COMMANDS block from the table. The header, global options and version lines stay as they are.
  - `command_exists <verb>` → 0/1.
  - `parse_account_args <verb> "$@"`:
    1. Requires `<provider> <name>`. Missing either → `die "usage: agentic <verb> <args> [flags]"`, built from the table row.
    2. Validates both.
    3. Sets `ARG_PROVIDER`, `ARG_NAME`, and `ARG_FLAGS` (space-padded, e.g. `" --force "`). `-y` is normalised to `--yes`.
    4. Sets `ARG_REST`, an indexed array (bash 3.2 has these) of the args left after an optional `--`; only `run` uses it.
    5. A flag that isn't in the row → `die "unknown option for <verb>: <flag>"`.
  - `has_flag <flag>` → 0/1 against `ARG_FLAGS`.
  - `complete_words <cword> <words...>` prints candidates as `value:description` lines:
    - `cword` 1: every verb and `--help`/`--version`, with summaries.
    - Position 2 of a verb whose args start with `<provider>` or `[<provider>]`: providers from `PROVIDER_LIST`.
    - Position 3 when args contain `<name>`: account names from `list_accounts`.
    - Later positions: the row's flags.
    - After `--rc`: the single line `__files__`.
- Dispatch: `bin/agentic` calls `command_exists`, then `cmd_$(printf %s "$verb" | tr - _)`. The hidden verb `__complete` calls `complete_words "$@"` and is absent from the table and from usage.
- Shims: bash strips `:description`; zsh feeds the lines to `_describe`. Both map `__files__` to file completion.

- [ ] **Step 1: Write the failing tests** in `test/complete.bats`:
  - `"__complete lists every verb"`: `run "$AGENTIC" __complete 1 ""`. For each verb in `login relogin use run which list check repair rm restore migrate shell-init`, assert `"$output" == *"$verb:"*`.
  - `"__complete offers providers then account names"`: create `codex/work`. `__complete 2 use ""` contains `codex:` and `cursor:`. `__complete 3 use codex ""` contains `work`.
  - `"__complete offers per-verb flags"`: `__complete 4 check codex work ""` contains `--deep`.
  - `"help lists every table verb"`: `run "$AGENTIC" --help`. The output contains each summary string from the table.
  - `"bash completion shim loads"`: `run bash -c "source '$REPO_ROOT/completions/agentic.bash' && complete -p agentic"` → status 0.
  - `"zsh completion shim loads"`: `command -v zsh || skip`. Then `run zsh -c "fpath=('$REPO_ROOT/completions' \$fpath); autoload -Uz compinit && compinit -u && autoload -Uz _agentic && whence -w _agentic"` → status 0.
  - `"unknown flag is rejected per verb"`: `use codex work --deep` → status 1, contains `unknown option for use: --deep`.
- [ ] **Step 2: Run them.** Expected `not ok` for the three `__complete` tests (`unknown command: __complete`). The rest may already pass. They pin current behaviour across the rewrite.
- [ ] **Step 3: Implement per the Interfaces block.** Delete the hardcoded verb, provider and flag lists from both completion files.
- [ ] **Step 4: Full suite and shellcheck green.** `completions/agentic.bash` is already in the shellcheck list. Diff `agentic --help` against the pre-change output. Only whitespace alignment may differ.
- [ ] **Step 5: Commit** `refactor(cli): one command table drives usage, parsing and completion`

---

### Task 5: Move rc-file editing to `lib/rc.sh`

**Files:**

- Create: `lib/rc.sh`
- Modify: `bin/agentic:368-508` (keeps only `cmd_shell_init`), source list
- Test: `test/shell-init.bats` (unchanged)

**Interfaces:**

- Produces:
  - `rc_install <rcfile> <snippet>` (the current `rc_add_integration` with the snippet passed in).
  - `rc_remove <rcfile>`.
  - `default_rcfile`.
  - The marker constants, path ownership and write-target helpers become private to `lib/rc.sh`.
- `cmd_shell_init` parses flags through Task 4's table and calls `rc_install`/`rc_remove`.

- [ ] **Step 1: Run `bats test/shell-init.bats`.** It is the safety net and must be green before the move.
- [ ] **Step 2: Move the code.** No behaviour change, no new tests: this is a pure move, and shell-init.bats already covers it through the binary.
- [ ] **Step 3: Full suite and shellcheck green.** `lib/*.sh` already covers the new file.
- [ ] **Step 4: Commit** `refactor(shell-init): move rc-file editing to lib/rc.sh`

---

### Task 6: Docs and release notes

**Files:** `README.md` (cursor `check --deep` limit in the Cursor section), `documentation/manual-smoke-test.md` (add the two-account cursor login check)

- [ ] **Step 1: Edit both files.** Add one sentence each. Don't change anything else.
- [ ] **Step 2: Commit** `docs: note cursor deep-check limit and two-account smoke step`
