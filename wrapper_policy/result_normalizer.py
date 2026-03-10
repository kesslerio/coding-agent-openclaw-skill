"""Structured result shapers for migrated wrappers."""

from __future__ import annotations

from typing import Any

from wrapper_policy.errors import error, success


def normalize_result(payload: dict[str, Any]) -> dict[str, object]:
    kind = payload["kind"]

    if kind == "safe-fallback-success":
        return success(
            {
                "mode": payload["mode"],
                "backend": payload["backend"],
                "state": payload["state"],
                "backend_response": payload.get("backend_response"),
            }
        )

    if kind == "safe-fallback-blocker":
        cause_class = payload.get("cause_class", "unknown_backend_failure")
        return error(
            "ALL_BACKENDS_UNAVAILABLE",
            f"All execution backends failed for mode '{payload['mode']}'.",
            context={"mode": payload["mode"]},
            remediation=[
                "Wait for tool availability or install the required CLI tools.",
                "Inspect the recorded failures and retry with a healthier backend.",
            ],
            data={
                "failures": payload.get("failures", []),
                "cause_class": cause_class,
            },
        )

    if kind == "code-implement-dry-run":
        return success(
            {
                "state": "validated",
                "backend": "codex_tmux",
                "repo_path": payload["repo_path"],
                "plan_path": payload.get("plan_path"),
                "plan_id": payload.get("plan_id"),
                "plan_status": payload.get("plan_status"),
                "output_mode": payload["output_mode"],
                "review_gate": payload["review_gate"],
                "dry_run": True,
            }
        )

    if kind == "code-implement-launch":
        return success(
            {
                "state": "launched_not_verified",
                "backend": "codex_tmux",
                "repo_path": payload["repo_path"],
                "plan_path": payload.get("plan_path"),
                "plan_id": payload.get("plan_id"),
                "transport": payload["transport"],
            }
        )

    raise ValueError(f"Unsupported normalization kind: {kind}")

