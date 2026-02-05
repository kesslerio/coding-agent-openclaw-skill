# coding-agent Reference

## Contents
- STOP-AND-VERIFY (Before ANY Implementation)
- Forbidden Flags & Minimum Timeouts
- Tool Fallback Chain
- Wrapper Scripts (Recommended)
- Pre-Completion Checklist
- Quick Reference
- Command Reference
- Code Quality Standards
- Issue Priority (P0-P3)
- tmux for Interactive Sessions

## ⛔ STOP-AND-VERIFY (Before ANY Implementation)

**Say this out loud before writing/changing any code:**
```
STOP. Before I proceed, let me verify:
□ Am I using Codex CLI in tmux? (not Edit/Write tools)
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
Implementation: Codex CLI (tmux) → Codex CLI (direct) → Claude CLI → BLOCKED
Reviews:        Codex CLI (tmux) → Codex CLI (direct) → Claude CLI → BLOCKED

⛔ NEVER skip to direct edits - request user override instead
```

## Wrapper Scripts (Recommended)

```bash
# Preferred: tmux-based wrappers
./scripts/code-implement "Implement feature X"
./scripts/code-review "Review this PR for bugs"

# Enforcement wrappers (use tmux for codex unless CODEX_TMUX_DISABLE=1)
TIMEOUT=300 ./scripts/safe-review.sh codex review --base main --title "PR Review"
TIMEOUT=180 ./scripts/safe-impl.sh codex --yolo exec "Implement feature X"
```

## Pre-Completion Checklist

Before marking ANY task complete:
- [ ] On feature branch? (not main)
- [ ] PR created with URL?
- [ ] Used Codex/Claude CLI in tmux? (not direct edits)
- [ ] Code review posted to PR?
- [ ] Standards review posted to PR?

**Unchecked box = Task NOT complete.**

---

## Quick Reference

### Activate
Use `/coding` in OpenClaw to activate this skill.

### Codex Commands

**High Thinking Mode (complex tasks, tmux):**
```bash
./scripts/tmux-run timeout 600s codex --yolo exec \
  --model gpt-5.2-codex -c model_reasoning_effort="high" "Your task"
```

**PR Review (in tmux):**
```bash
cd /path/to/repo
./scripts/code-review "Review PR #N: bugs, security, quality"
```

**Non-interactive (direct, only if tmux unavailable):**
```bash
timeout 300s codex review --base main --title "PR Review"
```

### Git Workflow
```bash
# Checkout and review
gh pr checkout <PR> --repo owner/repo
./scripts/code-review "Review PR #<PR> for bugs and security"

# Merge (Martin only)
gh pr merge <PR> --repo owner/repo --admin --merge
```

## Command Reference

| Task | Command |
|------|---------|
| List PRs | `gh pr list --repo owner/repo` |
| View PR | `gh pr view <PR> --json number,title,state` |
| Checkout PR | `gh pr checkout <PR>` |
| Review PR | `./scripts/code-review "Review PR #N for bugs, security, quality"` |
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
SOCKET_DIR="${OPENCLAW_TMUX_SOCKET_DIR:-${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/openclaw-tmux-sockets}}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/openclaw.sock"
SESSION=codex-review

tmux -S "$SOCKET" new-session -d -s "$SESSION" -n shell
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -l -- "codex review --base main" Enter

# Monitor
tmux -S "$SOCKET" attach -t "$SESSION"
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
```
