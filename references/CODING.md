# CODING.md - Coding Guidelines & Git Hygiene

## Core Principles

**Language:** English only - all code, comments, docs, examples, commits, configs, errors, tests
**Tools**: Use `rg` not `grep`, `fd` not `find`, `tree` is installed
**Claude CLI**: Use full path `~/.claude/local/claude` instead of 'claude' to avoid PATH issues
**Scope**: Respond to both code and non-code questions

**Precedence**
- **Per-repo CLAUDE.md overrides the system doc** on repo-specific rules (commit format, test commands, research flow).

## Codex CLI Profiles

- Codex CLI reads configuration from `~/.codex/config.toml`.
- Profiles are defined under `[profiles.<name>]` in that file.
- Invoke a profile with `codex --profile <name>` (or `-p <name>`).
- Set a default profile with `profile = "<name>"` at the top level of `config.toml`.
- You can override individual settings per run with `-c key=value` / `--config`.

## Codex CLI Non-Interactive Reviews (PRs)

**Non-interactive mode:** use `codex exec` (or `codex e`).  
**Prompt from stdin:** pass `-` as the prompt to read from stdin.  
**Model selection:** use `--model`/`-m` to override config on a single run (example model in docs: `gpt-5-codex`).  
**High reasoning:** set `model_reasoning_effort = "high"` via profile or `--config/-c`.  

**Example (high reasoning, non-interactive, stdin):**
```bash
gh pr diff 50 > /tmp/pr-50.diff

cat > /tmp/pr-50.prompt <<'EOF'
Review this PR diff as a code reviewer. Follow CODING.md: be brutally honest, prioritize bugs/risks/regressions, list findings by severity with file/line refs, note assumptions, suggest tests. If no issues, say so explicitly. Do not ask to read more files.

PR metadata:
- Repo: kesslerio/finance-news-clawdbot-skill
- PR: 50
- Base: main

Diff:
EOF
cat /tmp/pr-50.diff >> /tmp/pr-50.prompt
cat /tmp/pr-50.prompt | codex exec -m gpt-5-codex -c model_reasoning_effort=\"high\" -
```

**Notes**
- `codex exec` is designed for scripted/CI-style runs without interaction.
- `--model` overrides `config.toml` for that invocation.
- `-c/--config` parses values as JSON if possible; otherwise it uses the literal string.
- Add `--json` if you want JSONL output for tooling/pipelines.

---

## Communication Style

- **Perspective**: Brutally honest feedback, no false empathy or validation
- **Role**: Senior engineer peer, not assistant serving requests
- **Feedback**: Direct and professional, push back on flawed logic
- **Avoid**: Excessive validation ("Great question!", "Perfect!"), defaulting to agreement

---

## Development Methodology

- **Plan First**: Always discuss approach before implementation
- **Surface Decisions**: Present options with trade-offs when multiple approaches exist
- **Confirm Alignment**: Ensure agreement on approach before coding
- **Technical Discussion**: Assume understanding of common concepts, be direct with feedback

---

## Agent & Subagent Utilization

### When to Use Agents

**Specialized Task-Specific Workflows** — Delegate work to focused agents with domain expertise:
- **requirements-specialist**: Convert specs/bugs → GitHub issues with triage and prioritization
- **implementation-architect**: Design APIs and UI components, service boundaries, data models
- **refactoring-specialist**: Eliminate redundancy, untangle dependencies, modernize legacy code
- **quality-assurance-specialist**: Code review, test coverage, performance profiling, security scanning
- **problem-resolution-specialist**: Debug failures, resolve merge conflicts, fix CI issues
- **docs-architect**: Generate/update documentation, runbooks, API references
- **project-delegator-orchestrator**: Manage complex multi-step projects across domains

### Invocation Best Practices

**Early Investigation Phase** (CRITICAL):
- Deploy agents **early** in complex problem-solving to preserve main context
- Use agents to verify details, investigate questions, explore codebase structure
- Prevents context pollution in main conversation thread
- Trade-off: minimal efficiency loss vs. significant context preservation

**Parallel vs. Sequential**:
- **Parallel**: Deploy 3-4 agents simultaneously for unrelated tasks (use git worktrees for true independence)
- **Sequential**: Chain agents when later tasks depend on earlier outputs
- Example: Use Explore agent to find code → Use refactoring-specialist to restructure → Use quality-assurance-specialist to verify

**Separation of Concerns**:
- One agent writes code, another reviews it
- One agent writes tests, another implements solutions
- Prevents overfitting and maintains independent verification

### Agent Selection Triggers

- **requirements-specialist**: Feature specs, bug reports, planning docs need GitHub issues
- **implementation-architect**: Designing new APIs/endpoints, building UI components, data models
- **refactoring-specialist**: Files >500 lines, duplicated code, system-wide redundancy, tight coupling
- **quality-assurance-specialist**: Pre-commit review, pre-merge checks, pre-release scan, performance issues
- **problem-resolution-specialist**: Test failures, merge conflicts, CI errors, production crashes, regressions
- **docs-architect**: After major code changes, API modifications, architectural updates
- **project-delegator-orchestrator**: Complex multi-domain projects, large migrations, coordinated releases

### Context Management

**Preserve Main Context**:
- Offload investigations, exploratory work, verification to agents
- Keep main conversation focused on high-level decisions and coordination
- Use agents for "reading" codebase details, searching patterns, researching solutions

**Agent Context Isolation**:
- Each agent has separate context window (additional capacity)
- Agent results returned to main conversation after completion
- Design focused agents with single responsibility (avoid multi-purpose agents)

### Configuration Principles

- **Focused Descriptions**: Include clear triggers in agent descriptions ("use when...", "handles...")
- **Proactive Language**: Use "PROACTIVELY", "MUST BE USED" for automatic delegation
- **Tool Restrictions**: Grant only necessary tools for agent's purpose (security + focus)
- **Version Control**: Check agent configs into version control for team collaboration

---

## Code Quality Standards

### Foundational Principles

**KISS (Keep It Simple)**
- **Rule**: Simplest solution wins | Avoid premature abstraction | Reduce complexity
- **Detection**: Helper functions for one-time operations | Unused configurability | Nested abstractions
- **Action**: Inline single-use helpers | Remove unused flexibility | Flatten unnecessary layers

**YAGNI (You Aren't Gonna Need It)**
- **Rule**: Build only what's needed now | No speculative features | No "future-proofing"
- **Detection**: Unused parameters | Abstract interfaces with single implementation | "Might need this later" code
- **Action**: Delete unused code completely | Replace abstractions with concrete implementations | Add complexity when required, not before

**DRY (Don't Repeat Yourself)**
- **Rule**: Extract common patterns | Maintain consistency | Single source of truth
- **Detection**: Copy-pasted logic | Duplicate constants | Similar functions with minor variations
- **Action**: Extract shared functions | Use constants/enums | Parameterize variations | BUT: Three strikes rule - don't abstract until third occurrence

**SRP (Single Responsibility)**
- **Rule**: One class, one reason to change | One responsibility per module
- **Detection**: Class changes for multiple reasons | Too many dependencies | Mixed concerns
- **Refactoring**: Separate authentication, database operations, business logic, UI concerns

### Design Principles

**Law of Demeter**
- **Rule**: Classes know only direct dependencies | Avoid chaining | "Don't talk to strangers"
- **Detection**: Method chains beyond one level (a.b().c().d()) | Classes reaching through objects
- **Action**: Add delegation methods | Pass required objects directly | Flatten access patterns

**Dependency Injection**
- **Rule**: Inject dependencies explicitly | Avoid hidden coupling | Make relationships visible
- **Detection**: Hard-coded instantiations | Global state access | Static dependencies
- **Action**: Constructor injection for required dependencies | Method injection for optional | Avoid service locators

**Polymorphism over Conditionals**
- **Rule**: Prefer polymorphism to if/else chains | Use interfaces for extensibility
- **Detection**: Type checking (instanceof) | Switch on type codes | Parallel conditional logic
- **Action**: Extract strategy pattern | Create interface hierarchy | Replace conditionals with polymorphic dispatch

### Size Limits & Refactoring Triggers

- **Functions**: Max 30-40 lines | Refactor when logic becomes complex or multiple concerns
- **Classes**: Max 500 lines | Refactor when >30 methods or handling multiple responsibilities
- **Files**: Max 500 lines | Split when exceeding or mixing multiple concerns
- **Methods per Class**: Max 20-30 methods | Extract related functionality to separate classes

### Refactoring Best Practices

- **Small Steps**: Incremental changes to reduce bugs | Test each modification
- **Separate Concerns**: Never mix refactoring with bug fixing
- **Deduplication Priority**: Eliminate redundant code first | Extract common patterns
- **Test Coverage**: Validate SRP compliance through focused unit tests
- **No Backwards-Compatibility Hacks**: Delete unused code completely | No renaming to _vars | No // removed comments

### Universal Coding Standards

- **Naming**: Descriptive, searchable names | Replace magic numbers with named constants
- **Functions**: Max 3-4 parameters | Encapsulate boundary conditions | Declare variables near usage
- **TypeScript**: Use Record<string, unknown> over any | PascalCase (classes/interfaces) | camelCase (functions/variables)
- **Error Handling**: Explicit error patterns | Never silent failures
- **Imports**: Order as node → external → internal | Remove unused immediately
- **Git Commits**: Conventional format: type(scope): subject | 50 chars max, imperative mood | Atomic changes
  - *Repo override:* If a repository defines a different format (e.g., `Type: Description #issue`), **follow the repo** and retain `#issue` linkage.

---

## Research & Analysis Protocols

- **Pragmatic use of MCP servers**: Prefer the **fewest** tools needed to answer confidently. Default: **Official Docs / Vendor Guides → Context7 → GitHub → Reputable forums (incl. Reddit)**.
- **When to broaden**: Only if the prior source lacks coverage or is out-of-date; document what changed your mind.
- **Tool discovery**: **Do not invent tool/command IDs**. Introspect available MCP tools and use advertised names.
- **Query hygiene**: Merge similar queries; avoid redundant runs; append date only when recency matters.
- **Fallbacks**: Use Playwright when Fetch/domain blocks prevent retrieval.

---

## Inclusive Language

- **Terms**: allowlist/blocklist, primary/replica, placeholder/example, main branch, conflict-free, concurrent/parallel

---

## File Organization Conventions

### Root directory: Bootstrap files ONLY
- `AGENTS.md`, `SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md`, `MEMORY.md`, `WRITING_STYLE.md`, `SKILLS.md`, `HEARTBEAT.md`, `COMMUNICATION.md`, `CODING.md`, `GITHUB.md`, `.gitignore`
- Keep root clean — no artifacts, transcripts, or temporary files

### Required subdirectories:
- `memory/` - Daily memory logs (YYYY-MM-DD.md format)

### Organized subdirectories (create as needed):
- `artifacts/transcripts/` - Voice message transcriptions (from openai-whisper)
- `docs/` - Documentation and notes
- `logs/` - Application logs
- `scripts/` - Utility scripts
- `projects/` - Project tracking

### Tool output conventions:
- **openai-whisper**: ALWAYS use `--output_dir artifacts/transcripts/` (never workspace root)
- **Research outputs**: Route to `/home/art/clawd-research/reports/` (separate workspace)
- **Temporary files**: Use system temp directories or clean up after completion
- **Planning docs**: Save to `docs/` (not root)

---

## Git Hygiene

### Repository Structure
Every repo must include:
- `README.md` - Project overview, setup, usage
- `LICENSE` - Appropriate open-source license
- `.gitignore` - Comprehensive ignore rules (see Python below)

### Issue Triage
Use P0–P3 priority labels:
- **P0: Critical** - Security, data loss, production down
- **P1: High** - Major feature broken, significant impact
- **P2: Medium** - Minor features, workarounds exist
- **P3: Low** - Nice-to-have, cosmetic, future consideration
- **Format**: "Problem → Impact → Solution" for all issues

### Python .gitignore
```gitignore
__pycache__/
*.pyc
*.pyo
venv/
.venv/
env/
.env/
.pytest_cache/
.coverage
htmlcov/
*.sqlite3
*.db
*.log
```

### Git Workflow
1. **Branch** → Create feature branch for changes
2. **PR** → Open pull request with description
3. **Review** → Use Codex CLI, get user approval
4. **Merge** → Squash-merge for clean history (when appropriate)
5. **Post-merge** → Delete feature branch

### Codex CLI Usage

**⚠️ ALWAYS USE YOLO MODE FOR CODEX CLI ⚠️**

```bash
# ✅ CORRECT - Always use --yolo (or --dangerously-bypass-approvals-and-sandbox)
codex --yolo "Your prompt here"

# ❌ WRONG - Default mode blocks network, file writes, and most useful operations
codex "Your prompt here"
```

**Why yolo mode is required:**
- Default sandbox mode blocks network access (no `gh` commands, no API calls)
- Default sandbox mode is read-only (no file edits, no git commits)
- Codex becomes nearly useless without these capabilities
- We trust Codex to operate in our repos

**When invoking Codex from Clawdbot:**

**❌ DO NOT use sessions_spawn for code reviews** - sub-agents have restricted tools and can't fetch repos or run gh commands.

**✅ Use bash with PTY mode instead:**
```bash
# PR reviews (with repo access)
bash pty:true workdir:/path/to/repo command:"gh pr checkout <PR_NUMBER> && codex review --base main"

# One-shot tasks
bash pty:true workdir:/path/to/repo command:"codex --yolo 'Your prompt'"

# Background for longer tasks
bash pty:true workdir:/path/to/repo background:true command:"codex --yolo 'Your prompt'"

# Monitor background sessions
process action:log sessionId:<session_id>
process action:poll sessionId:<session_id>
```

**Why bash + PTY instead of sessions_spawn:**
- `sessions_spawn` creates isolated sub-agents with restricted tool access
- Sub-agents don't have `bash`, `gh`, or `git` tools needed for code reviews
- PTY mode gives Codex full shell access including network, file writes, git commands
- Background mode allows long-running tasks without blocking

---

### PR Review Hierarchy

**Use ONE tool for PR reviews, in this order:**

| Priority | Tool | When to Use |
|----------|------|-------------|
| 1️⃣ | **Codex CLI** | Primary tool for all PR reviews |
| 2️⃣ | **Gemini CLI** | Fallback when Codex hits usage limits |
| 3️⃣ | **Clawdbot sub-agent** | Last resort when both CLIs unavailable |

**⚠️ DO NOT use multiple tools for the same review** — it's redundant and wasteful.

**Example flow:**
```bash
# 1. Try Codex first
codex exec "Review PR #13 for bugs. Post findings as PR comment using gh pr comment."

# 2. If Codex limit exceeded, use Gemini
gemini "Review PR changes: $(git diff origin/main). Post findings."

# 3. Last resort: Clawdbot sub-agent (limited capabilities)
sessions_spawn task:"Review PR #13 changes and summarize issues"
```

---

### Codex Prompt Engineering - Avoiding Zero Output

**Problem:** Codex sometimes exits without producing any output, commits, or branches - wasting time and compute.

**Root causes & solutions:**

#### 1. Too Vague / Too Ambitious
**❌ Bad:**
```bash
codex --yolo "Implement data sync reliability per issue #11..."
```

**✅ Good - Be specific and scoped:**
```bash
codex --yolo "Create scripts/cache.py with OuraCache class. 
Methods: get(endpoint, date), set(endpoint, date, data), clear().
Cache dir: ~/.oura-analytics/cache/{endpoint}/{date}.json
Keep under 100 lines. Start now."
```

**Key principles:**
- **Single, concrete deliverable** per Codex run
- **Explicit file paths and function signatures**
- **Size constraints** ("under 100 lines", "3 functions max")
- **"Start now" or "Implement immediately"** to bias action

#### 2. Codex Asks for Confirmation, Gets None
Codex may stop and wait for approval even in --yolo mode if:
- The task seems ambiguous
- Multiple approaches are possible
- Destructive operations are involved

**Solution:** Use `codex exec` instead of interactive mode:
```bash
# ✅ Non-interactive - no confirmation prompts
codex exec "Create cache.py with OuraCache class..."

# ❌ May wait for confirmation
codex --yolo "Create cache.py..."
```

Or explicitly approve in prompt:
```bash
codex --yolo "Create cache.py... Auto-approve all changes. No confirmation needed."
```

#### 3. Planning Instead of Doing
Codex defaults to planning for complex tasks. If you want code, be explicit:

**❌ Bad (gets a plan, not code):**
```bash
codex --yolo "Implement caching for Oura API"
```

**✅ Good (gets code):**
```bash
codex exec "Step 1: Create scripts/cache.py NOW.
class OuraCache:
    def get(endpoint, date) -> Optional[list]
    def set(endpoint, date, data)
    def clear(endpoint)

Write the file. Commit when done. No planning - implement directly."
```

**Codex planning triggers:**
- Vague requirements
- Multi-step workflows
- Large scope ("refactor the entire API")

**How to force implementation:**
- Use **"Step 1: ..."** pattern (breaks down task)
- Add **"No planning - implement directly"**
- Use **`codex exec`** for one-shot tasks
- Provide **skeleton code** or function signatures

#### 4. No Clear Exit Condition
If Codex doesn't know when it's "done", it may exit prematurely.

**✅ Explicit completion criteria:**
```bash
codex exec "Create cache.py. Test it with: python3 -c 'from cache import OuraCache; c = OuraCache(); print(c.cache_dir)'. Commit when test passes."
```

**Include:**
- **Test command** to verify work
- **Commit requirement** ("git add + commit when done")
- **Success criteria** ("all tests pass", "PR created")

#### 5. Large Diffs / Too Many Files
Codex can get overwhelmed analyzing large changes.

**✅ Break into focused steps:**
```bash
# Step 1: Cache module only
codex exec "Create scripts/cache.py with OuraCache class. Commit."

# Step 2: Integration (after Step 1 completes)
codex exec "Integrate OuraCache into scripts/oura_api.py. Add _get_with_cache() method. Commit."

# Step 3: CLI commands
codex exec "Add 'sync' and 'cache' CLI commands to oura_api.py. Commit."
```

**Benefits:**
- Each run has clear scope
- Easier to debug failures
- Can verify/test between steps

#### 6. Working Directory Issues
Codex may fail silently if not in correct directory.

**✅ Always set workdir explicitly:**
```bash
bash pty:true workdir:/path/to/repo command:"codex exec '...'"
```

Or in prompt:
```bash
codex exec "Working in /path/to/repo. Create scripts/cache.py..."
```

---

### Codex Best Practices Summary

**Do:**
- ✅ Use `codex exec` for non-interactive tasks
- ✅ Be specific: file paths, function signatures, line count limits
- ✅ Break large tasks into 3-5 focused steps
- ✅ Include test commands and commit requirements
- ✅ Use "Start now", "Implement immediately", "No planning"
- ✅ Set explicit workdir
- ✅ Provide skeleton code or examples

**Don't:**
- ❌ Vague prompts ("implement X")
- ❌ Huge scope ("refactor entire codebase")
- ❌ Ambiguous requirements (forces planning mode)
- ❌ Multiple deliverables in one prompt
- ❌ Forget to specify --yolo mode

---

### Gemini CLI as Fallback (When Codex Hits Limits)

**When Codex usage limits are exceeded, use Gemini CLI for code review.**

#### Setup Gemini CLI Code Review Extension

```bash
# Install Gemini CLI (if not already installed)
npm install -g @google/gemini-cli

# Install code review extension
gemini extensions install https://github.com/gemini-cli-extensions/code-review
```

#### Code Review with Gemini

**Option 1: Using /code-review command (extension)**
```bash
cd /path/to/repo
git checkout <branch-or-pr>
gemini  # Enter interactive mode
# Then in Gemini CLI:
/code-review
```

**Option 2: Manual review prompt (non-interactive)**
```bash
# Review current changes
gemini "Review the git diff for bugs and improvements. Focus on:
1. Logic errors
2. Type safety issues
3. Edge cases
4. Performance concerns
5. Security issues

$(git diff origin/master)"

# Review specific PR
gh pr checkout <PR_NUMBER>
gemini "Review PR changes for production readiness. Check for bugs, type issues, edge cases.

$(git diff origin/master)"
```

#### Gemini CLI Best Practices

**Models:**
- Default: `gemini-2.5-pro` (general purpose, high usage limits)
- **Gemini 3 Pro access** (requires Google AI Ultra subscription or paid API key):
  1. Ensure CLI version 0.16.x+ (`gemini --version`)
  2. Run `gemini` (interactive mode)
  3. Type `/settings` → Enable "Preview features"
  4. Type `/model` → Select "Pro" (Gemini 3 Pro)
  5. Now available in this session
- **Note:** `--model` flag doesn't support Gemini 3 (use interactive mode)
- Check current model: In CLI, type `/stats` or ask "what model are you?"

**Thinking/Reasoning (Gemini 3 Pro):**
- Gemini 3 Pro has built-in thinking capability when enabled in `/model` menu
- The CLI automatically uses thinking for complex tasks
- Gemini CLI doesn't expose manual `thinking_level` parameter (as of Jan 2026)
- GitHub issue tracking manual control: [#6693](https://github.com/google-gemini/gemini-cli/issues/6693)
- For Gemini 2.5: Ask explicitly "Think deeply about edge cases before responding"

**Usage Limits:**
- **Free tier:** ~250 messages/24 hours
- **Pro subscribers:** Higher limits (~150+ prompts/day), rarely hit
- Separate limits for Gemini 3 Thinking vs Pro models (as of Jan 2026)

**Troubleshooting (hangs at “Loaded cached credentials”):**
- Known issue when MCP servers are configured (e.g., Playwright MCP); one-shot prompts can hang in non-interactive mode.
- Workarounds: run interactive `gemini` first to validate auth; temporarily remove/disable MCP servers in `settings.json`; avoid MCP-dependent prompts in one-shot mode.
- For automation, wrap CLI calls with a hard timeout and retry once.

#### When to Use Gemini vs Codex

**Use Codex when:**
- ✅ Need git/gh integration (checkout PRs, post comments)
- ✅ Need file editing + commit workflow
- ✅ Complex multi-step implementation tasks
- ✅ Usage quota available

**Use Gemini when:**
- ✅ Codex hit usage limits
- ✅ Need quick code review (read-only)
- ✅ Analyzing diffs or snippets
- ✅ Research/explanation tasks
- ✅ Want second opinion on architecture

#### Example Workflow

```bash
# Try Codex first
codex review --base origin/master

# If Codex fails with usage limit error:
# 1. Get the diff
git diff origin/master > /tmp/pr-diff.txt

# 2. Review with Gemini
gemini "Code review this diff for bugs and improvements:

$(cat /tmp/pr-diff.txt)

Focus on:
- Logic errors
- Type safety
- Edge cases
- Security issues"

# 3. Or use extension
gemini
# In CLI: /code-review
```

#### Posting Review Comments

Gemini CLI doesn't auto-post to GitHub. Manual workflow:

```bash
# 1. Get Gemini's review
gemini "Review this PR..." > /tmp/review.md

# 2. Post to GitHub
gh pr comment <PR_NUMBER> --body-file /tmp/review.md
```

Or integrate into automation:
```bash
gh pr checkout <PR>
REVIEW=$(gemini "Review $(git diff origin/master)")
gh pr comment <PR> --body "$REVIEW"
```

---

### PR Process

**See GITHUB.md** for full GitHub workflow, account roles, and `gh` CLI reference.

**Key points:**
- **@kesslerIO (Martin):** Owns all repos, makes all commits, merges PRs
- **@niemandBot (Niemand):** PR reviewer/commenter only, invoked via `@niemandBot` tag
- **Codex CLI:** Use for in-depth code analysis, then post via `gh pr comment`

**Quick Codex review:**
```bash
gh pr checkout <PR_NUMBER>
codex review --base main
# Then post findings via gh pr comment
```

### Critical Rules
- **Never push directly to main/master** for complex changes
- **Never merge until user explicitly approves** the PR
- **Never commit secrets**, API keys, or credentials
- **Excluded from git**: transcripts, logs, temp files, API keys
- **Niemand does NOT commit** - review/comment only

---

## Code Style

### Python
- Use **ruff** for linting (configured in `pyproject.toml`)
- Follow PEP 8 with these additions:
  - Line length: 100 characters
  - Type hints required for function signatures
  - Docstrings for all public functions/classes

### Testing
- pytest for unit tests
- Test files: `tests/test_*.py`
- Coverage target: 80%+ for new code

---

## Interactive Coding Agents (tmux)

### When to Use tmux vs. Standard Execution

**Standard `bash pty:true` is insufficient for truly interactive CLIs** that require:
- Bidirectional communication (agent asks questions → you respond)
- Long-running sessions with periodic monitoring
- Multiple parallel interactive sessions

**Use tmux for:**
- ✅ Interactive Codex sessions (questions, confirmations, multi-step workflows)
- ✅ Claude Code interactive mode
- ✅ Gemini CLI interactive mode (`gemini` command with user input)
- ✅ Any CLI that requires user responses during execution

**Use standard `bash pty:true` for:**
- ✅ One-shot Codex commands (`codex exec "..."` or `codex --yolo "..."`)
- ✅ Non-interactive reviews (`codex review --base main`)
- ✅ Commands that complete without user input

### Subagent Pattern for tmux Management

**Best practice:** Spawn a dedicated subagent to manage the tmux session and relay questions back to you.

**Why:**
- Main agent context stays clean
- Subagent handles tmux lifecycle (create → monitor → capture → cleanup)
- You receive periodic updates without manual polling
- Natural place to handle interactive prompts

**Pattern:**
```bash
# Main agent spawns subagent
sessions_spawn task:"Manage Codex review for PR 27 in finance-news repo via tmux. 
Checkout PR, run codex review, monitor output, relay any questions to me, 
capture final results when done." label:"codex-pr27-review"

# Subagent creates tmux session and monitors
# When Codex asks a question → subagent messages you
# You respond → subagent sends keys back to tmux
# Review completes → subagent reports results
```

### tmux Fundamentals

**Why tmux:**
- Persistent sessions survive network interruptions
- Capture pane output for review
- Send keystrokes to interactive shells
- Run multiple agents in parallel
- Inspect running processes without interrupting them

**Core commands:**
```bash
SOCKET="${TMPDIR:-/tmp}/clawdbot-tmux-sockets/clawdbot.sock"
SESSION=codex-review

# Create detached session
tmux -S "$SOCKET" new-session -d -s "$SESSION" -n shell

# Send command + Enter
tmux -S "$SOCKET" send-keys -t "$SESSION" "cd /path/to/repo && gh pr checkout 27 && codex review --base main" Enter

# Capture last 200 lines of output
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION" -S -200

# Kill session when done
tmux -S "$SOCKET" kill-session -t "$SESSION"
```

**Monitoring patterns:**
```bash
# Check if prompt returned (review complete)
if tmux -S "$SOCKET" capture-pane -p -t "$SESSION" -S -3 | grep -q "❯\|✓\|$"; then
  echo "Session complete"
fi

# Extract last question/prompt from Codex
tmux -S "$SOCKET" capture-pane -p -t "$SESSION" -S -50 | grep -A5 "?"

# Watch output continuously (for debugging)
watch -n 2 "tmux -S '$SOCKET' capture-pane -p -t '$SESSION' -S -30"
```

### Quickstart: Single Interactive Session

```bash
SOCKET="${TMPDIR:-/tmp}/clawdbot-tmux-sockets/clawdbot.sock"
SESSION=codex-review

tmux -S "$SOCKET" new-session -d -s "$SESSION" -n shell

# Run Codex review
tmux -S "$SOCKET" send-keys -t "$SESSION" "cd /path/to/repo && gh pr checkout 27 && codex review --base main" Enter

# Monitor output
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION" -S -200
```

### Parallel PR Reviews (Multiple tmux Sessions)

**Use case:** Review 4 PRs simultaneously with separate Codex instances.

```bash
SOCKET="${TMPDIR:-/tmp}/codex-army.sock"

# Launch parallel Codex reviews for PRs 27-30
for pr in 27 28 29 30; do
  tmux -S "$SOCKET" new-session -d -s "pr-$pr"
done

# Start reviews
tmux -S "$SOCKET" send-keys -t pr-27 "cd /tmp/finance-news-14 && codex review --base main" Enter
tmux -S "$SOCKET" send-keys -t pr-28 "cd /tmp/finance-news-15 && codex review --base main" Enter
tmux -S "$SOCKET" send-keys -t pr-29 "cd /tmp/finance-news-16 && codex review --base main" Enter
tmux -S "$SOCKET" send-keys -t pr-30 "cd /tmp/finance-news-19 && codex review --base main" Enter

# Check completion
for pr in 27 28 29 30; do
  if tmux -S "$SOCKET" capture-pane -p -t "pr-$pr" -S -3 | grep -q "❯\|✓"; then
    echo "PR $pr: DONE"
    tmux -S "$SOCKET" capture-pane -p -t "pr-$pr" -S -500
  fi
done

# Cleanup
tmux -S "$SOCKET" list-sessions -F '#{session_name}' | xargs -r -n1 tmux -S "$SOCKET" kill-session -t
```

### Full Reference

See: `/home/art/clawd/skills/tmux/SKILL.md` for comprehensive syntax, advanced patterns, and troubleshooting.

---

## Claude Skill Development

When creating or improving skills for Clawdbot, follow the **Progressive Disclosure** principle:

> **SKILL.md is a Map, Not the Territory** — Keep the main file under 500 lines. Move heavy reference data to separate files loaded on-demand.

**Key principles:**
- **Description is critical** — Claude reads only this to decide when to load a skill
- **Zero duplication** — Info lives in SKILL.md OR reference file, never both
- **Flat structure** — Avoid deep nesting; keep refs one level deep
- **Imperative tone** — "Do X" not "Please try to do X"

**Full guide:** `/home/art/Obsidian/04-Reference/Development/Claude Skills Best Practices.md`

---

**Last updated**: 2026-01-23
