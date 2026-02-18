#!/usr/bin/env bash
# safe-fallback.sh - Try tools in order, report blocker if all fail
# NEVER falls back to direct edits - that's a Rule 1 violation
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Timeouts
IMPL_TIMEOUT=${IMPL_TIMEOUT:-180}
REVIEW_TIMEOUT=${REVIEW_TIMEOUT:-1200}
TIMEOUT=$([[ "$MODE" == "review" ]] && echo "$REVIEW_TIMEOUT" || echo "$IMPL_TIMEOUT")

# Require tmux by default for Codex
CODEX_TMUX_REQUIRED=${CODEX_TMUX_REQUIRED:-1}
# Gemini fallback is opt-in only.
GEMINI_FALLBACK_ENABLE=${GEMINI_FALLBACK_ENABLE:-0}
if [[ "$GEMINI_FALLBACK_ENABLE" != "0" && "$GEMINI_FALLBACK_ENABLE" != "1" ]]; then
  echo "Error: GEMINI_FALLBACK_ENABLE must be 0 or 1" >&2
  exit 1
fi

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

# Try Codex CLI in tmux
try_codex_tmux() {
  info "Trying Codex CLI in tmux..."
  if [[ "$MODE" == "review" ]]; then
    if "$SCRIPT_DIR/code-review" "$PROMPT"; then
      ok "Codex tmux session started"
      return 0
    fi
  else
    if "$SCRIPT_DIR/code-implement" "$PROMPT"; then
      ok "Codex tmux session started"
      return 0
    fi
  fi
  FAILURES+=("Codex tmux: failed to start")
  return 1
}

# Try Codex CLI (direct, no tmux)
try_codex_cli_direct() {
  info "Trying Codex CLI (direct)..."
  if command -v codex &>/dev/null; then
    if ! command -v timeout &>/dev/null; then
      FAILURES+=("Codex CLI: timeout not installed")
      return 1
    fi
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
        if [[ -z "$base_branch" ]]; then
          base_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
        fi
      fi
      if timeout "${TIMEOUT}s" codex -c 'model_reasoning_effort="medium"' review --base "$base_branch" --title "${PROMPT:0:100}" 2>/dev/null; then
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

# Try Gemini CLI (opt-in only)
try_gemini_cli() {
  if [[ "$GEMINI_FALLBACK_ENABLE" != "1" ]]; then
    FAILURES+=("Gemini CLI: disabled (set GEMINI_FALLBACK_ENABLE=1 to enable)")
    return 1
  fi

  info "Trying Gemini CLI (timeout: ${TIMEOUT}s)..."
  if command -v gemini &>/dev/null; then
    if command -v timeout &>/dev/null; then
      if timeout "${TIMEOUT}s" gemini -y "$PROMPT" 2>/dev/null; then
        ok "Gemini CLI succeeded"
        return 0
      else
        FAILURES+=("Gemini CLI: timeout or error (${TIMEOUT}s)")
      fi
    else
      FAILURES+=("Gemini CLI: timeout command not available")
    fi
  else
    FAILURES+=("Gemini CLI: gemini not installed")
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
  echo "Gemini fallback: $GEMINI_FALLBACK_ENABLE" >&2
  echo "Prompt: $PROMPT" >&2
  echo "" >&2

  # Try tools in order
  try_codex_tmux && exit 0
  warn "Codex tmux unavailable, trying next..."

  if [[ "$CODEX_TMUX_REQUIRED" != "1" ]]; then
    try_codex_cli_direct && exit 0
    warn "Codex CLI unavailable, trying next..."
  fi

  try_claude_cli && exit 0
  warn "Claude CLI unavailable..."

  try_gemini_cli && exit 0
  warn "Gemini CLI unavailable..."

  # All tools failed
  report_blocker
}

main
