# TODOs

## PLAN_REVIEW_LIVE_ALLOW_NON_TTY deprecation check
- What: Evaluate deprecating `PLAN_REVIEW_LIVE_ALLOW_NON_TTY` after one release cycle.
- Why: `plan-review-live` now supports explicit non-TTY resolution inputs (`--resolve-file` or `--decisions/--blocking`) that are safer and more auditable.
- Context: Added to close issue #30 (chat/non-TTY dead-end for `plan-review-live`).
- Depends on/blocked by: One stable release cycle of smoke + real chat automation runs with the new non-TTY apply path.

## Verify whether gateway-level session recovery changes are still needed
- What: Validate if OpenClaw gateway session recovery changes remain necessary after wrapper lifecycle hardening (`TMUX_RUN_EVENT` + `RUN_EVENT` mapping and `--wait` execution).
- Why: Historical `No session found` incidents may now be fully resolved at wrapper level; gateway changes should only be added if evidence still reproduces.
- Context: Added after implementing runtime-only stabilization for `code-implement`/`tmux-run` long-run observability and deterministic terminal events.
- Depends on/blocked by: At least one real long-running production validation in Telegram topic `4112` with captured session log timeline.
