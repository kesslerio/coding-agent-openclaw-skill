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
- `/review_pr <number|url>` → review workflow with standards checks via `references/reviews.md`

### Approval Semantics

- `APPROVE` applies only to the latest plan in the **current conversation context**.
- Approval is not global, does not carry across unrelated threads/chats, and does not auto-approve future plans.
- If no pending plan exists in context, return: `No pending plan found. Run /plan first.`

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
  { "command": "review_pr", "description": "Review PR + standards check" }
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
