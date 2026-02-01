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

# Track failures
declare -a FAILURES=()

# Try Codex MCP
try_codex_mcp() {
  info "Trying Codex MCP..."
  if command -v mcporter &>/dev/null; then
    local sandbox=$([[ "$MODE" == "review" ]] && echo "read-only" || echo "workspace-write")
    if mcporter call codex.codex "prompt=\"$PROMPT\"" "sandbox=$sandbox" 2>/dev/null; then
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
    if mcporter call claude.Task "prompt=\"$PROMPT\"" "subagent_type=\"$subagent\"" 2>/dev/null; then
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
      if timeout "${TIMEOUT}s" codex review --base main 2>/dev/null; then
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

# Report blocker
report_blocker() {
  echo ""
  error "BLOCKED: All implementation tools unavailable"
  echo ""
  echo "Failures:"
  for failure in "${FAILURES[@]}"; do
    echo "  - $failure"
  done
  echo ""
  echo "Options:"
  echo "  a) Wait for tool availability (e.g., Codex usage limit reset)"
  echo "  b) User manually runs: codex --yolo exec \"$PROMPT\""
  echo "  c) User explicitly authorizes override: 'Override Rule 1 for this task'"
  echo ""
  echo "⛔ DO NOT use direct file edits - this is a Rule 1 violation"
  exit 1
}

# Main execution
main() {
  echo "Mode: $MODE | Timeout: ${TIMEOUT}s"
  echo "Prompt: $PROMPT"
  echo ""

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
