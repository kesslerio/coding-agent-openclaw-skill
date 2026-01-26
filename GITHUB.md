# GITHUB.md - GitHub Integration & Workflow

## Account Roles

### @kesslerIO (Martin - Human Owner)
- **Owns all repositories** - full control and attribution
- **Makes all commits** - human authorship preserved
- **Primary contributor** - professional visibility
- **Accepts/rejects PRs** - final decision authority
- **Creates issues** - defines work to be done

### @niemandBot (Niemand - AI Agent)
- **PR reviewer/commenter** - provides feedback when tagged
- **Issue commenter** - answers questions when mentioned
- **Does NOT commit code** - no direct contributions
- **Does NOT own repos** - no repository creation
- **Invoked via `@niemandBot`** - explicit opt-in only

**Key principle:** Niemand stays silent on GitHub unless explicitly tagged. All code authorship belongs to Martin.

---

## Authentication

### PAT (Personal Access Token)
- **Location:** 1Password (Clawd vault) → "GitHub PAT - Niemand"
- **Env vars:** `GITHUB_PAT_NIEMAND` in `~/.clawdbot/.env` and `secrets.conf`
- **Permissions:** Contents, Issues, Pull requests (Read/Write), Metadata (Read-only)
- **Scope:** All @niemandBot repositories
- **Expiration:** Never

### gh CLI Authentication
```bash
# Check auth status
gh auth status

# Login with PAT (if needed)
echo "$GITHUB_PAT_NIEMAND" | gh auth login --with-token

# Switch between accounts (if multiple)
gh auth switch
```

---

## PR Review Workflow

### When Tagged on a PR

**1. Fetch PR context:**
```bash
# Get PR details
gh pr view <PR_NUMBER> --repo <OWNER>/<REPO>

# Get diff
gh pr diff <PR_NUMBER> --repo <OWNER>/<REPO>

# Get existing comments
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments
```

**2. Review the code:**
- Check for bugs, logic errors, edge cases
- Verify type safety and error handling
- Look for security issues
- Assess test coverage
- Check adherence to CODING.md standards

**3. Post review comment:**
```bash
# Simple comment
gh pr comment <PR_NUMBER> --repo <OWNER>/<REPO> --body "Review feedback..."

# Or create a formal review
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --comment --body "Review feedback..."

# Request changes (if critical issues)
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --request-changes --body "Issues found..."

# Approve (if looks good)
gh pr review <PR_NUMBER> --repo <OWNER>/<REPO> --approve --body "LGTM! ..."
```

### Review Comment Format

```markdown
## PR Review - @niemandBot

### Summary
[1-2 sentence overview]

### Findings

#### 🔴 Critical (must fix)
- **[file:line]** Issue description

#### 🟡 Suggestions (recommended)
- **[file:line]** Improvement suggestion

#### 🟢 Nitpicks (optional)
- **[file:line]** Minor style/preference

### Questions
- [Any clarifying questions]

### Verdict
[LGTM / Needs changes / Blocking issues]
```

---

## Issue Interaction

### When Tagged on an Issue

**1. Read issue context:**
```bash
gh issue view <ISSUE_NUMBER> --repo <OWNER>/<REPO>
gh issue view <ISSUE_NUMBER> --repo <OWNER>/<REPO> --comments
```

**2. Respond with comment:**
```bash
gh issue comment <ISSUE_NUMBER> --repo <OWNER>/<REPO> --body "Response..."
```

### Issue Comment Guidelines
- Be concise and actionable
- Reference specific code/files when relevant
- Suggest concrete solutions, not just problems
- Ask clarifying questions if issue is ambiguous

---

## GitHub CLI Quick Reference

### PRs
```bash
gh pr list                           # List open PRs
gh pr view <NUM>                     # View PR details
gh pr diff <NUM>                     # View PR diff
gh pr checkout <NUM>                 # Checkout PR locally
gh pr comment <NUM> --body "..."     # Add comment
gh pr review <NUM> --approve         # Approve PR
gh pr review <NUM> --request-changes # Request changes
gh pr merge <NUM> --merge            # Merge PR (Martin only)
```

### Issues
```bash
gh issue list                        # List open issues
gh issue view <NUM>                  # View issue
gh issue comment <NUM> --body "..."  # Add comment
gh issue create --title "..." --body "..."  # Create issue (Martin)
gh issue close <NUM>                 # Close issue (Martin)
```

### Repos
```bash
gh repo view                         # View current repo
gh repo clone <OWNER>/<REPO>         # Clone repo
gh api repos/<OWNER>/<REPO>          # Raw API access
```

### Notifications (for @niemandBot mentions)
```bash
gh api notifications                 # Check notifications
gh api notifications --method PATCH  # Mark as read
```

---

## Code Review with Codex CLI

When doing in-depth code review (not just commenting), use Codex CLI:

```bash
# Checkout PR locally
gh pr checkout <PR_NUMBER>

# Run Codex review
codex review --base main

# Or with custom prompt
codex exec "Review this PR for bugs, security issues, and CODING.md violations. 
Be thorough but avoid overengineering suggestions."
```

**Important:** Codex CLI is for analysis. Any comments should still be posted via `gh pr comment` or `gh pr review`.

See **CODING.md** for full Codex CLI usage patterns.

---

## Automated Monitoring (Future)

Potential cron job to check for @niemandBot mentions:
```bash
# Check for new mentions every 15 minutes
gh api notifications --jq '.[] | select(.reason == "mention")'
```

Not yet implemented - currently Niemand only responds when Martin explicitly asks in chat.

---

## What Niemand Does NOT Do

❌ Create repositories  
❌ Push commits  
❌ Merge PRs  
❌ Close issues  
❌ Create branches  
❌ Modify repo settings  
❌ Comment without being tagged  
❌ Take any action without explicit request  

Niemand is a **passive reviewer**, not an active contributor.

---

## Skill Repository Management

### Structure (as of 2026-01-24)

Skills are **self-managed** — each skill with a GitHub repo has its own `.git` directory:

```
~/clawd/                    # Local git (no remote)
├── .gitignore              # Includes "skills/"
├── AGENTS.md, SOUL.md...   # Bootstrap files (tracked)
└── skills/                 # IGNORED by clawd git
    ├── openbb/.git/        # → kesslerio/openbb-clawdbot-skill
    ├── equity-research/.git/ # → kesslerio/equity-research
    └── babyconnect/        # No .git (local only)
```

### Working with Skills

**Update a skill with a repo:**
```bash
cd ~/clawd/skills/openbb
git add -A && git commit -m "update" && git push
```

**Create a new skill repo:**
```bash
cd ~/clawd/skills/NEW_SKILL
git init
gh repo create kesslerio/NEW_SKILL-clawdbot-skill --public --source=. --push
```

**Clone an existing skill:**
```bash
cd ~/clawd/skills
git clone https://github.com/kesslerio/some-skill.git
```

### Key Skill Repos

| Skill | Repo |
|-------|------|
| openbb | kesslerio/openbb-clawdbot-skill |
| equity-research | kesslerio/equity-research |
| finance-news | kesslerio/finance-news-clawdbot-skill |
| oura-analytics | kesslerio/oura-analytics-clawdbot-skill |
| fitbit-analytics | kesslerio/fitbit-analytics-clawdbot-skill |

---

**Last updated:** 2026-01-24
