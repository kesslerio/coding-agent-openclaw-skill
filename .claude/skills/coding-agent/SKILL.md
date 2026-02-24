---
name: coding-agent
description: Execute approved implementation plans for coding tasks, reviews, tests, and PR delivery.
argument-hint: "[approved-task]"
disable-model-invocation: true
---

# Coding-Agent Skill

Only run this skill after explicit `APPROVE`.
If approval is missing, request `APPROVE` and stop.

Execution rules:
- Verify toolchain before major workflows.
- Gather context read-only before making edits.
- Execute approved plan end-to-end.
- Run and report validation commands and outcomes.
- Do not use bypass flags by default; only when explicitly requested by the user.
