#!/usr/bin/env bash
# safe-fallback.sh - Try tools in order, report blocker if all fail
# NEVER falls back to direct edits - that's a Rule 1 violation
set -euo pipefail

# Configuration
MODE="${1:-impl}"  # impl or review
shift || true

PROMPT="${*:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Usage: safe-fallback.sh <impl|review> \"prompt...\""
  echo ""
  echo "Examples:"
  echo "  safe-fallback.sh impl \"Implement feature X\""
  echo "  safe-fallback.sh review \"Review this PR for bugs and security issues\""
  exit 1
fi

# Timeouts
IMPL_TIMEOUT=${IMPL_TIMEOUT:-180}
REVIEW_TIMEOUT=${REVIEW_TIMEOUT:-300}
TIMEOUT=$([[ "$MODE" == "review" ]] && echo "$REVIEW_TIMEOUT" || echo "$IMPL_TIMEOUT")

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

error() { echo -e "${RED}❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
ok() { echo -e "${GREEN}✅ $1${NC}" >&2; }
info() { echo -e "${CYAN}ℹ️  $1${NC}" >&2; }

# Track failures (portable array init)
FAILURES=()

# Try Codex MCP
try_codex_mcp() {
  info "Trying Codex MCP..."
  if command -v mcporter &>/dev/null; then
    local sandbox=$([[ "$MODE" == "review" ]] && echo "read-only" || echo "workspace-write")
    # Use heredoc-style quoting to handle special chars in prompt
    if mcporter call codex.codex "prompt=$PROMPT" "sandbox=$sandbox" 2>&1; then
      ok "Codex MCP succeeded"
      return 0
    else
      FAILURES+=("Codex MCP: command failed or usage limit")
    fi
  else
    FAILURES+=("Codex MCP: mcporter not installed")
  fi
  return 1
}

# Try Claude MCP
try_claude_mcp() {
  info "Trying Claude MCP..."
  if command -v mcporter &>/dev/null; then
    local subagent=$([[ "$MODE" == "review" ]] && echo "general-purpose" || echo "Bash")
    # Use simple quoting - mcporter handles the rest
    if mcporter call claude.Task "prompt=$PROMPT" "subagent_type=$subagent" 2>&1; then
      ok "Claude MCP succeeded"
      return 0
    else
      FAILURES+=("Claude MCP: command failed or connection error")
    fi
  else
    FAILURES+=("Claude MCP: mcporter not installed")
  fi
  return 1
}

# Try Codex CLI
try_codex_cli() {
  info "Trying Codex CLI..."
  if command -v codex &>/dev/null; then
    if [[ "$MODE" == "review" ]]; then
      local base_branch="main"
      if git rev-parse --git-dir &>/dev/null; then
        base_branch="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
        if [[ -z "$base_branch" ]]; then
          for candidate in main master trunk; do
            if git show-ref --verify --quiet "refs/heads/${candidate}" || \
               git show-ref --verify --quiet "refs/remotes/origin/${candidate}"; then
              base_branch="$candidate"
              break
            fi
          done
        fi
      fi
      if timeout "${TIMEOUT}s" codex review --base "$base_branch" 2>/dev/null; then
        ok "Codex CLI review succeeded"
        return 0
      else
        FAILURES+=("Codex CLI: review failed or timeout")
      fi
    else
      if timeout "${TIMEOUT}s" codex --yolo exec "$PROMPT" 2>/dev/null; then
        ok "Codex CLI succeeded"
        return 0
      else
        FAILURES+=("Codex CLI: exec failed or timeout")
      fi
    fi
  else
    FAILURES+=("Codex CLI: codex not installed")
  fi
  return 1
}

# Try Claude CLI
try_claude_cli() {
  info "Trying Claude CLI (timeout: ${TIMEOUT}s, skip-permissions)..."
  if command -v claude &>/dev/null; then
    if command -v timeout &>/dev/null; then
      # Use --dangerously-skip-permissions to avoid hanging on permission prompts
      if timeout "${TIMEOUT}s" claude -p --dangerously-skip-permissions "$PROMPT" 2>/dev/null; then
        ok "Claude CLI succeeded"
        return 0
      else
        FAILURES+=("Claude CLI: timeout or error (${TIMEOUT}s)")
      fi
    else
      FAILURES+=("Claude CLI: timeout command not available")
    fi
  else
    FAILURES+=("Claude CLI: claude not installed")
  fi
  return 1
}

# Report blocker (all to stderr)
report_blocker() {
  echo "" >&2
  error "BLOCKED: All implementation tools unavailable"
  echo "" >&2
  echo "Failures:" >&2
  for failure in "${FAILURES[@]}"; do
    echo "  - $failure" >&2
  done
  echo "" >&2
  echo "Options:" >&2
  echo "  a) Wait for tool availability (e.g., Codex usage limit reset)" >&2
  echo "  b) User manually runs: codex --yolo exec \"$PROMPT\"" >&2
  echo "  c) User explicitly authorizes override: 'Override Rule 1 for this task'" >&2
  echo "" >&2
  echo "⛔ DO NOT use direct file edits - this is a Rule 1 violation" >&2
  exit 1
}

# Main execution
main() {
  # All status to stderr so stdout only has tool output
  echo "Mode: $MODE | Timeout: ${TIMEOUT}s" >&2
  echo "Prompt: $PROMPT" >&2
  echo "" >&2

  # Try tools in order
  try_codex_mcp && exit 0
  warn "Codex MCP unavailable, trying next..."

  try_claude_mcp && exit 0
  warn "Claude MCP unavailable, trying next..."

  try_codex_cli && exit 0
  warn "Codex CLI unavailable, trying next..."

  try_claude_cli && exit 0
  warn "Claude CLI unavailable..."

  # All tools failed
  report_blocker
}

main
