# Codex CLI Reference

Canonical Codex guidance for this skill.

## Default Strategy

Use **single-agent Codex** for most work:
1. `codex --yolo exec "..."` for one-off implementation/review prompts.
2. `codex exec resume --last "..."` for follow-up work on the same task.
3. Use tmux only when terminal persistence/reattach is required.

This keeps workflows interactive and stateful without forcing a persistent tmux session.

## Core Commands

### One-off implementation

```bash
codex --yolo exec "Implement feature X. No questions."
```

### Resume previous context

```bash
codex exec resume --last "Fix findings from the previous run"
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

Choose one profile per run:

- Guardrailed sandbox: `codex exec --full-auto "..."`
- Full bypass (externally sandboxed environments only):

```bash
codex exec --dangerously-bypass-approvals-and-sandbox "..."
```

`codex --yolo exec` is equivalent to bypass mode.

## Execution Policy Matrix

| Task | Primary | Secondary | Notes |
|------|---------|-----------|-------|
| Implementation | direct `codex exec` | tmux transport | Use `resume` for iterative loops |
| PR review | `codex review --base` | Claude CLI fallback | Keep timeout >= 600s |
| Long-running implementation | tmux transport | direct `codex exec` | For reattach/log durability |

Implementation-mode env var:
- `CODING_AGENT_IMPL_MODE=direct|tmux|auto`
- `direct`: run Codex directly first
- `tmux`: run tmux transport first
- `auto`: tmux first only when attached to TTY and tmux is available

## MCP Clarification

There are two distinct MCP paths:

1. `codex mcp ...`
- Configure external MCP tools **for Codex**.
- Use when Codex needs extra context/tools.

2. `codex mcp-server`
- Expose **Codex itself** as an MCP server for another orchestrator.
- Experimental; use behind feature flags/pilots.

## Multi-Agent Guidance

Codex multi-agent workflows are experimental.

Use only when the task is truly decomposable into parallel tracks (for example: independent security/performance/test-review streams). Prefer single-agent `exec` + `resume` for normal implementation cycles.

## Official Sources

- https://developers.openai.com/codex/cli/reference
- https://developers.openai.com/codex/noninteractive
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/multi-agent
