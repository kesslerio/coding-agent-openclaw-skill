#!/usr/bin/env bash
set -euo pipefail

resolve_claude_bin() {
  local claude_local="${HOME}/.claude/local/claude"
  if [[ -x "$claude_local" ]]; then
    printf '%s\n' "$claude_local"
    return 0
  fi

  if command -v claude &>/dev/null; then
    command -v claude
    return 0
  fi

  return 1
}
