# Claude Code provider — design

Dates: started 2026-11-05, updated 2026-11-09. Status: **approved by Omar 2026-11-09** ("no changes"). Plan: `docs/superpowers/plans/2026-11-09-claude-provider.md`.
Builds on `2026-11-05-agentic-deepening-design.md`, which defines the provider-facts interface and the `live_*` module.

## Intent

Omar has two Claude Code accounts: `work` (Remotepass Team plan) and `personal`. He wants:

- both running **at the same time in different terminals**;
- plain `claude` opening whichever account he last chose with `agentic use`, defaulting to work.

Scope is the Claude Code CLI only. The desktop app and IDE extensions are out of scope.

## Goals

- `agentic run claude <name> -- args` runs Claude with that account, in that terminal only.
- `agentic use claude <name>` sets the account plain `claude` opens. The default is `work`.
- `login`, `check`, `which`, `list` and `rm` work for Claude the way they do for codex and cursor.

## Non-goals

- Sharing setup between accounts. Each account has its own CLAUDE.md, rules, skills, plugins, agents, settings and history.
- Desktop or IDE accounts.
- Console (API-billing) logins. They are stored outside the config dir, in `~/.config/anthropic`, so two of them can't be separated.
- `repair` and `restore` for Claude. There is no live file to repair.

## Anti-goals (failure even if everything "works")

- Anything that logs Omar out of work or moves, renames or deletes `~/.claude`.
- agentic reading, copying, moving or symlinking a Claude credential: a Keychain item or a `.credentials.json`. Refresh tokens rotate, and a copy creates two holders of one token, which causes `invalid_grant` errors and forced re-logins.

## Decided by Omar

1. Concurrent use: both accounts run side by side.
2. Separate setups: nothing is shared or linked between accounts.
3. `work` is the existing `~/.claude`, left where it is.
4. Plain `claude` opens the `use`-selected account. The default is work, `use claude personal` switches to personal, and `use claude work` switches back.
5. `rm claude work` deletes only agentic's record. `~/.claude` is never touched.

## Facts (verified 2026-11-05 to 11-09 on Claude Code 2.1.318, macOS)

- **One config dir per account** is the documented multi-account pattern (`CLAUDE_CONFIG_DIR=<dir> claude`). See https://code.claude.com/docs/en/authentication.md#credential-management.
- **Credentials:**
  - macOS: Keychain, keyed to the config dir path. It falls back to `<dir>/.credentials.json` (mode 0600) if the Keychain write fails.
  - Linux: `<dir>/.credentials.json`.
- **Verified locally:**
  - With `CLAUDE_CONFIG_DIR` unset, status is logged in (Remotepass) and `configDirectory` is `/Users/omarh/.claude`.
  - Setting `CLAUDE_CONFIG_DIR` to `/Users/omarh/.claude`, `/Users/omarh/.claude/`, or a symlink to it shows `loggedIn: false`. Each spelling is a different Keychain key.
  - A fresh custom dir also shows `loggedIn: false`.
- **Where `.claude.json` lives:** `~/.claude.json` by default, and `$CLAUDE_CONFIG_DIR/.claude.json` when the variable is set. See https://code.claude.com/docs/en/claude-directory.md.
- **Commands:**
  - `claude auth login [--claudeai|--console|--sso|--email e]` and `claude auth logout`.
  - `claude auth status [--json|--text]` exits 0 when logged in and 1 when not. Its JSON has `loggedIn`, `authMethod`, `email`, `orgName`, `subscriptionType` and `configDirectory`.
  - See https://code.claude.com/docs/en/cli-reference.md.
- **Variables that override the stored login:** cloud-provider variables, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `apiKeyHelper` and `CLAUDE_CODE_OAUTH_TOKEN` all win over a `/login` OAuth session. See https://code.claude.com/docs/en/authentication.md.
- **Process:** the native binary is `~/.local/bin/claude`. Not needed: running sessions are unaffected by `use`, which changes only environment variables at launch.

## Design

### Account model

An account is a config dir, never a token.

| Account                | Config dir                          | How it launches                |
| ---------------------- | ----------------------------------- | ------------------------------ |
| default (`work`)       | `~/.claude`                         | `CLAUDE_CONFIG_DIR` **unset**  |
| any other (`personal`) | `$AGENTIC_DIR/claude/<name>/config` | `CLAUDE_CONFIG_DIR=<that dir>` |

- Every account has a record dir, `$AGENTIC_DIR/claude/<name>/`.
- A default account's record holds a marker file, `default-dir`. Its presence means "launch with the variable unset; the config is `~/.claude`". At most one account may carry it.
- The config dir is never moved after creation, because moving it changes the Keychain key.
- Every Claude launch through agentic unsets `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN`, so they can't silently override the account. Cloud-provider variables (`CLAUDE_CODE_USE_BEDROCK` and similar) are left alone. [my call]

### Verbs

| Verb                              | Claude behaviour                                                                                                                                                                                                                                                                                    |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `login claude <name>`             | Create the record and config dir, then run `claude auth login` with that account's env. Exactly what was written to `~/.agentic/claude/<name>/` and the Keychain stays where Claude put it.                                                                                                         |
| `login claude <name> --existing`  | Register `~/.claude` as `<name>` (writes `default-dir`). Runs `claude auth login` with the variable unset only if `claude auth status` reports logged out. Refuses if another account already holds `default-dir`. [my call: flag name and behaviour]                                               |
| `relogin claude <name>`           | `claude auth login` with that account's env.                                                                                                                                                                                                                                                        |
| `run claude <name> [--] args`     | `exec claude args` with that account's env.                                                                                                                                                                                                                                                         |
| `use claude <name>`               | Write `.current`. No refusal checks: nothing is linked, and running sessions are unaffected.                                                                                                                                                                                                        |
| `which claude`                    | Print `.current`, or the default account when `.current` is absent.                                                                                                                                                                                                                                 |
| `list claude`                     | List accounts and mark the default one.                                                                                                                                                                                                                                                             |
| `check claude <name> [--deep]`    | `claude auth status --json` with that account's env. Print logged in or out, email, org and plan. `--deep` is the same check: status already reflects the stored login. [my call]                                                                                                                   |
| `rm claude <name>`                | Default account: delete the record only. Other accounts: best-effort `claude auth logout` with that env, so the Keychain entry isn't orphaned, then delete the record and config dir. If `.current` named it, clear it so plain `claude` falls back to the default. [my call: logout before delete] |
| `repair claude`, `restore claude` | Die with `claude has no live auth to <verb>; each account keeps its own login`.                                                                                                                                                                                                                     |

### Plain `claude` (shell-init)

- `shell/agentic.sh` gains a `claude()` wrapper, defined only when `$AGENTIC_DIR/claude` exists.
- On each call it reads `.current`:
  - Non-default account: `CLAUDE_CONFIG_DIR=<dir> command claude "$@"`, with the three override variables unset.
  - Default account, or no `.current`: run `command claude "$@"` with `CLAUDE_CONFIG_DIR` unset.
- Because `.current` is read at launch, `use` takes effect on the next `claude` started in any terminal, matching how `use` already behaves for codex and cursor. Running sessions are untouched. [my call]
- `claude auth login/logout` is **not** blocked. With nothing linked, it can only affect the selected account's own login, which is what the user asked for. [my call]

### Provider interface

Claude does not fit the live-symlink model. It plugs into the deepening spec's facts as follows:

- **New fact `provider_switch_mode`.** It prints `link` by default and `env` for Claude. In `env` mode:
  - `live_login` skips reconcile, harvest and link. It runs the login with the account env and **never writes `.current`**; only `use` does (see Settled after builder check, item 1).
  - `live_switch` only writes `.current`.
  - `live_detach` only clears `.current`.
  - `live_repair` and `live_restore` die with the message above.
- **`provider_account_env <home>`** for Claude prints `CLAUDE_CONFIG_DIR=<home>/config`, or nothing for a default account. A new shared step unsets the variables listed by a new optional fact, `provider_unset_env`; Claude lists the three override variables. Building the env must also _unset_ `CLAUDE_CONFIG_DIR` for a default account even if the caller's shell exported it.
- `provider_live_home` and `provider_auth_artifact` don't apply to an `env` provider. `load_provider` stops requiring `provider_live_home` when `provider_switch_mode` is `env`.
- **`test/seams.bats` gains a guard:** nothing in `lib/`, `bin/` or `providers/` names `.credentials.json` or calls `security` (Keychain). This keeps the "never touch Claude credentials" anti-goal in CI.

### Platforms

macOS and Linux both use the same env model. agentic never touches the credential store, so the Keychain-versus-file difference doesn't matter. [my call]

## Tests (behaviour to pin; fake CLI extended for `claude`)

- **`run`:** `run claude personal` passes `CLAUDE_CONFIG_DIR=<record>/config` and unsets the three override variables. `run claude work` (default) passes **no** `CLAUDE_CONFIG_DIR`, even when the caller exported one.
- **`use` and the wrapper:**
  - `use claude personal`, then the wrapper launches with personal's dir.
  - `use claude work` switches back.
  - With no `.current`, the wrapper uses the default.
- **`rm`:**
  - `rm claude work` (default) leaves a sentinel file inside a fake `~/.claude` untouched.
  - `rm claude personal` invokes logout, then deletes the record, and clears `.current` if it named personal.
- **`login --existing`:** a second `--existing` is refused while another account holds `default-dir`.
- **`repair claude` and `restore claude`:** both exit 1 with the message.
- **Seam guard:** no `.credentials.json` or `security` in `lib/`, `bin/` or `providers/`.

## Settled after builder check [all my calls]

1. **Login never moves plain `claude`.**
   - Env-mode login never writes `.current`; only `use` does. `login claude personal` therefore leaves plain `claude` on work.
   - Test: after `login claude personal` with no `.current`, the wrapper still launches the default.
2. **No default record yet.** This covers both before `login claude work --existing` and after `rm claude work`.
   - Plain `claude` and `which claude` act on the default dir; `which` prints `default (~/.claude)`.
   - `list claude` shows only registered accounts.
   - `use claude <name>` needs a registered record, so it dies with `no such account` otherwise.
   - "work" is not a reserved name. It is whatever name Omar registers with `--existing`.
3. **List marker.**
   - Human `list claude` marks the `use`-selected account the way codex and cursor mark their active account. With no `.current`, the default-dir account is marked.
   - It also tags the default-dir account `(~/.claude)`.
   - `list --names` stays bare names.
4. **`check` in env mode.**
   - `cmd_check` branches on `provider_switch_mode`: it skips the artifact and JSON checks and runs the provider's status command with the account env.
   - It exits 1 when logged out, mirroring `claude auth status`.
   - `provider_login` and `provider_status` gain two optional facts: `provider_login_args`, default `login`, and `provider_status_args`, default `login status`. Claude sets `auth login` and `auth status --json`.
5. **Stable config path.**
   - At login, the config dir path is canonicalized once with `cd … && pwd -P`, then recorded in `<record>/config-path`.
   - `run`, the wrapper and `check` always read that file; they never re-derive the path. The Keychain is keyed by the exact string.
6. **`.current` names a missing record.**
   - The wrapper and `run` warn `agentic: claude account '<name>' not found; using default (~/.claude)` and launch the default.
   - `rm` already clears `.current`, so this only happens after a manual deletion.
7. **Failed first login.**
   - If `claude auth login` fails for a new account, agentic deletes the new record and config dir it just created, then dies `login failed - '<name>' was not created`.
   - A failed `relogin` deletes nothing.

## Left to the builder

- Fake-CLI shape for `claude auth status --json`.
- Exact output format of `check claude`.
- Completion entries: `claude` joins `PROVIDER_LIST`, and `--existing` joins the `login` row.
- README and manual smoke-test steps. The smoke test must include two accounts logged in at once, and `use`, `run` and the plain-`claude` wrapper.

## Verification still owed (manual, real CLI)

- Two dirs logged in to different accounts simultaneously on 2.1.318, both used concurrently for at least one token-refresh cycle. GitHub reports refresh races only for shared stores (https://github.com/anthropics/claude-code/issues/54443), but nobody has verified separate dirs over a refresh.
