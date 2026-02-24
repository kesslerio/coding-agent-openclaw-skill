# Codex CLI Reference

Canonical Codex guidance for `plan-issue` + `coding-agent`.

## Plan-First Gate

For non-trivial tasks:
1. Plan first (`plan-issue` behavior).
2. Wait for explicit `APPROVE`.
3. Execute with Codex (`coding-agent` behavior).

Do not perform writes before `APPROVE`.

## Default Strategy

Use single-agent Codex for most work:
1. `codex exec --full-auto "..."` for implementation/review prompts after approval.
2. `codex exec resume --last "..."` for follow-up work.
3. Use tmux only when persistence/reattach is required.

## Core Commands

### Implementation (post-approval)

```bash
codex exec --full-auto "Implement feature X according to the approved plan."
```

### Resume previous context

```bash
codex exec resume --last "Address review findings from the previous run"
```

### Review against base branch

```bash
timeout 600s codex review --base <base> --title "PR #N Review"
```

### Structured non-interactive output

```bash
codex exec --json --output-last-message /tmp/last.txt "Summarize changes"
```

Useful automation flags:
- `--json`
- `--output-schema <FILE>`
- `--output-last-message <FILE>`
- `--skip-git-repo-check`

## Safety Profiles

- Guardrailed default: `codex exec --full-auto "..."`
- Explicit bypass (only when user asks to bypass approvals):

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "..."
```

## Execution Policy Matrix

| Task | Primary | Secondary | Notes |
|------|---------|-----------|-------|
| Implementation | direct `codex exec --full-auto` | tmux transport | Use `resume` for iterative loops |
| PR review | `codex review --base` | Claude CLI fallback | Keep timeout >= 600s |
| Long-running implementation | tmux transport | direct `codex exec --full-auto` | For reattach/log durability |

Implementation-mode env var:
- `CODING_AGENT_IMPL_MODE=direct|tmux|auto`
- `direct`: run Codex directly first
- `tmux`: run tmux transport first
- `auto`: tmux first only when attached to TTY and tmux is available

## MCP Clarification

1. `codex mcp ...`: configure external MCP tools for Codex runs.
2. `codex mcp-server`: expose Codex itself as an MCP server.

## Official Sources

- https://developers.openai.com/codex/cli/reference
- https://developers.openai.com/codex/noninteractive
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/multi-agent
