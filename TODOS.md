# TODOs

## PLAN_REVIEW_LIVE_ALLOW_NON_TTY deprecation check (tracked in #57)
- What: Evaluate deprecating `PLAN_REVIEW_LIVE_ALLOW_NON_TTY` after one release cycle.
- Why: `plan-review-live` now supports explicit non-TTY resolution inputs (`--resolve-file` or `--decisions/--blocking`) that are safer and more auditable.
- Context: Added to close issue #30 (chat/non-TTY dead-end for `plan-review-live`).
- Depends on/blocked by: One stable release cycle of smoke + real chat automation runs with the new non-TTY apply path.

## Verify whether gateway-level session recovery changes are still needed (tracked in #58)
- What: Validate if OpenClaw gateway session recovery changes remain necessary after wrapper lifecycle hardening (`TMUX_RUN_EVENT` + `RUN_EVENT` mapping and `--wait` execution).
- Why: Historical `No session found` incidents may now be fully resolved at wrapper level; gateway changes should only be added if evidence still reproduces.
- Context: Added after implementing runtime-only stabilization for `code-implement`/`tmux-run` long-run observability and deterministic terminal events.
- Depends on/blocked by: At least one real long-running production validation in Telegram topic `4112` with captured session log timeline.

## Follow-up: full auto merge stage for review-loop supervisor (tracked in #59)
- What: Add opt-in full-auto E2E merge mode for `scripts/review-loop-supervisor` after PR required checks pass.
- Why: Users requested end-to-end automation beyond review/fix + PR-open in issue #50 planning.
- Context: Scope-reduced implementation shipped supervisor + optional PR open/update only.
- Depends on/blocked by: Stability of supervisor loop artifacts/events in real runs and a strict rollback rehearsal contract.

## Follow-up: parser reliability telemetry for supervisor footer contract (tracked in #60)
- What: Add telemetry and diagnostics for strict footer parse failures (`SUPERVISOR_COUNTS` / `SUPERVISOR_TOP`) in review-loop runs.
- Why: Track LLM formatting drift and identify when retry/fail-closed behavior needs prompt or parser updates.
- Context: Current implementation uses strict parse + single retry, then hard fail.
- Depends on/blocked by: Sufficient production run volume with archived `.ai/review-loops/*.json` history.
