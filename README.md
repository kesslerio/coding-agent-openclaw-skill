# coding-agent OpenClaw Skill 💻

OpenClaw skill for coding assistant using agent CLIs (Codex, Claude Code). Primary mode: direct CLI with session resume and permission bypass. Secondary mode: tmux wrappers for durable TTY sessions.

## Features

- **Session Resume Workflows** — Multi-phase issue → implement → PR → review → fix cycles with full context preservation
- **Agent CLI Integration** — Direct CLI execution with permission bypass (`--yolo`, `--dangerously-skip-permissions`)
- **Auto-Reasoning** — Diff-size-based reasoning effort scaling for reviews (threshold: 500 changed lines)
- **PR Review Workflow** — Checkout PRs and run reviews with auto-blocking and cleanup
- **Dev Persona** — Pragmatic code reviews with clear feedback
- **Git Workflow Documentation** — Branch, commit, PR conventions
- **Code Quality Standards** — KISS, YAGNI, DRY, SRP principles

## Requirements

- GitHub CLI (`gh`)
- One of: Codex CLI (`codex`) or Claude Code CLI (`claude`)
- Optional: tmux (for durable TTY sessions and wrapper scripts)

## Installation

```bash
# Clone to OpenClaw skills directory
cd /home/art/clawd/skills
git clone https://github.com/kesslerio/coding-agent-openclaw-skill.git coding-agent
```

## Usage

In OpenClaw, activate with:
```
/coding
```

### Direct CLI (Primary)

```bash
# Implementation (Codex)
codex --yolo exec "Implement feature X. No questions."

# Implementation (Claude Code)
claude -p --dangerously-skip-permissions "Implement feature X"

# Resume last session (context preserved)
codex exec resume --last
claude -p -c "Fix the review findings"
```

### Wrapper Scripts (Secondary)

```bash
# PR Review (10 min timeout, blocking, auto-reasoning)
gh pr checkout <PR>
./scripts/code-review "Review PR #N: bugs, security, quality"

# Implementation (3 min timeout, tmux)
./scripts/code-implement "Implement feature X"
```

## Files

- `SKILL.md` — Full skill documentation (includes Dev persona)
- `references/WORKFLOW.md` — Coding workflow, Git integration, multi-phase workflows
- `references/STANDARDS.md` — Coding standards & rules
- `references/quick-reference.md` — Command quick reference
- `references/tooling.md` — CLI usage, session management, timeouts
- `references/claude-code.md` — Claude Code CLI reference and session resume
- `references/reviews.md` — Review + PR/issue writing patterns

## GitHub Hygiene

- PR titles: `type(scope): imperative summary` (or repo override).
- Issue titles:
  - Feature: `feat: <capability> (for <surface>)`
  - Bug: `bug: <symptom> when <condition>`
  - Tracking: `TODO: <cleanup> after <dependency>`
- PR bodies must include: `What`, `Why`, `Tests`, `AI Assistance`.
- `Tests` should be exact commands; `AI Assistance` should include prompt/session link when available.

## License

MIT
