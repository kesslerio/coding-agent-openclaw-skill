# Coding Workflow & Operations

## Contents
- Overview
- Git Workflow
- Hard Requirements (Violation = Task Failure)
- GitHub CLI (gh)
- Codex Workflow
- Codex MCP (Automated)
- Agent Utilization

## Overview

**Roles:**
- **@kesslerIO (Martin)**: Human Owner. Approves P0/P1 changes.
- **@niemandBot (Niemand)**: AI Agent. Reviews code, runs checks, implements features.

**Philosophy:**
- **Plan First**: Always discuss approach before implementation.
- **Surface Decisions**: Present options with trade-offs.
- **Confirm Alignment**: Ensure agreement before coding.
- **No Direct Edits**: Use Codex/Agents to write code.

## Git Workflow

**Note:** Niemand does NOT create branches, commit code, or merge PRs unless explicitly requested.

### Standard Flow
1. **Create Branch**: `git checkout -b type/description`
2. **Implement**: Use Codex (see below)
3. **Commit**: `git commit -m "type(scope): description"`
4. **Push**: `git push -u origin branch-name`
5. **PR**: `gh pr create`
6. **Review**: Run Codex review (see below)
7. **Fix**: Address issues
8. **Merge**: `gh pr merge`

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting (no code change)
- `refactor`: Restructuring code (no API change)
- `test`: Adding tests
- `chore`: Build/tooling changes

## Hard Requirements (Violation = Task Failure)

These are non-negotiable requirements. Violating any of these means the task has FAILED.

### 1. Branch Requirement
- **MUST** create feature branch before any code changes
- **MUST NOT** commit directly to main
- **Violation Response**: Stop and ask user to confirm branch creation

### 2. PR Requirement
- **MUST** create PR before code can be considered "done"
- **MUST** post review to PR before merge
- **MUST** include PR URL in task completion message
- **Violation Response**: Refuse to mark task complete without PR URL

### 3. Tool Usage Requirement
- When user specifies "use claude/codex/gemini": **MUST** use that CLI tool
- **MUST NOT** use direct file edits when agent CLI is specified
- **MUST** document which tool was used in PR description
- **Violation Response**: Stop and switch to specified tool

### 4. Review Requirement
- **MUST** run code review before merge
- **MUST** run standards review (references/STANDARDS.md) before merge
- **MUST** post both reviews to GitHub PR
- **Violation Response**: Block merge until reviews are posted

### Self-Check Before Completion
Before reporting task complete, verify:
- [ ] Changes on feature branch (not main)?
- [ ] PR created and URL available?
- [ ] Correct tools used (as specified by user)?
- [ ] Code review completed and posted?
- [ ] Standards review completed and posted?

## GitHub CLI (gh)

### Authentication
- **Check status**: `gh auth status`
- **Login**: `gh auth login` (uses PAT or browser)
- **Switch account**: `gh auth switch --user <username>`

### Common Commands
- **Create PR**: `gh pr create --title "feat: ..." --body "..."`
- **View PR**: `gh pr view <number>`
- **Checkout PR**: `gh pr checkout <number>`
- **Review PR**: `gh pr review <number> --approve`
- **Merge PR**: `gh pr merge <number> --admin --merge --delete-branch`

## Codex Workflow

### Implementation
**Always use `--yolo` (or `--dangerously-bypass-approvals-and-sandbox`) for write access.**

```bash
# Implement a feature
codex --yolo exec "Implement feature X. No questions."

# Complex task (high reasoning)
codex --yolo exec -c model_reasoning_effort="high" "Redesign auth module..."
```

### Code Review Process

**Hierarchy:**
1. **Codex**: Primary reviewer (`codex review`).
2. **Gemini**: Fallback if Codex hits limits (`gemini code-review`).
3. **Sub-agent**: Last resort for orchestration.

**Step 1: Code Review (Logic/Bugs)**
```bash
gh pr checkout <PR>
codex review --base main --title "PR #N Review"
```

**Step 2: Standards Review (Required)**
```bash
# Checks against STANDARDS.md
codex exec --model gpt-5.2-codex -c model_reasoning_effort="high" \
  "Review against STANDARDS.md..."
```

**Step 3: Posting Results**
```bash
gh pr review <PR> --comment --body "$(cat review.md)"
```

### Prompt Engineering Best Practices
- **Be Specific**: "Implement X using Y library" vs "Add X".
- **No Confirmation**: "Do not ask for confirmation. Just implement."
- **Small Batches**: Don't change 50 files at once.
- **Clear Exit**: "Reply with DONE when finished."

## Codex MCP (Automated)

For purely automated, structured tasks where terminal visibility is not required.

**Mechanism:** We use the native `codex mcp-server` via `mcporter`.

**Capabilities:**
- **Stateful Threads**: Uses `threadId` to continue conversations natively.
- **No Terminal Scraping**: Returns structured JSON responses.
- **Approval Policies**: Fine-grained control over command execution.

**Workflow:**
1. **Start**: `codex.codex(prompt="...", sandbox="danger-full-access")`
2. **Continue**: `codex.codex-reply(threadId="...", prompt="...")`

**Note:** This is the Supervisor Pattern. The Agent calls Codex via `mcporter` to drive automated coding tasks.

## Agent Utilization

Delegate specific tasks to focused agents:

- **requirements-specialist**: Specs → GitHub Issues
- **implementation-architect**: API/UI Design
- **quality-assurance-specialist**: Tests, Security, Perf
- **docs-architect**: Documentation updates

**Trigger**: When a task is too complex for a single prompt, spawn a sub-agent with a specific role.
