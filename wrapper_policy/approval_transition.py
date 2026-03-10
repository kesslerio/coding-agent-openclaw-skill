"""Approval state decisions for code-implement."""

from __future__ import annotations

from datetime import datetime

from wrapper_policy.errors import error, success


def _approved_at_now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def _plan_context(
    repo_path: str,
    plan_path: str,
    plan_id: str,
    plan_status: str,
) -> dict[str, str]:
    return {
        "repo_path": repo_path,
        "plan_path": plan_path,
        "plan_id": plan_id,
        "plan_status": plan_status,
    }


def decide_approval_transition(
    *,
    repo_path: str,
    plan_path: str,
    plan_id: str,
    plan_status: str,
    approve_plan: bool,
    require_approved: bool,
    non_interactive: bool,
    non_interactive_stdin: bool,
    dry_run: bool,
) -> dict[str, object]:
    context = _plan_context(repo_path, plan_path, plan_id, plan_status)

    if plan_status == "APPROVED":
        return success({"action": "none", "approved_at": None})

    if dry_run:
        if require_approved:
            return error(
                "APPROVAL_REQUIRED",
                "Plan status must already be APPROVED.",
                context=context,
                remediation=["Approve the plan in advance or rerun without --require-approved."],
            )
        if non_interactive or non_interactive_stdin:
            return error(
                "APPROVAL_REQUIRED",
                "Plan approval is required in non-interactive mode.",
                context=context,
                remediation=["Approve the plan in advance before using --dry-run in non-interactive mode."],
            )
        return success({"action": "none", "approved_at": None})

    if approve_plan:
        return success({"action": "approve", "approved_at": _approved_at_now()})

    if require_approved:
        return error(
            "APPROVAL_REQUIRED",
            "Plan status must already be APPROVED.",
            context=context,
            remediation=["Approve the plan in advance or rerun with --approve."],
        )

    if non_interactive_stdin:
        return error(
            "APPROVAL_REQUIRED",
            f"Plan {plan_id} is {plan_status or 'PENDING'} and code-implement is running without interactive stdin.",
            context=context,
            remediation=[
                "Resolve plan decisions before implementation or approve the plan explicitly.",
                f"./scripts/plan-review-live --plan {plan_path} --decisions \"1A,2B,3A,4A\" --blocking none",
                f"./scripts/plan-review-live --plan {plan_path} --resolve-file /path/to/decisions.json",
                f"./scripts/code-implement --plan {plan_path} --approve --non-interactive",
            ],
        )

    if non_interactive:
        return error(
            "APPROVAL_REQUIRED",
            "Plan approval is required in non-interactive mode.",
            context=context,
            remediation=[
                f"./scripts/plan-review-live --plan {plan_path} --decisions \"1A,2B,3A,4A\" --blocking none",
                f"./scripts/plan-review-live --plan {plan_path} --resolve-file /path/to/decisions.json",
                "Approve the plan in advance or rerun with --approve.",
            ],
        )

    return success({"action": "prompt", "approved_at": None})


def resolve_interactive_response(
    *,
    repo_path: str,
    plan_path: str,
    plan_id: str,
    plan_status: str,
    approval_response: str,
) -> dict[str, object]:
    context = _plan_context(repo_path, plan_path, plan_id, plan_status)
    normalized = approval_response.strip().lower()

    if normalized in {"y", "yes"}:
        return success({"action": "approve", "approved_at": _approved_at_now()})

    if normalized == "revise":
        return error(
            "APPROVAL_DECLINED",
            "Plan left unchanged for revision.",
            context=context,
            remediation=["Revise the plan, then rerun code-implement."],
        )

    return error(
        "APPROVAL_DECLINED",
        "Execution cancelled.",
        context=context,
        remediation=["Approve the plan when you are ready to execute it."],
    )

