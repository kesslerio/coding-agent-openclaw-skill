---
name: coding-agent
description: "Compatibility entry skill for plan-first coding work. Routes requests through planning and enforces explicit APPROVE before implementation."
metadata: {"openclaw":{"emoji":"💻","requires":{"bins":["gh"],"anyBins":["codex","claude"],"env":[]}}}
---

# Coding Agent Compatibility Skill 💻

This file exists for backward compatibility with single-entry skill setups (for example `/coding`).
Canonical sibling skills live at:

- `.agents/skills/plan-issue/SKILL.md`
- `.agents/skills/coding-agent/SKILL.md`
- `.claude/skills/plan-issue/SKILL.md`
- `.claude/skills/coding-agent/SKILL.md`

## Routing Rules

1. If user asks to plan/scope/estimate/design, follow `plan-issue` behavior.
2. For non-trivial implementation requests, produce a plan first and wait for exact `APPROVE` before any writes.
3. Only after `APPROVE`, follow `coding-agent` behavior.

## Non-Negotiable Gates

1. Never write files, install packages, commit, or open PRs before explicit `APPROVE`.
2. Never default to bypass flags (`--yolo`, `--dangerously-skip-permissions`).
3. Use bypass flags only when the user explicitly asks to bypass approvals.
