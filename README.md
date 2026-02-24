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
```

CLI wrappers:

```bash
# Generate a read-only plan artifact
./scripts/plan --engine codex --repo /path/to/repo "Implement feature X"

# Execute an approved plan artifact
./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md
```

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
