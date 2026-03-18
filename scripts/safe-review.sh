#!/usr/bin/env bash
# safe-review.sh - Wrapper for claude/codex review commands
# Enforces timeout minimums and blocks --max-turns
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

# Configuration
MIN_REVIEW_TIMEOUT=${MIN_REVIEW_TIMEOUT:-600}
DEFAULT_TIMEOUT=${DEFAULT_TIMEOUT:-1200}
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/canonical-repo-guard.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-cli.sh"
ensure_canonical_repo_from_script_dir "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() { echo -e "${RED}❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }

emit_run_event() {
  local event="$1"
  local details="${2:-}"
  if [[ -n "$details" ]]; then
    echo "RUN_EVENT $event ts=$(date -Iseconds) $details" >&2
  else
    echo "RUN_EVENT $event ts=$(date -Iseconds)" >&2
  fi
}

HEARTBEAT_PID=""
CHILD_PID=""
TERMINAL_EVENT_EMITTED=0
START_TS=""

start_heartbeat() {
  (
    sleep 30 || exit 0
    while true; do
      local now elapsed
      now="$(date +%s)"
      elapsed=$(( now - START_TS ))
      emit_run_event "heartbeat" "phase=safe-review cli=$CLI elapsed=${elapsed}s"
      sleep 20 || exit 0
    done
  ) &
  HEARTBEAT_PID=$!
}

stop_heartbeat() {
  if [[ -n "$HEARTBEAT_PID" ]]; then
    kill "$HEARTBEAT_PID" >/dev/null 2>&1 || true
    wait "$HEARTBEAT_PID" 2>/dev/null || true
    HEARTBEAT_PID=""
  fi
}

emit_terminal_event_once() {
  local event="$1"
  local details="${2:-}"
  if (( TERMINAL_EVENT_EMITTED == 0 )); then
    emit_run_event "$event" "$details"
    TERMINAL_EVENT_EMITTED=1
  fi
}

# shellcheck disable=SC2317,SC2329
handle_signal() {
  local signal="$1"
  local exit_code="130"
  if [[ "$signal" == "TERM" ]]; then
    exit_code="143"
  fi

  stop_heartbeat
  if [[ -n "$CHILD_PID" ]]; then
    kill "$CHILD_PID" >/dev/null 2>&1 || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  emit_terminal_event_once "interrupted" "phase=safe-review cli=$CLI signal=$signal exit_code=$exit_code"
  exit "$exit_code"
}

# Detect which CLI to use
CLI="${1:-}"
if [[ -z "$CLI" ]]; then
  error "Usage: safe-review.sh <claude|codex> [args...]"
  exit 1
fi

if [[ "$CLI" != "claude" && "$CLI" != "codex" ]]; then
  error "Unknown CLI: $CLI. Must be 'codex' or 'claude'."
  exit 1
fi

shift # Remove CLI name from args
START_TS="$(date +%s)"
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM
emit_run_event "start" "phase=safe-review cli=$CLI"

# Check for forbidden --max-turns flag
for arg in "$@"; do
  if [[ "$arg" == "--max-turns"* ]] || [[ "$arg" == "--max-turns="* ]]; then
    error "--max-turns is FORBIDDEN by coding-agent skill."
    echo "  Let the command complete naturally with adequate timeout."
    echo "  See: SKILL.md Rule 4"
    emit_terminal_event_once "failed" "phase=safe-review cli=$CLI reason=forbidden_max_turns"
    exit 1
  fi
done

# Check timeout command exists (not default on macOS)
if ! command -v timeout &>/dev/null; then
  error "'timeout' command not found. Install coreutils (brew install coreutils on macOS)."
  emit_terminal_event_once "failed" "phase=safe-review cli=$CLI reason=missing_timeout"
  exit 1
fi

# Parse timeout from environment or args
TIMEOUT="${TIMEOUT:-$DEFAULT_TIMEOUT}"

# Check minimum timeout for reviews
if [[ $TIMEOUT -lt $MIN_REVIEW_TIMEOUT ]]; then
  error "Timeout ${TIMEOUT}s is below minimum ${MIN_REVIEW_TIMEOUT}s for reviews."
  echo "  Reviews require adequate time for quality analysis."
  echo "  See: SKILL.md Rule 5"
  echo ""
  echo "  Fix: TIMEOUT=$MIN_REVIEW_TIMEOUT $0 $CLI $*"
  emit_terminal_event_once "failed" "phase=safe-review cli=$CLI reason=timeout_below_minimum"
  exit 1
fi

# Validate CLI exists
CLI_BIN="$CLI"
if [[ "$CLI" == "claude" ]]; then
  if ! CLI_BIN="$(resolve_claude_bin)"; then
    if [[ -n "${CODING_AGENT_CLAUDE_BIN:-}" ]]; then
      error "CODING_AGENT_CLAUDE_BIN is set but not executable: ${CODING_AGENT_CLAUDE_BIN}"
    else
      error "Claude CLI not found (tried CODING_AGENT_CLAUDE_BIN, ~/.claude/local/claude, then PATH)."
    fi
    emit_terminal_event_once "failed" "phase=safe-review cli=$CLI reason=missing_claude_cli"
    exit 1
  fi
elif ! command -v "$CLI" &>/dev/null; then
  error "CLI '$CLI' not found in PATH"
  emit_terminal_event_once "failed" "phase=safe-review cli=$CLI reason=missing_cli"
  exit 1
fi

# For Claude CLI with -p flag, add --dangerously-skip-permissions to avoid hanging
EXTRA_ARGS=()
if [[ "$CLI" == "claude" ]]; then
  for arg in "$@"; do
    if [[ "$arg" == "-p" || "$arg" == "--print" ]]; then
      # Check if --dangerously-skip-permissions is already present
      if [[ ! " $* " =~ " --dangerously-skip-permissions " ]]; then
        EXTRA_ARGS+=("--dangerously-skip-permissions")
        warn "Adding --dangerously-skip-permissions to prevent permission prompt hangs"
      fi
      break
    fi
  done
fi

# Execute with timeout (use ${arr[@]+...} for older bash compatibility)
warn "Running $CLI with ${TIMEOUT}s timeout (min: ${MIN_REVIEW_TIMEOUT}s)"
start_heartbeat

set +e
timeout -k5s "${TIMEOUT}s" "$CLI_BIN" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} "$@" &
CHILD_PID=$!
wait "$CHILD_PID"
rc=$?
set -e

stop_heartbeat
CHILD_PID=""

case "$rc" in
  0)
    emit_terminal_event_once "done" "phase=safe-review cli=$CLI exit_code=0"
    ;;
  124|130|137|143)
    emit_terminal_event_once "interrupted" "phase=safe-review cli=$CLI exit_code=$rc"
    ;;
  *)
    emit_terminal_event_once "failed" "phase=safe-review cli=$CLI exit_code=$rc"
    ;;
esac

exit "$rc"
