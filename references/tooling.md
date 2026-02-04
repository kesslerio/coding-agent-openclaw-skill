# Tooling and Timeouts

## Approach Comparison

| Method | Reliability | Output | Best For |
|--------|-------------|--------|----------|
| MCP + `MCPORTER_DEBUG_HANG=1` | ⚠️ Moderate | Structured JSON | Short tasks (<60s) |
| `codex --yolo exec` | ✅ High | Text stream | Implementation tasks |
| `codex review` | ✅ High | Review format | PR reviews |
| Interactive tmux | ✅ High | Full UI | Complex/long tasks |

## Known Issues

**Codex MCP hanging** (GitHub #6664, #6127):
- The `codex mcp-server` hangs indefinitely for tasks >30-60s
- Workaround: `MCPORTER_DEBUG_HANG=1` environment variable
- Default mcporter timeout (30s) is too short for most tasks

## Wrapper Scripts (Recommended)

The wrapper scripts handle timeouts and fallbacks automatically:

```bash
# Review (5 min timeout, auto-fallback)
"${CODING_AGENT_DIR:-./}/scripts/code-review" "Review PR #123 for bugs, security, quality"

# Implementation (3 min timeout, auto-fallback)  
"${CODING_AGENT_DIR:-./}/scripts/code-implement" "Implement feature X in /path/to/repo"
```

## Direct MCP Usage

If using MCP directly, always set these environment variables:

```bash
export MCPORTER_DEBUG_HANG=1
export MCPORTER_CALL_TIMEOUT=300000  # 5 min in ms

mcporter call codex.codex \
  'prompt="Your prompt here"' \
  'sandbox=workspace-write' \
  'approval-policy=on-failure'
```

## CLI Fallbacks

When MCP fails or for complex tasks, use CLI directly:

```bash
# Implementation (full autonomy)
timeout 180s codex --yolo exec "Implement feature X. No questions."

# Review (purpose-built command)
codex review --base main --title "PR Review"

# Claude CLI fallback
timeout 300s claude -p --dangerously-skip-permissions "Review this codebase..."
```

## Minimum Timeouts

| Task Type | Minimum | Recommended |
|-----------|---------|-------------|
| Code review | 180s | 300s |
| Architectural review | 300s | 600s |
| Single-file implementation | 120s | 180s |
| Multi-file implementation | 300s | 600s |

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `MCPORTER_DEBUG_HANG` | Fix MCP hanging issues | `1` (set by wrappers) |
| `MCPORTER_CALL_TIMEOUT` | MCP call timeout (ms) | `30000` |
| `CODE_REVIEW_TIMEOUT` | Review wrapper timeout (ms) | `300000` |
| `CODE_IMPLEMENT_TIMEOUT` | Implement wrapper timeout (ms) | `180000` |

## Fallback Chain

**Implementation:**
1. MCP with `MCPORTER_DEBUG_HANG=1`
2. `codex --yolo exec`
3. Manual intervention

**Review:**
1. MCP with `MCPORTER_DEBUG_HANG=1`
2. `codex review --base main`
3. `codex --yolo exec`
4. Manual intervention

## Advanced: tmux-based Interactive Sessions

For complex tasks requiring monitoring, use tmux:

```bash
# Create persistent session
SOCKET="/tmp/codex-work.sock"
tmux -S "$SOCKET" new-session -d -s codex-work
tmux -S "$SOCKET" send-keys "cd /path/to/project && codex" Enter

# Send commands
tmux -S "$SOCKET" send-keys "Your prompt here" Enter

# Capture output
tmux -S "$SOCKET" capture-pane -p -S -100

# Attach for monitoring
tmux -S "$SOCKET" attach
```

See [codex-cli-farm](https://github.com/waskosky/codex-cli-farm) for a full tmux management solution.
