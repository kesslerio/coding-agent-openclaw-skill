#!/usr/bin/env bash
# smoke-wrappers.sh - lightweight behavior checks for wrapper scripts
set -euo pipefail

# Ensure standard tools are available on NixOS
export PATH="$PATH:/run/current-system/sw/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
shift
exec "$@"
EOF

cat >"$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SMOKE_CODEX_ARGS_FILE:?}"
{
  for arg in "$@"; do
    printf '%s\n' "$arg"
  done
} >"$SMOKE_CODEX_ARGS_FILE"
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

chmod +x "$fake_bin/timeout" "$fake_bin/codex" "$fake_bin/claude"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'Assertion failed: expected "%s" in %s\n' "$expected" "$file" >&2
    printf '--- file content ---\n' >&2
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

  assert_contains "$codex_args" "--yolo"
  assert_contains "$codex_args" "exec"
  assert_contains "$codex_args" "$prompt"
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
  "$SCRIPT_DIR/code-plan" --engine codex --repo "$repo" --base main "smoke plan request" > "$tmp_dir/code-plan.out"

  local plan_file
  plan_file="$(find "$repo/.ai/plans" -maxdepth 1 -type f -name '*.md' | head -1)"
  [[ -n "$plan_file" && -f "$plan_file" ]] || { echo "Expected plan file" >&2; exit 1; }
  assert_contains "$codex_args" "--sandbox"
  assert_contains "$codex_args" "read-only"
  assert_contains "$codex_args" "--ephemeral"
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

test_invalid_mode_rejected
test_invalid_cli_rejected
test_review_prompt_pass_through
test_invalid_impl_mode_rejected
test_impl_direct_mode_uses_codex_exec
test_code_plan_generates_artifact
test_safe_impl_claude_plan_mode_no_dangerous_skip

printf 'Wrapper smoke tests passed.\n'
