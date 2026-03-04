# Theory: Canonical ACPX Invocation as a Reliability Boundary

## Problem

The ACP reliability failures in this repo are mostly contract failures, not
single bugs. The same underlying operation was invoked with different command
shapes across scripts, docs, and operator habits. On ACPX 0.1.15, small flag
placement differences can turn into hard failures or stalled behavior. Issue
#48 captures this as command-shape drift, queue contention, and unattended
permission mismatches.

The remaining concrete failure was in `acp-smoke-local.sh`: it still forwarded
`--timeout` after `codex`, which is interpreted as an invalid agent-subcommand
flag and fails immediately.

## Operating Theory

ACPX automation is reliable only when invocation shape is centralized and
enforced. Any per-script local interpretation of ACPX globals eventually drifts
and reintroduces version-sensitive breakage.

The wrapper layer is therefore the reliability boundary:
- wrapper owns ACPX global flags and non-interactive policy,
- callsites pass only agent/subcommand args,
- tests assert both helper-level guards and real wrapper entrypoint behavior.

If the tests only validate one layer (for example `safe-fallback` but not
`acp-smoke-local`), regressions can survive until runtime.

## Strategy

1. Keep all ACPX global policy in `acpx_run_canonical` and reject forwarded
   globals, including `--timeout`.
2. Keep timeout control in wrapper runtime (`ACPX_RUN_TIMEOUT`) rather than
   scattered ACPX `--timeout` forwarding at callsites.
3. Validate both dimensions in smoke:
   - guard rejection of non-canonical forwarded globals,
   - end-to-end behavior of `acp-smoke-local.sh` under fake ACPX.
4. Keep troubleshooting guidance aligned with wrapper contract so docs and code
   do not diverge.

## Key Discoveries

The branch already had a strong canonicalization pass, but one drifted callsite
remained. This confirms that central helpers alone are not enough; the suite
must explicitly exercise each high-value wrapper entrypoint.

`acp-smoke-local.sh` is a critical canary because it is the first place where
operators verify ACP health. If that script itself violates canonical shape,
it creates false-negative diagnostics and undermines incident response.

## Open Questions

- Should wrapper-level timeout support eventually map to ACPX global `--timeout`
  for parity, or stay purely outer `timeout(1)` bounded for portability?
- Should CI add a dedicated grep/policy gate for forbidden forwarded ACPX
  globals (`--cwd`, `--format`, `--timeout`) outside the wrapper?
