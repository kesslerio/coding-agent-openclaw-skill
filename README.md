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
3. Use `coding-agent` to execute the approved plan.

Guardrail: no bypass flags (`--yolo`, `--dangerously-skip-permissions`) unless explicitly requested.

## Usage

In OpenClaw:

```text
/coding
/plan <task>
/approve
/review_pr <number|url>
```

CLI wrappers:

```bash
# Generate a read-only plan artifact
./scripts/plan --engine codex --repo /path/to/repo "Implement feature X"

# Execute an approved plan artifact
./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md
```

## Command Map (Telegram/OpenClaw)

These aliases are routing hints at the channel layer. Behavior is enforced by skills.

- `/coding` → compatibility entry skill (`SKILL.md`), routes plan-first + execution flow
- `/plan <task>` → `skills/plan-issue/SKILL.md` (plan only, no writes)
- `/approve` → approves execution of the latest plan in the current session/thread
- `/review_pr <number|url>` → review workflow with standards checks via `references/reviews.md`

### Approval Semantics

- `APPROVE` (or `/approve`) applies only to the latest plan in the **current conversation context**.
- Approval is not global, does not carry across unrelated threads/chats, and does not auto-approve future plans.
- If no pending plan exists in context, `/approve` should return: `No pending plan found. Run /plan first.`

## OpenClaw Setup: Add Slash Commands

To enable these aliases for your team, add them to OpenClaw under `telegram.customCommands`.

1. Open your OpenClaw JSON config.
2. Find the `telegram` block and replace or extend `customCommands` in place.
3. Save the file and restart/reload OpenClaw.
4. Verify in Telegram that commands appear in the bot command list.

```json
[
  { "command": "daily", "description": "Daily standup (priorities, blockers)" },
  { "command": "weekly", "description": "Weekly priorities" },
  { "command": "done24h", "description": "Done in last 24 hours" },
  { "command": "done7d", "description": "Done in last 7 days" },
  { "command": "work", "description": "Switch to work agent" },
  { "command": "demo_followup", "description": "Post-demo follow-up for a deal" },
  { "command": "reengagement", "description": "Manual demo re-engagement run" },
  { "command": "coding", "description": "Run coding-agent workflow" },
  { "command": "plan", "description": "Plan implementation only (no writes)" },
  { "command": "approve", "description": "Approve last plan and execute" },
  { "command": "review_pr", "description": "Review PR + standards check" },
  { "command": "tasks", "description": "Show current priorities/tasks" },
  { "command": "pipeline", "description": "Work pipeline snapshot" },
  { "command": "followups_today", "description": "Deals needing follow-up today" },
  { "command": "remind", "description": "Create reminder (one-shot)" },
  { "command": "digest", "description": "Curated daily digest" },
  { "command": "heartbeat", "description": "Run one heartbeat check now" },
  { "command": "status", "description": "Show active runs/subagents" }
]
```

If some commands already exist in your config, keep existing entries and append only missing new ones to avoid overriding other aliases.

## Requirements

- GitHub CLI (`gh`)
- One of: Codex CLI (`codex`) or Claude Code CLI (`claude` / `~/.claude/local/claude`)
- GNU `timeout` command (coreutils on macOS)
- Optional: tmux (wrapper workflows)

## Validation

```bash
./scripts/doctor
./scripts/smoke-wrappers.sh
```

## References

- `references/WORKFLOW.md`
- `references/STANDARDS.md`
- `references/tooling.md`
- `references/codex-cli.md`
- `references/claude-code.md`
- `references/reviews.md`

## License

MIT
