#!/usr/bin/env bash
# acp-smoke-local.sh - bounded local ACP health check for codex/acpx wiring
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/canonical-repo-guard.sh"
ensure_canonical_repo_from_script_dir "$SCRIPT_DIR"

AGENT="${CODING_AGENT_ACP_SMOKE_AGENT:-codex}"
RUN_TIMEOUT="${CODING_AGENT_ACP_SMOKE_TIMEOUT:-120}"
PROMPT='Reply with READY only.'

if ! command -v acpx &>/dev/null; then
  printf '[fail] acpx: command not found in PATH\n' >&2
  exit 1
fi

if ! command -v timeout &>/dev/null; then
  printf '[fail] timeout: command not found in PATH\n' >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail_with_log() {
  local title="$1"
  local log_file="$2"
  printf '[fail] %s\n' "$title" >&2
  printf '%s\n' '------- captured output -------' >&2
  sed -n '1,200p' "$log_file" >&2
  printf '%s\n' '-------------------------------' >&2
  exit 1
}

assert_no_runtime_loader_errors() {
  local log_file="$1"
  if rg -qi 'error while loading shared libraries|cannot open shared object file|failed to start|adapter startup failed|command not found' "$log_file"; then
    fail_with_log 'ACP runtime/loader error detected' "$log_file"
  fi
}

printf 'ACP local smoke check\n'
printf '=====================\n'
printf '[info] cwd: %s\n' "$PWD"
printf '[info] agent: %s\n' "$AGENT"
printf '[info] timeout: %ss\n' "$RUN_TIMEOUT"

status_log="$tmp_dir/status.log"
printf '\n[step] status\n'
if ! timeout "${RUN_TIMEOUT}s" acpx --cwd "$PWD" --format json "$AGENT" status >"$status_log" 2>&1; then
  fail_with_log 'status command failed' "$status_log"
fi
assert_no_runtime_loader_errors "$status_log"
printf '[ok] status returned\n'

session_name="acp-smoke-$(date +%s)"
session_log="$tmp_dir/session-new.log"
printf '\n[step] sessions new (%s)\n' "$session_name"
if ! timeout "${RUN_TIMEOUT}s" acpx --cwd "$PWD" --format json "$AGENT" sessions new --name "$session_name" >"$session_log" 2>&1; then
  fail_with_log 'sessions new command failed' "$session_log"
fi
assert_no_runtime_loader_errors "$session_log"
printf '[ok] session created\n'

exec_log="$tmp_dir/exec.log"
printf '\n[step] one-shot exec\n'
if ! timeout "${RUN_TIMEOUT}s" acpx --cwd "$PWD" --format text --timeout 90 "$AGENT" exec "$PROMPT" >"$exec_log" 2>&1; then
  fail_with_log 'exec command failed' "$exec_log"
fi
assert_no_runtime_loader_errors "$exec_log"
if ! rg -q '\bREADY\b' "$exec_log"; then
  fail_with_log 'exec did not return READY' "$exec_log"
fi
printf '[ok] exec returned READY\n'

close_log="$tmp_dir/session-close.log"
if timeout "${RUN_TIMEOUT}s" acpx --cwd "$PWD" --format json "$AGENT" sessions close "$session_name" >"$close_log" 2>&1; then
  printf '\n[ok] closed smoke session: %s\n' "$session_name"
else
  printf '\n[warn] could not close smoke session: %s\n' "$session_name" >&2
  sed -n '1,80p' "$close_log" >&2
fi

printf '\nSmoke passed.\n'
