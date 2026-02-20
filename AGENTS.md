**Current date**: 2026-02-19

## Purpose

High-signal instructions for coding agents in this repository.
Keep this file concise; move long examples and deep procedures to `README.md` and `references/`.

## Scope

- Applies to the repository root and descendants.
- Add nested `AGENTS.md` files only when a subdirectory needs different rules.
- `CLAUDE.md` should remain a symlink to this file.

## Language

- English only for code, comments, docs, examples, commits, configs, errors, and tests.

## Tooling

- Prefer `rg` over `grep`.
- Prefer `fd`/`tree` when available; fall back to `find`/`ls -R` when missing.
- Resolve Claude CLI in this order: `~/.claude/local/claude` (if present), otherwise `claude` from `PATH`.
- Prefer non-interactive command execution.

## Runtime Reality Check

- Before running major workflows, verify toolchain:
  - `command -v codex && codex --version`
  - `command -v timeout`
  - `command -v gh`
  - `command -v claude || test -x ~/.claude/local/claude`
- If a required binary is missing, stop and report exact install/unblock steps.

## Codex Command Canon

- Prefer Codex for implementation and review:
  - Implementation: `codex exec "..."` (or `codex --yolo exec "..."` only in trusted/sandboxed environments)
  - Resume: `codex exec resume --last`
  - Review: `codex review --base <branch> "custom focus prompt"`
- Use `--full-auto` for sandboxed low-friction automation.
- Use `--yolo` only when bypassing sandbox/approvals is explicitly intended.

## Workflow

1. Gather context with read-only operations first.
2. For non-trivial work, propose a concise plan with assumptions, risks, and one alternative.
3. Get explicit `APPROVE` before file writes, package installs, or system changes.
4. After approval, execute end-to-end and report progress, results, and deviations.

## Long-Running Commands

- Ensure `tsx` scripts close watchers/timers and call `process.exit(0)`.
- Wrap long tasks with process-group timeout, e.g.:
  - `timeout -k5s 60s bash -lc 'exec npx --yes tsx scripts/tool-schema-lint.ts'`
- Avoid `timeout --foreground`.
- After timeout, verify child processes are stopped; if not, run `pkill -P <wrapper_pid>`.

## Code Standards

- Prefer KISS and YAGNI; avoid speculative abstractions.
- Apply DRY with a three-strikes rule before abstraction.
- Keep modules and classes focused (SRP).
- TypeScript: avoid `any`; prefer precise types or `Record<string, unknown>`.
- Use explicit error handling; never fail silently.
- Import order: node -> external -> internal.
- Use descriptive names and named constants instead of magic numbers.

## Review Expectations (Plan/Review Mode)

- Review in this order: Architecture, Code Quality, Tests, Performance.
- For each issue:
  - include file/line references,
  - present 2-3 options (include do-nothing when reasonable),
  - state effort, risk, impact, and maintenance burden per option,
  - recommend one option and ask for user decision before implementation.
- Interactive flow:
  - Big change: section-by-section with up to 4 top issues per section.
  - Small change: one focused question per section.

## Testing and Validation

- Reproduce first when debugging.
- Before finalizing, run relevant checks:
  - formatting/lint
  - typecheck
  - unit/integration/e2e tests as applicable
- Report exact commands run and outcomes.
- Explicitly call out checks not run and residual risk.

## Documentation Hygiene

- Update `README.md` or `references/` when public behavior/workflow changes.
- Final report must summarize files changed, key diffs, and side effects.
- Prefer inclusive language: allowlist/blocklist, primary/replica, main branch.

## OpenClaw Skill Notes

- Keep `SKILL.md` AgentSkills-compatible: clear `name` + `description`, concise body, references for deep detail.
- For OpenClaw compatibility, keep frontmatter keys single-line and keep `metadata` as a single-line JSON object.

## CLI Drift Check

- Periodically verify docs/scripts against real CLI help:
  - `codex --help`
  - `codex review --help`
  - `claude --help`
- Update references when flags/behavior drift.
