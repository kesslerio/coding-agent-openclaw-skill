# Coding Workflow & Operations

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

## Interactive Sessions (t-pane)

For complex multi-step tasks where context must be preserved.

**Mechanism:** We use the `t-pane` MCP server to manage tmux sessions reliably. This replaces brittle raw `tmux` commands.

**Capabilities:**
- **Persistent Context**: Codex runs in a session that survives between prompts.
- **Reliable Output**: `t-pane` uses markers to capture exact output.
- **Prompt Detection**: Detects when Codex needs input.

**Workflow:**
1. **Create Session**: `create_pane(name="codex-session")`
2. **Execute**: `execute_command(pane="codex-session", command="codex --yolo exec '...'")`
3. **Monitor**: Output is returned automatically.

**Note:** This is the Supervisor Pattern. The Agent (Niemand) calls `t-pane` to drive Codex.

## Agent Utilization

Delegate specific tasks to focused agents:

- **requirements-specialist**: Specs → GitHub Issues
- **implementation-architect**: API/UI Design
- **quality-assurance-specialist**: Tests, Security, Perf
- **docs-architect**: Documentation updates

**Trigger**: When a task is too complex for a single prompt, spawn a sub-agent with a specific role.
