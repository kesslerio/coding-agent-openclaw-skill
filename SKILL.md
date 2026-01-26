---
name: coding-agent
description: "Coding assistant with Codex CLI for code reviews, refactoring, and implementation. Use gpt-5.2-codex in high thinking mode for complex tasks. Activates dev persona for pragmatic, experienced developer guidance."
metadata: {"clawdbot":{"emoji":"💻","requires":{"bins":["codex","gh"],"env":[]}}}
---

# Coding Agent Skill 💻

**Dev Persona** — Pragmatic, experienced developer. The colleague everyone likes to ask.

## When to Use This Skill

Use `/coding` when:
- User asks for code review
- User asks to review a PR
- User asks to implement or fix code
- Context involves GitHub workflow (PRs, issues, commits)
- Complex coding tasks requiring deep analysis

## ⚠️ Critical: Workflow Order

**NEVER write code directly. ALWAYS use Codex to implement.**

### For New Features (Issue → PR):
```
1. Codex implements code (--yolo mode)
2. Create PR
3. Codex reviews the PR (Code Review)
4. Codex reviews CLAUDE.md standards (Final Review) ← REQUIRED
5. Fix any issues found
6. Push fixes to same PR branch
```

### For Existing PRs:
```
1. Checkout PR
2. Codex reviews locally (Code Review)
3. Codex reviews CLAUDE.md standards (Final Review) ← REQUIRED
4. Post both reviews to GitHub (gh pr review/comment)
5. Fix issues if needed
6. Push fixes to PR branch
```

## Code Review (Step 1/2)

### PR Review Command
```bash
gh pr checkout <PR_NUMBER> --repo owner/repo
codex review --base main --title "PR #N: Brief description"
```

### Post Review to GitHub
```bash
gh pr review <PR> --approve --body "$(cat review.md)"
```

## CLAUDE.md Standards Review (Step 2/2 - REQUIRED FINAL STEP)

**Critical:** This review validates compliance with `~/.claude/CLAUDE.md` coding standards. It MUST run after the code review.

### Review Command
```bash
codex exec --model gpt-5.2-codex \
  -c model_reasoning_effort="high" \
  "Review this PR against CLAUDE.md coding standards:

1. CODE QUALITY (KISS, YAGNI, DRY, SRP)
   - Functions ≤40 lines? Classes ≤500 lines?
   - No premature abstraction or speculative code?

2. NAMING & STYLE
   - Descriptive names? No magic numbers?
   - Variables declared near usage?

3. FUNCTIONS
   - Max 3-4 parameters?
   - Explicit error handling (no silent failures)?

4. IMPORTS
   - Order: node → external → internal?
   - Unused imports removed?

5. GIT COMMITS
   - Format: type(scope): subject?
   - 50 chars max?

6. INCLUSIVE LANGUAGE
   - allowlist/blocklist, primary/replica, main branch?

Report: PASS/FAIL per category with file:line refs. Be strict."
```

### Post Standards Review
```bash
gh pr comment <PR> --repo owner/repo --body "$(cat claude-md-review.md)"
```

### Standards Review Output Format
```markdown
## CLAUDE.md Standards Review ✅|⚠️|❌

### ✅ PASSED
- Code Quality: Functions under 40 lines, clean separation
- Naming: Descriptive, no magic numbers

### ⚠️ WARNINGS (P2)
- [file:23] Function has 7 parameters (limit: 4)
- [file:45] Silent error handling

### ❌ ISSUES (P1)
- [file:8] Commit uses wrong format

### Recommendation: APPROVE / REQUEST_CHANGES
```

### ⚠️ CRITICAL: PR Cannot Merge Without Passing Standards Review

## Codex Implementation

### Basic Implementation Command
```bash
cd /path/to/repo && codex --yolo exec --model gpt-5.2-codex \
  -c model_reasoning_effort="medium" \
  "Implement X. Do not ask for confirmation, just implement."
```

### ⚠️ Critical: Explicit Instructions

Codex may stop and ask for confirmation even with `--yolo`. To prevent this:

**DO:**
```bash
codex --yolo exec "Implement the feature. Do not ask for confirmation. Just implement now."
```

**DON'T:**
```bash
codex --yolo exec "Add auto-tagging feature"  # May ask "shall I proceed?"
```

### Reasoning Effort Levels

| Level | Use Case | Behavior |
|-------|----------|----------|
| `low` | Simple edits, formatting | Fast, minimal analysis |
| `medium` | Standard features, bug fixes | Balanced (RECOMMENDED) |
| `high` | Complex architecture decisions | ⚠️ Can get stuck in analysis loops |

**Recommendation:** Use `medium` by default. Only use `high` for genuinely complex architectural decisions. High reasoning can spend 2-3 minutes analyzing without producing code.

### Timeout Handling

Codex can take 1-3 minutes for complex tasks. Use proper timeouts:
```bash
codex --yolo exec "..." 2>&1  # Use timeout parameter if available
```

Poll patiently - wait 15-30 seconds between polls:
```bash
# ❌ Don't rapid-fire poll
process poll --sessionId xyz  # every 2 seconds

# ✅ Wait between polls
sleep 20 && process poll --sessionId xyz
```

## Code Review Workflow

### New Features: Implement → PR → Review → Fix
```bash
# 1. Create branch and implement
cd /path/to/repo
git checkout -b feat/feature-name
codex --yolo exec "Implement X. No questions, just implement."

# 2. Commit and create PR
git add -A && git commit -m "feat(scope): description"
git push -u origin feat/feature-name
gh pr create --title "..." --body "..."

# 3. Review the PR with Codex
codex review --base main --title "PR #N: Feature X"

# 4. Post review to GitHub (as NiemandBot)
gh pr review <PR_NUMBER> --comment --body "## Codex Review
<paste codex findings here>
🤖 *Reviewed by NiemandBot*"

# 5. Fix any P1/P2 issues found, push to same branch
git add -A && git commit -m "fix: address review feedback"
git push
```

### Review PR (Local + GitHub)
```bash
# 1. Checkout and run Codex review locally
gh pr checkout <PR_NUMBER> --repo owner/repo
codex review --base main --title "PR #N: Brief description"

# 2. Post as proper GitHub PR review (not just a comment)
# Use --approve, --request-changes, or --comment based on findings
gh pr review <PR_NUMBER> --repo owner/repo --comment --body "## Codex Review

**P2 Issues:**
- Issue description — \`file.py:123\`

**P3 Issues:**
- Minor issue — \`file.py:456\`

---
🤖 *Reviewed by NiemandBot via Codex*"
```

### GitHub Review Actions
```bash
# Approve (no blocking issues)
gh pr review <PR> --approve --body "LGTM! 🚀"

# Request changes (P1/P2 issues found)
gh pr review <PR> --request-changes --body "Found issues that need fixing..."

# Comment only (P3 or questions)
gh pr review <PR> --comment --body "Some suggestions..."
```

## Sandbox Modes

| Mode | Flag | Use Case |
|------|------|----------|
| Read-only | (default) | Reviews, analysis |
| Full access | `--yolo` | Implementation, commits |

```bash
# Review (read-only is fine)
codex review --base main

# Implement (needs write access)
codex --yolo exec "Fix the bug and commit"
```

## Git Workflow

**Note:** Per GITHUB.md, Niemand does NOT create branches, commit code, or merge PRs unless explicitly requested by user.

### When User Says "Take to PR" or Similar:
1. Create feature branch
2. Have Codex implement
3. Have Codex review
4. Fix review issues
5. Commit and push
6. Create PR with proper description

### Commit Message Format
```bash
git commit -m "type(scope): description (#ISSUE)"  # max 50 chars
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

## Issue Priority Labels

| Label | Severity | Action |
|-------|----------|--------|
| P0 | Critical | Security, data loss, production down |
| P1 | High | Major feature broken |
| P2 | Medium | Minor features, workarounds exist |
| P3 | Low | Nice-to-have |

## Code Quality Standards

### Size Limits
| Component | Max Lines |
|-----------|-----------|
| Functions | 30-40 |
| Classes | 500 |
| Files | 500 |

### Principles
- **KISS** (Keep It Simple)
- **YAGNI** (You Aren't Gonna Need It)
- **DRY** (Don't Repeat Yourself)
- **SRP** (Single Responsibility)

## Common Pitfalls (Lessons Learned)

### ❌ DON'T: Write code yourself
```bash
# Wrong - you're writing code directly
Edit file.py: add function xyz...
```

### ✅ DO: Have Codex implement
```bash
codex --yolo exec "Add function xyz to file.py. Implement now."
```

### ❌ DON'T: Skip review entirely
```bash
# Wrong - no review at all
git push && gh pr create && gh pr merge
```

### ✅ DO: Create PR, then review, then fix
```bash
git push && gh pr create
codex review --base main --title "PR #N: Feature"
# Fix issues found
git commit && git push  # Fixes go to same PR
```

### ❌ DON'T: Use high reasoning for everything
```bash
# Can get stuck in 3+ minute analysis loops
codex exec -c model_reasoning_effort="high" "Simple task"
```

### ✅ DO: Match reasoning to complexity
```bash
# Simple tasks: medium (default)
codex --yolo exec "Add logging to function X"

# Complex architecture: high
codex --yolo exec -c model_reasoning_effort="high" "Redesign the auth system"
```

## Quick Reference

```bash
# Implement feature
codex --yolo exec "Implement X. No questions."

# Review changes locally
codex review --base main --title "Feature X"

# Review specific PR
gh pr checkout 123 && codex review --base main

# Post review to GitHub (as NiemandBot)
gh pr review 123 --comment --body "Codex review findings..."
gh pr review 123 --approve --body "LGTM! 🚀"
gh pr review 123 --request-changes --body "Issues found..."

# Create PR
gh pr create --title "feat: X" --body "Description"
```

## tmux for Interactive Sessions

For long-running Codex sessions:
```bash
SOCKET="${TMPDIR:-/tmp}/clawdbot-tmux-sockets/clawdbot.sock"
SESSION=codex-session

tmux -S "$SOCKET" new-session -d -s "$SESSION"
tmux -S "$SOCKET" send-keys -t "$SESSION" "codex --yolo exec '...'" Enter
# Wait, then capture
tmux -S "$SOCKET" capture-pane -p -t "$SESSION" -S -200
```

## References

- `CODING.md` - Full coding guidelines & Git hygiene
- `GITHUB.md` - GitHub integration & workflow
