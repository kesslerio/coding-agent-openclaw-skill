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
exit 0
EOF

chmod +x "$fake_bin/timeout" "$fake_bin/codex"

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

test_invalid_mode_rejected
test_invalid_cli_rejected
test_review_prompt_pass_through
test_invalid_impl_mode_rejected
test_impl_direct_mode_uses_codex_exec

printf 'Wrapper smoke tests passed.\n'
