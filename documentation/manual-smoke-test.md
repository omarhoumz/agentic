# Manual smoke test (real CLI)

Run these against a real Cursor Agent CLI install — not in CI.

```bash
agentic login cursor personal
agentic whoami   # via: agentic run cursor personal -- whoami
agent whoami     # after: agentic use cursor personal
```
