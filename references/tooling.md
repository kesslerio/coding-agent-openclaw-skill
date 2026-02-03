# Tooling and Timeouts

## MCP Preferred

Use Codex MCP for implementation and Codex MCP or CLI for reviews.

```bash
# Implementation
mcporter call codex.codex 'prompt="Implement feature X. Just implement, no questions."' \
  'sandbox=workspace-write' 'approval-policy=untrusted'

# Review
mcporter call codex.codex 'prompt="Review this PR for bugs, security, quality."' \
  'sandbox=read-only' 'approval-policy=untrusted'
```

## CLI Fallbacks

```bash
# Codex CLI quick edit
codex --yolo exec "Fix typo in file X line Y"

# Claude CLI fallback for reviews
timeout 300s claude -p --dangerously-skip-permissions "Review this codebase for issues..."
```

## Wrapper Scripts

Use wrappers to enforce minimum timeouts and block `--max-turns`.

```bash
# Review (5 min)
"${CODING_AGENT_DIR:-./}/scripts/code-review" "Review PR #123 for bugs, security, quality"

# Implementation (3 min)
"${CODING_AGENT_DIR:-./}/scripts/code-implement" "Implement feature X in /path/to/repo"
```

## Minimum Timeouts

- Code review: 300s
- Architectural review: 600s
- Implementation: 180s per file

## Environment Variables

- `MCPORTER_CALL_TIMEOUT`: global default
- `CODE_REVIEW_TIMEOUT`: review override in milliseconds
- `CODE_IMPLEMENT_TIMEOUT`: implementation override in milliseconds

## Fallback Chain

Implementation:
- Codex MCP
- Claude MCP
- Codex CLI
- Claude CLI
- Blocked

Review:
- Codex CLI or MCP
- Claude MCP
- Claude CLI
- Blocked
