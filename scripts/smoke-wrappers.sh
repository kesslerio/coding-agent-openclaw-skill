#!/usr/bin/env bash
# smoke-wrappers.sh - lightweight behavior checks for wrapper scripts
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export CODING_AGENT_ALLOW_NONCANONICAL=1

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/timeout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 ]]; then
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--kill-after)
      shift 2
      ;;
    -k*)
      shift
      ;;
    -*)
      shift
      ;;
    --*)
      shift
      ;;
    *)
      shift
      break
      ;;
  esac
done

if [[ $# -lt 1 ]]; then
  exit 2
fi

exec "$@"
EOF

cat >"$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SMOKE_GH_ARGS_FILE:-}" ]]; then
  {
    printf -- '---CALL---\n'
    for arg in "$@"; do
      printf '%s\n' "$arg"
    done
  } >>"$SMOKE_GH_ARGS_FILE"
fi

if [[ "${1:-}" == "--version" ]]; then
  echo "gh version smoke"
  exit 0
fi

if [[ "${1:-}" == "pr" ]]; then
  sub="${2:-}"
  case "$sub" in
    list)
      if [[ "${SMOKE_GH_PR_EXISTS:-0}" == "1" ]]; then
        printf '[{"number":99,"url":"https://example.test/pr/99"}]\n'
      else
        printf '[]\n'
      fi
      exit 0
      ;;
    view)
      if [[ -n "${SMOKE_GH_PR_VIEW_JSON:-}" ]]; then
        printf '%s\n' "$SMOKE_GH_PR_VIEW_JSON"
        exit 0
      fi
      if [[ "${SMOKE_GH_PR_EXISTS:-0}" == "1" ]]; then
        printf '{"number":99,"url":"https://example.test/pr/99"}\n'
        exit 0
      fi
      exit 1
      ;;
    create)
      printf '%s\n' "${SMOKE_GH_PR_CREATE_URL:-https://example.test/pr/123}"
      exit 0
      ;;
    edit|checks)
      exit 0
      ;;
  esac
fi

if [[ "${1:-}" == "api" && "${2:-}" == "graphql" ]]; then
  if [[ -n "${SMOKE_GH_GRAPHQL_JSON:-}" ]]; then
    printf '%s\n' "$SMOKE_GH_GRAPHQL_JSON"
    exit 0
  fi

  if [[ -n "${SMOKE_GH_GRAPHQL_SCENARIO:-}" ]]; then
    repo_path="${SMOKE_GH_REPO_PATH:-$PWD}"
    head_oid="${SMOKE_GH_GRAPHQL_HEAD_OID:-$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || printf 'missing-head')}"
    review_author="${SMOKE_GH_GRAPHQL_REVIEW_AUTHOR:-codex-bot}"
    pr_url="${SMOKE_GH_GRAPHQL_PR_URL:-https://example.test/pr/99}"
    case "$SMOKE_GH_GRAPHQL_SCENARIO" in
      immediate-clear)
        cat <<JSON
{"data":{"repository":{"pullRequest":{"number":99,"url":"$pr_url","headRefOid":"$head_oid","reviews":{"nodes":[{"author":{"login":"$review_author"},"state":"COMMENTED","submittedAt":"2026-01-01T00:00:00Z","url":"$pr_url#pullrequestreview-1","commit":{"oid":"$head_oid"}}]}}}}}
JSON
        exit 0
        ;;
      pending-review)
        cat <<JSON
{"data":{"repository":{"pullRequest":{"number":99,"url":"$pr_url","headRefOid":"$head_oid","reviews":{"nodes":[]}}}}}
JSON
        exit 0
        ;;
      pending-head)
        cat <<JSON
{"data":{"repository":{"pullRequest":{"number":99,"url":"$pr_url","headRefOid":"stale-head","reviews":{"nodes":[]}}}}}
JSON
        exit 0
        ;;
    esac
  fi
fi

exit 0
EOF

cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SMOKE_CODEX_ARGS_FILE:?}"
{
  printf -- '---CALL---\n'
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >>"$SMOKE_CODEX_ARGS_FILE"

all_args="$*"

if [[ "${SMOKE_CODEX_MODE:-}" == "review-loop" ]]; then
  state_file="${SMOKE_REVIEW_LOOP_STATE_FILE:-}"
  if [[ -z "$state_file" ]]; then
    state_file="$(mktemp)"
  fi
  if [[ ! -f "$state_file" ]]; then
    printf '0' >"$state_file"
  fi

  if [[ "${1:-}" == "review" ]]; then
    review_count="$(cat "$state_file")"
    review_count=$((review_count + 1))
    printf '%s' "$review_count" >"$state_file"

    scenario="${SMOKE_REVIEW_LOOP_SCENARIO:-converge}"
    case "$scenario" in
      converge)
        if (( review_count == 1 )); then
          cat <<'OUT'
Review findings.
SUPERVISOR_COUNTS P0=0 P1=1 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|src/app.ts:42|Null guard missing|Add null guard for payload lookup
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        else
          cat <<'OUT'
Review findings.
SUPERVISOR_COUNTS P0=0 P1=0 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|none|none|none
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        fi
        exit 0
        ;;
      already-clear)
        cat <<'OUT'
Already clear.
SUPERVISOR_COUNTS P0=0 P1=0 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|none|none|none
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        exit 0
        ;;
      parse-retry-success)
        if (( review_count == 1 )); then
          echo "Missing strict footer intentionally."
        else
          cat <<'OUT'
Retry review.
SUPERVISOR_COUNTS P0=0 P1=0 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|none|none|none
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        fi
        exit 0
        ;;
      parse-retry-fail)
        echo "Still malformed footer."
        exit 0
        ;;
      review-nonzero)
        echo "Wrapped review failed intentionally." >&2
        exit 7
        ;;
      state-change)
        if (( review_count == 1 )); then
          cat <<'OUT'
Iteration 1 findings.
SUPERVISOR_COUNTS P0=0 P1=0 P2=1 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|none|none|none
SUPERVISOR_TOP P2|src/a.ts:9|Slow path|Index query path
SUPERVISOR_TOP P3|none|none|none
OUT
        elif (( review_count == 2 )); then
          cat <<'OUT'
Iteration 2 findings.
SUPERVISOR_COUNTS P0=0 P1=1 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|src/b.ts:15|Regression introduced|Restore previous guard behavior
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        else
          cat <<'OUT'
Iteration 3 findings.
SUPERVISOR_COUNTS P0=0 P1=0 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|none|none|none
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        fi
        exit 0
        ;;
      stuck)
        cat <<'OUT'
Stuck findings.
SUPERVISOR_COUNTS P0=0 P1=1 P2=0 P3=0
SUPERVISOR_TOP P0|none|none|none
SUPERVISOR_TOP P1|src/stuck.ts:2|Issue remains|Need patch
SUPERVISOR_TOP P2|none|none|none
SUPERVISOR_TOP P3|none|none|none
OUT
        exit 0
        ;;
      *)
        echo "Unknown SMOKE_REVIEW_LOOP_SCENARIO" >&2
        exit 2
        ;;
    esac
  fi

  if [[ " $all_args " == *" exec "* ]]; then
    if [[ "${SMOKE_REVIEW_LOOP_FIX_BEHAVIOR:-change}" == "change" ]]; then
      target_file="${SMOKE_REVIEW_LOOP_FIX_FILE:-$PWD/review-loop-fix.txt}"
      printf 'fix-%s\n' "$(date +%s)" >>"$target_file"
    fi
    echo "fix ok"
    exit 0
  fi
fi

if [[ -n "${SMOKE_CODEX_STDOUT:-}" ]]; then
  printf '%s\n' "$SMOKE_CODEX_STDOUT"
fi

if [[ -n "${SMOKE_CODEX_EXIT_CODE:-}" ]]; then
  exit "$SMOKE_CODEX_EXIT_CODE"
fi

if [[ "$all_args" == *"LIVE REVIEW SECTION:"* ]]; then
  section="$(printf '%s\n' "$all_args" | sed -nE 's/.*LIVE REVIEW SECTION: ([A-Za-z ]+).*/\1/p' | head -n 1)"
  if [[ -z "$section" ]]; then
    section="Unknown"
  fi
  cat <<EOF2
# ${section} Findings

1. ${section} issue.
A) Do recommended ${section} option.
B) Do alternate ${section} option.
EOF2
  exit 0
fi

cat <<'PLAN'
# Plan: Smoke test

## Fast-Path
- Eligible: yes
- Reason: test

## 1. Problem statement
x

## 2. Current state evidence
- Files:
  - `README.md#L1-L1` — test
- Commands run:
  - `rg foo`
- Observations:
  - test

## 3. Proposed approach
x

## 4. Step-by-step change list
1. a
2. b

## 5. Risks + rollback
- Risks:
  - r
- Rollback:
  - `git restore .`

## 6. Test plan
- Automated:
  - `echo ok`
- Manual:
  - check
- Success criteria:
  - ok

## 7. Out-of-scope
- none

## 8. Approval prompt
Reply with one:
- `APPROVE: smoke`
- `REVISE: tweak`
PLAN
exit 0
EOF

cat >"$fake_bin/safe-review.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SMOKE_SAFE_REVIEW_ARGS_FILE:-}" ]]; then
  {
    printf -- '---CALL---\n'
    printf 'TIMEOUT=%s\n' "${TIMEOUT:-}"
    for arg in "$@"; do
      printf '%s\n' "$arg"
    done
  } >>"$SMOKE_SAFE_REVIEW_ARGS_FILE"
fi

exec "$@"
EOF

cat >"$fake_bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SMOKE_CLAUDE_ARGS_FILE:?}"
{
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >"$SMOKE_CLAUDE_ARGS_FILE"
exit 0
EOF

cat >"$fake_bin/acpx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SMOKE_ACPX_ARGS_FILE:-}" ]]; then
  {
    printf -- '---CALL---\n'
    for arg in "$@"; do
      printf '%s\n' "$arg"
    done
  } >>"$SMOKE_ACPX_ARGS_FILE"
fi

case "${SMOKE_ACPX_BEHAVIOR:-fail}" in
  success)
    printf 'acpx ok\n'
    exit 0
    ;;
  smoke-local)
    args=" $* "
    if [[ "$args" == *" status "* ]]; then
      printf '{"ok":true}\n'
      exit 0
    fi
    if [[ "$args" == *" sessions ensure "* ]]; then
      printf '{"ok":true}\n'
      exit 0
    fi
    if [[ "$args" == *" sessions close "* ]]; then
      printf '{"ok":true}\n'
      exit 0
    fi
    if [[ "$args" == *" -s "* ]]; then
      printf 'READY\n'
      exit 0
    fi
    printf 'unexpected smoke-local invocation\n' >&2
    exit 1
    ;;
  fail)
    printf 'acpx fail\n' >&2
    exit 1
    ;;
  *)
    printf 'invalid SMOKE_ACPX_BEHAVIOR\n' >&2
    exit 2
    ;;
esac
EOF

cat >"$fake_bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "mock tmux unavailable" >&2
exit 1
EOF

cat >"$fake_bin/tmux-run" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mode="${SMOKE_TMUX_RUN_MODE:-success}"
session="${SMOKE_TMUX_RUN_SESSION:-smoke-session}"
log_path="${SMOKE_TMUX_RUN_LOG_PATH:-/tmp/smoke-session.log}"
elapsed="${SMOKE_TMUX_RUN_ELAPSED:-21}"
exit_code="${SMOKE_TMUX_RUN_EXIT_CODE:-0}"
token="${CODEX_TMUX_EVENT_TOKEN:-}"
output_mode="text"
token_part=""
if [[ -n "$token" ]]; then
  token_part=" token=${token}"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      output_mode="${2:-text}"
      shift 2
      ;;
    --wait|--cleanup)
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ -n "${SMOKE_TMUX_RUN_ARGS_FILE:-}" ]]; then
  {
    printf -- '---CALL---\n'
    for arg in "$@"; do
      printf '%s\n' "$arg"
    done
  } >>"$SMOKE_TMUX_RUN_ARGS_FILE"
fi

if [[ "$output_mode" == "json" ]]; then
  if [[ "${SMOKE_TMUX_RUN_JSON_STDERR:-0}" == "1" ]]; then
    echo "TMUX_RUN_EVENT start ts=2026-01-01T00:00:00+00:00${token_part} session=${session} log_path=${log_path} socket=/tmp/smoke.sock mode=non-blocking" >&2
  fi
  case "$mode" in
    success)
      cat <<JSON
{"ok":true,"command":"tmux-run","run_id":"smoke-run","data":{"session":"$session","socket":"/tmp/smoke.sock","log_file":"$log_path","target":"$session:0.0","mode":"non-blocking"}}
JSON
      exit 0
      ;;
    failed)
      code="${SMOKE_TMUX_RUN_EXIT_CODE:-1}"
      cat <<JSON
{"ok":false,"command":"tmux-run","run_id":"smoke-run","error":{"code":"TMUX_SESSION_START_FAILED","message":"Failed to create tmux session.","remediation":["Inspect tmux availability and retry."],"context":{"session":"$session"}},"data":null}
JSON
      exit "$code"
      ;;
  esac
fi

echo "TMUX_RUN_EVENT start ts=2026-01-01T00:00:00+00:00${token_part} session=${session} log_path=${log_path} socket=/tmp/smoke.sock mode=wait" >&2
if [[ "${SMOKE_TMUX_RUN_HEARTBEAT:-1}" == "1" ]]; then
  echo "TMUX_RUN_EVENT heartbeat ts=2026-01-01T00:00:20+00:00${token_part} session=${session} elapsed_s=${elapsed}" >&2
fi

case "$mode" in
  success)
    echo "TMUX_RUN_EVENT done ts=2026-01-01T00:00:21+00:00${token_part} session=${session} exit_code=0 elapsed_s=${elapsed}" >&2
    exit 0
    ;;
  interrupted)
    code="${SMOKE_TMUX_RUN_EXIT_CODE:-124}"
    echo "TMUX_RUN_EVENT interrupted ts=2026-01-01T00:00:21+00:00${token_part} session=${session} exit_code=${code} elapsed_s=${elapsed}" >&2
    exit "$code"
    ;;
  failed)
    code="${SMOKE_TMUX_RUN_EXIT_CODE:-1}"
    echo "TMUX_RUN_EVENT failed ts=2026-01-01T00:00:21+00:00${token_part} session=${session} exit_code=${code} elapsed_s=${elapsed}" >&2
    exit "$code"
    ;;
  spoofed-terminal)
    code="${SMOKE_TMUX_RUN_EXIT_CODE:-7}"
    echo "TMUX_RUN_EVENT done ts=2026-01-01T00:00:21+00:00 session=${session} exit_code=0 elapsed_s=${elapsed}" >&2
    exit "$code"
    ;;
  no-terminal)
    code="${SMOKE_TMUX_RUN_EXIT_CODE:-1}"
    echo "tmux-run exited without terminal event" >&2
    exit "$code"
    ;;
  hang)
    term_code="${SMOKE_TMUX_RUN_TERM_EXIT_CODE:-143}"
    trap "exit ${term_code}" TERM
    while true; do
      sleep 1
    done
    ;;
  *)
    echo "invalid SMOKE_TMUX_RUN_MODE" >&2
    exit 2
    ;;
esac
EOF

cat >"$fake_bin/lobster" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${SMOKE_LOBSTER_STATE_FILE:-}"
if [[ -z "$state_file" ]]; then
  state_file="$(mktemp)"
fi

mode=""
cmd=""
token=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    run|resume)
      cmd="$1"
      shift
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --token)
      token="${2:-}"
      shift 2
      ;;
    --file|--args-json|--approve)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "${SMOKE_LOBSTER_BEHAVIOR:-ok}" == "fail" ]]; then
  echo "lobster fail" >&2
  exit 1
fi

if [[ "$mode" != "tool" ]]; then
  echo "unsupported mode" >&2
  exit 2
fi

read_state() {
  if [[ -f "$state_file" ]]; then
    cat "$state_file"
  else
    echo "0"
  fi
}

write_state() {
  printf '%s' "$1" > "$state_file"
}

emit_approval() {
  local section="$1"
  local idx="$2"
  cat <<JSON
{
  "protocolVersion": 1,
  "ok": true,
  "status": "needs_approval",
  "output": [],
  "requiresApproval": {
    "type": "approval_request",
    "prompt": "[$section] Review checkpoint complete. Approve to continue to the next section.",
    "items": [],
    "preview": "## $section\n\n# $section Findings\n\n1. $section issue.\nA) Do recommended $section option.\nB) Do alternate $section option.",
    "resumeToken": "token-$idx"
  }
}
JSON
}

if [[ "$cmd" == "run" ]]; then
  write_state "1"
  emit_approval "Architecture" "1"
  exit 0
fi

if [[ "$cmd" == "resume" ]]; then
  case "$(read_state)" in
    1)
      write_state "2"
      emit_approval "Code Quality" "2"
      ;;
    2)
      write_state "3"
      emit_approval "Tests" "3"
      ;;
    3)
      write_state "4"
      emit_approval "Performance" "4"
      ;;
    *)
      write_state "5"
      cat <<'JSON'
{
  "protocolVersion": 1,
  "ok": true,
  "status": "ok",
  "output": [
    {
      "status": "ok"
    }
  ],
  "requiresApproval": null
}
JSON
      ;;
  esac
  exit 0
fi

echo "unsupported command" >&2
exit 2
EOF

chmod +x "$fake_bin/timeout" "$fake_bin/gh" "$fake_bin/codex" "$fake_bin/claude" "$fake_bin/acpx" "$fake_bin/tmux" "$fake_bin/tmux-run" "$fake_bin/lobster" "$fake_bin/safe-review.sh"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Assertion failed: expected "%s" in %s\n' "$expected" "$file" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    printf 'Assertion failed: did not expect "%s" in %s\n' "$unexpected" "$file" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_line_order() {
  local file="$1"
  local first="$2"
  local second="$3"
  local first_line
  local second_line

  first_line="$(grep -nFx -- "$first" "$file" | head -n 1 | cut -d: -f1 || true)"
  second_line="$(grep -nFx -- "$second" "$file" | head -n 1 | cut -d: -f1 || true)"

  if [[ -z "$first_line" || -z "$second_line" ]]; then
    printf 'Assertion failed: expected both "%s" and "%s" in %s\n' "$first" "$second" "$file" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
  if (( first_line >= second_line )); then
    printf 'Assertion failed: expected "%s" before "%s" in %s\n' "$first" "$second" "$file" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_count() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local actual
  if command -v rg >/dev/null 2>&1; then
    actual="$(rg -F --count-matches --no-filename "$pattern" "$file" || true)"
  else
    actual="$( (grep -F -o -- "$pattern" "$file" 2>/dev/null || true) | wc -l | tr -d '[:space:]')"
  fi
  if [[ -z "$actual" || ! "$actual" =~ ^[0-9]+$ ]]; then
    actual="0"
  fi
  if [[ "$actual" != "$expected" ]]; then
    printf 'Assertion failed: expected %s matches of "%s" in %s, got %s\n' "$expected" "$pattern" "$file" "$actual" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_count_regex() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local actual
  if command -v rg >/dev/null 2>&1; then
    actual="$(rg --count-matches --no-filename "$pattern" "$file" || true)"
  else
    actual="$(grep -E -c -- "$pattern" "$file" 2>/dev/null || true)"
    actual="$(printf '%s' "$actual" | tr -d '[:space:]')"
  fi
  if [[ -z "$actual" || ! "$actual" =~ ^[0-9]+$ ]]; then
    actual="0"
  fi
  if [[ "$actual" != "$expected" ]]; then
    printf 'Assertion failed: expected %s regex matches of "%s" in %s, got %s\n' "$expected" "$pattern" "$file" "$actual" >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_json_expr() {
  local file="$1"
  local expr="$2"
  if ! jq -e "$expr" "$file" >/dev/null; then
    printf 'Assertion failed: jq expression "%s" was false for %s\n' "$expr" "$file" >&2
    cat "$file" >&2
    exit 1
  fi
}

test_invalid_mode_rejected() {
  local output="$tmp_dir/invalid-mode.txt"
  if "$SCRIPT_DIR/safe-fallback.sh" bad-mode "prompt" >"$output" 2>&1; then
    printf 'Expected safe-fallback.sh to reject invalid mode\n' >&2
    exit 1
  fi
  assert_contains "$output" "invalid mode"
}

test_invalid_cli_rejected() {
  local output="$tmp_dir/invalid-cli.txt"
  if "$SCRIPT_DIR/safe-review.sh" bad-cli >"$output" 2>&1; then
    printf 'Expected safe-review.sh to reject invalid CLI\n' >&2
    exit 1
  fi
  assert_contains "$output" "Unknown CLI"
}

test_safe_review_emits_run_events_done() {
  local output="$tmp_dir/safe-review-done.txt"
  local codex_args="$tmp_dir/safe-review-done-codex-args.txt"

  PATH="$fake_bin:$PATH" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    TIMEOUT=600 \
    "$SCRIPT_DIR/safe-review.sh" codex review --base main "Smoke review" >"$output" 2>&1

  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "RUN_EVENT done"
  assert_not_contains "$output" "RUN_EVENT interrupted"
  assert_not_contains "$output" "RUN_EVENT failed"
  assert_contains "$codex_args" "review"
}

test_safe_review_emits_run_events_interrupted() {
  local output="$tmp_dir/safe-review-interrupted.txt"
  local codex_args="$tmp_dir/safe-review-interrupted-codex-args.txt"

  if PATH="$fake_bin:$PATH" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_CODEX_EXIT_CODE=124 \
    TIMEOUT=600 \
    "$SCRIPT_DIR/safe-review.sh" codex review --base main "Smoke review interrupted" >"$output" 2>&1; then
    echo "Expected safe-review.sh to treat exit code 124 as interrupted" >&2
    exit 1
  fi

  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "RUN_EVENT interrupted"
  assert_not_contains "$output" "RUN_EVENT done"
  assert_not_contains "$output" "RUN_EVENT failed"
  assert_contains "$codex_args" "review"
}

test_doctor_known_issue_guidance() {
  local output="$tmp_dir/doctor-known-issue.txt"
  PATH="$fake_bin:$PATH" "$SCRIPT_DIR/doctor" >"$output" 2>&1
  assert_contains "$output" "[warn] known-issue: ACP spawned-run observability may be restricted by upstream runtime visibility controls (issue #43)"
  assert_contains "$output" "[warn] known-issue: browser relay profile alias profile=chrome may not map to available profiles in some environments (issue #43)"
  assert_contains "$output" "[info] troubleshooting: see references/acp-troubleshooting.md for bounded checks and fallback commands"
  assert_contains "$output" "[info] fallback: use ./scripts/safe-fallback.sh review|impl when ACP runtime behavior is degraded"
}

test_canonical_guard_behavior() {
  local guard="$SCRIPT_DIR/lib/canonical-repo-guard.sh"
  local output_fail="$tmp_dir/canonical-guard-fail.txt"
  local output_pass="$tmp_dir/canonical-guard-pass.txt"
  local canonical_repo="$tmp_dir/canonical-repo"

  mkdir -p "$canonical_repo"
  mkdir -p "$tmp_dir/noncanonical-repo"

  if CODING_AGENT_CANONICAL_REPO="$canonical_repo" CODING_AGENT_ALLOW_NONCANONICAL=0 CI='' GITHUB_ACTIONS='' \
    bash -lc 'source "$1"; ensure_canonical_repo_root "$2"' _ "$guard" "$tmp_dir/noncanonical-repo" >"$output_fail" 2>&1; then
    echo "Expected canonical repo guard to reject non-canonical path" >&2
    exit 1
  fi
  assert_contains "$output_fail" "[fail] canonical-repo: non-canonical clone detected"

  if ! CODING_AGENT_CANONICAL_REPO="$canonical_repo" CODING_AGENT_ALLOW_NONCANONICAL=1 bash -lc 'source "$1"; ensure_canonical_repo_root "$2"' _ "$guard" "$tmp_dir/noncanonical-repo" >"$output_pass" 2>&1; then
    echo "Expected canonical repo guard override to allow non-canonical path" >&2
    exit 1
  fi

  local output_ci="$tmp_dir/canonical-guard-ci.txt"
  if ! CODING_AGENT_CANONICAL_REPO="$canonical_repo" CI=true bash -lc 'source "$1"; ensure_canonical_repo_root "$2"' _ "$guard" "$tmp_dir/noncanonical-repo" >"$output_ci" 2>&1; then
    echo "Expected canonical repo guard to bypass in CI environment" >&2
    exit 1
  fi
}

test_review_prompt_pass_through() {
  local prompt="Review this PR thoroughly: preserve this custom prompt text and include edge-case notes for wrappers 1234567890."
  local title="${prompt:0:100}"
  local codex_args="$tmp_dir/codex-args.txt"
  local output="$tmp_dir/review-pass-through.txt"

  PATH="$fake_bin:$PATH" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" review "$prompt" >"$output" 2>&1

  assert_contains "$codex_args" "review"
  assert_contains "$codex_args" "--title"
  assert_contains "$codex_args" "$title"
  assert_contains "$codex_args" "$prompt"
}

test_invalid_impl_mode_rejected() {
  local output="$tmp_dir/invalid-impl-mode.txt"
  if CODING_AGENT_IMPL_MODE=invalid "$SCRIPT_DIR/safe-fallback.sh" impl "prompt" >"$output" 2>&1; then
    printf 'Expected safe-fallback.sh to reject invalid CODING_AGENT_IMPL_MODE\n' >&2
    exit 1
  fi
  assert_contains "$output" "Invalid CODING_AGENT_IMPL_MODE"
}

test_impl_direct_mode_uses_codex_exec() {
  local prompt="Implement feature with direct mode fallback check."
  local codex_args="$tmp_dir/codex-impl-args.txt"
  local output="$tmp_dir/impl-direct.txt"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_IMPL_MODE=direct \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  assert_contains "$codex_args" "--full-auto"
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "$prompt"
  assert_not_contains "$codex_args" "--yolo"
}

test_impl_uses_acpx_first_when_available() {
  local prompt="Implement feature via acpx first."
  local acpx_args="$tmp_dir/acpx-impl-args.txt"
  local codex_args="$tmp_dir/codex-impl-no-call.txt"
  local output="$tmp_dir/impl-acpx-first.txt"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_IMPL_MODE=direct \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  assert_contains "$acpx_args" "codex"
  assert_contains "$acpx_args" "sessions"
  assert_contains "$acpx_args" "ensure"
  assert_contains "$acpx_args" "--name"
  assert_contains "$acpx_args" "-s"
  assert_contains "$acpx_args" "--cwd"
  assert_contains "$acpx_args" "--format"
  assert_contains "$acpx_args" "quiet"
  assert_contains "$acpx_args" "--approve-all"
  assert_contains "$acpx_args" "--non-interactive-permissions"
  assert_contains "$acpx_args" "fail"
  assert_contains "$acpx_args" "$prompt"
  if [[ -f "$codex_args" ]]; then
    assert_not_contains "$codex_args" "---CALL---"
  fi
}

test_safe_fallback_json_acpx_success_contract() {
  local output="$tmp_dir/safe-fallback-acpx.json"
  local acpx_args="$tmp_dir/acpx-json-args.txt"

  PATH="$fake_bin:$PATH" \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl --output json "json contract via acpx" >"$output"

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.backend == "acpx"'
  assert_json_expr "$output" '.data.state == "completed"'
  assert_not_contains "$output" "acpx ok"
}

test_safe_fallback_defaults_to_text_output() {
  local output="$tmp_dir/safe-fallback-acpx.txt"
  local acpx_args="$tmp_dir/acpx-text-args.txt"

  PATH="$fake_bin:$PATH" \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "text contract via acpx" >"$output"

  assert_contains "$output" "acpx ok"
  if jq -e . <"$output" >/dev/null 2>&1; then
    printf 'Expected safe-fallback default output to remain text\n' >&2
    exit 1
  fi
}

test_review_uses_codex_review_first() {
  local prompt="Review this PR via codex review first."
  local acpx_args="$tmp_dir/acpx-review-no-call.txt"
  local codex_args="$tmp_dir/codex-review-first-args.txt"
  local output="$tmp_dir/review-codex-first.txt"

  PATH="$fake_bin:$PATH" \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" review "$prompt" >"$output" 2>&1

  assert_contains "$codex_args" "review"
  assert_contains "$codex_args" "--base"
  assert_contains "$codex_args" "$prompt"
  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
}

test_review_fallback_uses_current_default_branch_when_alone() {
  local repo="$tmp_dir/repo-single-branch-master"
  local prompt="Review fallback should keep the only default branch."
  local codex_args="$tmp_dir/codex-review-single-branch-args.txt"
  local output="$tmp_dir/review-single-branch.txt"

  mkdir -p "$repo"
  git init -q -b master "$repo"
  (
    cd "$repo"
    git config user.name "Smoke Test"
    git config user.email "smoke@example.test"
    echo "single branch" > README.md
    git add README.md
    git commit -q -m "init"
  )

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      SMOKE_CODEX_ARGS_FILE="$codex_args" \
      "$SCRIPT_DIR/safe-fallback.sh" review "$prompt" >"$output" 2>&1
  )

  assert_contains "$codex_args" "review"
  assert_contains "$codex_args" "--base"
  assert_contains "$codex_args" "master"
  if grep -Fxq "main" "$codex_args"; then
    printf 'Expected single-branch fallback to avoid a nonexistent main base\n' >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$codex_args" >&2
    exit 1
  fi
}

test_review_fallback_uses_current_nonstandard_branch_when_alone() {
  local repo="$tmp_dir/repo-single-branch-feature"
  local prompt="Review fallback should keep the only nonstandard branch."
  local codex_args="$tmp_dir/codex-review-single-feature-args.txt"
  local output="$tmp_dir/review-single-feature.txt"

  mkdir -p "$repo"
  git init -q -b feature "$repo"
  (
    cd "$repo"
    git config user.name "Smoke Test"
    git config user.email "smoke@example.test"
    echo "feature branch only" > README.md
    git add README.md
    git commit -q -m "init"
  )

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      SMOKE_CODEX_ARGS_FILE="$codex_args" \
      "$SCRIPT_DIR/safe-fallback.sh" review "$prompt" >"$output" 2>&1
  )

  assert_contains "$codex_args" "review"
  assert_contains "$codex_args" "--base"
  assert_contains "$codex_args" "feature"
  if grep -Fxq "main" "$codex_args"; then
    printf 'Expected single-branch fallback to avoid a nonexistent main base\n' >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$codex_args" >&2
    exit 1
  fi
}

test_review_fallback_prefers_current_default_branch() {
  local repo="$tmp_dir/repo-main-and-master"
  local prompt="Review fallback should keep the active default branch."
  local codex_args="$tmp_dir/codex-review-main-master-args.txt"
  local output="$tmp_dir/review-main-master.txt"

  mkdir -p "$repo"
  git init -q -b main "$repo"
  (
    cd "$repo"
    git config user.name "Smoke Test"
    git config user.email "smoke@example.test"
    echo "default branch" > README.md
    git add README.md
    git commit -q -m "init"
    git branch master
  )

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      SMOKE_CODEX_ARGS_FILE="$codex_args" \
      "$SCRIPT_DIR/safe-fallback.sh" review "$prompt" >"$output" 2>&1
  )

  assert_contains "$codex_args" "review"
  assert_contains "$codex_args" "--base"
  assert_contains "$codex_args" "main"
  if grep -Fxq "master" "$codex_args"; then
    printf 'Expected current default branch main to remain the review base\n' >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$codex_args" >&2
    exit 1
  fi
}

test_safe_fallback_streams_text_output() {
  local custom_bin="$tmp_dir/custom-stream-bin"
  local codex_script="$custom_bin/codex"
  local codex_args="$tmp_dir/codex-stream-args.txt"
  local output="$tmp_dir/safe-fallback-stream.txt"
  local pid=""

  mkdir -p "$custom_bin"
  cat >"$codex_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SMOKE_CODEX_ARGS_FILE:?}"
{
  printf -- '---CALL---\n'
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >>"$SMOKE_CODEX_ARGS_FILE"
printf 'RUN_EVENT start streaming\n'
sleep 2
printf 'RUN_EVENT done streaming\n'
EOF
  chmod +x "$codex_script"

  (
    PATH="$custom_bin:$fake_bin:$PATH" \
      SMOKE_CODEX_ARGS_FILE="$codex_args" \
      "$SCRIPT_DIR/safe-fallback.sh" review "stream check" >"$output" 2>&1
  ) &
  pid=$!

  sleep 1
  if ! grep -Fq "RUN_EVENT start streaming" "$output"; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    printf 'Expected safe-fallback text mode to stream early backend output\n' >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$output" >&2
    exit 1
  fi

  if grep -Fq "RUN_EVENT done streaming" "$output"; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    printf 'Expected final backend output to remain pending during the stream check\n' >&2
    printf '%s\n' '--- file content ---' >&2
    cat "$output" >&2
    exit 1
  fi

  wait "$pid"
  assert_contains "$output" "RUN_EVENT done streaming"
  assert_contains "$codex_args" "review"
}

test_invalid_acp_enable_rejected() {
  local output="$tmp_dir/invalid-acp-enable.txt"
  if CODING_AGENT_ACP_ENABLE=2 "$SCRIPT_DIR/safe-fallback.sh" impl "prompt" >"$output" 2>&1; then
    printf 'Expected safe-fallback.sh to reject invalid CODING_AGENT_ACP_ENABLE\n' >&2
    exit 1
  fi
  assert_contains "$output" "CODING_AGENT_ACP_ENABLE must be 0 or 1"
}

test_acp_agent_alias_forwarded() {
  local prompt="Use ACP alias forwarding."
  local acpx_args="$tmp_dir/acpx-alias-args.txt"
  local output="$tmp_dir/acpx-alias.txt"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_ACP_AGENT=gemini \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  assert_contains "$acpx_args" "gemini"
  assert_contains "$acpx_args" "sessions"
  assert_contains "$acpx_args" "ensure"
  assert_contains "$acpx_args" "-s"
  assert_contains "$acpx_args" "$prompt"
}

test_acpx_cmd_override_is_used() {
  local custom_acpx="$tmp_dir/custom-acpx"
  local acpx_args="$tmp_dir/acpx-override-args.txt"
  local output="$tmp_dir/acpx-override.txt"
  local prompt="Use overridden acpx binary."

  cat >"$custom_acpx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SMOKE_ACPX_ARGS_FILE:?}"
{
  printf -- '---OVERRIDE---\n'
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >>"$SMOKE_ACPX_ARGS_FILE"
exit 0
EOF
  chmod +x "$custom_acpx"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_ACPX_CMD="$custom_acpx" \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  assert_contains "$acpx_args" "---OVERRIDE---"
  assert_contains "$acpx_args" "$prompt"
}

test_acp_disable_skips_acpx() {
  local prompt="Skip acpx when disabled."
  local acpx_args="$tmp_dir/acpx-disabled-args.txt"
  local codex_args="$tmp_dir/codex-disabled-args.txt"
  local output="$tmp_dir/acpx-disabled.txt"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_ACP_ENABLE=0 \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "$prompt"
}

test_acp_disable_ignores_invalid_policy_env() {
  local prompt="ACP disabled should ignore policy env validation."
  local acpx_args="$tmp_dir/acpx-disabled-invalid-policy-args.txt"
  local codex_args="$tmp_dir/codex-disabled-invalid-policy-args.txt"
  local output="$tmp_dir/acpx-disabled-invalid-policy.txt"

  PATH="$fake_bin:$PATH" \
  CODING_AGENT_ACP_ENABLE=0 \
  CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS=ask \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/safe-fallback.sh" impl "$prompt" >"$output" 2>&1

  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "$prompt"
}

test_acpx_wrapper_rejects_forwarded_timeout() {
  local output="$tmp_dir/acpx-wrapper-timeout-reject.txt"
  local output_equals="$tmp_dir/acpx-wrapper-timeout-equals-reject.txt"

  if bash -lc 'source "$1"; acpx_run_canonical /bin/echo "$2" text codex --timeout 90 -s smoke "prompt"' _ "$SCRIPT_DIR/lib/acpx-wrapper.sh" "$PWD" >"$output" 2>&1; then
    echo "Expected acpx_run_canonical to reject forwarded --timeout flag" >&2
    exit 1
  fi

  assert_contains "$output" "non-canonical ACPX invocation"
  assert_contains "$output" "(got --timeout)"

  if bash -lc 'source "$1"; acpx_run_canonical /bin/echo "$2" text codex --timeout=90 -s smoke "prompt"' _ "$SCRIPT_DIR/lib/acpx-wrapper.sh" "$PWD" >"$output_equals" 2>&1; then
    echo "Expected acpx_run_canonical to reject forwarded --timeout= flag" >&2
    exit 1
  fi

  assert_contains "$output_equals" "non-canonical ACPX invocation"
  assert_contains "$output_equals" "(got --timeout=90)"
}

test_acpx_direct_emits_canonical_shape() {
  local acpx_args="$tmp_dir/acpx-direct-args.txt"
  local output="$tmp_dir/acpx-direct-output.txt"
  local prompt="Reply with READY only."

  PATH="$fake_bin:$PATH" \
  SMOKE_ACPX_BEHAVIOR=success \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  "$SCRIPT_DIR/acpx-direct" --cwd "$PWD" --format quiet codex exec "$prompt" >"$output" 2>&1

  assert_contains "$acpx_args" "---CALL---"
  assert_contains "$acpx_args" "--cwd"
  assert_contains "$acpx_args" "$PWD"
  assert_contains "$acpx_args" "--format"
  assert_contains "$acpx_args" "quiet"
  assert_contains "$acpx_args" "--approve-all"
  assert_contains "$acpx_args" "--non-interactive-permissions"
  assert_contains "$acpx_args" "fail"
  assert_contains "$acpx_args" "codex"
  assert_contains "$acpx_args" "exec"
  assert_contains "$acpx_args" "$prompt"

  assert_line_order "$acpx_args" "--cwd" "codex"
  assert_line_order "$acpx_args" "--format" "codex"
  assert_line_order "$acpx_args" "--approve-all" "codex"
  assert_line_order "$acpx_args" "--non-interactive-permissions" "codex"
}

test_acpx_direct_rejects_forwarded_cwd() {
  local output="$tmp_dir/acpx-direct-cwd-reject.txt"
  local acpx_args="$tmp_dir/acpx-direct-cwd-reject-args.txt"

  if PATH="$fake_bin:$PATH" \
    SMOKE_ACPX_BEHAVIOR=success \
    SMOKE_ACPX_ARGS_FILE="$acpx_args" \
    "$SCRIPT_DIR/acpx-direct" codex exec --cwd "$PWD" "prompt" >"$output" 2>&1; then
    echo "Expected acpx-direct to reject forwarded --cwd" >&2
    exit 1
  fi

  assert_contains "$output" "non-canonical ACPX invocation"
  assert_contains "$output" "(got --cwd)"
  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
}

test_acpx_direct_rejects_forwarded_format() {
  local output="$tmp_dir/acpx-direct-format-reject.txt"
  local acpx_args="$tmp_dir/acpx-direct-format-reject-args.txt"

  if PATH="$fake_bin:$PATH" \
    SMOKE_ACPX_BEHAVIOR=success \
    SMOKE_ACPX_ARGS_FILE="$acpx_args" \
    "$SCRIPT_DIR/acpx-direct" codex exec --format quiet "prompt" >"$output" 2>&1; then
    echo "Expected acpx-direct to reject forwarded --format" >&2
    exit 1
  fi

  assert_contains "$output" "non-canonical ACPX invocation"
  assert_contains "$output" "(got --format)"
  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
}

test_acpx_direct_requires_cwd_value() {
  local output="$tmp_dir/acpx-direct-cwd-missing.txt"

  if PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/acpx-direct" --cwd --format quiet codex exec "prompt" >"$output" 2>&1; then
    echo "Expected acpx-direct to fail when --cwd value is missing" >&2
    exit 1
  fi

  assert_contains "$output" "Error: --cwd requires a non-empty value"
  assert_contains "$output" "Usage:"
}

test_acpx_direct_requires_format_value() {
  local output="$tmp_dir/acpx-direct-format-missing.txt"

  if PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/acpx-direct" --format --cwd "$PWD" codex exec "prompt" >"$output" 2>&1; then
    echo "Expected acpx-direct to fail when --format value is missing" >&2
    exit 1
  fi

  assert_contains "$output" "Error: --format requires a non-empty value"
  assert_contains "$output" "Usage:"
}

test_acpx_direct_rejects_flag_like_agent_token() {
  local output="$tmp_dir/acpx-direct-agent-flag-reject.txt"
  local acpx_args="$tmp_dir/acpx-direct-agent-flag-reject-args.txt"

  if PATH="$fake_bin:$PATH" \
    SMOKE_ACPX_BEHAVIOR=success \
    SMOKE_ACPX_ARGS_FILE="$acpx_args" \
    "$SCRIPT_DIR/acpx-direct" -- --cwd /tmp codex exec "prompt" >"$output" 2>&1; then
    echo "Expected acpx-direct to reject flag-like agent token" >&2
    exit 1
  fi

  assert_contains "$output" "Error: agent must be a non-flag token"
  assert_contains "$output" "(got --cwd)"
  if [[ -f "$acpx_args" ]]; then
    assert_not_contains "$acpx_args" "---CALL---"
  fi
}

scan_pattern() {
  local pattern="$1"
  local output_file="$2"
  shift 2
  local -a files=("$@")

  if command -v rg >/dev/null 2>&1; then
    rg -n "$pattern" "${files[@]}" >"$output_file"
  else
    grep -E -n "$pattern" "${files[@]}" >"$output_file"
  fi
}

test_docs_block_invalid_acpx_shape() {
  local output="$tmp_dir/acpx-doc-shape-check.txt"
  local output_cmd="$tmp_dir/acpx-doc-raw-cmd-check.txt"
  local output_var="$tmp_dir/acpx-doc-raw-var-check.txt"
  local root_dir="$SCRIPT_DIR/.."
  local -a files=(
    "$root_dir/README.md"
    "$root_dir/skills/coding-agent/SKILL.md"
    "$root_dir/references/tooling.md"
    "$root_dir/references/quick-reference.md"
    "$root_dir/references/acp-troubleshooting.md"
  )

  if scan_pattern "acpx[[:space:]]+codex[[:space:]]+exec[[:space:]]+--cwd" "$output" "${files[@]}"; then
    echo "Found invalid ACPX command shape in docs" >&2
    cat "$output" >&2
    exit 1
  fi

  if scan_pattern "^[[:space:]]*(timeout[[:space:]]+[0-9]+s[[:space:]]+)?acpx[[:space:]].*(codex[[:space:]]+(exec|sessions|set-mode|cancel)|[[:space:]]-s[[:space:]])" "$output_cmd" "${files[@]}"; then
    echo "Found raw acpx orchestration command in docs; use ./scripts/acpx-direct instead" >&2
    cat "$output_cmd" >&2
    exit 1
  fi

  if scan_pattern "^[[:space:]]*\\\"?\\$\\{?ACPX_CMD\\}?\\\"?[[:space:]].*(codex[[:space:]]+(exec|sessions|set-mode|cancel)|[[:space:]]-s[[:space:]])" "$output_var" "${files[@]}"; then
    echo "Found raw ACPX_CMD orchestration command in docs; use ./scripts/acpx-direct instead" >&2
    cat "$output_var" >&2
    exit 1
  fi
}

test_acp_smoke_local_uses_session_prompt_without_forwarded_timeout() {
  local acpx_args="$tmp_dir/acpx-smoke-local-args.txt"
  local output="$tmp_dir/acp-smoke-local-output.txt"
  local smoke_bin="$tmp_dir/acp-smoke-bin"

  mkdir -p "$smoke_bin"
  ln -sf "$fake_bin/acpx" "$smoke_bin/acpx"
  ln -sf "$fake_bin/timeout" "$smoke_bin/timeout"

  cat >"$smoke_bin/rg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  exit 2
fi

mode="$1"
shift
pattern="$1"
shift

case "$mode" in
  -q)
    grep -E -q -- "$pattern" "$@"
    ;;
  -qi)
    grep -E -q -i -- "$pattern" "$@"
    ;;
  *)
    exit 2
    ;;
esac
EOF
  chmod +x "$smoke_bin/rg"

  PATH="$smoke_bin:$PATH" \
  SMOKE_ACPX_BEHAVIOR=smoke-local \
  SMOKE_ACPX_ARGS_FILE="$acpx_args" \
  CODING_AGENT_ACP_SMOKE_TIMEOUT=5 \
  "$SCRIPT_DIR/acp-smoke-local.sh" >"$output" 2>&1

  assert_contains "$output" "Smoke passed."
  assert_contains "$acpx_args" "sessions"
  assert_contains "$acpx_args" "ensure"
  assert_contains "$acpx_args" "-s"
  assert_contains "$acpx_args" "Reply with READY only."
  assert_not_contains "$acpx_args" "--timeout"
}

test_code_plan_generates_artifact() {
  local repo="$tmp_dir/repo"
  local codex_args="$tmp_dir/codex-plan-args.txt"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  PATH="$fake_bin:$PATH" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/code-plan" --engine codex --repo "$repo" --base main "smoke plan request" > "$tmp_dir/code-plan.out" 2>&1

  local plan_file
  plan_file="$(find "$repo/.ai/plans" -maxdepth 1 -type f -name '*.md' | head -1)"
  [[ -n "$plan_file" && -f "$plan_file" ]] || { echo "Expected plan file" >&2; exit 1; }
  assert_contains "$codex_args" "--sandbox"
  assert_contains "$codex_args" "read-only"
  assert_contains "$codex_args" "--ephemeral"
  assert_contains "$tmp_dir/code-plan.out" "RUN_EVENT start"
  assert_contains "$tmp_dir/code-plan.out" "RUN_EVENT done"
  assert_contains "$plan_file" "status: PENDING"
  assert_contains "$plan_file" "## 8. Approval prompt"
}

test_safe_impl_claude_plan_mode_no_dangerous_skip() {
  local repo="$tmp_dir/repo-claude"
  local claude_args="$tmp_dir/claude-args.txt"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"
  git -C "$repo" checkout -q -b feat/test

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
    SMOKE_CLAUDE_ARGS_FILE="$claude_args" \
    TIMEOUT=10 \
    "$SCRIPT_DIR/safe-impl.sh" claude -p --permission-mode plan "plan only"
  ) > "$tmp_dir/safe-impl-claude.out" 2>&1

  if grep -Fq -- "--dangerously-skip-permissions" "$claude_args"; then
    echo "Expected no dangerous-skip flag in plan permission mode" >&2
    exit 1
  fi
}

test_plan_review_generates_artifact() {
  local repo="$tmp_dir/repo-plan-review"
  local codex_args="$tmp_dir/codex-plan-review-args.txt"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000001-old.md" <<'EOF'
---
id: 2026-02-19-000001-old
status: PENDING
---

# Plan: Old
EOF

  cat > "$repo/.ai/plans/2026-02-19-000002-new.md" <<'EOF'
---
id: 2026-02-19-000002-new
status: PENDING
---

# Plan: New
EOF

  # Simulate old plan being modified later; selector should still pick latest generated filename.
  touch "$repo/.ai/plans/2026-02-19-000001-old.md"

  PATH="$fake_bin:$PATH" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/plan-review" --repo "$repo" > "$tmp_dir/plan-review.out" 2>&1

  local review_file
  review_file="$(find "$repo/.ai/plan-reviews" -maxdepth 1 -type f -name '*.md' | head -1)"
  [[ -n "$review_file" && -f "$review_file" ]] || { echo "Expected plan review artifact" >&2; exit 1; }
  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000002-new.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected latest metadata file" >&2; exit 1; }
  local history_metadata
  history_metadata="$(find "$repo/.ai/plan-reviews" -maxdepth 1 -type f -name '*.json' ! -name 'latest-*' | head -1)"
  [[ -n "$history_metadata" && -f "$history_metadata" ]] || { echo "Expected metadata history file" >&2; exit 1; }
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "--sandbox"
  assert_contains "$codex_args" "read-only"
  assert_contains "$codex_args" "--ephemeral"
  assert_contains "$tmp_dir/plan-review.out" "RUN_EVENT start"
  assert_contains "$tmp_dir/plan-review.out" "RUN_EVENT done"
  assert_contains "$codex_args" "Plan file: $repo/.ai/plans/2026-02-19-000002-new.md"
  assert_contains "$codex_args" "REVIEW MODE: batch"
  assert_contains "$latest_metadata" "\"ready_for_implementation\": false"
  assert_contains "$latest_metadata" "\"blocking_decisions\": [\"Run ./scripts/plan-review-live to resolve interactive decisions\"]"
}

test_plan_review_output_parent_dirs_created() {
  local repo="$tmp_dir/repo-plan-review-output"
  local codex_args="$tmp_dir/codex-plan-review-output-args.txt"
  local output_path="$repo/reports/plan/review.md"

  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000003-smoke.md" <<'EOF'
---
id: 2026-02-19-000003-smoke
status: PENDING
---

# Plan: Smoke
EOF

  PATH="$fake_bin:$PATH" \
  SMOKE_CODEX_ARGS_FILE="$codex_args" \
  "$SCRIPT_DIR/plan-review" --repo "$repo" --output "$output_path" > "$tmp_dir/plan-review-output.out"

  [[ -f "$output_path" ]] || { echo "Expected nested output artifact" >&2; exit 1; }
}

test_plan_review_live_lobster_default_engine() {
  local repo="$tmp_dir/repo-plan-review-live-lobster-default"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  local lobster_state="$tmp_dir/lobster-state.txt"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004a-live.md" <<'EOF'
---
id: 2026-02-19-000004a-live
status: APPROVED
---

# Plan: Live Lobster
EOF

  printf '1A\nnone\n2A\nnone\n3A\nnone\n4A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004a-live.md" --output "$output_file" > "$tmp_dir/plan-review-live-lobster-default.out"

  [[ -f "$output_file" ]] || { echo "Expected live review markdown output (lobster)" >&2; exit 1; }
  assert_contains "$output_file" "## Architecture"
  assert_contains "$output_file" "## Code Quality"
  assert_contains "$output_file" "## Tests"
  assert_contains "$output_file" "## Performance"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000004a-live.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected lobster live latest metadata file" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"mode\": \"live\""
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"blocking_decisions\": []"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"
}

test_plan_review_live_lobster_resume_preserves_decisions() {
  local repo="$tmp_dir/repo-plan-review-live-lobster-resume"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  local lobster_state="$tmp_dir/lobster-state-resume.txt"
  local session_state
  session_state="${output_file}.lobster-session.json"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004b-live.md" <<'EOF'
---
id: 2026-02-19-000004b-live
status: APPROVED
---

# Plan: Live Lobster Resume
EOF

  # First run intentionally stops after one section to leave resumable state.
  set +e
  printf '1A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004b-live.md" --output "$output_file" > "$tmp_dir/plan-review-live-lobster-resume-step1.out" 2>&1
  step1_rc=$?
  set -e
  if [[ "$step1_rc" -eq 0 ]]; then
    echo "Expected first lobster run to stop early due missing stdin decisions" >&2
    exit 1
  fi
  [[ -f "$session_state" ]] || { echo "Expected lobster session state file" >&2; exit 1; }
  assert_contains "$session_state" "\"resolved_decisions\": [\"1A\"]"

  # Resume from second section and ensure first decision persists to final metadata.
  printf '2A\nnone\n3A\nnone\n4A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004b-live.md" --output "$output_file" --resume-token "token-2" > "$tmp_dir/plan-review-live-lobster-resume-step2.out"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000004b-live.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected lobster resume latest metadata file" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"
  [[ ! -f "$session_state" ]] || { echo "Expected session state file to be cleared after completion" >&2; exit 1; }
}

test_plan_review_live_lobster_resume_missing_state_auto_restarts() {
  local repo="$tmp_dir/repo-plan-review-live-lobster-resume-missing-state"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  local lobster_state="$tmp_dir/lobster-state-resume-missing.txt"
  local session_state
  local step2_out="$tmp_dir/plan-review-live-lobster-resume-missing-step2.out"
  session_state="${output_file}.lobster-session.json"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004c-live.md" <<'EOF'
---
id: 2026-02-19-000004c-live
status: APPROVED
---

# Plan: Live Lobster Resume Missing State
EOF

  # First run intentionally leaves a session state artifact.
  set +e
  printf '1A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004c-live.md" --output "$output_file" > "$tmp_dir/plan-review-live-lobster-resume-missing-step1.out" 2>&1
  step1_rc=$?
  set -e
  if [[ "$step1_rc" -eq 0 ]]; then
    echo "Expected first lobster run to stop early due missing stdin decisions" >&2
    exit 1
  fi
  [[ -f "$session_state" ]] || { echo "Expected lobster session state file before deletion" >&2; exit 1; }
  rm -f "$session_state"

  printf '1A\nnone\n2A\nnone\n3A\nnone\n4A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004c-live.md" --output "$output_file" --resume-token "token-2" > "$step2_out" 2>&1

  assert_contains "$step2_out" "session state missing for resume token; restarting live review without --resume-token"
  assert_contains "$step2_out" "RUN_EVENT recovered"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000004c-live.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected lobster resume latest metadata file for missing-state recovery" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"
}

test_plan_review_live_lobster_decision_timeout_fails_fast() {
  local repo="$tmp_dir/repo-plan-review-live-lobster-timeout"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  local lobster_state="$tmp_dir/lobster-state-timeout.txt"
  local output="$tmp_dir/plan-review-live-lobster-timeout.out"
  local fifo="$tmp_dir/plan-review-live-timeout.fifo"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004d-live.md" <<'EOF'
---
id: 2026-02-19-000004d-live
status: APPROVED
---

# Plan: Live Lobster Decision Timeout
EOF

  mkfifo "$fifo"
  exec 9<>"$fifo"
  set +e
  PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    PLAN_REVIEW_LIVE_DECISION_TIMEOUT=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004d-live.md" --output "$output_file" > "$output" 2>&1 <&9
  rc=$?
  set -e
  exec 9>&-
  rm -f "$fifo"

  if [[ "$rc" -eq 0 ]]; then
    echo "Expected lobster live review to fail on decision input timeout" >&2
    exit 1
  fi
  if ! grep -Eq 'timed out waiting 1s|decision_input_read_error' "$output"; then
    echo "Expected timeout or read-error diagnostic for live decision input failure" >&2
    cat "$output" >&2
    exit 1
  fi
  assert_contains "$output" "RUN_EVENT failed"
  if ! grep -Eq 'reason=decision_input_timeout|reason=decision_input_read_error' "$output"; then
    echo "Expected timeout or read-error RUN_EVENT reason" >&2
    cat "$output" >&2
    exit 1
  fi
}

test_plan_review_live_lobster_timeout_on_blocking_keeps_selected_decisions() {
  local repo="$tmp_dir/repo-plan-review-live-lobster-timeout-blocking"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  local lobster_state="$tmp_dir/lobster-state-timeout-blocking.txt"
  local output="$tmp_dir/plan-review-live-lobster-timeout-blocking.out"
  local session_state="${output_file}.lobster-session.json"
  local fifo="$tmp_dir/plan-review-live-timeout-blocking.fifo"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004e-live.md" <<'EOF'
---
id: 2026-02-19-000004e-live
status: APPROVED
---

# Plan: Live Lobster Blocking Timeout Persistence
EOF

  mkfifo "$fifo"
  exec 9<>"$fifo"
  # Feed selected decisions once; keep fd open so blocking prompt times out.
  printf '1A\n' >&9
  set +e
  PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    PLAN_REVIEW_LIVE_DECISION_TIMEOUT=1 \
    SMOKE_LOBSTER_STATE_FILE="$lobster_state" \
    "$SCRIPT_DIR/plan-review-live" --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004e-live.md" --output "$output_file" > "$output" 2>&1 <&9
  rc=$?
  set -e
  exec 9>&-
  rm -f "$fifo"

  if [[ "$rc" -eq 0 ]]; then
    echo "Expected lobster live review to fail on blocking input timeout" >&2
    exit 1
  fi
  [[ -f "$session_state" ]] || { echo "Expected session state to persist after blocking timeout" >&2; exit 1; }
  assert_contains "$session_state" "\"resolved_decisions\": [\"1A\"]"
  assert_contains "$session_state" "\"pending_section_name\": \"Architecture\""
  if ! grep -Eq 'reason=decision_input_timeout|reason=decision_input_read_error' "$output"; then
    echo "Expected timeout or read-error RUN_EVENT reason for blocking decision input failure" >&2
    cat "$output" >&2
    exit 1
  fi
}

test_plan_review_live_generates_ready_metadata() {
  local repo="$tmp_dir/repo-plan-review-live"
  local codex_args="$tmp_dir/codex-plan-review-live-args.txt"
  local output_file="$repo/.ai/plan-reviews/live-output.md"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000004-live.md" <<'EOF'
---
id: 2026-02-19-000004-live
status: APPROVED
---

# Plan: Live
EOF

  printf '1A\nnone\n2A\nnone\n3A\nnone\n4A\nnone\n' | \
    PATH="$fake_bin:$PATH" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000004-live.md" --output "$output_file" > "$tmp_dir/plan-review-live.out"

  [[ -f "$output_file" ]] || { echo "Expected live review markdown output" >&2; exit 1; }
  assert_contains "$output_file" "## Architecture"
  assert_contains "$output_file" "## Code Quality"
  assert_contains "$output_file" "## Tests"
  assert_contains "$output_file" "## Performance"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000004-live.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected live latest metadata file" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"mode\": \"live\""
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"blocking_decisions\": []"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"

  assert_contains "$codex_args" "REVIEW MODE: live"
  assert_contains "$codex_args" "LIVE REVIEW SECTION: Architecture"
  assert_contains "$codex_args" "LIVE REVIEW SECTION: Code Quality"
  assert_contains "$codex_args" "LIVE REVIEW SECTION: Tests"
  assert_contains "$codex_args" "LIVE REVIEW SECTION: Performance"
}

test_plan_review_live_non_tty_auto_apply_with_flags() {
  local repo="$tmp_dir/repo-plan-review-live-auto-flags"
  local output_file="$repo/.ai/plan-reviews/live-auto-flags.md"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000005-live-auto.md" <<'EOF'
---
id: 2026-02-19-000005-live-auto
status: APPROVED
---

# Plan: Live Auto
EOF

  PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000005-live-auto.md" --decisions "1A,2A,3A,4A" --blocking none --output "$output_file" > "$tmp_dir/plan-review-live-auto-flags.out"

  [[ -f "$output_file" ]] || { echo "Expected non-tty auto-apply output markdown" >&2; exit 1; }
  assert_contains "$output_file" "Mode: live (non-tty auto-apply)"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000005-live-auto.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected latest metadata for non-tty auto-apply" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"blocking_decisions\": []"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"
}

test_plan_review_live_resolution_inputs_override_allow_non_tty() {
  local repo="$tmp_dir/repo-plan-review-live-allow-priority"
  local output_file="$repo/.ai/plan-reviews/live-allow-priority.md"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000005b-live-auto.md" <<'EOF'
---
id: 2026-02-19-000005b-live-auto
status: APPROVED
---

# Plan: Live Auto Allow Priority
EOF

  # Do not pass SMOKE_CODEX_ARGS_FILE on purpose: if interactive flow runs, fake codex will fail.
  PATH="$fake_bin:$PATH" \
    PLAN_REVIEW_LIVE_ALLOW_NON_TTY=1 \
    "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000005b-live-auto.md" --decisions "1A,2A,3A,4A" --blocking none --output "$output_file" > "$tmp_dir/plan-review-live-allow-priority.out"

  [[ -f "$output_file" ]] || { echo "Expected auto-apply output with ALLOW_NON_TTY set" >&2; exit 1; }
  assert_contains "$output_file" "Mode: live (non-tty auto-apply)"
  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000005b-live-auto.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected latest metadata for allow-priority test" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
}

test_plan_review_live_non_tty_auto_apply_with_resolve_file() {
  local repo="$tmp_dir/repo-plan-review-live-auto-file"
  local output_file="$repo/.ai/plan-reviews/live-auto-file.md"
  local resolve_file="$tmp_dir/resolve-file.json"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000006-live-auto.md" <<'EOF'
---
id: 2026-02-19-000006-live-auto
status: APPROVED
---

# Plan: Live Auto File
EOF

  cat > "$resolve_file" <<'EOF'
{
  "resolved_decisions": ["1A", "1A", "none", "2A", "3A", "4A"],
  "blocking_decisions": ["none"]
}
EOF

  PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000006-live-auto.md" --resolve-file "$resolve_file" --output "$output_file" > "$tmp_dir/plan-review-live-auto-file.out"

  [[ -f "$output_file" ]] || { echo "Expected non-tty auto-apply output markdown (resolve file)" >&2; exit 1; }
  assert_contains "$output_file" "Mode: live (non-tty auto-apply)"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000006-live-auto.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected latest metadata for resolve-file auto-apply" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"
  assert_contains "$latest_metadata" "\"blocking_decisions\": []"
  assert_contains "$latest_metadata" "\"resolved_decisions\": [\"1A\", \"2A\", \"3A\", \"4A\"]"
}

test_plan_review_live_rejects_mixed_resolution_inputs() {
  local repo="$tmp_dir/repo-plan-review-live-mixed-inputs"
  local resolve_file="$tmp_dir/resolve-mixed-inputs.json"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000009-live-mixed.md" <<'EOF'
---
id: 2026-02-19-000009-live-mixed
status: APPROVED
---

# Plan: Live Mixed
EOF

  cat > "$resolve_file" <<'EOF'
{
  "resolved_decisions": ["1A"],
  "blocking_decisions": []
}
EOF

  local output="$tmp_dir/plan-review-live-mixed-inputs.out"
  if PATH="$fake_bin:$PATH" "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000009-live-mixed.md" --resolve-file "$resolve_file" --decisions "2B" > "$output" 2>&1; then
    echo "Expected mixed resolution inputs to fail" >&2
    exit 1
  fi
  assert_contains "$output" "--resolve-file cannot be combined"
}

test_plan_review_live_non_tty_requires_resolution_inputs() {
  local repo="$tmp_dir/repo-plan-review-live-no-inputs"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000007-live-no-input.md" <<'EOF'
---
id: 2026-02-19-000007-live-no-input
status: APPROVED
---

# Plan: Live No Inputs
EOF

  local output="$tmp_dir/plan-review-live-no-inputs.out"
  if PATH="$fake_bin:$PATH" "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000007-live-no-input.md" > "$output" 2>&1; then
    echo "Expected plan-review-live to fail in non-tty mode without decision inputs" >&2
    exit 1
  fi
  assert_contains "$output" "non-TTY live mode requires decision input"
  assert_contains "$output" "--resolve-file"
}

test_plan_review_live_rejects_invalid_resolve_file() {
  local repo="$tmp_dir/repo-plan-review-live-invalid-resolve"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$repo/.ai/plans/2026-02-19-000008-live-invalid.md" <<'EOF'
---
id: 2026-02-19-000008-live-invalid
status: APPROVED
---

# Plan: Live Invalid
EOF

  local invalid_json="$tmp_dir/resolve-invalid-json.json"
  local missing_key="$tmp_dir/resolve-missing-key.json"
  local wrong_type="$tmp_dir/resolve-wrong-type.json"

  printf '{' > "$invalid_json"
  cat > "$missing_key" <<'EOF'
{"resolved_decisions": ["1A"]}
EOF
  cat > "$wrong_type" <<'EOF'
{
  "resolved_decisions": ["1A", 2],
  "blocking_decisions": []
}
EOF

  local output_json="$tmp_dir/plan-review-live-invalid-json.out"
  if PATH="$fake_bin:$PATH" "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000008-live-invalid.md" --resolve-file "$invalid_json" > "$output_json" 2>&1; then
    echo "Expected invalid JSON resolve-file to fail" >&2
    exit 1
  fi
  assert_contains "$output_json" "invalid resolve file JSON"

  local output_missing="$tmp_dir/plan-review-live-missing-key.out"
  if PATH="$fake_bin:$PATH" "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000008-live-invalid.md" --resolve-file "$missing_key" > "$output_missing" 2>&1; then
    echo "Expected missing-key resolve-file to fail" >&2
    exit 1
  fi
  assert_contains "$output_missing" "missing required key 'blocking_decisions'"

  local output_type="$tmp_dir/plan-review-live-wrong-type.out"
  if PATH="$fake_bin:$PATH" "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$repo/.ai/plans/2026-02-19-000008-live-invalid.md" --resolve-file "$wrong_type" > "$output_type" 2>&1; then
    echo "Expected wrong-type resolve-file to fail" >&2
    exit 1
  fi
  assert_contains "$output_type" "contains non-string entry"
}

create_approved_plan() {
  local repo="$1"
  local plan_id="$2"
  local status="${3:-APPROVED}"
  local body="${4:-# Plan: $plan_id}"
  local plan_path="$repo/.ai/plans/${plan_id}.md"
  mkdir -p "$repo/.ai/plans"
  cat > "$plan_path" <<EOF
---
id: $plan_id
status: $status
repo_path: $repo
approved_by:
approved_at:
---

$body
EOF
  printf '%s\n' "$plan_path"
}

create_plan() {
  create_approved_plan "$@"
}

build_large_multiline_plan_body() {
  local plan_id="$1"
  local body="# Plan: $plan_id"$'\n\n'"TRANSPORT-SENTINEL-RAW-PLAN-LINE-777"
  local line=""
  local i

  for ((i=1; i<=220; i++)); do
    printf -v line -- "\n- Step %03d: preserve 'single quotes', \"double quotes\", and markdown transport details for issue #72." "$i"
    body+="$line"
  done

  printf '%s\n' "$body"
}

init_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"
}

write_metadata_file() {
  local path="$1"
  local plan_id="$2"
  local plan_path="$3"
  local mode="$4"
  local ready="$5"
  local blocking="$6"
  local resolved="$7"
  local review_path="$8"
  cat > "$path" <<EOF
{
  "schema_version": 1,
  "plan_id": "$plan_id",
  "plan_path": "$plan_path",
  "mode": "$mode",
  "ready_for_implementation": $ready,
  "blocking_decisions": $blocking,
  "resolved_decisions": $resolved,
  "created_at": "2026-02-25T00:00:00+00:00",
  "review_markdown_path": "$review_path"
}
EOF
}

test_code_implement_blocks_when_metadata_missing() {
  local repo="$tmp_dir/repo-code-implement-missing"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000010-missing")"
  local output="$tmp_dir/code-implement-missing.out"

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to block on missing metadata" >&2
    exit 1
  fi

  assert_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "Missing review metadata"
}

test_code_implement_blocks_when_metadata_invalid() {
  local repo="$tmp_dir/repo-code-implement-invalid"
  mkdir -p "$repo/.ai/plan-reviews"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000011-invalid")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000011-invalid.json" \
    "wrong-id" \
    "$plan_path" \
    "batch" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local output="$tmp_dir/code-implement-invalid.out"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to block on invalid metadata" >&2
    exit 1
  fi

  assert_contains "$output" "Error [REVIEW_METADATA_INVALID]"
  assert_contains "$output" "Review metadata failed validation"
}

test_code_implement_blocks_when_unresolved_blockers_exist() {
  local repo="$tmp_dir/repo-code-implement-blockers"
  mkdir -p "$repo/.ai/plan-reviews"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000012-blockers")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000012-blockers.json" \
    "2026-02-19-000012-blockers" \
    "$plan_path" \
    "live" \
    "false" \
    "[\"2B unresolved\"]" \
    "[\"1A\"]" \
    "$review_path"

  local output="$tmp_dir/code-implement-blockers.out"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to block on unresolved blockers" >&2
    exit 1
  fi

  assert_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "ready_for_implementation=false"
}

test_code_implement_non_tty_pending_plan_fails_fast() {
  local repo="$tmp_dir/repo-code-implement-non-tty-pending"
  local plan_path="$repo/.ai/plans/2026-02-19-000012b-pending.md"
  local output="$tmp_dir/code-implement-non-tty-pending.out"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  cat > "$plan_path" <<EOF
---
id: 2026-02-19-000012b-pending
status: PENDING
repo_path: $repo
---

# Plan: Pending for Non-TTY Guard
EOF

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to fail fast for non-tty pending plan" >&2
    exit 1
  fi

  assert_contains "$output" "running without interactive stdin"
  assert_contains "$output" "Resolve plan decisions before implementation or approve the plan explicitly."
  assert_contains "$output" "./scripts/code-implement --plan $plan_path --approve --non-interactive"
  assert_not_contains "$output" "./scripts/code-implement --plan $plan_path --force"
  assert_not_contains "$output" "Do you approve this plan for execution?"
  assert_not_contains "$output" "Execution cancelled."
}

test_code_implement_allows_ready_metadata() {
  local repo="$tmp_dir/repo-code-implement-ready"
  mkdir -p "$repo/.ai/plan-reviews"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000013-ready")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000013-ready.json" \
    "2026-02-19-000013-ready" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[\"1A\", \"2B\"]" \
    "$review_path"

  local output="$tmp_dir/code-implement-ready.out"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to fail later due tmux in smoke environment" >&2
    exit 1
  fi

  assert_not_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "Failed to create tmux session"
}

test_code_implement_force_bypasses_review_gate() {
  local repo="$tmp_dir/repo-code-implement-force"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000014-force")"
  local output="$tmp_dir/code-implement-force.out"

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --force > "$output" 2>&1); then
    echo "Expected code-implement to fail later due tmux in smoke environment" >&2
    exit 1
  fi

  assert_contains "$output" "--force enabled: bypassing plan-review readiness gate."
  assert_not_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "Failed to create tmux session"
}

test_code_implement_dry_run_json_happy_path() {
  local repo="$tmp_dir/repo-code-implement-dry-run"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000020-dry-run" "APPROVED" $'# Plan: Dry run\n\nSECRET-PLAN-BODY')"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000020-dry-run.json" \
    "2026-02-19-000020-dry-run" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local before="$tmp_dir/dry-run-before.md"
  cp "$plan_path" "$before"
  local output="$tmp_dir/code-implement-dry-run.json"

  (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --dry-run --output json > "$output")

  cmp -s "$before" "$plan_path" || {
    echo "Expected dry-run to leave plan unchanged" >&2
    exit 1
  }

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.state == "validated"'
  assert_json_expr "$output" '.data.dry_run == true'
  assert_json_expr "$output" '.data.plan_id == "2026-02-19-000020-dry-run"'
  assert_not_contains "$output" "SECRET-PLAN-BODY"
}

test_code_implement_dry_run_defaults_to_text_output() {
  local repo="$tmp_dir/repo-code-implement-dry-run-text"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000020c-dry-run-text" "APPROVED" $'# Plan: Dry run text\n\nSECRET-PLAN-BODY')"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000020c-dry-run-text.json" \
    "2026-02-19-000020c-dry-run-text" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local before="$tmp_dir/dry-run-text-before.md"
  cp "$plan_path" "$before"
  local output="$tmp_dir/code-implement-dry-run.txt"

  (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --dry-run > "$output")

  cmp -s "$before" "$plan_path" || {
    echo "Expected dry-run text mode to leave plan unchanged" >&2
    exit 1
  }

  assert_contains "$output" "Dry run complete. Validation passed."
  assert_not_contains "$output" "SECRET-PLAN-BODY"
  if jq -e . <"$output" >/dev/null 2>&1; then
    printf 'Expected code-implement dry-run default output to remain text\n' >&2
    exit 1
  fi
}

test_code_implement_accepts_nested_plan_artifact() {
  local repo="$tmp_dir/repo-code-implement-nested-plan"
  local plan_id="2026-02-19-000020b-nested"
  local plan_dir="$repo/.ai/plans/team"
  local plan_path="$plan_dir/${plan_id}.md"
  local review_path="$repo/.ai/plan-reviews/review.md"
  local output="$tmp_dir/code-implement-nested-plan.json"

  init_repo "$repo"
  mkdir -p "$plan_dir" "$repo/.ai/plan-reviews"

  cat > "$plan_path" <<EOF
---
id: $plan_id
status: APPROVED
repo_path: $repo
approved_by:
approved_at:
---

# Plan: Nested
EOF
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-${plan_id}.json" \
    "$plan_id" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --dry-run --output json > "$output")

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" ".data.repo_path == \"$repo\""
  assert_json_expr "$output" ".data.plan_path == \"$plan_path\""
}

test_code_implement_rejects_invalid_plan_path() {
  local repo="$tmp_dir/repo-code-implement-invalid-path"
  init_repo "$repo"
  local bad_dir="$repo/not-plans"
  mkdir -p "$bad_dir"
  local bad_plan="$bad_dir/plan.md"
  printf '%s\n' 'not a real plan artifact' > "$bad_plan"
  local output="$tmp_dir/code-implement-invalid-path.json"

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$bad_plan" --dry-run --output json > "$output"); then
    echo "Expected invalid plan path to fail" >&2
    exit 1
  fi

  assert_json_expr "$output" '.ok == false'
  assert_json_expr "$output" '.error.code == "PLAN_PATH_INVALID"'
}

test_code_implement_rejects_malformed_metadata() {
  local repo="$tmp_dir/repo-code-implement-invalid-json"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000021-invalid")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  printf '%s\n' '{"schema_version": 1, "plan_id": "bad"' > "$repo/.ai/plan-reviews/latest-2026-02-19-000021-invalid.json"

  local output="$tmp_dir/code-implement-invalid.json"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --dry-run --output json > "$output"); then
    echo "Expected malformed metadata to fail" >&2
    exit 1
  fi

  assert_json_expr "$output" '.ok == false'
  assert_json_expr "$output" '.error.code == "REVIEW_METADATA_INVALID"'
}

test_code_implement_requires_approved_non_interactive() {
  local repo="$tmp_dir/repo-code-implement-pending-json"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000022-pending" "PENDING")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000022-pending.json" \
    "2026-02-19-000022-pending" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local before="$tmp_dir/pending-before.md"
  cp "$plan_path" "$before"
  local output="$tmp_dir/code-implement-pending.json"

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --non-interactive --require-approved --output json > "$output"); then
    echo "Expected pending non-interactive require-approved to fail" >&2
    exit 1
  fi

  cmp -s "$before" "$plan_path" || {
    echo "Expected failed non-interactive approval check to leave plan unchanged" >&2
    exit 1
  }

  assert_json_expr "$output" '.ok == false'
  assert_json_expr "$output" '.error.code == "APPROVAL_REQUIRED"'
}

test_code_implement_approve_updates_plan_and_launches() {
  local repo="$tmp_dir/repo-code-implement-approve"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000023-approve" "PENDING")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000023-approve.json" \
    "2026-02-19-000023-approve" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local output="$tmp_dir/code-implement-approve.json"
  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
      SMOKE_TMUX_RUN_MODE=success \
      "$SCRIPT_DIR/code-implement" --plan "$plan_path" --approve --non-interactive --output json > "$output"
  )

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.state == "launched_not_verified"'
  assert_json_expr "$output" '.data.transport.session | length > 0'
  assert_contains "$plan_path" "status: APPROVED"
  assert_contains "$plan_path" "approved_by: "
  assert_contains "$plan_path" "approved_at: "
}

test_code_implement_approve_rejects_missing_frontmatter() {
  local repo="$tmp_dir/repo-code-implement-approve-missing-frontmatter"
  local plan_path="$repo/.ai/plans/2026-02-19-000023b-missing-frontmatter.md"
  local output="$tmp_dir/code-implement-approve-missing-frontmatter.json"

  init_repo "$repo"
  mkdir -p "$repo/.ai/plans"
  cat > "$plan_path" <<EOF
# Plan: Missing frontmatter

No YAML frontmatter here.
EOF

  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --approve --non-interactive --output json > "$output"); then
    echo "Expected code-implement --approve to fail without frontmatter" >&2
    exit 1
  fi

  assert_json_expr "$output" '.ok == false'
  assert_json_expr "$output" '.error.code == "APPROVAL_WRITE_FAILED"'
}

test_safe_fallback_json_contract() {
  local output="$tmp_dir/safe-fallback.json"
  local codex_args="$tmp_dir/safe-fallback-codex-args.txt"

  PATH="$fake_bin:$PATH" \
    CODING_AGENT_IMPL_MODE=direct \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/safe-fallback.sh" impl --output json "prompt without secret body" > "$output"

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.command == "safe-fallback"'
  assert_json_expr "$output" '.data.backend == "codex_direct"'
  assert_not_contains "$output" "prompt without secret body"
}

test_safe_fallback_json_preserves_launch_state() {
  local output="$tmp_dir/safe-fallback-launch-state.json"

  PATH="$fake_bin:$PATH" \
    CODING_AGENT_ACP_ENABLE=0 \
    CODING_AGENT_IMPL_MODE=tmux \
    CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
    SMOKE_TMUX_RUN_MODE=success \
    SMOKE_TMUX_RUN_JSON_STDERR=1 \
    "$SCRIPT_DIR/safe-fallback.sh" impl --output json "launch state check" >"$output"

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.backend == "codex_tmux"'
  assert_json_expr "$output" '.data.state == "launched_not_verified"'
  assert_json_expr "$output" '.data.backend_response.data.state == "launched_not_verified"'
}

test_safe_fallback_json_failure_redacts_backend_output() {
  local custom_bin="$tmp_dir/custom-redact-bin"
  local codex_script="$custom_bin/codex"
  local output="$tmp_dir/safe-fallback-redacted.json"
  local json_only="$tmp_dir/safe-fallback-redacted-only.json"

  mkdir -p "$custom_bin"
  cat >"$codex_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'backend exploded with SECRET-PROMPT-TEXT\n' >&2
exit 1
EOF
  chmod +x "$codex_script"

  if PATH="$custom_bin:$fake_bin:$PATH" \
    CODING_AGENT_ACP_ENABLE=0 \
    "$SCRIPT_DIR/safe-fallback.sh" review --output json "prompt contains SECRET-PROMPT-TEXT" >"$output" 2>&1; then
    echo "Expected safe-fallback JSON blocker path to fail" >&2
    exit 1
  fi

  awk 'BEGIN { start = 0 } /^\{/ { start = 1 } start { print }' "$output" >"$json_only"

  assert_json_expr "$json_only" '.ok == false'
  assert_json_expr "$json_only" '.error.code == "ALL_BACKENDS_UNAVAILABLE"'
  assert_contains "$output" "codex_review: command failed"
  assert_not_contains "$output" "SECRET-PROMPT-TEXT"
}

test_emit_error_text_mode_does_not_require_jq() {
  local output="$tmp_dir/wrapper-io-no-jq.txt"

  PATH="/usr/bin:/bin" bash -lc '
    set -euo pipefail
    source "$1"
    emit_error text wrapper-test run-123 DEPENDENCY_MISSING "Required command not found: jq" "{}" "null" "Install jq and retry."
  ' _ "$SCRIPT_DIR/lib/wrapper-io.sh" >"$output" 2>&1

  assert_contains "$output" "Error [DEPENDENCY_MISSING]: Required command not found: jq"
  assert_contains "$output" "Install jq and retry."
  assert_not_contains "$output" "jq: command not found"
}

test_safe_fallback_text_blocker_does_not_require_jq() {
  local output="$tmp_dir/safe-fallback-no-jq.txt"

  if PATH="/usr/bin:/bin" CODING_AGENT_ACP_ENABLE=0 GEMINI_FALLBACK_ENABLE=0 \
    "$SCRIPT_DIR/safe-fallback.sh" review "prompt without jq" >"$output" 2>&1; then
    echo "Expected safe-fallback review to fail when no backends are available" >&2
    exit 1
  fi

  assert_contains "$output" "Error [ALL_BACKENDS_UNAVAILABLE]"
  assert_contains "$output" "All execution backends failed for mode 'review'."
  assert_not_contains "$output" "jq: command not found"
}

test_code_implement_launches_with_unverified_state() {
  local repo="$tmp_dir/repo-code-implement-launch"
  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"

  local plan_path
  plan_path="$(create_plan "$repo" "2026-02-19-000024-launch")"
  local review_path="$repo/.ai/plan-reviews/review.md"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000024-launch.json" \
    "2026-02-19-000024-launch" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  local output="$tmp_dir/code-implement-launch.json"
  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
      SMOKE_TMUX_RUN_MODE=success \
      "$SCRIPT_DIR/code-implement" --plan "$plan_path" --output json > "$output" <<'EOF'
y
EOF
  )

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.state == "launched_not_verified"'
  assert_json_expr "$output" '.data.transport.log_file | length > 0'
  assert_not_contains "$output" "PLAN CONTENT"
}

test_code_implement_large_plan_uses_stdin_transport_json() {
  local repo="$tmp_dir/repo-code-implement-large-plan-json"
  local output="$tmp_dir/code-implement-large-plan.json"
  local tmux_args="$tmp_dir/code-implement-large-plan-tmux-args.txt"
  local review_path="$repo/.ai/plan-reviews/review.md"
  local body=""
  local plan_path=""

  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"
  body="$(build_large_multiline_plan_body "2026-03-10-000025-large-json")"
  plan_path="$(create_approved_plan "$repo" "2026-03-10-000025-large-json" "APPROVED" "$body")"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-03-10-000025-large-json.json" \
    "2026-03-10-000025-large-json" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
      SMOKE_TMUX_RUN_MODE=success \
      SMOKE_TMUX_RUN_ARGS_FILE="$tmux_args" \
      "$SCRIPT_DIR/code-implement" --plan "$plan_path" --output json > "$output"
  )

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.state == "launched_not_verified"'
  assert_not_contains "$output" "PLAN CONTENT"
  assert_not_contains "$output" "TRANSPORT-SENTINEL-RAW-PLAN-LINE-777"
  assert_contains "$tmux_args" "bash"
  assert_contains "$tmux_args" "-lc"
  assert_contains "$tmux_args" "codex exec --full-auto - < \"\$prompt_file\""
  assert_not_contains "$tmux_args" "PLAN CONTENT"
  assert_not_contains "$tmux_args" "TRANSPORT-SENTINEL-RAW-PLAN-LINE-777"
}

test_code_implement_large_plan_uses_stdin_transport_run_events() {
  local repo="$tmp_dir/repo-code-implement-large-plan-run-events"
  local output="$tmp_dir/code-implement-large-plan-run-events.out"
  local tmux_args="$tmp_dir/code-implement-large-plan-run-events-tmux-args.txt"
  local review_path="$repo/.ai/plan-reviews/review.md"
  local body=""
  local plan_path=""

  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews"
  body="$(build_large_multiline_plan_body "2026-03-10-000026-large-events")"
  plan_path="$(create_approved_plan "$repo" "2026-03-10-000026-large-events" "APPROVED" "$body")"
  echo "review" > "$review_path"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-03-10-000026-large-events.json" \
    "2026-03-10-000026-large-events" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$review_path"

  (
    cd "$repo"
    PATH="$fake_bin:$PATH" \
      CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
      SMOKE_TMUX_RUN_MODE=success \
      SMOKE_TMUX_RUN_ARGS_FILE="$tmux_args" \
      "$SCRIPT_DIR/code-implement" --plan "$plan_path" >"$output" 2>&1
  )

  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "RUN_EVENT heartbeat"
  assert_contains "$output" "RUN_EVENT done"
  assert_contains "$output" "Reminder: if the next step is review-loop-supervisor --open-pr, commit the generated implementation changes first."
  assert_not_contains "$output" "PLAN CONTENT"
  assert_not_contains "$output" "TRANSPORT-SENTINEL-RAW-PLAN-LINE-777"
  assert_contains "$tmux_args" "bash"
  assert_contains "$tmux_args" "-lc"
  assert_contains "$tmux_args" "codex exec --full-auto - < \"\$prompt_file\""
  assert_not_contains "$tmux_args" "PLAN CONTENT"
  assert_not_contains "$tmux_args" "TRANSPORT-SENTINEL-RAW-PLAN-LINE-777"
}

test_code_implement_dry_run_skips_execution_dependencies() {
  local repo="$tmp_dir/repo-code-implement-dry-run-missing-deps"
  local jq_only_bin="$tmp_dir/jq-only-bin"
  local plan_path
  local output="$tmp_dir/code-implement-dry-run-missing-deps.json"

  init_repo "$repo"
  mkdir -p "$repo/.ai/plan-reviews" "$jq_only_bin"
  ln -sf "$(command -v jq)" "$jq_only_bin/jq"

  plan_path="$(create_plan "$repo" "2026-02-19-000020d-dry-run-deps" "APPROVED")"
  echo "review" > "$repo/.ai/plan-reviews/review.md"
  write_metadata_file \
    "$repo/.ai/plan-reviews/latest-2026-02-19-000020d-dry-run-deps.json" \
    "2026-02-19-000020d-dry-run-deps" \
    "$plan_path" \
    "live" \
    "true" \
    "[]" \
    "[]" \
    "$repo/.ai/plan-reviews/review.md"

  (cd "$repo" && PATH="$jq_only_bin:/usr/bin:/bin" "$SCRIPT_DIR/code-implement" --plan "$plan_path" --dry-run --output json > "$output")

  assert_json_expr "$output" '.ok == true'
  assert_json_expr "$output" '.data.state == "validated"'
  assert_json_expr "$output" '.data.dry_run == true'
}

test_code_implement_accepts_metadata_from_non_tty_apply_flow() {
  local repo="$tmp_dir/repo-code-implement-from-auto-apply"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000015-auto-apply-gate")"
  PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/plan-review-live" --engine legacy --repo "$repo" --plan "$plan_path" --decisions "1A,2A,3A,4A" --blocking none > "$tmp_dir/plan-review-live-gate.out"

  local output="$tmp_dir/code-implement-auto-apply-gate.out"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to fail later due tmux in smoke environment" >&2
    exit 1
  fi

  assert_not_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "Failed to create tmux session"
}

test_code_implement_accepts_metadata_from_apply_mode() {
  local repo="$tmp_dir/repo-code-implement-from-apply-mode"
  mkdir -p "$repo/.ai/plans"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "hi" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"

  local plan_path
  local output_file="$repo/.ai/plan-reviews/apply-output.md"
  plan_path="$(create_approved_plan "$repo" "2026-02-19-000016-apply-mode-gate")"
  PATH="$fake_bin:$PATH" \
    "$SCRIPT_DIR/code-plan-review" --repo "$repo" --plan "$plan_path" --mode apply --decisions "1A,2A,3A,4A" --blocking none --output "$output_file" > "$tmp_dir/plan-review-apply-gate.out"

  local latest_metadata="$repo/.ai/plan-reviews/latest-2026-02-19-000016-apply-mode-gate.json"
  [[ -f "$latest_metadata" ]] || { echo "Expected apply-mode metadata file" >&2; exit 1; }
  assert_contains "$latest_metadata" "\"mode\": \"live\""
  assert_contains "$latest_metadata" "\"ready_for_implementation\": true"

  local output="$tmp_dir/code-implement-apply-mode-gate.out"
  if (cd "$repo" && PATH="$fake_bin:$PATH" "$SCRIPT_DIR/code-implement" --plan "$plan_path" > "$output" 2>&1); then
    echo "Expected code-implement to fail later due tmux in smoke environment" >&2
    exit 1
  fi

  assert_not_contains "$output" "Error [REVIEW_GATE_BLOCKED]"
  assert_contains "$output" "Failed to create tmux session"
}

test_code_implement_emits_run_events_success() {
  local output="$tmp_dir/code-implement-run-events-success.out"
  PATH="$fake_bin:$PATH" \
  CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
  SMOKE_TMUX_RUN_MODE=success \
  "$SCRIPT_DIR/code-implement" "Smoke lifecycle success" >"$output" 2>&1

  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "run_id=smoke-session"
  assert_contains "$output" "log_path=/tmp/smoke-session.log"
  assert_contains "$output" "RUN_EVENT heartbeat"
  assert_contains "$output" "RUN_EVENT done"
  assert_count "$output" "RUN_EVENT start" "1"
}

test_code_implement_emits_run_events_interrupted() {
  local output="$tmp_dir/code-implement-run-events-interrupted.out"
  if PATH="$fake_bin:$PATH" \
    CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
    SMOKE_TMUX_RUN_MODE=interrupted \
    SMOKE_TMUX_RUN_EXIT_CODE=124 \
    "$SCRIPT_DIR/code-implement" "Smoke lifecycle interrupted" >"$output" 2>&1; then
    echo "Expected code-implement to exit non-zero on interrupted tmux-run" >&2
    exit 1
  fi

  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "RUN_EVENT heartbeat"
  assert_contains "$output" "RUN_EVENT interrupted"
}

test_code_implement_fallback_terminal_event_without_tmux_terminal_line() {
  local output="$tmp_dir/code-implement-run-events-fallback.out"
  if PATH="$fake_bin:$PATH" \
    CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
    SMOKE_TMUX_RUN_MODE=no-terminal \
    SMOKE_TMUX_RUN_EXIT_CODE=7 \
    "$SCRIPT_DIR/code-implement" "Smoke lifecycle fallback terminal" >"$output" 2>&1; then
    echo "Expected code-implement to exit non-zero when tmux-run returns failure" >&2
    exit 1
  fi

  assert_contains "$output" "tmux-run exited without terminal event"
  assert_contains "$output" "RUN_EVENT start"
  assert_contains "$output" "RUN_EVENT failed"
  assert_count "$output" "RUN_EVENT done" "0"
  assert_count "$output" "RUN_EVENT interrupted" "0"
}

test_code_implement_ignores_spoofed_terminal_event_without_token() {
  local output="$tmp_dir/code-implement-run-events-spoofed-terminal.out"
  if PATH="$fake_bin:$PATH" \
    CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
    SMOKE_TMUX_RUN_MODE=spoofed-terminal \
    SMOKE_TMUX_RUN_EXIT_CODE=7 \
    "$SCRIPT_DIR/code-implement" "Smoke lifecycle spoofed terminal" >"$output" 2>&1; then
    echo "Expected code-implement to exit non-zero when tmux-run returns failure" >&2
    exit 1
  fi

  assert_contains "$output" "TMUX_RUN_EVENT done"
  assert_contains "$output" "RUN_EVENT failed"
  assert_count_regex "$output" "^RUN_EVENT done " "0"
}

test_code_implement_emits_interrupted_on_sigterm() {
  local output="$tmp_dir/code-implement-run-events-sigterm.out"
  local impl_pid=""
  local saw_start=0
  local rc=0

  set +e
  PATH="$fake_bin:$PATH" \
    CODE_IMPLEMENT_TMUX_RUN="$fake_bin/tmux-run" \
    SMOKE_TMUX_RUN_MODE=hang \
    "$SCRIPT_DIR/code-implement" "Smoke lifecycle interrupted by signal" >"$output" 2>&1 &
  impl_pid=$!
  set -e

  for _ in $(seq 1 120); do
    if [[ -f "$output" ]] && grep -Fq "RUN_EVENT start" "$output"; then
      saw_start=1
      break
    fi
    sleep 0.1
  done
  if [[ "$saw_start" != "1" ]]; then
    kill -TERM "$impl_pid" 2>/dev/null || true
    set +e
    wait "$impl_pid" 2>/dev/null
    set -e
    echo "Expected code-implement to emit RUN_EVENT start before signal" >&2
    cat "$output" >&2 || true
    exit 1
  fi

  kill -TERM "$impl_pid"
  set +e
  wait "$impl_pid"
  rc=$?
  set -e
  if [[ "$rc" != "143" ]]; then
    echo "Expected code-implement SIGTERM exit code 143, got $rc" >&2
    cat "$output" >&2 || true
    exit 1
  fi

  assert_contains "$output" "RUN_EVENT interrupted"
  assert_count_regex "$output" "^RUN_EVENT (done|failed) " "0"
}

create_supervisor_repo() {
  local repo="$1"
  git -C "$repo" init -q
  git -C "$repo" config user.email smoke@example.com
  git -C "$repo" config user.name smoke
  echo "smoke" > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m "init"
  git -C "$repo" checkout -q -b kesslerio/fix/smoke-supervisor
}

test_review_loop_supervisor_converges() {
  local repo="$tmp_dir/repo-review-loop-converge"
  local output="$tmp_dir/review-loop-converge.out"
  local codex_args="$tmp_dir/review-loop-converge-codex-args.txt"
  local safe_review_args="$tmp_dir/review-loop-converge-safe-review-args.txt"
  local state_file="$tmp_dir/review-loop-converge-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=converge \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_SAFE_REVIEW_ARGS_FILE="$safe_review_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1

  assert_contains "$output" "\"type\":\"ready\""
  assert_contains "$output" "\"type\":\"done\""
  assert_contains "$safe_review_args" "TIMEOUT=900"
  assert_contains "$safe_review_args" "codex"
  assert_contains "$safe_review_args" "review"
  assert_contains "$safe_review_args" "--base"
  assert_contains "$safe_review_args" "main"
  assert_contains "$safe_review_args" "--title"
  assert_contains "$safe_review_args" "PR Review"
  local latest_state="$repo/.ai/review-loops/latest.json"
  [[ -f "$latest_state" ]] || { echo "Expected review-loop latest state file" >&2; exit 1; }
  assert_contains "$latest_state" "\"state\": \"done\""
  assert_contains "$latest_state" "\"P1\": 0"
}

test_review_loop_supervisor_parse_retry_success() {
  local repo="$tmp_dir/repo-review-loop-parse-retry-success"
  local output="$tmp_dir/review-loop-parse-retry-success.out"
  local codex_args="$tmp_dir/review-loop-parse-retry-success-codex-args.txt"
  local safe_review_args="$tmp_dir/review-loop-parse-retry-success-safe-review-args.txt"
  local state_file="$tmp_dir/review-loop-parse-retry-success-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=parse-retry-success \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_SAFE_REVIEW_ARGS_FILE="$safe_review_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1

  assert_contains "$output" "\"attempt\":2"
  assert_contains "$output" "\"parse\":\"ok\""
  assert_contains "$safe_review_args" "TIMEOUT=900"
}

test_review_loop_supervisor_parse_retry_fails_closed() {
  local repo="$tmp_dir/repo-review-loop-parse-retry-fail"
  local output="$tmp_dir/review-loop-parse-retry-fail.out"
  local codex_args="$tmp_dir/review-loop-parse-retry-fail-codex-args.txt"
  local safe_review_args="$tmp_dir/review-loop-parse-retry-fail-safe-review-args.txt"
  local state_file="$tmp_dir/review-loop-parse-retry-fail-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=parse-retry-fail \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_SAFE_REVIEW_ARGS_FILE="$safe_review_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1; then
    echo "Expected parse retry failure to fail closed" >&2
    exit 1
  fi

  assert_contains "$output" "reason=parse_failed"
  assert_contains "$repo/.ai/review-loops/latest.json" "\"last_review_artifact\":"
}

test_review_loop_supervisor_emits_state_change_event() {
  local repo="$tmp_dir/repo-review-loop-state-change"
  local output="$tmp_dir/review-loop-state-change.out"
  local codex_args="$tmp_dir/review-loop-state-change-codex-args.txt"
  local state_file="$tmp_dir/review-loop-state-change-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=state-change \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1

  assert_contains "$output" "\"type\":\"state_change\""
  assert_contains "$output" "\"severity\":\"P1\""
}

test_review_loop_supervisor_detects_stuck_loop() {
  local repo="$tmp_dir/repo-review-loop-stuck"
  local output="$tmp_dir/review-loop-stuck.out"
  local codex_args="$tmp_dir/review-loop-stuck-codex-args.txt"
  local state_file="$tmp_dir/review-loop-stuck-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=stuck \
    SMOKE_REVIEW_LOOP_FIX_BEHAVIOR=no-change \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1; then
    echo "Expected stuck-loop detection to fail" >&2
    exit 1
  fi

  assert_contains "$output" "reason=no_changes_after_fix"
}

test_review_loop_supervisor_detects_stuck_loop_on_dirty_worktree() {
  local repo="$tmp_dir/repo-review-loop-stuck-dirty"
  local output="$tmp_dir/review-loop-stuck-dirty.out"
  local codex_args="$tmp_dir/review-loop-stuck-dirty-codex-args.txt"
  local state_file="$tmp_dir/review-loop-stuck-dirty-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  echo "preexisting-dirty-change" >> "$repo/README.md"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=stuck \
    SMOKE_REVIEW_LOOP_FIX_BEHAVIOR=no-change \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1; then
    echo "Expected dirty-worktree no-op fix detection to fail" >&2
    exit 1
  fi

  assert_contains "$output" "reason=no_changes_after_fix"
}

test_review_loop_supervisor_without_open_pr_does_not_require_gh() {
  local repo="$tmp_dir/repo-review-loop-no-gh-required"
  local output="$tmp_dir/review-loop-no-gh-required.out"
  local codex_args="$tmp_dir/review-loop-no-gh-required-codex-args.txt"
  local state_file="$tmp_dir/review-loop-no-gh-required-state.txt"
  local no_gh_bin="$tmp_dir/no-gh-bin"

  mkdir -p "$repo" "$no_gh_bin"
  create_supervisor_repo "$repo"

  ln -sf "$fake_bin/codex" "$no_gh_bin/codex"
  ln -sf "$fake_bin/timeout" "$no_gh_bin/timeout"

  PATH="$no_gh_bin:/usr/bin:/bin:/run/current-system/sw/bin" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=converge \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1

  assert_contains "$output" "\"type\":\"done\""
  assert_not_contains "$output" "missing required tools: gh"
}

test_review_loop_supervisor_open_pr_creates_pr() {
  local repo="$tmp_dir/repo-review-loop-open-pr"
  local remote="$tmp_dir/repo-review-loop-open-pr-remote.git"
  local output="$tmp_dir/review-loop-open-pr.out"
  local codex_args="$tmp_dir/review-loop-open-pr-codex-args.txt"
  local gh_args="$tmp_dir/review-loop-open-pr-gh-args.txt"
  local state_file="$tmp_dir/review-loop-open-pr-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  git -C "$repo" config protocol.file.allow always
  git init --bare -q "$remote"
  git -C "$repo" remote add origin "$remote"

  if ! PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=converge \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_GH_ARGS_FILE="$gh_args" \
    SMOKE_GH_PR_EXISTS=0 \
    SMOKE_GH_PR_CREATE_URL="https://example.test/pr/321" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main --open-pr --issue 50 >"$output" 2>&1; then
    cat "$output" >&2
    if [[ -f "$gh_args" ]]; then
      cat "$gh_args" >&2
    fi
    exit 1
  fi

  assert_contains "$output" "PR: https://example.test/pr/321"
  assert_contains "$gh_args" "pr"
  assert_contains "$gh_args" "create"
  assert_contains "$repo/.ai/review-loops/latest.json" "\"pr_url\": \"https://example.test/pr/321\""
}

test_review_loop_supervisor_open_pr_updates_existing_pr() {
  local repo="$tmp_dir/repo-review-loop-open-pr-update"
  local remote="$tmp_dir/repo-review-loop-open-pr-update-remote.git"
  local output="$tmp_dir/review-loop-open-pr-update.out"
  local codex_args="$tmp_dir/review-loop-open-pr-update-codex-args.txt"
  local gh_args="$tmp_dir/review-loop-open-pr-update-gh-args.txt"
  local state_file="$tmp_dir/review-loop-open-pr-update-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  git -C "$repo" config protocol.file.allow always
  git init --bare -q "$remote"
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" remote add upstream "git@github.com:example/repo.name.git"

  if ! PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=converge \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_GH_ARGS_FILE="$gh_args" \
    SMOKE_GH_PR_EXISTS=1 \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main --open-pr --issue 50 >"$output" 2>&1; then
    cat "$output" >&2
    if [[ -f "$gh_args" ]]; then
      cat "$gh_args" >&2
    fi
    exit 1
  fi

  assert_contains "$gh_args" "edit"
  assert_contains "$gh_args" "--repo"
  assert_contains "$gh_args" "example/repo.name"
  assert_contains "$repo/.ai/review-loops/latest.json" "\"pr_url\": \"https://example.test/pr/99\""
}

test_review_loop_supervisor_open_pr_requires_clean_tree() {
  local repo="$tmp_dir/repo-review-loop-open-pr-dirty"
  local output="$tmp_dir/review-loop-open-pr-dirty.out"
  local codex_args="$tmp_dir/review-loop-open-pr-dirty-codex-args.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  echo "dirty" >> "$repo/README.md"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=converge \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main --open-pr >"$output" 2>&1; then
    echo "Expected --open-pr clean-tree precheck to fail" >&2
    exit 1
  fi

  assert_contains "$output" "requires a clean working tree at start"
  assert_contains "$output" "Implementation changes must already be committed before starting review-loop-supervisor --open-pr."
  assert_contains "$output" "Commit the generated changes on the feature branch, then rerun review-loop-supervisor."
  assert_contains "$output" "open_pr_requires_clean_tree"
}

test_review_loop_supervisor_review_nonzero_persists_artifact() {
  local repo="$tmp_dir/repo-review-loop-review-nonzero"
  local output="$tmp_dir/review-loop-review-nonzero.out"
  local codex_args="$tmp_dir/review-loop-review-nonzero-codex-args.txt"
  local safe_review_args="$tmp_dir/review-loop-review-nonzero-safe-review-args.txt"
  local state_file="$tmp_dir/review-loop-review-nonzero-state.txt"
  local latest_state=""
  local artifact_path=""

  mkdir -p "$repo"
  create_supervisor_repo "$repo"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=review-nonzero \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_SAFE_REVIEW_ARGS_FILE="$safe_review_args" \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main >"$output" 2>&1; then
    echo "Expected wrapped review nonzero failure" >&2
    exit 1
  fi

  latest_state="$repo/.ai/review-loops/latest.json"
  [[ -f "$latest_state" ]] || { echo "Expected review-loop latest state file" >&2; exit 1; }
  assert_contains "$output" "reason=review_command_failed"
  assert_contains "$safe_review_args" "TIMEOUT=900"
  assert_contains "$safe_review_args" "codex"
  assert_contains "$safe_review_args" "review"
  assert_contains "$safe_review_args" "--base"
  assert_contains "$safe_review_args" "main"
  assert_contains "$safe_review_args" "--title"
  assert_contains "$safe_review_args" "PR Review"
  assert_contains "$latest_state" "\"last_review_exit_code\": 7"
  assert_contains "$latest_state" "\"last_review_command\": \"TIMEOUT=900 $fake_bin/safe-review.sh codex review --base main --title PR Review [prompt omitted]\""
  assert_contains "$latest_state" "\"last_review_artifact\": "
  artifact_path="$(jq -r '.last_review_artifact' <"$latest_state")"
  [[ -f "$artifact_path" ]] || { echo "Expected durable review artifact" >&2; exit 1; }
  assert_contains "$artifact_path" "Wrapped review failed intentionally."
}

test_review_loop_supervisor_github_closure_clears() {
  local repo="$tmp_dir/repo-review-loop-github-clear"
  local output="$tmp_dir/review-loop-github-clear.out"
  local codex_args="$tmp_dir/review-loop-github-clear-codex-args.txt"
  local gh_args="$tmp_dir/review-loop-github-clear-gh-args.txt"
  local state_file="$tmp_dir/review-loop-github-clear-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  git -C "$repo" remote add origin "git@github.com:example/repo.name.git"

  PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=already-clear \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_GH_ARGS_FILE="$gh_args" \
    SMOKE_GH_PR_EXISTS=1 \
    SMOKE_GH_REPO_PATH="$repo" \
    SMOKE_GH_GRAPHQL_SCENARIO=immediate-clear \
    SMOKE_GH_GRAPHQL_REVIEW_AUTHOR=codex-bot \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main --closure-mode github --github-review-author codex-bot >"$output" 2>&1

  assert_contains "$output" "\"type\":\"github_review_cleared\""
  assert_contains "$gh_args" "--repo"
  assert_contains "$gh_args" "example/repo.name"
  assert_contains "$repo/.ai/review-loops/latest.json" "\"state\": \"done\""
  assert_contains "$repo/.ai/review-loops/latest.json" "\"status\": \"cleared\""
}

test_review_loop_supervisor_pending_github_review_fails_closed() {
  local repo="$tmp_dir/repo-review-loop-github-pending"
  local output="$tmp_dir/review-loop-github-pending.out"
  local codex_args="$tmp_dir/review-loop-github-pending-codex-args.txt"
  local state_file="$tmp_dir/review-loop-github-pending-state.txt"

  mkdir -p "$repo"
  create_supervisor_repo "$repo"
  git -C "$repo" remote add origin "git@github.com:example/repo.name.git"

  if PATH="$fake_bin:$PATH" \
    REVIEW_LOOP_SAFE_REVIEW_BIN="$fake_bin/safe-review.sh" \
    SMOKE_CODEX_MODE=review-loop \
    SMOKE_REVIEW_LOOP_SCENARIO=already-clear \
    SMOKE_REVIEW_LOOP_STATE_FILE="$state_file" \
    SMOKE_CODEX_ARGS_FILE="$codex_args" \
    SMOKE_GH_PR_EXISTS=1 \
    SMOKE_GH_REPO_PATH="$repo" \
    SMOKE_GH_GRAPHQL_SCENARIO=pending-review \
    "$SCRIPT_DIR/review-loop-supervisor" --repo "$repo" --base main --closure-mode github --github-review-wait-seconds 1 --github-review-poll-seconds 1 >"$output" 2>&1; then
    echo "Expected pending GitHub review closure to fail closed" >&2
    exit 1
  fi

  assert_contains "$output" "pending_github_review"
  assert_contains "$repo/.ai/review-loops/latest.json" "\"state\": \"pending_github_review\""
  assert_contains "$repo/.ai/review-loops/latest.json" "\"status\": \"pending_review\""
}

run_test() {
  local test_name="$1"
  echo "SMOKE_TEST start name=${test_name}" >&2
  "$test_name"
  echo "SMOKE_TEST done name=${test_name}" >&2
}

run_test test_invalid_mode_rejected
run_test test_invalid_cli_rejected
run_test test_safe_review_emits_run_events_done
run_test test_safe_review_emits_run_events_interrupted
run_test test_doctor_known_issue_guidance
run_test test_canonical_guard_behavior
run_test test_review_prompt_pass_through
run_test test_invalid_impl_mode_rejected
run_test test_invalid_acp_enable_rejected
run_test test_impl_direct_mode_uses_codex_exec
run_test test_impl_uses_acpx_first_when_available
run_test test_safe_fallback_json_acpx_success_contract
run_test test_safe_fallback_defaults_to_text_output
run_test test_review_uses_codex_review_first
run_test test_review_fallback_uses_current_default_branch_when_alone
run_test test_review_fallback_uses_current_nonstandard_branch_when_alone
run_test test_review_fallback_prefers_current_default_branch
run_test test_safe_fallback_streams_text_output
run_test test_acp_agent_alias_forwarded
run_test test_acpx_cmd_override_is_used
run_test test_acp_disable_skips_acpx
run_test test_acp_disable_ignores_invalid_policy_env
run_test test_acpx_wrapper_rejects_forwarded_timeout
run_test test_acpx_direct_emits_canonical_shape
run_test test_acpx_direct_rejects_forwarded_cwd
run_test test_acpx_direct_rejects_forwarded_format
run_test test_acpx_direct_requires_cwd_value
run_test test_acpx_direct_requires_format_value
run_test test_acpx_direct_rejects_flag_like_agent_token
run_test test_docs_block_invalid_acpx_shape
run_test test_acp_smoke_local_uses_session_prompt_without_forwarded_timeout
run_test test_code_plan_generates_artifact
run_test test_safe_impl_claude_plan_mode_no_dangerous_skip
run_test test_plan_review_generates_artifact
run_test test_plan_review_output_parent_dirs_created
run_test test_plan_review_live_lobster_default_engine
run_test test_plan_review_live_lobster_resume_preserves_decisions
run_test test_plan_review_live_lobster_resume_missing_state_auto_restarts
run_test test_plan_review_live_lobster_decision_timeout_fails_fast
run_test test_plan_review_live_lobster_timeout_on_blocking_keeps_selected_decisions
run_test test_plan_review_live_generates_ready_metadata
run_test test_plan_review_live_non_tty_auto_apply_with_flags
run_test test_plan_review_live_resolution_inputs_override_allow_non_tty
run_test test_plan_review_live_non_tty_auto_apply_with_resolve_file
run_test test_plan_review_live_non_tty_requires_resolution_inputs
run_test test_plan_review_live_rejects_invalid_resolve_file
run_test test_plan_review_live_rejects_mixed_resolution_inputs
run_test test_code_implement_blocks_when_metadata_missing
run_test test_code_implement_blocks_when_metadata_invalid
run_test test_code_implement_blocks_when_unresolved_blockers_exist
run_test test_code_implement_non_tty_pending_plan_fails_fast
run_test test_code_implement_allows_ready_metadata
run_test test_code_implement_force_bypasses_review_gate
run_test test_code_implement_dry_run_json_happy_path
run_test test_code_implement_dry_run_defaults_to_text_output
run_test test_code_implement_dry_run_skips_execution_dependencies
run_test test_code_implement_accepts_nested_plan_artifact
run_test test_code_implement_rejects_invalid_plan_path
run_test test_code_implement_rejects_malformed_metadata
run_test test_code_implement_requires_approved_non_interactive
run_test test_code_implement_approve_updates_plan_and_launches
run_test test_code_implement_approve_rejects_missing_frontmatter
run_test test_safe_fallback_json_contract
run_test test_safe_fallback_json_preserves_launch_state
run_test test_safe_fallback_json_failure_redacts_backend_output
run_test test_emit_error_text_mode_does_not_require_jq
run_test test_safe_fallback_text_blocker_does_not_require_jq
run_test test_code_implement_launches_with_unverified_state
run_test test_code_implement_large_plan_uses_stdin_transport_json
run_test test_code_implement_large_plan_uses_stdin_transport_run_events
run_test test_code_implement_accepts_metadata_from_non_tty_apply_flow
run_test test_code_implement_accepts_metadata_from_apply_mode
run_test test_code_implement_emits_run_events_success
run_test test_code_implement_emits_run_events_interrupted
run_test test_code_implement_fallback_terminal_event_without_tmux_terminal_line
run_test test_code_implement_ignores_spoofed_terminal_event_without_token
run_test test_code_implement_emits_interrupted_on_sigterm
run_test test_review_loop_supervisor_converges
run_test test_review_loop_supervisor_parse_retry_success
run_test test_review_loop_supervisor_parse_retry_fails_closed
run_test test_review_loop_supervisor_review_nonzero_persists_artifact
run_test test_review_loop_supervisor_github_closure_clears
run_test test_review_loop_supervisor_pending_github_review_fails_closed
run_test test_review_loop_supervisor_emits_state_change_event
run_test test_review_loop_supervisor_detects_stuck_loop
run_test test_review_loop_supervisor_detects_stuck_loop_on_dirty_worktree
run_test test_review_loop_supervisor_without_open_pr_does_not_require_gh
run_test test_review_loop_supervisor_open_pr_creates_pr
run_test test_review_loop_supervisor_open_pr_updates_existing_pr
run_test test_review_loop_supervisor_open_pr_requires_clean_tree

printf 'Wrapper smoke tests passed.\n'
