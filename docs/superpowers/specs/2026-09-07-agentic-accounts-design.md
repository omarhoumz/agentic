# Agentic — multi-CLI account manager

**Date:** 2026-09-07  
**Status:** Draft for review  
**Replaces (eventually):** [codex-accounts](https://github.com/omarhoumz/codex-accounts)

## Problem

OpenAI Codex CLI and Cursor Agent CLI each assume a single home directory and a single signed-in account. Switching accounts means logout/login (and for Codex, a bare `login` can overwrite a stored credential through a live symlink). `codex-accounts` already solves this for Codex. Cursor CLI has the same shape (`CURSOR_CONFIG_DIR`, optional file credential store) but no manager. We want one tool for both, with a clear deprecation path off `codex-accounts`.

## Goals

- One CLI (`agentic`) to login / switch / run / list / repair accounts for **Codex** and **Cursor Agent CLI**.
- Per-provider account pools: `agentic use codex work` and `agentic use cursor work` are independent.
- Both modes: **`use`** (active default for the plain CLI) and **`run`** (isolated home, concurrent accounts).
- Migrate existing `~/.codex-accounts` into the new store without re-auth when possible.
- Shell integration that blocks bare `codex login|logout` and `agent login|logout`.
- Deprecate `codex-accounts` via shims, then sunset.

## Non-goals (v1)

- Cursor IDE multi-account (`--user-data-dir` / app profiles).
- Shared cross-provider identity (one “work” binding both CLIs).
- Auto-installing Codex or Cursor CLIs.
- Providers beyond `codex` and `cursor` (seam should allow them later).

## Decisions (locked)

| Topic | Choice |
|---|---|
| Product shape | New sibling tool; do not evolve `codex-accounts` in place |
| Account naming | Per-provider pools |
| CLI verb style | `agentic <verb> <provider> <name> …` |
| Modes | Both `use` and `run` |
| Cursor surface | Agent CLI only; IDE later |
| Migration | Import `~/.codex-accounts` → `~/.agentic/codex/` |
| Shell init | Wrap both `codex` and `agent` login/logout |
| Architecture | Provider adapters + shared verbs |

## Architecture

```text
agentic (shared verbs)
  ├── providers/codex.sh    # CODEX_HOME, auth.json, codex login/status
  ├── providers/cursor.sh   # CURSOR_CONFIG_DIR, file credential store, agent login/status
  ├── lib/                  # store paths, symlink switch, repair, migrate, shell-init
  └── shims (separate package / later)  # codex-accounts → agentic
```

**Deep seam:** callers only learn `agentic <verb> <provider> <name>`. Provider scripts satisfy a small contract; shared code owns store layout, switch/run, repair, migrate, and shell-init.

### Store layout

```text
~/.agentic/
  codex/<account>/     # that account's CODEX_HOME
  cursor/<account>/    # that account's CURSOR_CONFIG_DIR
  active               # last `use` per provider (and/or markers as needed)
```

Credentials and CLI-local state live under the account home. Shared non-secret config may be symlinked from a common place per provider (same idea as `codex-accounts` sharing `config.toml`) — exact files decided per provider during implementation.

### Provider contract

Each provider implements:

| Capability | Purpose |
|---|---|
| `live_home` | Default CLI state dir (e.g. `~/.codex`, `~/.cursor`) |
| `account_home name` | `~/.agentic/<provider>/<name>` |
| `run_env name` | Exports required for isolated run |
| `login` / status | Invoke the underlying CLI login and whoami/status |
| `auth_artifact` | Path(s) that must be switched/symlinked on `use` |
| `cli_bin` | `codex` or `agent` |

Shared verbs never hardcode CLI-specific paths; they call the active provider.

## CLI surface (v1)

```text
agentic login   <provider> <name> [--force]
agentic relogin <provider> <name>
agentic use     <provider> <name> [--force]
agentic run     <provider> <name> [--] <cli-args...>
agentic which   <provider>
agentic list    [<provider>]
agentic check   <provider> <name> [--deep]
agentic repair  [<provider>] [--yes]
agentic rm      <provider> <name> [--yes]
agentic restore <provider>          # undo live-home auth swap / restore backup
agentic migrate                     # ~/.codex-accounts → ~/.agentic/codex/
agentic shell-init [--remove|--print]
```

Shorthands (optional v1 or v1.1): none required; `codex-switch` / `codex-run` become shims instead.

## Provider behavior

### Codex

- Isolation: `CODEX_HOME=~/.agentic/codex/<name>`.
- Credential: `auth.json`; `use` symlinks it into the live Codex home (port of current behavior).
- `run`: export `CODEX_HOME`, exec `codex` with remaining args.
- Keep bare-login detection and repair (symlink overwrite trap).
- Health: reuse existing check/`codex login status` patterns where possible.

### Cursor (Agent CLI)

- Isolation: `CURSOR_CONFIG_DIR=~/.agentic/cursor/<name>`.
- Always set `AGENT_CLI_CREDENTIAL_STORE=file` so credentials live under the account dir (not macOS Keychain), matching Codex’s file-based switch/migrate model.
- `login`: env + `agent login`; status via `agent whoami` / `agent status`.
- `use`: point the live Cursor CLI auth/config at the account artifact(s). Exact file set confirmed against current CLI during implementation (spike if docs underspecify).
- `run`: export `CURSOR_CONFIG_DIR` + `AGENT_CLI_CREDENTIAL_STORE=file`, exec `agent`.
- Out of scope: Cursor IDE Keychain / `Application Support` profiles.

## Shell integration

`agentic shell-init` installs an idempotent rc block that:

| User types | Behavior |
|---|---|
| `codex login` / `codex logout` | Refuse; suggest `agentic login\|relogin codex <name>` |
| `agent login` / `agent logout` | Refuse; suggest `agentic login\|relogin cursor <name>` |
| `codex login status` and other subcommands | Pass through |
| No `~/.agentic` store | Wrappers no-op; plain CLIs behave normally |

Bypass: `command codex login`, `command agent login`.

Without shell-init, detection/repair still refuse or fix after a destructive bare login where possible (same two-layer model as `codex-accounts`).

## Migration

`agentic migrate`:

1. If `~/.codex-accounts` exists and `~/.agentic/codex` is empty/missing, import accounts (copy or move — prefer copy first, then optional cleanup flag).
2. Preserve active-account marker when present.
3. Idempotent: second run reports already migrated / nothing to do.
4. Does not touch Cursor; Cursor accounts are created via `agentic login cursor <name>`.
5. Print next steps: `agentic use codex <name>`, `agentic shell-init`.

## Deprecation path for `codex-accounts`

| Phase | Behavior |
|---|---|
| **1 – Ship** | `agentic` is the implementation; docs instruct `migrate` + shell-init |
| **2 – Shim** | `codex-accounts` / `codex-switch` / `codex-run` print a one-line deprecation on stderr and `exec` into `agentic` (e.g. `codex-switch use work` → `agentic use codex work`) |
| **3 – Sunset** | Tap caveat + README: uninstall old formulae; remove shims after a stated version or date |

Example mappings:

- `codex-accounts login work` → `agentic login codex work`
- `codex-switch use work` → `agentic use codex work`
- `codex-run work exec …` → `agentic run codex work -- exec …`

Until phase 2, `codex-accounts` remains independently usable; `agentic migrate` must not break a machine that still runs the old tools unless the user opts into moving the store.

## Error handling

- Unknown provider → exit non-zero, list supported providers.
- Missing account → clear message; suggest `login` or `list`.
- `use`/`login` while a conflicting CLI session holds the live auth → warn/block (port Codex running-session checks where applicable).
- Cursor without file credential store support → fail with upgrade guidance rather than silent Keychain writes.

## Testing

- Smoke tests with fake provider fixtures (temp dirs, stub `login`/`status` binaries).
- Codex path: reuse/adapt `codex-accounts` smoke ideas against `~/.agentic/codex`.
- Cursor path: env isolation + file store under account home; no requirement for live browser login in CI.
- Migrate: fixture old store → new layout → `which`/`list` agree.
- Shell-init: install/remove idempotency on a temp rc file.

## Open points (resolve in implementation, not blockers)

1. Exact Cursor CLI auth file path(s) under `CURSOR_CONFIG_DIR` when using file credential store.
2. Whether `use` for Cursor should symlink only auth artifacts or the whole config dir into `~/.cursor` (prefer minimal artifact swap if safe).
3. Copy vs move default for `migrate` (recommend copy + `--cleanup` later).
4. Homebrew formula name (`agentic` vs `agentic-accounts`) and tap location.

## Success criteria

- User can `agentic migrate`, `agentic use codex <existing>`, and keep working without re-login.
- User can `agentic login cursor work` / `agentic run cursor work …` without affecting Codex accounts.
- Bare `codex login` and `agent login` are blocked after `shell-init`.
- `codex-accounts` can later become a thin shim without changing the store layout again.
