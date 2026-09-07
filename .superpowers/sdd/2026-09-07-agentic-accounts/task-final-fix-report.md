## Final-fix wave

### What changed

- Made `list --names` work without a provider and emit bare names across providers.
- Exported Cursor's file credential store from active shell wrappers; documented the file-store requirement and Cursor's separate `run` config.
- Let forced activation recover from a stale, missing active account after preserving live auth.
- Linked an existing Codex live `config.toml` into account homes when absent.
- Kept only the three newest timestamped live-auth backups, secured newly-created live homes, and removed ignored `repair --yes` from help, parsing, and completions.

### Verification

```text
$ bats test/
1..49
49 tests passed

$ shellcheck -x -P bin:.:providers:lib bin/agentic lib/*.sh providers/*.sh shell/agentic.sh
(no output; exit 0)
```

Coverage includes `list --names` with no provider, sourced Cursor file-store export, stale active-marker switching, Codex config linking, and backup retention.

### Commits

- `2354d80 fix account activation edge cases`
