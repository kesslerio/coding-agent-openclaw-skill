#!/usr/bin/env bash
# acpx-wrapper.sh - canonical ACPX invocation helpers
set -euo pipefail

acpx_validate_policy_env() {
  local approve_all="${CODING_AGENT_ACP_APPROVE_ALL:-1}"
  local non_interactive="${CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS:-fail}"

  if [[ "$approve_all" != "0" && "$approve_all" != "1" ]]; then
    printf 'Error: CODING_AGENT_ACP_APPROVE_ALL must be 0 or 1\n' >&2
    return 1
  fi
  if [[ "$non_interactive" != "fail" && "$non_interactive" != "deny" ]]; then
    printf 'Error: CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS must be fail or deny\n' >&2
    return 1
  fi
}

acpx_run_canonical() {
  if [[ $# -lt 4 ]]; then
    printf 'Error: acpx_run_canonical requires: <acpx_bin> <cwd> <format> <agent> [args...]\n' >&2
    return 1
  fi

  local acpx_bin="$1"
  local run_cwd="$2"
  local out_format="$3"
  local agent="$4"
  shift 4

  local arg
  for arg in "$@"; do
    case "$arg" in
      --cwd|--format|--approve-all|--approve-reads|--deny-all|--non-interactive-permissions)
        printf 'Error: non-canonical ACPX invocation: pass global flags via acpx_run_canonical only (got %s)\n' "$arg" >&2
        return 1
        ;;
    esac
  done

  local -a cmd
  cmd=("$acpx_bin" --cwd "$run_cwd" --format "$out_format")
  if [[ "${CODING_AGENT_ACP_APPROVE_ALL:-1}" == "1" ]]; then
    cmd+=(--approve-all)
  fi
  cmd+=(--non-interactive-permissions "${CODING_AGENT_ACP_NON_INTERACTIVE_PERMISSIONS:-fail}")
  cmd+=("$agent")
  cmd+=("$@")
  if [[ -n "${ACPX_RUN_TIMEOUT:-}" ]]; then
    if [[ ! "${ACPX_RUN_TIMEOUT}" =~ ^[0-9]+$ ]] || (( ACPX_RUN_TIMEOUT <= 0 )); then
      printf 'Error: ACPX_RUN_TIMEOUT must be a positive integer when set\n' >&2
      return 1
    fi
    timeout "${ACPX_RUN_TIMEOUT}s" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}
