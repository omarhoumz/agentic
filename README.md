# agentic

`agentic` manages separate CLI accounts for Codex, Cursor Agent CLI and Claude
Code. For Codex and Cursor it keeps each account's credentials in
`~/.agentic/<provider>/<name>` and switches the provider's live credentials to
the selected account. For Claude Code each account is its own config
directory, so accounts run side by side and agentic never touches a Claude
credential.

**[omarhoumz.github.io/agentic](https://omarhoumz.github.io/agentic/)** —
what it is and how to start, in one page. This file is the reference.

See the [design specification](docs/superpowers/specs/2026-09-07-agentic-accounts-design.md)
for the command model, storage layout, and safety guarantees.

## Install

### Homebrew (recommended)

```sh
brew install omarhoumz/tap/agentic
agentic --help
```

### From source

Clone this repository, then install the executable as a symlink:

```sh
./install.sh
export PATH="$HOME/.local/bin:$PATH" # Add this to your shell profile if needed.
agentic --help
```

The installer only creates `~/.local/bin/agentic`; it never creates, changes,
or removes `~/.agentic`. Remove the link with:

```sh
./install.sh --uninstall
```

To enable completions when installing from source, source the appropriate file
from your shell profile (Homebrew installs them automatically):

```sh
# Bash
source /path/to/agentic/completions/agentic.bash

# Zsh
fpath=(/path/to/agentic/completions $fpath)
autoload -Uz compinit && compinit
```

## Usage

```text
agentic <verb> <provider> <name> [options]
```

Providers are `codex`, `cursor` and `claude`. Run `agentic --help` for the complete
command reference.

### Codex

```sh
agentic login codex work
agentic login codex personal
agentic use codex work
agentic run codex personal -- exec "explain this repository"
agentic list codex
```

### Cursor Agent CLI

```sh
agentic login cursor work
agentic login cursor personal
agentic use cursor work
agentic run cursor personal -- "summarize this project"
agentic list cursor
```

`agentic run` isolates a single CLI invocation to the requested account.
`agentic use` changes the account used by a normal `codex` or `agent` command.
Cursor management requires `AGENT_CLI_CREDENTIAL_STORE=file`. The Agent CLI
always writes credentials to `~/.cursor/auth.json` (it ignores
`CURSOR_CONFIG_DIR` for the auth file); `agentic login` copies that file into
the account home and then symlinks the live path. `agentic login` and `run`
set the file-store variable automatically; for `agentic use cursor …`, install
shell-init (or export the variable manually) before using bare `agent`.
Cursor `run` uses a separate config directory, so it does not merge the
normal Cursor configuration.
`agentic check cursor <name> --deep` works only on the active Cursor
account, because the Agent CLI only reads `~/.cursor/auth.json`; on any
other account it refuses and names the active account, so run
`agentic use cursor <name>` first.

`agentic check` uses either `jq` or `python3` to validate credential JSON.

### Claude Code

```sh
agentic login claude work --existing   # register ~/.claude as "work"
agentic login claude personal          # new account in its own config dir
agentic run claude personal -- -p "hi" # this terminal only
agentic use claude personal            # plain `claude` now opens personal
agentic use claude work                # and back
agentic check claude personal
agentic list claude
```

Claude Code keeps each login keyed to its config directory (the macOS
Keychain, or a file inside the directory on Linux), so agentic never reads,
copies or links a Claude credential. An account is a config directory:

- the default account is `~/.claude`, launched with `CLAUDE_CONFIG_DIR`
  unset; `login --existing` registers it under a name and logs it in only if
  it is logged out;
- every other account gets `~/.agentic/claude/<name>/config`, launched with
  `CLAUDE_CONFIG_DIR` pointing at it. Accounts share nothing: each has its
  own settings, CLAUDE.md, skills, plugins and history.

Differences from Codex and Cursor:

- `use` takes effect for the next `claude` started in any terminal; running
  sessions keep their account, so `use` never refuses and `--force` changes
  nothing.
- `login` never changes the account plain `claude` opens; only `use` does.
- `which claude` prints `default (~/.claude)` when nothing is selected or
  registered.
- `rm` of the `--existing` account forgets agentic's record only; `~/.claude`
  and its login are kept. `rm` of any other account runs `claude auth logout`
  first, then deletes its directory.
- `check` runs `claude auth status` for that account and exits 1 when it is
  logged out; `--deep` is the same check.
- `repair` and `restore` refuse `claude`: there is no live file.
- Every launch through agentic unsets `ANTHROPIC_API_KEY`,
  `ANTHROPIC_AUTH_TOKEN` and `CLAUDE_CODE_OAUTH_TOKEN`, which would override
  the account's login. Console (API-billing) logins are not supported: Claude
  stores them outside the config directory.

## Migrate from codex-accounts

Copy existing Codex accounts into the new store:

```sh
agentic migrate
agentic list codex
agentic use codex work
```

Migration copies rather than deletes `~/.codex-accounts`, so the old tools
continue to work until you deliberately retire them.

| Old | New |
|---|---|
| `codex-switch use work` | `agentic use codex work` |
| `codex-run work …` | `agentic run codex work -- …` |
| `codex-accounts login work` | `agentic login codex work` |

## Shell integration

After accounts are configured, install shell wrappers:

```sh
agentic shell-init
```

They prevent bare `codex login`, `codex logout`, `agent login`, and `agent
logout` from overwriting a managed account. Use `agentic shell-init --remove`
to remove the marked block later. When a Cursor account store exists under
`~/.agentic/cursor`, they also export `AGENT_CLI_CREDENTIAL_STORE=file` so
bare `agent` follows the managed file credential store.

When `~/.agentic/claude` exists they also wrap `claude`: it opens the account
picked with `agentic use claude <name>`, or `~/.claude` when none is picked.
`claude auth login` and `logout` are not blocked, because they only affect
the selected account's own login. Open a new shell after the first
`agentic login claude …` so the wrapper is defined.

## Scope and status

This manages CLI credentials only; IDE and desktop-app account management is
out of scope.
Phase-2 compatibility shims for `codex-accounts`, `codex-switch`, and
`codex-run` are not shipped yet.

## Manual install checklist

```sh
tmp=$(mktemp -d)
./install.sh --prefix "$tmp/bin"
test -L "$tmp/bin/agentic"
"$tmp/bin/agentic" --version
./install.sh --prefix "$tmp/bin" --uninstall
test ! -e "$tmp/bin/agentic"
rm -rf "$tmp"
```

## Manual Claude check (real CLI)

```sh
agentic login claude work --existing        # no browser if ~/.claude is logged in
agentic login claude personal               # browser login as the personal account
agentic check claude work && agentic check claude personal
agentic run claude personal -- -p "which account?"   # terminal 1
claude -p "which account?"                  # terminal 2, plain claude = work
agentic use claude personal; claude -p hi   # plain claude now personal
agentic use claude work
```

Still owed: keep both accounts in use for longer than one token refresh and
confirm neither is logged out.
