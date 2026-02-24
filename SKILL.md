---
name: coding-router
description: "Compatibility entry skill for plan-first coding work in OpenClaw."
metadata: {"openclaw":{"emoji":"💻","requires":{"bins":["gh"],"anyBins":["codex","claude"],"env":[]}}}
---

# Coding Router Skill 💻

This file exists for backward compatibility with single-entry skill setups (for example `/coding`).
Canonical sibling skills live at:

- `skills/plan-issue/SKILL.md`
- `skills/coding-agent/SKILL.md`

## Routing Rules

1. If user asks to plan/scope/estimate/design, follow `plan-issue` behavior.
2. For non-trivial implementation requests, produce a plan first and wait for exact `APPROVE` before any writes.
3. Only after `APPROVE`, follow `coding-agent` behavior.

## Command Routing (Channel Aliases)

When invoked via channel aliases:

- `/coding` → use this compatibility skill as router.
- `/plan` → route directly to `plan-issue` behavior.
- `/approve` → treat as explicit approval gate for the latest in-context plan, then route to `coding-agent` behavior.
- `/review_pr` → route to review flow using `references/reviews.md`.

## Non-Negotiable Gates

1. Never write files, install packages, commit, or open PRs before explicit `APPROVE`.
2. Never default to bypass flags (`--yolo`, `--dangerously-skip-permissions`).
3. Use bypass flags only when the user explicitly asks to bypass approvals.
