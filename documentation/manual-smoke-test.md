# Manual smoke test (real CLI)

Run these against real Codex and Cursor Agent CLI installs — not in CI. Use a
throwaway machine or back up config directories before Step 1.

## Step 1: Migrate real Codex accounts

Back up existing Codex account state, then migrate and verify the pool works.

- [ ] Back up `~/.codex-accounts` before migrating

```bash
cp -R ~/.codex-accounts ~/.codex-accounts.bak
agentic migrate
agentic list codex
agentic use codex <name>
codex login status   # or equivalent
```

## Step 2: Cursor account

- [ ] Log in, run one-off via `run`, switch active account, confirm shim

```bash
agentic login cursor personal
agentic run cursor personal -- whoami
agentic use cursor personal
agent whoami
```

## Step 3: Shell-init

Shell-init must block bare provider login/logout so managed accounts are not
overwritten.

- [ ] Install shell-init, open a new shell, confirm login is refused

```bash
agentic shell-init
# new shell
codex login    # must refuse
agent login    # must refuse
```

## Step 4: Confirm IDE untouched

- [ ] Opening Cursor.app still uses normal IDE login; it does **not** follow
  `agentic use cursor`. Agentic manages CLI credentials only — IDE account
  management is out of scope.

## Recording results

After completing the checklist, note pass/fail and any caveats here:

| Step | Result | Notes |
|------|--------|-------|
| 1. Codex migrate | | |
| 2. Cursor account | | |
| 3. Shell-init | | |
| 4. IDE untouched | | |
