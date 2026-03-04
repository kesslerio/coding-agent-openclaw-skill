# ACP Troubleshooting (Issue #43)

This repo tracks a known upstream ACP/OpenClaw runtime limitation:
- Issue: https://github.com/kesslerio/coding-agent-openclaw-skill/issues/43
- Scope: spawned ACP run observability and browser relay profile alias mismatch.

## What This Means

This skill repo can provide mitigations and fallbacks, but it does not own the
runtime fix for:
- cross-session ACP run completion visibility, and
- browser relay alias mapping for `profile=chrome`.

## Symptom Signatures

### 1) Spawn accepted, but run output not observable
You may see successful spawn output with a child session key, followed by
forbidden history reads (for example visibility restrictions).

Typical pattern:
- `status: accepted` with `childSessionKey`/`runId`
- later: `status: forbidden` for session history from parent context

### 2) Browser relay profile mismatch
Relay attempts using `profile="chrome"` fail even when browser relay is working.
Available profile names may differ (for example `niemand`, `mac`, `openclaw`).

### 3) ACPX runtime timeouts
`acpx` can be installed and still fail with initialization timeout in some
runtime states.

## Fast Triage

1. Run local preflight:
```bash
./scripts/doctor
```

2. Verify ACPX install:
```bash
command -v acpx
acpx --version
```

3. Optional ACPX sanity probe (bounded):
```bash
timeout 120s acpx --cwd "$PWD" --approve-all --non-interactive-permissions fail --format text --timeout 90 codex exec "Reply with READY only."
```

Stable unattended pattern (preferred for automation):
```bash
acpx --cwd "$PWD" --approve-all --non-interactive-permissions fail --format quiet codex sessions ensure --name "ca-codex-$(basename "$PWD")"
acpx --cwd "$PWD" --approve-all --non-interactive-permissions fail --format quiet codex -s "ca-codex-$(basename "$PWD")" "Reply with READY only."
```

Wrapper note:
- `scripts/lib/acpx-wrapper.sh` treats ACPX globals as wrapper-owned. Do not
  forward `--timeout` (or other ACPX globals) through agent subcommand args.
- Use `ACPX_RUN_TIMEOUT=<seconds>` to bound wrapper calls instead.

4. Repeatable local smoke check from this repo:
```bash
./scripts/acp-smoke-local.sh
```

## Recommended Fallbacks

When ACP observability is degraded, use direct wrapper/CLI review and
implementation flows in this repo:

```bash
# Plan review wrappers
./scripts/plan-review --repo /path/to/repo
./scripts/plan-review-live --repo /path/to/repo

# PR/code review (primary)
timeout 600s codex review --base <base> --title "PR #N Review"

# Wrapper fallback chain
./scripts/safe-fallback.sh review "Review PR #N"
./scripts/safe-fallback.sh impl "Implement approved plan"
```

## Important Boundary

- This mitigation doc is a repo-side operational workaround.
- Root runtime fixes are tracked upstream and will be specified separately.
