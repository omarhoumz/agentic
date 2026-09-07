# agentic

`agentic` manages separate CLI accounts for Codex and Cursor Agent CLI. It keeps
each account's credentials in `~/.agentic/<provider>/<name>` and switches the
provider's live credentials to the selected account.

See the [design specification](docs/superpowers/specs/2026-09-07-agentic-accounts-design.md)
for the command model, storage layout, and safety guarantees.

## Install

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

To enable completions, source the appropriate file from your shell profile:

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

Providers are `codex` and `cursor`. Run `agentic --help` for the complete
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
to remove the marked block later.

## Scope and status

This manages CLI credentials only; IDE account management is out of scope.
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
