#!/usr/bin/env bash
set -euo pipefail

generate_run_id() {
  printf '%s-%s-%s\n' "$(date +%Y%m%d%H%M%S)" "$$" "${RANDOM}"
}

is_tty_stdout() {
  [[ -t 1 ]]
}

resolve_output_mode() {
  local requested="${1:-}"
  local default_mode="${2:-text}"

  if [[ -n "$requested" ]]; then
    printf '%s\n' "$requested"
    return 0
  fi

  printf '%s\n' "$default_mode"
}

ensure_output_mode() {
  local value="$1"
  if [[ "$value" != "text" && "$value" != "json" ]]; then
    printf 'Invalid output mode: %s\n' "$value" >&2
    return 1
  fi
}

reject_control_chars() {
  local field="$1"
  local value="$2"

  if printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    printf 'Control characters are not allowed in %s\n' "$field" >&2
    return 1
  fi
}

require_cmd_or_die() {
  local output_mode="$1"
  local command_name="$2"
  local run_id="$3"
  local binary_name="$4"
  local remediation="$5"
  local context_json

  if command -v "$binary_name" >/dev/null 2>&1; then
    return 0
  fi

  context_json="$(printf '{"dependency":"%s"}' "$binary_name")"
  emit_error "$output_mode" "$command_name" "$run_id" "DEPENDENCY_MISSING" \
    "Required command not found: $binary_name" \
    "$context_json" \
    "null" \
    "$remediation"
  exit 1
}

emit_error() {
  local output_mode="$1"
  local command_name="$2"
  local run_id="$3"
  local code="$4"
  local message="$5"
  local context_json="${6:-"{}"}"
  local data_json="${7:-"null"}"
  shift 7 || true
  local remediation=("$@")
  local remediation_json="[]"

  if ((${#remediation[@]} > 0)); then
    remediation_json="$(printf '%s\n' "${remediation[@]}" | jq -R . | jq -s .)"
  fi

  if [[ "$output_mode" == "json" ]] && command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg command "$command_name" \
      --arg run_id "$run_id" \
      --arg code "$code" \
      --arg message "$message" \
      --argjson remediation "$remediation_json" \
      --argjson context "$context_json" \
      --argjson data "$data_json" \
      '{
        ok: false,
        command: $command,
        run_id: $run_id,
        error: {
          code: $code,
          message: $message,
          remediation: $remediation,
          context: $context
        },
        data: $data
      }'
    return 0
  fi

  printf 'Error [%s]: %s\n' "$code" "$message" >&2
  if [[ "$context_json" != "{}" ]]; then
    printf 'Context: %s\n' "$context_json" >&2
  fi
  if ((${#remediation[@]} > 0)); then
    printf 'Remediation:\n' >&2
    for item in "${remediation[@]}"; do
      printf '  - %s\n' "$item" >&2
    done
  fi
}

emit_success() {
  local output_mode="$1"
  local command_name="$2"
  local run_id="$3"
  local data_json="$4"
  local text_message="${5:-}"

  if [[ "$output_mode" == "json" ]] && command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg command "$command_name" \
      --arg run_id "$run_id" \
      --argjson data "$data_json" \
      '{
        ok: true,
        command: $command,
        run_id: $run_id,
        data: $data
      }'
    return 0
  fi

  if [[ -n "$text_message" ]]; then
    printf '%s\n' "$text_message"
  fi
}
