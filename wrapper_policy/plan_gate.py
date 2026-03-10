"""Plan-path and review-gate validation for code-implement."""

from __future__ import annotations

from pathlib import Path
import json
import subprocess
from typing import Any

from wrapper_policy.approval_transition import decide_approval_transition
from wrapper_policy.errors import error, success


def _canonicalize_file_path(raw_path: str) -> str:
    return str(Path(raw_path).expanduser().resolve(strict=True))


def _read_frontmatter(plan_path: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    with open(plan_path, "r", encoding="utf-8") as handle:
        lines = handle.read().splitlines()

    if not lines or lines[0] != "---":
        return fields

    for line in lines[1:]:
        if line == "---":
            break
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip()] = value.strip()
    return fields


def _repo_from_plan_path(plan_path: str) -> str | None:
    marker = f"{Path('/').as_posix()}.ai/plans/"
    normalized = plan_path.replace("\\", "/")
    if marker not in normalized:
        return None
    return normalized.rsplit(marker, 1)[0] or None


def _is_git_repo(path: str) -> bool:
    result = subprocess.run(
        ["git", "-C", path, "rev-parse", "--git-dir"],
        check=False,
        text=True,
        capture_output=True,
    )
    return result.returncode == 0


def _plan_context(repo_path: str, plan_path: str, plan_id: str, plan_status: str) -> dict[str, str]:
    return {
        "repo_path": repo_path,
        "plan_path": plan_path,
        "plan_id": plan_id,
        "plan_status": plan_status,
    }


def _validate_review_metadata(
    *,
    repo_path: str,
    display_repo_path: str,
    plan_path: str,
    canonical_plan_path: str,
    plan_id: str,
) -> dict[str, object]:
    metadata_path = Path(repo_path) / ".ai" / "plan-reviews" / f"latest-{plan_id}.json"
    context = _plan_context(display_repo_path, plan_path, plan_id, "")
    if not metadata_path.is_file():
        return error(
            "REVIEW_GATE_BLOCKED",
            f"Missing review metadata: {metadata_path}",
            context=context,
            remediation=[
                f"./scripts/plan-review-live --plan {plan_path}",
                f"./scripts/plan-review --plan {plan_path}",
                "Use --force only when you explicitly accept bypass risk.",
            ],
        )

    try:
        with metadata_path.open("r", encoding="utf-8") as handle:
            metadata = json.load(handle)
    except json.JSONDecodeError:
        return error(
            "REVIEW_METADATA_INVALID",
            f"Review metadata failed validation: {metadata_path}",
            context=context,
            remediation=["Regenerate the plan review metadata with ./scripts/plan-review or ./scripts/plan-review-live."],
        )

    metadata_plan_path = metadata.get("plan_path", "")
    if isinstance(metadata_plan_path, str) and metadata_plan_path:
        metadata_plan_path = str(Path(metadata_plan_path).expanduser().resolve(strict=False))

    required_shape = (
        metadata.get("schema_version") == 1
        and metadata.get("plan_id") == plan_id
        and metadata_plan_path == canonical_plan_path
        and metadata.get("mode") in {"batch", "live"}
        and isinstance(metadata.get("ready_for_implementation"), bool)
        and isinstance(metadata.get("created_at"), str)
        and metadata.get("created_at")
        and isinstance(metadata.get("review_markdown_path"), str)
        and metadata.get("review_markdown_path")
        and isinstance(metadata.get("blocking_decisions"), list)
    )
    if not required_shape:
        return error(
            "REVIEW_METADATA_INVALID",
            f"Review metadata failed validation: {metadata_path}",
            context=context,
            remediation=["Regenerate the plan review metadata with ./scripts/plan-review or ./scripts/plan-review-live."],
        )

    review_markdown_path = Path(metadata["review_markdown_path"])
    if not review_markdown_path.is_file():
        return error(
            "REVIEW_METADATA_INVALID",
            f"Review markdown target is missing: {review_markdown_path}",
            context=context,
            remediation=["Re-run ./scripts/plan-review or ./scripts/plan-review-live to refresh metadata."],
        )

    if metadata["ready_for_implementation"] is not True:
        return error(
            "REVIEW_GATE_BLOCKED",
            "Latest review is not ready for implementation (ready_for_implementation=false).",
            context=context,
            remediation=[
                f"./scripts/plan-review-live --plan {plan_path}",
                f"./scripts/plan-review --plan {plan_path}",
                "Use --force only when you explicitly accept bypass risk.",
            ],
        )

    blocking_decisions = metadata["blocking_decisions"]
    if blocking_decisions:
        return error(
            "REVIEW_GATE_BLOCKED",
            "Latest review still has unresolved blocking decisions.",
            context=context,
            remediation=[
                f"./scripts/plan-review-live --plan {plan_path}",
                "Resolve blocking decisions before implementation.",
            ],
            data={"blocking_decisions": blocking_decisions},
        )

    return success({"review_gate": "validated"})


def resolve_plan_gate(payload: dict[str, Any]) -> dict[str, object]:
    plan_path_input = str(payload["plan_path"])
    display_plan_path = plan_path_input
    try:
        plan_path = _canonicalize_file_path(plan_path_input)
    except FileNotFoundError:
        return error(
            "PLAN_PATH_INVALID",
            f"Plan file not found: {plan_path_input}",
            remediation=["Pass an existing plan file under the target repository's .ai/plans directory."],
        )

    repo_path = _repo_from_plan_path(plan_path)
    if repo_path is None:
        return error(
            "PLAN_PATH_INVALID",
            "Plan file must live under a repository .ai/plans directory.",
            remediation=["Move or select a plan file from <repo>/.ai/plans/<plan>.md."],
        )
    display_repo_path = _repo_from_plan_path(display_plan_path) or repo_path
    if not Path(repo_path).is_dir():
        return error(
            "PLAN_PATH_INVALID",
            f"Unable to resolve repository root from plan path: {plan_path}",
            remediation=["Use a plan file stored under <repo>/.ai/plans/."],
        )
    if not _is_git_repo(repo_path):
        return error(
            "PLAN_PATH_INVALID",
            f"Resolved plan repository is not a git repository: {repo_path}",
            remediation=["Use a plan file stored inside a git repository under .ai/plans."],
        )

    frontmatter = _read_frontmatter(plan_path)
    plan_status = frontmatter.get("status", "")
    plan_id = frontmatter.get("id") or Path(plan_path).stem
    context = _plan_context(display_repo_path, display_plan_path, plan_id, plan_status)

    repo_from_frontmatter = frontmatter.get("repo_path", "")
    if repo_from_frontmatter:
        repo_path_frontmatter = str(Path(repo_from_frontmatter).expanduser().resolve())
        if not Path(repo_path_frontmatter).is_dir():
            return error(
                "PLAN_PATH_INVALID",
                f"Plan repo_path does not exist or is not a directory: {repo_from_frontmatter}",
                context=context,
                remediation=["Regenerate the plan or update repo_path to the repository that contains the plan artifact."],
            )
        if repo_path_frontmatter != repo_path:
            return error(
                "PLAN_PATH_INVALID",
                "Plan repo_path does not match the repository that contains the plan artifact.",
                context=context,
                remediation=["Regenerate the plan or move it back under the repository named in repo_path."],
            )

    approval_result = decide_approval_transition(
        repo_path=repo_path,
        plan_path=display_plan_path,
        plan_id=plan_id,
        plan_status=plan_status,
        approve_plan=bool(payload.get("approve_plan")),
        require_approved=bool(payload.get("require_approved")),
        non_interactive=bool(payload.get("non_interactive")),
        non_interactive_stdin=bool(payload.get("non_interactive_stdin")),
        dry_run=bool(payload.get("dry_run")),
    )
    if not approval_result["ok"]:
        return approval_result

    approval_data = approval_result["data"]
    if approval_data["action"] in {"approve", "prompt"}:
        return success(
            {
                "repo_path": display_repo_path,
                "plan_path": display_plan_path,
                "plan_id": plan_id,
                "plan_status": plan_status,
                "review_gate": "pending_approval",
                "approval_action": approval_data["action"],
                "approved_at": approval_data["approved_at"],
            }
        )

    review_gate = "bypassed" if bool(payload.get("force")) else "validated"
    if not bool(payload.get("force")):
        metadata_result = _validate_review_metadata(
            repo_path=repo_path,
            display_repo_path=display_repo_path,
            plan_path=display_plan_path,
            canonical_plan_path=plan_path,
            plan_id=plan_id,
        )
        if not metadata_result["ok"]:
            metadata_result["error"]["context"].update(context)
            return metadata_result

    return success(
        {
            "repo_path": display_repo_path,
            "plan_path": display_plan_path,
            "plan_id": plan_id,
            "plan_status": plan_status,
            "review_gate": review_gate,
            "approval_action": approval_data["action"],
            "approved_at": approval_data["approved_at"],
        }
    )
