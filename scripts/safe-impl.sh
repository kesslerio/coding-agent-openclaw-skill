#!/usr/bin/env bash
# safe-impl.sh - Wrapper for codex implementation commands
# Enforces branch check and blocks --max-turns
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

# Configuration
MIN_IMPL_TIMEOUT=${MIN_IMPL_TIMEOUT:-180}
DEFAULT_TIMEOUT=${DEFAULT_TIMEOUT:-180}

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

error() { echo -e "${RED}❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
ok() { echo -e "${GREEN}✅ $1${NC}" >&2; }

# Check for forbidden --max-turns flag
for arg in "$@"; do
  if [[ "$arg" == "--max-turns"* ]] || [[ "$arg" == "--max-turns="* ]]; then
    error "--max-turns is FORBIDDEN by coding-agent skill."
    echo "  Let the command complete naturally with adequate timeout."
    echo "  See: SKILL.md Rule 4"
    exit 1
  fi
done

# Check timeout command exists (not default on macOS)
if ! command -v timeout &>/dev/null; then
  error "'timeout' command not found. Install coreutils (brew install coreutils on macOS)."
  exit 1
fi

# Check we're not on main/master branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -z "$BRANCH" ]]; then
  error "Not in a git repository or no branch checked out."
  echo "  Implementation requires a git repository with a feature branch."
  exit 1
fi

PROTECTED_BRANCHES="main master"
for protected in $PROTECTED_BRANCHES; do
  if [[ "$BRANCH" == "$protected" ]]; then
    error "Cannot run implementation on '$BRANCH' branch."
    echo "  Create a feature branch first:"
    echo "    git checkout -b type/description"
    echo "  See: SKILL.md Rule 2"
    exit 1
  fi
done

ok "Branch check passed: $BRANCH"

# Parse timeout from environment
TIMEOUT="${TIMEOUT:-$DEFAULT_TIMEOUT}"

# Validate minimum timeout
if [[ $TIMEOUT -lt $MIN_IMPL_TIMEOUT ]]; then
  warn "Timeout ${TIMEOUT}s is below recommended ${MIN_IMPL_TIMEOUT}s"
fi

# Require explicit CLI specification
CLI="${1:-}"
if [[ -z "$CLI" ]]; then
  error "Usage: safe-impl.sh <codex|claude> [args...]"
  exit 1
fi

if [[ "$CLI" != "codex" && "$CLI" != "claude" ]]; then
  error "Unknown CLI: $CLI. Must be 'codex' or 'claude'."
  exit 1
fi

shift # Remove CLI name from args

# Validate CLI exists
if ! command -v "$CLI" &>/dev/null; then
  error "CLI '$CLI' not found in PATH"
  exit 1
fi

# Prefer tmux for codex unless explicitly disabled
if [[ "$CLI" == "codex" && "${CODEX_TMUX_DISABLE:-0}" != "1" ]]; then
  if ! command -v tmux &>/dev/null; then
    error "tmux not found in PATH. Install tmux or set CODEX_TMUX_DISABLE=1 to run direct."
    exit 1
  fi
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  TMUX_RUN="$SCRIPT_DIR/tmux-run"
  if [[ ! -x "$TMUX_RUN" ]]; then
    error "tmux-run not found or not executable: $TMUX_RUN"
    exit 1
  fi
  warn "Running codex implementation in tmux with ${TIMEOUT}s timeout"
  CODEX_TMUX_SESSION_PREFIX="${CODEX_TMUX_SESSION_PREFIX:-codex-impl}" \
    "$TMUX_RUN" timeout "${TIMEOUT}s" "$CLI" "$@"
  exit $?
fi

# For Claude CLI with -p flag, add --dangerously-skip-permissions to avoid hanging
EXTRA_ARGS=()
if [[ "$CLI" == "claude" ]]; then
  for arg in "$@"; do
    if [[ "$arg" == "-p" || "$arg" == "--print" ]]; then
      if [[ ! " $* " =~ " --dangerously-skip-permissions " ]]; then
        EXTRA_ARGS+=("--dangerously-skip-permissions")
        warn "Adding --dangerously-skip-permissions to prevent permission prompt hangs"
      fi
      break
    fi
  done
fi

# Execute with timeout (use ${arr[@]+...} for older bash compatibility)
warn "Running $CLI implementation with ${TIMEOUT}s timeout"
exec timeout "${TIMEOUT}s" "$CLI" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} "$@"
