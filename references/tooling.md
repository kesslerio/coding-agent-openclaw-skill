# Tooling and Timeouts

## Approach Comparison

| Method | Reliability | Output | Best For |
|--------|-------------|--------|----------|
| Direct CLI (Codex/Claude) | ✅ High | Text stream | Most tasks, session resume workflows |
| tmux + Codex CLI | ✅ High | Full TTY + logs | Long/complex tasks, durable sessions |
| Claude CLI (fallback) | ⚠️ Medium | Text stream | When Codex is unavailable |

## Direct CLI (Primary)

Agent CLIs support non-interactive execution with permission bypass and session resume.

### Codex CLI

| Command | Purpose |
|---------|---------|
| `codex --yolo exec "prompt"` | Full autonomy implementation |
| `codex exec --model gpt-5.3-codex "prompt"` | Specify model |
| `codex review --base main` | Code review against base branch |
| `codex exec resume --last` | Resume last session |
| `codex -c 'model_reasoning_effort="medium"' exec "prompt"` | Set reasoning effort |

### Claude Code CLI

| Command | Purpose |
|---------|---------|
| `claude -p --dangerously-skip-permissions "prompt"` | Full autonomy implementation |
| `claude -p --model opus "prompt"` | Specify model |
| `claude -p --permission-mode acceptEdits "prompt"` | Auto-accept edits only |
| `claude -p -c "follow up"` | Continue most recent session |
| `claude -p --resume <id> "follow up"` | Resume specific session |
| `claude --resume` | Interactive session picker |

### Permission Bypass

| CLI | Flag | Behavior |
|-----|------|----------|
| Codex | `--yolo` | Skip all permission prompts |
| Codex | `--dangerously-bypass-approvals-and-sandbox` | Full name equivalent |
| Claude | `--dangerously-skip-permissions` | Skip all permission checks |
| Claude | `--permission-mode bypassPermissions` | Equivalent via mode flag |
| Claude | `--permission-mode acceptEdits` | Auto-accept file edits only |

### Session Management

| CLI | Command | Purpose |
|-----|---------|---------|
| Codex | `codex exec resume --last` | Resume last session |
| Claude | `claude -p -c "prompt"` | Continue most recent conversation |
| Claude | `claude -p --resume <id> "prompt"` | Resume specific session by ID |
| Claude | `claude --resume` | Interactive session picker |

Sessions persist to disk (`~/.codex/sessions/` and `~/.claude/sessions/`) and survive process restarts.

## Wrapper Scripts (Recommended for Reviews)

The wrapper scripts run Codex inside tmux and emit monitoring info. `code-review` runs in blocking mode by default (`--wait --cleanup`).

```bash
# Review (10 min timeout default, auto-reasoning, blocking)
"${CODING_AGENT_DIR:-./}/scripts/code-review" "Review PR #123 for bugs, security, quality"

# Implementation (3 min timeout, tmux)
"${CODING_AGENT_DIR:-./}/scripts/code-implement" "Implement feature X in /path/to/repo"
```

### Auto-Reasoning Threshold

`code-review` automatically sets `medium` reasoning effort when the diff exceeds a threshold (default: 500 changed lines). Override with `--auto-reasoning-threshold <n>` or `CODE_REVIEW_DIFF_THRESHOLD` env var. Explicit `--reasoning-effort` takes priority.

## Advanced: tmux Wrapper (Optional)

For durable TTY sessions with logging. Use when you need to monitor long-running tasks or preserve terminal output.

### tmux Conventions (OpenClaw)

- Socket directory: `OPENCLAW_TMUX_SOCKET_DIR` (legacy: `CLAWDBOT_TMUX_SOCKET_DIR`)
- Default socket: `${TMPDIR:-/tmp}/openclaw-tmux-sockets/openclaw.sock`
- Send commands literally: `tmux ... send-keys -l -- "cmd"`
- Always print monitor commands after creating a session

### Direct tmux Usage

```bash
SOCKET_DIR="${OPENCLAW_TMUX_SOCKET_DIR:-${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/openclaw-tmux-sockets}}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/openclaw.sock"
SESSION="codex-review-$(date +%Y%m%d-%H%M%S)"

# Start session and run codex
tmux -S "$SOCKET" new-session -d -s "$SESSION" -n shell
TARGET="$(tmux -S "$SOCKET" list-panes -t "$SESSION" -F "#{session_name}:#{window_index}.#{pane_index}" | head -n 1)"
tmux -S "$SOCKET" send-keys -t "$TARGET" -l -- "codex review --base main"
tmux -S "$SOCKET" send-keys -t "$TARGET" Enter

# Monitor
tmux -S "$SOCKET" attach -t "$SESSION"
tmux -S "$SOCKET" capture-pane -p -J -t "$TARGET" -S -200
```

### tmux-run Helper

`scripts/tmux-run` standardizes sockets, logging, and session names. Non-blocking by default unless `--wait` is passed.

```bash
# Run an implementation command in tmux (non-blocking)
CODEX_TMUX_SESSION_PREFIX=codex-impl \
  ./scripts/tmux-run timeout 180s codex --yolo exec "Implement feature X"

# Run a review in tmux and wait for completion
CODEX_TMUX_SESSION_PREFIX=codex-review \
  ./scripts/tmux-run --wait timeout 600s codex review --base main --title "PR Review"
```

Logs: `${XDG_STATE_HOME:-$HOME/.local/state}/openclaw/tmux/<session>.log`

Cleanup:
- Kill session: `tmux -S "$SOCKET" kill-session -t "$SESSION"`
- Remove old logs: `find "$LOG_DIR" -type f -mtime +7 -delete`

## Minimum Timeouts

| Task Type | Minimum | Default |
|-----------|---------|---------|
| Code review | 600s | 600s |
| Architectural review | 600s | 600s |
| Single-file implementation | 120s | 180s |
| Multi-file implementation | 300s | 600s |

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `OPENCLAW_TMUX_SOCKET_DIR` | Socket directory (preferred) | `${TMPDIR:-/tmp}/openclaw-tmux-sockets` |
| `CLAWDBOT_TMUX_SOCKET_DIR` | Legacy socket directory | unset |
| `CODEX_TMUX_SOCKET_DIR` | Explicit socket directory override | unset |
| `CODEX_TMUX_SOCKET` | Explicit socket path | `${OPENCLAW_TMUX_SOCKET_DIR}/openclaw.sock` |
| `CODEX_TMUX_SESSION` | Explicit session name | autogenerated |
| `CODEX_TMUX_SESSION_PREFIX` | Session name prefix | `codex` |
| `CODEX_TMUX_LOG_DIR` | Log directory | `${XDG_STATE_HOME:-$HOME/.local/state}/openclaw/tmux` |
| `CODEX_TMUX_WAIT` | Block until command finishes | `0` |
| `CODEX_TMUX_CLEANUP` | Kill session after completion | `0` |
| `CODEX_TMUX_WAIT_TIMEOUT` | Optional wait timeout (seconds) | unset |
| `CODEX_TMUX_DISABLE` | Disable tmux and run direct CLI | `0` |
| `CODEX_TMUX_REQUIRED` | Require tmux for Codex (safe-fallback) | `1` |
| `GEMINI_FALLBACK_ENABLE` | Enable Gemini fallback in `safe-fallback.sh` | `0` |
| `CODE_REVIEW_TIMEOUT_SEC` | Review wrapper timeout (seconds) | `600` |
| `CODE_REVIEW_TIMEOUT` | Review wrapper timeout (ms, legacy) | `600000` |
| `CODE_REVIEW_REASONING_EFFORT` | Force review reasoning effort | unset |
| `CODE_REVIEW_DIFF_THRESHOLD` | Auto-medium threshold (changed lines) | `500` |
| `CODE_IMPLEMENT_TIMEOUT` | Implement wrapper timeout (ms) | `180000` |
