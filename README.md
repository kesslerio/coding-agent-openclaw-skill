# coding-agent OpenClaw Skill 💻

OpenClaw skill for coding assistant with Codex CLI integration. Activates dev persona for pragmatic, experienced developer guidance.

## Features

- **Codex CLI Integration** — Use `gpt-5.3-codex` with stable review defaults (`medium` reasoning, blocking tmux, longer timeout)
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

# Complex task (explicit override only when truly needed)
./scripts/tmux-run timeout 600s codex --yolo exec \
  --model gpt-5.3-codex -c model_reasoning_effort="medium" "Your task"
```

Note: `code-review` now blocks by default and cleans up its tmux session when complete.

## Files

- `SKILL.md` — Full skill documentation (includes Dev persona)
- `references/STANDARDS.md` — Coding standards & rules
- `references/WORKFLOW.md` — Coding workflow & Git integration
- `references/quick-reference.md` — Command quick reference
- `references/reviews.md` — Review + PR/issue writing patterns

## GitHub Hygiene

- PR titles: `type(scope): imperative summary` (or repo override).
- Issue titles:
  - Feature: `feat: <capability> (for <surface>)`
  - Bug: `bug: <symptom> when <condition>`
  - Tracking: `TODO: <cleanup> after <dependency>`
- PR bodies must include: `What`, `Why`, `Tests`, `AI Assistance`.
- `Tests` should be exact commands; `AI Assistance` should include prompt/session link when available.

## Requirements

- OpenClaw
- Codex CLI (`gpt-5.3-codex`)
- GitHub CLI (`gh`)
- tmux
- Optional: OpenClaw tmux skill (for `wait-for-text.sh` helpers)

## License

MIT
