# coding-agent OpenClaw Skill 💻

OpenClaw skill for coding assistant with Codex CLI integration. Activates dev persona for pragmatic, experienced developer guidance.

## Features

- **Codex CLI Integration** — Use `gpt-5.2-codex` in high thinking mode for complex coding tasks
- **PR Review Workflow** — Checkout PRs and run Codex reviews with GitHub CLI
- **Dev Persona** — Pragmatic code reviews with clear feedback
- **Git Workflow Documentation** — Branch, commit, PR conventions
- **Code Quality Standards** — KISS, YAGNI, DRY, SRP principles

## Installation

```bash
# Clone to OpenClaw skills directory
cd /home/art/clawd/skills
git clone https://github.com/kesslerio/coding-agent-clawdhub-skill.git coding-agent
```

## Usage

In OpenClaw, activate with:
```
/coding
```

Then use Codex commands (tmux-based):
```bash
# PR Review
gh pr checkout <PR>
./scripts/code-review "Review PR #N: bugs, security, quality"

# Complex task with high reasoning
./scripts/tmux-run timeout 600s codex --yolo exec \
  --model gpt-5.2-codex -c model_reasoning_effort="high" "Your task"
```

Note: tmux wrappers are non-blocking. Set `CODEX_TMUX_WAIT=1` to wait for completion.

## Files

- `SKILL.md` — Full skill documentation (includes Dev persona)
- `references/STANDARDS.md` — Coding standards & rules
- `references/WORKFLOW.md` — Coding workflow & Git integration
- `references/quick-reference.md` — Command quick reference

## Requirements

- OpenClaw
- Codex CLI (`gpt-5.2-codex`)
- GitHub CLI (`gh`)
- tmux

## License

MIT
