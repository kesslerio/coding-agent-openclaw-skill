---
name: coding-agent
description: "Implementation/review workflow for approved plans. Use after explicit APPROVE."
disable-model-invocation: true
metadata: {"openclaw":{"emoji":"💻","requires":{"bins":["gh"],"anyBins":["codex","claude"],"env":[]}}}
---

# Coding-Agent Skill

## Entry Gate

Only execute this skill after explicit approval in the current conversation context:
- `APPROVE`
- `/approve`

Approval must correspond to the latest pending plan in-context.
If no matching approved plan exists, stop and request:
`Run /plan first, then reply APPROVE.`

## Execution Workflow

1. Verify toolchain before major workflows:
- `command -v codex && codex --version`
- `command -v timeout`
- `command -v gh`
- `command -v claude || test -x ~/.claude/local/claude`
2. Gather read-only context first (`rg`, `git status`, `git diff`, docs).
3. Execute the approved implementation plan.
4. Run relevant validation:
- formatting/lint
- typecheck
- unit/integration/e2e tests as applicable
5. Report exact commands run, outcomes, and residual risk.

## Guardrails

- No bypass-by-default. Do not use approval-bypass flags unless the user explicitly requests bypass.
- Use feature branches for code changes.
- Keep changes scoped to the approved plan.

## Reference Loading

Open only the references needed for the current task:
- `references/WORKFLOW.md`
- `references/STANDARDS.md`
- `references/tooling.md`
- `references/codex-cli.md`
- `references/claude-code.md`
- `references/reviews.md`
