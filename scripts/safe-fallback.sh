#!/usr/bin/env bash
# safe-fallback.sh - Try tools in order, report blocker if all fail
set -euo pipefail

export PATH="$PATH:/run/current-system/sw/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/canonical-repo-guard.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/resolve-cli.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/acpx-wrapper.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/wrapper-io.sh"
ensure_canonical_repo_from_script_dir "$SCRIPT_DIR"

COMMAND_NAME="safe-fallback"
MODE="${1:-impl}"
shift || true
OUTPUT_MODE="text"
RUN_ID="$(generate_run_id)"

if [[ "$MODE" != "impl" && "$MODE" != "review" ]]; then
  echo "Error: invalid mode '$MODE' (expected: impl|review)" >&2
  echo "Usage: safe-fallback.sh <impl|review> [--output text|json] \"prompt...\"" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_MODE="${2:-}"
      shift 2
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

if ! ensure_output_mode "$OUTPUT_MODE"; then
  exit 1
fi

if [[ "$OUTPUT_MODE" == "json" ]]; then
  require_cmd_or_die "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "jq" \
    "Install jq before using --output json with safe-fallback.sh."
fi

PROMPT="${*:-}"
if [[ -z "$PROMPT" ]]; then
  echo "Usage: safe-fallback.sh <impl|review> [--output text|json] \"prompt...\"" >&2
  exit 1
fi

if ! reject_control_chars "prompt" "$PROMPT"; then
  emit_error "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "INPUT_CONTROL_CHARS" \
    "Prompt contains control characters." \
    "{}" \
    "null" \
    "Remove control characters from the prompt and retry."
  exit 1
fi

IMPL_TIMEOUT=${IMPL_TIMEOUT:-180}
REVIEW_TIMEOUT=${REVIEW_TIMEOUT:-1200}
TIMEOUT=$([[ "$MODE" == "review" ]] && echo "$REVIEW_TIMEOUT" || echo "$IMPL_TIMEOUT")
GEMINI_FALLBACK_ENABLE=${GEMINI_FALLBACK_ENABLE:-0}
CODING_AGENT_ACP_ENABLE=${CODING_AGENT_ACP_ENABLE:-1}
CODING_AGENT_ACP_AGENT=${CODING_AGENT_ACP_AGENT:-codex}
CODING_AGENT_ACP_APPROVE_ALL=${CODING_AGENT_ACP_APPROVE_ALL:-1}
CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS=${CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS:-fail}
CODING_AGENT_ACP_SESSION_MODE=${CODING_AGENT_ACP_SESSION_MODE:-}
FAILURES=()

if [[ "$GEMINI_FALLBACK_ENABLE" != "0" && "$GEMINI_FALLBACK_ENABLE" != "1" ]]; then
  echo "Error: GEMINI_FALLBACK_ENABLE must be 0 or 1" >&2
  exit 1
fi

if [[ "$CODING_AGENT_ACP_ENABLE" != "0" && "$CODING_AGENT_ACP_ENABLE" != "1" ]]; then
  echo "Error: CODING_AGENT_ACP_ENABLE must be 0 or 1" >&2
  exit 1
fi

require_cmd_or_die "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "python3" \
  "Install python3 before running safe-fallback.sh."

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

error() { echo -e "${RED}❌ $1${NC}" >&2; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}" >&2; }
ok() { echo -e "${GREEN}✅ $1${NC}" >&2; }
info() { echo -e "${CYAN}ℹ️  $1${NC}" >&2; }

resolve_wrapper_policy_cmd() {
  local policy_cmd="${WRAPPER_POLICY_CMD:-$SCRIPT_DIR/wrapper-policy}"
  if [[ ! -x "$policy_cmd" ]]; then
    emit_error "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "DEPENDENCY_MISSING" \
      "wrapper-policy helper is missing or not executable: $policy_cmd" \
      "{}" \
      "null" \
      "Restore scripts/wrapper-policy and retry."
    exit 1
  fi
  printf '%s\n' "$policy_cmd"
}

run_wrapper_policy() {
  local policy_cmd="$1"
  shift
  local output=""

  if ! output="$("$policy_cmd" "$@")"; then
    emit_error "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "WRAPPER_POLICY_FAILED" \
      "wrapper-policy command failed." \
      "{}" \
      "null" \
      "Inspect the Python wrapper policy command and retry."
    exit 1
  fi
  printf '%s\n' "$output"
}

emit_policy_error_from_json() {
  local payload_json="$1"
  local code message context_json data_json
  local remediation_items=()

  code="$(printf '%s' "$payload_json" | jq -r '.error.code')"
  message="$(printf '%s' "$payload_json" | jq -r '.error.message')"
  context_json="$(printf '%s' "$payload_json" | jq -c '.error.context // {}')"
  data_json="$(printf '%s' "$payload_json" | jq -c '.data // null')"
  while IFS= read -r remediation_item; do
    remediation_items+=("$remediation_item")
  done < <(printf '%s' "$payload_json" | jq -r '.error.remediation // [] | .[]')
  emit_error "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "$code" \
    "$message" \
    "$context_json" \
    "$data_json" \
    "${remediation_items[@]}"
}

WRAPPER_POLICY_BIN="$(resolve_wrapper_policy_cmd)"

resolve_impl_mode() {
  if [[ -n "${CODING_AGENT_IMPL_MODE:-}" ]]; then
    printf '%s\n' "${CODING_AGENT_IMPL_MODE}"
    return 0
  fi

  if [[ "${CODEX_TMUX_DISABLE:-0}" == "1" ]]; then
    printf 'direct\n'
    return 0
  fi
  if [[ "${CODEX_TMUX_REQUIRED:-0}" == "1" ]]; then
    printf 'tmux\n'
    return 0
  fi

  printf 'direct\n'
}

detect_base_branch() {
  local policy_cmd="$1"
  run_wrapper_policy "$policy_cmd" review-base --cwd "$PWD" --format raw
}

normalize_success_payload() {
  local policy_cmd="$1"
  local backend="$2"
  local state="$3"
  local backend_response_json="${4:-null}"
  local payload_json normalized_json

  payload_json="$(jq -n \
    --arg kind "safe-fallback-success" \
    --arg mode "$MODE" \
    --arg backend "$backend" \
    --arg state "$state" \
    --argjson backend_response "$backend_response_json" \
    '{
      kind: $kind,
      mode: $mode,
      backend: $backend,
      state: $state,
      backend_response: $backend_response
    }')"
  normalized_json="$(printf '%s' "$payload_json" | "$policy_cmd" normalize-result)"
  printf '%s\n' "$normalized_json"
}

record_failure() {
  FAILURES+=("$1")
}

emit_blocker() {
  local policy_cmd blocker_payload_json blocker_json failures_json context_json
  context_json="$(printf '{"mode":"%s"}' "$MODE")"
  if [[ "$OUTPUT_MODE" != "json" ]] || ! command -v jq >/dev/null 2>&1; then
    emit_error "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" "ALL_BACKENDS_UNAVAILABLE" \
      "All execution backends failed for mode '$MODE'." \
      "$context_json" \
      "null" \
      "Wait for tool availability or install the required CLI tools." \
      "Inspect the recorded failures and retry with a healthier backend."
    exit 1
  fi

  policy_cmd="$(resolve_wrapper_policy_cmd)"
  failures_json="$(printf '%s\n' "${FAILURES[@]}" | jq -R . | jq -s .)"
  blocker_payload_json="$(jq -n \
    --arg kind "safe-fallback-blocker" \
    --arg mode "$MODE" \
    --arg cause_class "unknown_backend_failure" \
    --argjson failures "$failures_json" \
    '{
      kind: $kind,
      mode: $mode,
      cause_class: $cause_class,
      failures: $failures
    }')"
  blocker_json="$(printf '%s' "$blocker_payload_json" | "$policy_cmd" normalize-result)"
  emit_policy_error_from_json "$blocker_json"
  exit 1
}

run_backend() {
  local backend="$1"
  shift
  local output=""
  local backend_response='null'
  local backend_state="completed"
  local normalized_json=""
  local output_file=""
  local stdout_file=""
  local stderr_file=""
  local failure_summary="${backend}: command failed"

  if [[ "$OUTPUT_MODE" != "json" ]]; then
    output_file="$(mktemp)"
    if "$@" 2>&1 | tee "$output_file"; then
      rm -f "$output_file"
      return 0
    fi

    output="$(cat "$output_file" 2>/dev/null || true)"
    rm -f "$output_file"
    record_failure "$failure_summary"
    return 1
  fi

  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  if ! "$@" >"$stdout_file" 2>"$stderr_file"; then
    rm -f "$stdout_file" "$stderr_file"
    record_failure "$failure_summary"
    return 1
  fi
  output="$(cat "$stdout_file" 2>/dev/null || true)"
  rm -f "$stdout_file" "$stderr_file"

  if printf '%s' "$output" | jq -e '.ok' >/dev/null 2>&1; then
    backend_response="$(printf '%s' "$output" | jq -c '.')"
    backend_state="$(printf '%s' "$output" | jq -r '.data.state // "completed"')"
  fi
  normalized_json="$(normalize_success_payload "$WRAPPER_POLICY_BIN" "$backend" "$backend_state" "$backend_response")"
  emit_success "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" \
    "$(printf '%s' "$normalized_json" | jq -c '.data')"
  return 0
}

build_acpx_prompt() {
  printf '%s\n' "$PROMPT"
}

derive_acpx_session_name() {
  if [[ -n "${CODING_AGENT_ACP_SESSION:-}" ]]; then
    printf '%s\n' "$CODING_AGENT_ACP_SESSION"
    return 0
  fi
  local repo_token
  repo_token="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  if [[ -z "$repo_token" ]]; then
    repo_token="workspace"
  fi
  printf 'ca-%s-%s\n' "$CODING_AGENT_ACP_AGENT" "$repo_token"
}

try_acpx() {
  if [[ "$CODING_AGENT_ACP_ENABLE" != "1" ]]; then
    record_failure "ACPX: disabled (set CODING_AGENT_ACP_ENABLE=1 to enable)"
    return 1
  fi

  if ! acpx_validate_policy_env; then
    record_failure "ACPX: invalid policy env (CODING_AGENT_ACP_APPROVE_ALL/CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS)"
    return 1
  fi

  local acpx_bin=""
  if ! acpx_bin="$(resolve_acpx_bin)"; then
    if [[ -n "${CODING_AGENT_ACPX_CMD:-}" ]]; then
      record_failure "ACPX: CODING_AGENT_ACPX_CMD is set but not executable (${CODING_AGENT_ACPX_CMD})"
    else
      record_failure "ACPX: not found (CODING_AGENT_ACPX_CMD, PATH)"
    fi
    return 1
  fi

  if ! command -v timeout >/dev/null 2>&1; then
    record_failure "ACPX: timeout command not available"
    return 1
  fi

  local acpx_prompt=""
  local acpx_session=""
  local acpx_log=""
  acpx_prompt="$(build_acpx_prompt)"
  acpx_session="$(derive_acpx_session_name)"

  info "Trying ACPX (${CODING_AGENT_ACP_AGENT}) session=${acpx_session}..."
  if [[ "$OUTPUT_MODE" == "json" ]]; then
    if ! ACPX_RUN_TIMEOUT="$TIMEOUT" acpx_run_canonical "$acpx_bin" "$PWD" quiet "$CODING_AGENT_ACP_AGENT" sessions ensure --name "$acpx_session" >/dev/null 2>&1; then
      record_failure "ACPX: sessions ensure failed"
      return 1
    fi
  elif ! ACPX_RUN_TIMEOUT="$TIMEOUT" acpx_run_canonical "$acpx_bin" "$PWD" quiet "$CODING_AGENT_ACP_AGENT" sessions ensure --name "$acpx_session"; then
    record_failure "ACPX: sessions ensure failed"
    return 1
  fi

  if [[ -n "$CODING_AGENT_ACP_SESSION_MODE" ]]; then
    if [[ "$OUTPUT_MODE" == "json" ]]; then
      if ! ACPX_RUN_TIMEOUT="$TIMEOUT" acpx_run_canonical "$acpx_bin" "$PWD" quiet "$CODING_AGENT_ACP_AGENT" set-mode "$CODING_AGENT_ACP_SESSION_MODE" >/dev/null 2>&1; then
        warn "ACPX set-mode failed; continuing with existing mode"
      fi
    elif ! ACPX_RUN_TIMEOUT="$TIMEOUT" acpx_run_canonical "$acpx_bin" "$PWD" quiet "$CODING_AGENT_ACP_AGENT" set-mode "$CODING_AGENT_ACP_SESSION_MODE"; then
      warn "ACPX set-mode failed; continuing with existing mode"
    fi
  fi

  acpx_log="$(mktemp)"
  if ACPX_RUN_TIMEOUT="$TIMEOUT" acpx_run_canonical "$acpx_bin" "$PWD" quiet "$CODING_AGENT_ACP_AGENT" -s "$acpx_session" "$acpx_prompt" >"$acpx_log" 2>&1; then
    if [[ "$OUTPUT_MODE" == "json" ]]; then
      local normalized_json=""
      normalized_json="$(normalize_success_payload "$WRAPPER_POLICY_BIN" "acpx" "completed" "null")"
      emit_success "$OUTPUT_MODE" "$COMMAND_NAME" "$RUN_ID" \
        "$(printf '%s' "$normalized_json" | jq -c '.data')"
    else
      cat "$acpx_log"
    fi
    rm -f "$acpx_log"
    ok "ACPX succeeded"
    return 0
  fi
  warn "ACPX failed; tail follows:"
  tail -n 20 "$acpx_log" >&2 || true
  rm -f "$acpx_log"

  record_failure "ACPX: session prompt failed or timeout"
  return 1
}

try_codex_tmux() {
  if [[ "$MODE" != "impl" ]]; then
    record_failure "Codex tmux: unsupported in review mode"
    return 1
  fi

  info "Trying Codex CLI in tmux..."
  local -a cmd=("$SCRIPT_DIR/code-implement")
  if [[ "$OUTPUT_MODE" == "json" ]]; then
    cmd+=(--output json)
  fi
  cmd+=("$PROMPT")
  run_backend "codex_tmux" "${cmd[@]}"
}

try_codex_cli_direct() {
  info "Trying Codex CLI (direct)..."
  if ! command -v codex >/dev/null 2>&1; then
    record_failure "Codex CLI: codex not installed"
    return 1
  fi
  if ! command -v timeout >/dev/null 2>&1; then
    record_failure "Codex CLI: timeout not installed"
    return 1
  fi

  if [[ "$MODE" == "review" ]]; then
    local base_branch=""
    base_branch="$(detect_base_branch "$WRAPPER_POLICY_BIN")"
    run_backend "codex_review" timeout "${TIMEOUT}s" codex review --base "$base_branch" --title "${PROMPT:0:100}" "$PROMPT"
    return $?
  fi

  run_backend "codex_direct" timeout "${TIMEOUT}s" codex exec --full-auto "$PROMPT"
}

try_claude_cli() {
  info "Trying Claude CLI (timeout: ${TIMEOUT}s, acceptEdits)..."
  local claude_bin=""
  if ! claude_bin="$(resolve_claude_bin)"; then
    if [[ -n "${CODING_AGENT_CLAUDE_BIN:-}" ]]; then
      record_failure "Claude CLI: CODING_AGENT_CLAUDE_BIN is set but not executable (${CODING_AGENT_CLAUDE_BIN})"
    else
      record_failure "Claude CLI: not found (CODING_AGENT_CLAUDE_BIN, ~/.claude/local/claude, PATH)"
    fi
    return 1
  fi
  if ! command -v timeout >/dev/null 2>&1; then
    record_failure "Claude CLI: timeout command not available"
    return 1
  fi

  run_backend "claude_cli" timeout "${TIMEOUT}s" "$claude_bin" -p --permission-mode acceptEdits "$PROMPT"
}

try_gemini_cli() {
  if [[ "$GEMINI_FALLBACK_ENABLE" != "1" ]]; then
    record_failure "Gemini CLI: disabled (set GEMINI_FALLBACK_ENABLE=1 to enable)"
    return 1
  fi

  info "Trying Gemini CLI (timeout: ${TIMEOUT}s)..."
  if ! command -v gemini >/dev/null 2>&1; then
    record_failure "Gemini CLI: gemini not installed"
    return 1
  fi
  if ! command -v timeout >/dev/null 2>&1; then
    record_failure "Gemini CLI: timeout command not available"
    return 1
  fi

  run_backend "gemini_cli" timeout "${TIMEOUT}s" gemini -y "$PROMPT"
}

report_blocker() {
  echo "" >&2
  error "BLOCKED: All tools unavailable for mode '$MODE'"
  echo "" >&2
  echo "Failures:" >&2
  for failure in "${FAILURES[@]}"; do
    echo "  - $failure" >&2
  done
  echo "" >&2
  echo "Options:" >&2
  echo "  a) Wait for tool availability (for example a Codex quota reset)" >&2
  echo "  b) Install or repair the preferred CLI backend" >&2
  echo "  c) Retry with an explicit routing override after the backend recovers" >&2
}

main() {
  echo "Mode: $MODE | Timeout: ${TIMEOUT}s" >&2
  echo "ACP routing: $CODING_AGENT_ACP_ENABLE (agent: $CODING_AGENT_ACP_AGENT)" >&2
  echo "Gemini fallback: $GEMINI_FALLBACK_ENABLE" >&2

  if [[ "$MODE" == "review" ]]; then
    try_codex_cli_direct && exit 0
    warn "Codex CLI unavailable for review, trying ACP fallback..."

    try_acpx && exit 0
    warn "ACPX unavailable for review, trying next..."
  else
    try_acpx && exit 0
    warn "ACPX unavailable, trying CLI fallback chain..."

    local impl_mode
    impl_mode="$(resolve_impl_mode)"
    case "$impl_mode" in
      direct|tmux|auto)
        ;;
      *)
        error "Invalid CODING_AGENT_IMPL_MODE '$impl_mode' (expected: direct|tmux|auto)"
        exit 1
        ;;
    esac

    if [[ "$impl_mode" == "auto" ]]; then
      if command -v tmux >/dev/null 2>&1 && [[ -t 1 ]]; then
        impl_mode="tmux"
      else
        impl_mode="direct"
      fi
    fi

    echo "Implementation mode: $impl_mode" >&2

    if [[ "$impl_mode" == "tmux" ]]; then
      try_codex_tmux && exit 0
      warn "Codex tmux unavailable, trying direct CLI..."
      try_codex_cli_direct && exit 0
      warn "Codex direct CLI unavailable, trying next..."
    else
      try_codex_cli_direct && exit 0
      warn "Codex direct CLI unavailable, trying tmux..."
      try_codex_tmux && exit 0
      warn "Codex tmux unavailable, trying next..."
    fi
  fi

  try_claude_cli && exit 0
  warn "Claude CLI unavailable..."

  try_gemini_cli && exit 0
  warn "Gemini CLI unavailable..."

  report_blocker
  emit_blocker
}

main
