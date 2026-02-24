# coding-agent Skill Pack 💻

Plan-first coding skill pack for Codex/OpenAI Skills and Claude Code Skills.

## Skill Layout

This repo now ships two sibling skills:

- `.agents/skills/plan-issue/SKILL.md` (Codex/OpenAI)
- `.agents/skills/coding-agent/SKILL.md` (Codex/OpenAI)
- `.claude/skills/plan-issue/SKILL.md` (Claude Code)
- `.claude/skills/coding-agent/SKILL.md` (Claude Code)

`SKILL.md` at repo root is kept as a compatibility entry for single-skill setups.

## Behavior Model

1. Use `plan-issue` for planning/scoping tasks.
2. Wait for explicit `APPROVE`.
3. Use `coding-agent` to execute the approved plan.

Guardrail: no bypass flags (`--yolo`, `--dangerously-skip-permissions`) unless explicitly requested.

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
