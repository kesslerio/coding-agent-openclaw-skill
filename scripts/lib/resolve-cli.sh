#!/usr/bin/env bash
set -euo pipefail

resolve_claude_bin() {
  if [[ -n "${CODING_AGENT_CLAUDE_BIN:-}" ]]; then
    if [[ -x "${CODING_AGENT_CLAUDE_BIN}" ]]; then
      printf '%s\n' "${CODING_AGENT_CLAUDE_BIN}"
      return 0
    fi
    return 1
  fi

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
