#!/usr/bin/env bash
# canonical-repo-guard.sh - enforce single canonical local clone for this repo

canonical_repo_path() {
  printf '%s\n' "${CODING_AGENT_CANONICAL_REPO:-/home/art/projects/skills/shared/coding-agent}"
}

resolve_physical_path() {
  local target="$1"
  (cd -- "$target" 2>/dev/null && pwd -P) || return 1
}

ensure_canonical_repo_root() {
  local repo_hint="$1"
  local expected_root
  local current_root

  if [[ "${CODING_AGENT_ALLOW_NONCANONICAL:-0}" == "1" ]]; then
    return 0
  fi

  if ! expected_root="$(resolve_physical_path "$(canonical_repo_path)")"; then
    printf '[fail] canonical-repo: configured canonical path is not accessible: %s\n' "$(canonical_repo_path)" >&2
    return 1
  fi

  if current_root="$(git -C "$repo_hint" rev-parse --show-toplevel 2>/dev/null)"; then
    if ! current_root="$(resolve_physical_path "$current_root")"; then
      printf '[fail] canonical-repo: unable to resolve current repo path: %s\n' "$current_root" >&2
      return 1
    fi
  else
    if ! current_root="$(resolve_physical_path "$repo_hint")"; then
      printf '[fail] canonical-repo: unable to resolve current path: %s\n' "$repo_hint" >&2
      return 1
    fi
  fi

  if [[ "$current_root" != "$expected_root" ]]; then
    printf '[fail] canonical-repo: non-canonical clone detected\n' >&2
    printf '       Current: %s\n' "$current_root" >&2
    printf '       Expected: %s\n' "$expected_root" >&2
    printf '       Fix: use canonical repo path or set CODING_AGENT_ALLOW_NONCANONICAL=1 (temporary override)\n' >&2
    return 1
  fi
}

ensure_canonical_repo_from_script_dir() {
  local script_dir="$1"
  ensure_canonical_repo_root "$script_dir/.."
}
