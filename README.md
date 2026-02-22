# coding-agent OpenClaw Skill 💻

OpenClaw skill for coding assistant using agent CLIs (Codex, Claude Code). Primary mode: direct CLI with session resume and permission bypass. Secondary mode: tmux wrappers for durable TTY sessions.

## Features

- **Session Resume Workflows** — Multi-phase issue → implement → PR → review → fix cycles with full context preservation
- **Agent CLI Integration** — Direct CLI execution with permission bypass (`--yolo`, `--dangerously-skip-permissions`)
- **PR Review Workflow** — Direct CLI reviews with proper timeouts
- **Plan Mode Workflow** — Read-only plan generation with machine-checkable approval gate before implementation
- **Self-Auditing Workflow** — Mandatory implementation + review checklists with VERIFIED/UNVERIFIED command labeling
- **Dev Persona** — Pragmatic code reviews with clear feedback
- **Git Workflow Documentation** — Branch, commit, PR conventions
- **Code Quality Standards** — KISS, YAGNI, DRY, SRP principles

## Requirements

- GitHub CLI (`gh`)
- One of: Codex CLI (`codex`) or Claude Code CLI (`claude`)
- GNU `timeout` command (coreutils on macOS)
- Optional: tmux (for durable TTY sessions and wrapper scripts)

## Installation

```bash
# Clone to OpenClaw skills directory
cd /home/art/clawd/skills
git clone https://github.com/kesslerio/coding-agent-openclaw-skill.git coding-agent
```

## Preflight and Validation

```bash
# Verify local tooling before running wrappers
./scripts/doctor

# Run wrapper behavior smoke tests
./scripts/smoke-wrappers.sh
```

## Usage

In OpenClaw, activate with:
```
/coding
```

Plan-first shortcut:
```
/plan <task>
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

### Reviews (Direct CLI)

```bash
gh pr checkout <PR>
timeout 600s codex review --base <base> --title "Review PR #N"
```

### Wrapper Scripts (Plan + Implementation)

```bash
# Plan mode (read-only planning artifact)
./scripts/code-plan --engine codex --repo /path/to/repo "Implement feature X"

# Execute plan (prompts for approval if status is still PENDING)
./scripts/code-implement --plan /path/to/repo/.ai/plans/<plan>.md

# Direct implementation (3 min timeout, tmux)
./scripts/code-implement "Implement feature X"
```

Implementation mode policy can be configured:

```bash
export CODING_AGENT_IMPL_MODE=direct  # direct|tmux|auto
```

## Files

- `SKILL.md` — Full skill documentation (includes Dev persona)
- `references/WORKFLOW.md` — Coding workflow, Git integration, multi-phase workflows
- `references/STANDARDS.md` — Coding standards & rules
- `references/quick-reference.md` — Command quick reference
- `references/tooling.md` — CLI usage, session management, timeouts
- `references/codex-cli.md` — Canonical Codex CLI reference and policy matrix
- `references/claude-code.md` — Claude Code CLI reference and session resume
- `scripts/code-plan` — Plan mode wrapper (read-only execution + artifact validation)
- `references/reviews.md` — Review + PR/issue writing patterns
- `references/templates/plan-system-prompt.txt` — Deterministic plan-mode system prompt
- `references/templates/plan-template.md` — Canonical plan structure template

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
