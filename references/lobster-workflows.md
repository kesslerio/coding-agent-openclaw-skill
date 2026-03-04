# Lobster Workflows (In-Repo)

This repository contains the `plan-review-live` Lobster workflow used by
`./scripts/plan-review-live`.

## Files

- `workflows/plan-review-live.lobster`: workflow definition.
- `scripts/plan-review-lobster/section-step.sh`: per-section review runner.
- `scripts/plan-review-live-lobster`: wrapper integration for metadata contract and decision collection.

## Execution Contract

- Default live engine is Lobster (`PLAN_REVIEW_LIVE_ENGINE=lobster`).
- If `lobster` binary is missing, wrapper falls back to legacy engine automatically.
- Output + metadata contract remains unchanged:
  - markdown output in `.ai/plan-reviews/*.md`
  - metadata history file + `latest-<plan-id>.json`
  - fields: `schema_version`, `plan_id`, `plan_path`, `mode`,
    `ready_for_implementation`, `blocking_decisions`, `resolved_decisions`,
    `created_at`, `review_markdown_path`

## Commands

```bash
# Default (Lobster first)
./scripts/plan-review-live --repo /path/to/repo

# Legacy path
./scripts/plan-review-live --engine legacy --repo /path/to/repo

# Resume a paused Lobster run
./scripts/plan-review-live --resume-token <token> --output /path/to/repo/.ai/plan-reviews/<same-file>.md

# Optional strict mode when resume state is missing
./scripts/plan-review-live --resume-token <token> --resume-missing-state error --output /path/to/repo/.ai/plan-reviews/<same-file>.md
```

Resume behavior persists decision state in:
- `<review-markdown-path>.lobster-session.json`

By default, if `--resume-token` is provided but session state is missing, the
wrapper auto-recovers by restarting live mode without the resume token.
Use `--resume-missing-state error` (or env override below) to keep strict fail
behavior.

That file is removed automatically when the live review completes successfully.

## Environment

- `PLAN_REVIEW_LIVE_ENGINE`: `lobster` (default) or `legacy`.
- `PLAN_REVIEW_LOBSTER_FILE`: override workflow file path.
- `PLAN_REVIEW_LIVE_SECTION_TIMEOUT`: per-section timeout seconds.
- `PLAN_REVIEW_LIVE_TOTAL_TIMEOUT`: total timeout budget seconds.
- `PLAN_REVIEW_LIVE_DECISION_TIMEOUT`: timeout for each interactive decision prompt (default `600`).
- `PLAN_REVIEW_LIVE_RESUME_MISSING_STATE`: `auto` (default) or `error`.
- `PLAN_REVIEW_LIVE_ALLOW_NON_TTY`: allow live mode in non-TTY for scripted runs.
