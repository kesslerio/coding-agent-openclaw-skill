# coding-agent Skill Pack 💻

Plan-first OpenClaw skill pack.

## Skill Layout

This repo now ships two sibling skills:

- `skills/plan-issue/SKILL.md`
- `skills/coding-agent/SKILL.md`

`SKILL.md` at repo root is a compatibility entry for single-skill setups.

## Behavior Model

1. Use `plan-issue` for planning/scoping tasks.
2. Wait for explicit `APPROVE`.
3. Use `coding-agent` to execute the approved plan with ACP-first routing, then CLI fallback.

Guardrail: no bypass flags (`--yolo`, `--dangerously-skip-permissions`) unless explicitly requested.

## Review Routing + Run Status Contract

- Plan artifact review: use `./scripts/plan-review` or `./scripts/plan-review-live`.
- PR/code review: use `codex review --base ...` directly or `./scripts/safe-review.sh`.
- Never provide a manual review summary before running the matching wrapper/command.

Long-run wrapper status events (hard-fail policy):
- `RUN_EVENT start`
- `RUN_EVENT heartbeat` every 20s after 30s elapsed
- `RUN_EVENT interrupted` on signal/timeout/interruption
- `RUN_EVENT failed` on non-interruption errors
- `RUN_EVENT done` on success

## Usage

In OpenClaw:

```text
/coding
/plan <task>
/plan-review [--plan <path>]
/plan-review-live [--plan <path>]
/review_pr <number|url>
```

CLI wrappers:

```bash
# Generate a read-only plan artifact
./scripts/plan --engine codex --repo /path/to/repo "Implement feature X"

# Review latest generated plan (or pass --plan explicitly)
./scripts/plan-review --repo /path/to/repo

# Review with interactive section checkpoints (Architecture -> Code Quality -> Tests -> Performance)
# Default engine: Lobster workflow in this repo (falls back to legacy engine if lobster is unavailable)
./scripts/plan-review-live --repo /path/to/repo

# Non-TTY/chat-safe live review finalization (no interactive prompts)
./scripts/plan-review-live --repo /path/to/repo --decisions "1A,2B,3A,4A" --blocking none
# or
./scripts/plan-review-live --repo /path/to/repo --resolve-file /path/to/decisions.json

# Force legacy engine explicitly
./scripts/plan-review-live --engine legacy --repo /path/to/repo

# Resume a paused Lobster approval run
./scripts/plan-review-live --resume-token <token> --output /path/to/repo/.ai/plan-reviews/<same-file>.md
# Optional: fail instead of auto-restarting when session state is missing
./scripts/plan-review-live --resume-token <token> --resume-missing-state error --output /path/to/repo/.ai/plan-reviews/<same-file>.md

# Execute an approved plan artifact
# Requires latest plan-review metadata to be ready unless --force is used.
# In non-TTY orchestration, this fails fast if plan status is not APPROVED.
# Wrapper output remains text by default; pass --output json explicitly for machine-readable automation.
./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md

# Supervise review/fix loop until P0/P1/P2 clear (optional PR open/update)
./scripts/review-loop-supervisor --repo /path/to/repo --base main
./scripts/review-loop-supervisor --repo /path/to/repo --base main \
  --test-cmd "npm run lint" \
  --test-cmd "npm test" \
  --open-pr --issue 50

# Validate an approved plan without mutating or launching (machine-readable output stays opt-in)
# Dry-run now validates plan/review/approval state only; it no longer requires codex/tmux to be installed.
./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md --dry-run --output json
```

## Wrapper Architecture

The wrapper surface is split intentionally:

```text
Bash wrappers:
- argv/env parsing
- backend execution
- text streaming
- tmux lifecycle and trusted RUN_EVENT handling

Python policy core:
- review-base selection
- plan-path and review-gate validation
- approval decisioning
- structured result normalization
```

This keeps transport behavior in shell while moving duplicated policy into one tested core.

## Command Map (Telegram/OpenClaw)

These aliases are routing hints at the channel layer. Behavior is enforced by skills.

- `/coding` → compatibility entry skill (`SKILL.md`), routes plan-first + execution flow
- `/plan <task>` → `skills/plan-issue/SKILL.md` (plan only, no writes)
- `/plan-review [--plan <path>]` → batch plan review (single-pass full report, marks unresolved blocking decisions)
- `/plan-review-live [--plan <path>]` → Lobster workflow checkpoints by default (in-repo `workflows/plan-review-live.lobster`), legacy fallback if Lobster is unavailable; in non-TTY/chat use `--decisions/--blocking` or `--resolve-file` to finalize readiness metadata
- `/review_pr <number|url>` → review workflow with standards checks via `references/reviews.md`

Supervisor wrapper (CLI-only, no slash alias):
- `./scripts/review-loop-supervisor` → finite-state review/fix supervisor with machine-checkable milestone events and `.ai/review-loops/latest.json` state output.

### Approval Semantics

- `APPROVE` applies only to the latest plan in the **current conversation context**.
- Approval is not global, does not carry across unrelated threads/chats, and does not auto-approve future plans.
- If no pending plan exists in context, return: `No pending plan found. Run /plan first.`
- Plan approval is text-gated via `APPROVE`; this workflow does not require a separate "ExitPlanMode" tool.

## OpenClaw Setup: Add Coding Skill Slash Commands

To enable this skill’s aliases for your team, add these entries under
`telegram.customCommands` in OpenClaw.

1. Open your OpenClaw JSON config.
2. Find the `telegram` block and replace or extend `customCommands` in place.
3. Save the file and restart/reload OpenClaw.
4. Verify in Telegram that commands appear in the bot command list.

```json
[
  { "command": "coding", "description": "Run coding-agent workflow" },
  { "command": "plan", "description": "Plan implementation only (no writes)" },
  { "command": "plan-review", "description": "Review generated plan in read-only mode" },
  { "command": "plan-review-live", "description": "Interactive plan review with decision checkpoints" },
  { "command": "review_pr", "description": "Review PR + standards check" }
]
```

If some commands already exist in your config, keep existing entries and append only missing new ones to avoid overriding other aliases.

Example resolve file for non-TTY finalization:

```json
{
  "resolved_decisions": ["1A", "2B", "3A", "4A"],
  "blocking_decisions": []
}
```

## Requirements

- GitHub CLI (`gh`)
- `jq`
- `python3`
- One of: Codex CLI (`codex`) or Claude Code CLI (`claude` / `~/.claude/local/claude`)
- GNU `timeout` command (coreutils on macOS)
- Optional: tmux (wrapper workflows)

## Validation

```bash
./scripts/doctor
./scripts/smoke-wrappers.sh
```

## Canonical Local Repo Path

- Canonical local clone path: `/home/art/projects/skills/shared/coding-agent`
- Do not maintain independent duplicate clones for this repository.
- Wrappers fail fast when run from a non-canonical clone.
- Temporary override (recovery-only): `CODING_AGENT_ALLOW_NONCANONICAL=1`
- CI bypass: canonical-path guard is bypassed automatically when `CI=true`/`GITHUB_ACTIONS=true`.

## ACP-First Wrapper Routing

Execution routing in `scripts/safe-fallback.sh` is mode-specific:

- `impl`: ACP first (via `acpx`), then CLI fallback chain
- `review`: `codex review --base` first, then ACP fallback, then remaining CLI fallback chain
- direct ACPX path: `scripts/acpx-direct` only (raw `acpx ...` invocations are not allowed in coding-agent orchestration)

- `CODING_AGENT_ACP_ENABLE`: `1` (default) or `0` to skip ACP attempt
- `CODING_AGENT_ACP_AGENT`: ACP harness alias (default: `codex`)
- `CODING_AGENT_ACPX_CMD`: executable path override for ACPX binary

Direct ACPX examples (sanctioned wrapper):

```bash
./scripts/acpx-direct --cwd /path/to/repo --format quiet codex sessions ensure --name "ca-codex-$(basename /path/to/repo)"
./scripts/acpx-direct --cwd /path/to/repo --format quiet codex -s "ca-codex-$(basename /path/to/repo)" "Reply with READY only."
```

Known runtime limitation:
- Issue #43 tracks upstream ACP observability and relay profile alias behavior.
- Repo-side mitigations and bounded fallbacks are documented in `references/acp-troubleshooting.md`.

## Verbosity Configuration

The coding-agent skill supports an opt-in execution progress verbosity mode via
`CODING_AGENT_VERBOSE`.

- Default: off (concise updates)
- On: structured progress updates (`Now`, `Why`, `Next`) during execution
- Scope: progress updates only (not globally longer planning/review prose)

Truthy values (case-insensitive): `1`, `true`, `on`, `yes`, `verbose`

Planning/review wrapper heartbeat settings:
- `CODING_AGENT_STATUS_PING_SECONDS` (default `20`)
- `CODING_AGENT_LONG_RUN_THRESHOLD_SECONDS` (default `30`)

Review-loop supervisor heartbeat setting:
- `--status-interval-seconds` (default `120`)

One-shot example:

```bash
CODING_AGENT_VERBOSE=1 ./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md
```

Persistent OpenClaw gateway setup:

1. Add to `~/.config/systemd/user/secrets.conf`:
   `CODING_AGENT_VERBOSE="1"`
2. Reload the user unit:

```bash
systemctl --user daemon-reload && systemctl --user restart openclaw-gateway.service
```
## CI Workflows

- `wrapper-smoke.yml`: wrapper syntax, drift, and smoke validation.
- `pr-policy.yml`: PR policy caller for `main`/`master` pull requests.
- `reusable-pr-checks.yml`: reusable branch/title/linked-issue policy checks with concurrency cancellation.

## References

- `references/WORKFLOW.md`
- `references/STANDARDS.md`
- `references/tooling.md`
- `references/codex-cli.md`
- `references/claude-code.md`
- `references/reviews.md`
- `references/lobster-workflows.md`
- `references/acp-troubleshooting.md`

## License

MIT
