# coding-agent Reference

## Quick Reference

### Activate
Use `/coding` in OpenClaw to activate this skill.

### Process Checklist (Before Completing Any Task)

**MUST verify before marking task complete:**
- [ ] On feature branch? (not main)
- [ ] PR created?
- [ ] Used specified tools? (codex/claude/gemini if requested)
- [ ] Code review posted to PR?
- [ ] Standards review posted to PR?

**If any box is unchecked → STOP and fix before proceeding.**

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
