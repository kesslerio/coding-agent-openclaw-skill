---
name: coding-agent
description: "Implementation/review workflow for approved plans. Use after explicit APPROVE to execute coding changes, tests, PR creation, and follow-up review loops."
---

# Coding-Agent Skill

## Entry Gate

Only execute this skill after the user has explicitly sent `APPROVE` for a plan in the current conversation.
If `APPROVE` is missing, stop and request approval.

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

- No bypass-by-default. Do not use `--yolo` or `--dangerously-skip-permissions` unless the user explicitly requests approval bypass.
- Prefer Codex for implementation/review and Claude as fallback.
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
