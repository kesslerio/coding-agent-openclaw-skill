# coding-agent Clawdbot Skill 💻

Clawdbot skill for coding assistant with Codex CLI integration. Activates dev persona for pragmatic, experienced developer guidance.

## Features

- **Codex CLI Integration** — Use `gpt-5.2-codex` in high thinking mode for complex coding tasks
- **PR Review Workflow** — Checkout PRs and run Codex reviews with GitHub CLI
- **Dev Persona** — Pragmatic code reviews with clear feedback
- **Git Workflow Documentation** — Branch, commit, PR conventions
- **Code Quality Standards** — KISS, YAGNI, DRY, SRP principles

## Installation

```bash
# Clone to Clawdbot skills directory
cd /home/art/clawd/skills
git clone https://github.com/kesslerio/coding-agent-clawdhub-skill.git coding-agent
```

## Usage

In Clawdbot, activate with:
```
/coding
```

Then use Codex commands:
```bash
# PR Review
gh pr checkout <PR>
codex review --base main --title "PR #N: Description"

# Complex task with high reasoning
codex exec --model gpt-5.2-codex -c model_reasoning_effort="high" "Your task"
```

## Files

- `SKILL.md` — Full skill documentation
- `dev.md` — Dev persona configuration
- `references/CODING.md` — Coding guidelines
- `references/GITHUB.md` — Git workflow
- `references/RULES.md` — Coding standards
- `references/quick-reference.md` — Command quick reference

## Requirements

- Clawdbot
- Codex CLI (`gpt-5.2-codex`)
- GitHub CLI (`gh`)

## License

MIT
