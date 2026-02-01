# coding-agent Reference

## ⛔ STOP-AND-VERIFY (Before ANY Implementation)

**Say this out loud before writing/changing any code:**
```
STOP. Before I proceed, let me verify:
□ Am I using Codex MCP/CLI? (not Edit/Write tools)
□ Am I on a feature branch? (not main)
□ Will I create a PR before completing this task?
□ Am I using adequate timeout? (≥300s for reviews)
□ Am I avoiding --max-turns? (let it complete naturally)
```
**If any box is unchecked → STOP and fix before proceeding.**

## Forbidden Flags & Minimum Timeouts

```
❌ FORBIDDEN: --max-turns (any value)
❌ FORBIDDEN: timeout < 300s for reviews

✅ Reviews: TIMEOUT=300 minimum
✅ Architecture: TIMEOUT=600 minimum
```

## Tool Fallback Chain

```
Implementation: Codex MCP → Claude MCP → Codex CLI → Claude CLI → BLOCKED
Reviews:        Codex CLI → Claude MCP → Claude CLI → BLOCKED

⛔ NEVER skip to direct edits - request user override instead
```

## Wrapper Scripts (Recommended)
```bash
# Auto-fallback (tries all tools in order)
./scripts/safe-fallback.sh impl "Implement feature X"
./scripts/safe-fallback.sh review "Review this PR for bugs"

# Reviews (enforces 300s min, blocks --max-turns)
TIMEOUT=300 ./scripts/safe-review.sh claude -p "..."
TIMEOUT=600 ./scripts/safe-review.sh codex review --base main

# Implementation (checks branch, blocks --max-turns)
TIMEOUT=180 ./scripts/safe-impl.sh codex --yolo exec "..."
```

## Claude MCP Commands
```bash
# Implementation via Claude MCP
mcporter call claude.Task 'prompt="Implement X"' 'subagent_type="Bash"'

# Review via Claude MCP
mcporter call claude.Task 'prompt="Review for bugs"' 'subagent_type="general-purpose"'
```

## Pre-Completion Checklist

Before marking ANY task complete:
- [ ] On feature branch? (not main)
- [ ] PR created with URL?
- [ ] Used Codex/Claude CLI? (not direct edits)
- [ ] Code review posted to PR?
- [ ] Standards review posted to PR?

**Unchecked box = Task NOT complete.**

---

## Quick Reference

### Activate
Use `/coding` in OpenClaw to activate this skill.

### Codex Commands

**High Thinking Mode (complex tasks):**
```bash
codex exec --model gpt-5.2-codex -c model_reasoning_effort="high" "Your task"
```

**PR Review:**
```bash
cd /path/to/repo
gh pr checkout <PR>
codex review --base main --title "PR #N: Description"
```

**Non-interactive:**
```bash
codex review --commit <SHA> --base <BRANCH> --title "Brief description"
```

### Git Workflow
```bash
# Checkout and review
gh pr checkout <PR> --repo owner/repo
codex review --base main

# Merge (Martin only)
gh pr merge <PR> --repo owner/repo --admin --merge
```

## Command Reference

| Task | Command |
|------|---------|
| List PRs | `gh pr list --repo owner/repo` |
| View PR | `gh pr view <PR> --json number,title,state` |
| Checkout PR | `gh pr checkout <PR>` |
| Review PR | `codex review --base main --title "PR #N"` |
| Check CI | `gh pr checks <PR> --repo owner/repo` |
| Merge PR | `gh pr merge <PR> --repo owner/repo --admin --merge` |

## Code Quality Standards

- Functions: max 30-40 lines
- Classes: max 500 lines
- Files: max 500 lines
- KISS, YAGNI, DRY, SRP principles

## Issue Priority (P0-P3)

- **P0**: Critical (security, data loss)
- **P1**: High (major feature broken)
- **P2**: Medium (minor features)
- **P3**: Low (nice-to-have)

## tmux for Interactive Sessions

```bash
SOCKET="${TMPDIR:-/tmp}/openclaw-tmux-sockets/openclaw.sock"
SESSION=codex-review

tmux -S "$SOCKET" new-session -d -s "$SESSION"
tmux -S "$SOCKET" send-keys -t "$SESSION" "codex review --base main" Enter
tmux -S "$SOCKET" capture-pane -p -t "$SESSION" -S -200
```
