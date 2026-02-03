# Reviews and Standards

## Review Workflow

### New Features (Issue → PR)
1. Implement with Codex MCP.
2. Create PR.
3. Run Codex review.
4. Run standards review (references/STANDARDS.md) — required.
5. Fix issues, push updates to same branch.

### Existing PRs
1. Checkout PR.
2. Run Codex review locally.
3. Run standards review.
4. Post both reviews to GitHub.
5. Fix issues, push updates.

### Codebase Reviews
1. Run full review (Codex or Claude CLI with long timeout).
2. Classify findings by severity (P0–P3).
3. Create issues with file:line references.

## Review Commands

```bash
# Code review
codex review --base main --title "PR #N Review"

# Standards review
mcporter call codex.codex \
  'prompt="Review against coding standards in references/STANDARDS.md. Report PASS/FAIL per category with file:line refs."' \
  'approval-policy=untrusted' 'sandbox=read-only'
```

## Posting Reviews to GitHub

```bash
# Approve
gh pr review <PR> --approve --body "LGTM"

# Request changes
gh pr review <PR> --request-changes --body "Found issues that need fixing"

# Comment only
gh pr review <PR> --comment --body "Suggestions and notes"
```

## Standards Review Output Format

```markdown
## references/STANDARDS.md Standards Review ✅|⚠️|❌

### ✅ PASSED
- Code Quality: Functions under 40 lines

### ⚠️ WARNINGS (P2)
- [file:23] Function has 7 parameters (limit: 4)

### ❌ ISSUES (P1)
- [file:8] Commit uses wrong format

### Recommendation: APPROVE / REQUEST_CHANGES
```
