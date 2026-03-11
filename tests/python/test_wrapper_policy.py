from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from wrapper_policy.approval_transition import decide_approval_transition, resolve_interactive_response
from wrapper_policy.plan_gate import resolve_plan_gate
from wrapper_policy.result_normalizer import normalize_result
from wrapper_policy.review_base import GitState, select_review_base


class ReviewBaseTests(unittest.TestCase):
    def test_uses_origin_head_when_available(self) -> None:
        state = GitState(True, "feature", "main", ["feature", "main", "master"])
        self.assertEqual(select_review_base(state), "main")

    def test_prefers_current_main(self) -> None:
        state = GitState(True, "main", None, ["main", "master"])
        self.assertEqual(select_review_base(state), "main")

    def test_prefers_master_when_main_missing(self) -> None:
        state = GitState(True, "feature", None, ["feature", "master"])
        self.assertEqual(select_review_base(state), "master")

    def test_prefers_other_standard_branch_when_current_not_standard(self) -> None:
        state = GitState(True, "feature", None, ["feature", "main", "master"])
        self.assertEqual(select_review_base(state), "main")

    def test_uses_first_other_ref_when_detached(self) -> None:
        state = GitState(True, None, None, ["topic"])
        self.assertEqual(select_review_base(state), "topic")

    def test_defaults_to_main_outside_repo(self) -> None:
        state = GitState(False, None, None, [])
        self.assertEqual(select_review_base(state), "main")


class ApprovalTransitionTests(unittest.TestCase):
    def test_non_interactive_pending_requires_approval(self) -> None:
        result = decide_approval_transition(
            repo_path="/tmp/repo",
            plan_path="/tmp/repo/.ai/plans/plan.md",
            plan_id="plan",
            plan_status="PENDING",
            approve_plan=False,
            require_approved=False,
            non_interactive=True,
            non_interactive_stdin=False,
            dry_run=False,
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["code"], "APPROVAL_REQUIRED")

    def test_require_approved_pending_fails(self) -> None:
        result = decide_approval_transition(
            repo_path="/tmp/repo",
            plan_path="/tmp/repo/.ai/plans/plan.md",
            plan_id="plan",
            plan_status="PENDING",
            approve_plan=False,
            require_approved=True,
            non_interactive=False,
            non_interactive_stdin=False,
            dry_run=False,
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["code"], "APPROVAL_REQUIRED")

    def test_approve_returns_explicit_action(self) -> None:
        result = decide_approval_transition(
            repo_path="/tmp/repo",
            plan_path="/tmp/repo/.ai/plans/plan.md",
            plan_id="plan",
            plan_status="PENDING",
            approve_plan=True,
            require_approved=False,
            non_interactive=True,
            non_interactive_stdin=True,
            dry_run=False,
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["action"], "approve")
        self.assertTrue(result["data"]["approved_at"])

    def test_approved_is_noop(self) -> None:
        result = decide_approval_transition(
            repo_path="/tmp/repo",
            plan_path="/tmp/repo/.ai/plans/plan.md",
            plan_id="plan",
            plan_status="APPROVED",
            approve_plan=False,
            require_approved=False,
            non_interactive=True,
            non_interactive_stdin=True,
            dry_run=False,
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["action"], "none")

    def test_interactive_revise_declines(self) -> None:
        result = resolve_interactive_response(
            repo_path="/tmp/repo",
            plan_path="/tmp/repo/.ai/plans/plan.md",
            plan_id="plan",
            plan_status="PENDING",
            approval_response="revise",
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["code"], "APPROVAL_DECLINED")


class PlanGateTests(unittest.TestCase):
    def _init_repo(self, repo: Path) -> None:
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.name", "Smoke"], check=True)
        subprocess.run(["git", "-C", str(repo), "config", "user.email", "smoke@example.test"], check=True)
        (repo / "README.md").write_text("hi\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "README.md"], check=True)
        subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "init"], check=True)

    def _write_plan(self, repo: Path, relative_dir: str, plan_id: str, status: str = "APPROVED", repo_path: str | None = None) -> Path:
        plan_dir = repo / ".ai" / "plans" / relative_dir
        plan_dir.mkdir(parents=True, exist_ok=True)
        plan_path = plan_dir / f"{plan_id}.md"
        plan_path.write_text(
            "\n".join(
                [
                    "---",
                    f"id: {plan_id}",
                    f"status: {status}",
                    f"repo_path: {repo_path or repo}",
                    "approved_by: ",
                    "approved_at: ",
                    "---",
                    "",
                    "# Plan",
                ]
            ),
            encoding="utf-8",
        )
        return plan_path

    def _write_metadata(
        self,
        repo: Path,
        plan_id: str,
        plan_path: Path,
        ready: bool = True,
        blocking: list[str] | None = None,
        mode: str = "live",
    ) -> None:
        review_dir = repo / ".ai" / "plan-reviews"
        review_dir.mkdir(parents=True, exist_ok=True)
        review_path = review_dir / "review.md"
        review_path.write_text("review\n", encoding="utf-8")
        metadata = {
            "schema_version": 1,
            "plan_id": plan_id,
            "plan_path": str(plan_path),
            "mode": mode,
            "ready_for_implementation": ready,
            "created_at": "2026-03-10T00:00:00Z",
            "review_markdown_path": str(review_path),
            "blocking_decisions": blocking or [],
        }
        (review_dir / f"latest-{plan_id}.json").write_text(json.dumps(metadata), encoding="utf-8")

    def test_invalid_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            result = resolve_plan_gate({"plan_path": str(repo / "missing.md")})
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"]["code"], "PLAN_PATH_INVALID")

    def test_nested_plan_artifact_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._init_repo(repo)
            plan_id = "nested"
            plan_path = self._write_plan(repo, "team", plan_id)
            self._write_metadata(repo, plan_id, plan_path)
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertTrue(result["ok"])
            self.assertEqual(result["data"]["repo_path"], str(repo))
            self.assertEqual(result["data"]["plan_path"], str(plan_path))

    def test_repo_resolution_uses_rightmost_plans_segment(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir) / ".ai" / "plans" / "repo"
            repo.mkdir(parents=True)
            self._init_repo(repo)
            plan_id = "rightmost"
            plan_path = self._write_plan(repo, "", plan_id)
            self._write_metadata(repo, plan_id, plan_path)
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertTrue(result["ok"])
            self.assertEqual(result["data"]["repo_path"], str(repo))

    def test_repo_path_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir) / "repo"
            repo.mkdir()
            self._init_repo(repo)
            plan_id = "mismatch"
            plan_path = self._write_plan(repo, "", plan_id, repo_path=str(repo / "other"))
            self._write_metadata(repo, plan_id, plan_path)
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"]["code"], "PLAN_PATH_INVALID")

    def test_malformed_metadata_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._init_repo(repo)
            plan_id = "bad-metadata"
            plan_path = self._write_plan(repo, "", plan_id)
            review_dir = repo / ".ai" / "plan-reviews"
            review_dir.mkdir(parents=True, exist_ok=True)
            (review_dir / f"latest-{plan_id}.json").write_text('{"schema_version": 1,', encoding="utf-8")
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"]["code"], "REVIEW_METADATA_INVALID")

    def test_blocking_decisions_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._init_repo(repo)
            plan_id = "blocked"
            plan_path = self._write_plan(repo, "", plan_id)
            self._write_metadata(repo, plan_id, plan_path, mode="live", blocking=["2B unresolved"])
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"]["code"], "REVIEW_GATE_BLOCKED")

    def test_batch_review_requires_interactive_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._init_repo(repo)
            plan_id = "batch-blocked"
            plan_path = self._write_plan(repo, "", plan_id)
            self._write_metadata(
                repo,
                plan_id,
                plan_path,
                mode="batch",
                ready=False,
                blocking=[
                    "Interactive resolution required: batch plan-review cannot finalize implementation readiness without explicit decision input."
                ],
            )
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertFalse(result["ok"])
            self.assertEqual(result["error"]["code"], "REVIEW_REQUIRES_INTERACTIVE_RESOLUTION")

    def test_ready_metadata_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            repo = Path(temp_dir)
            self._init_repo(repo)
            plan_id = "ready"
            plan_path = self._write_plan(repo, "", plan_id)
            self._write_metadata(repo, plan_id, plan_path)
            result = resolve_plan_gate({"plan_path": str(plan_path), "dry_run": True})
            self.assertTrue(result["ok"])
            self.assertEqual(result["data"]["review_gate"], "validated")


class ResultNormalizerTests(unittest.TestCase):
    def test_validated_state(self) -> None:
        result = normalize_result(
            {
                "kind": "code-implement-dry-run",
                "repo_path": "/tmp/repo",
                "plan_path": "/tmp/repo/.ai/plans/plan.md",
                "plan_id": "plan",
                "plan_status": "APPROVED",
                "output_mode": "json",
                "review_gate": "validated",
            }
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["state"], "validated")

    def test_launched_not_verified_state(self) -> None:
        result = normalize_result(
            {
                "kind": "code-implement-launch",
                "repo_path": "/tmp/repo",
                "plan_path": "/tmp/repo/.ai/plans/plan.md",
                "plan_id": "plan",
                "transport": {"session": "abc"},
            }
        )
        self.assertTrue(result["ok"])
        self.assertEqual(result["data"]["state"], "launched_not_verified")

    def test_blocker_is_normalized(self) -> None:
        result = normalize_result(
            {
                "kind": "safe-fallback-blocker",
                "mode": "review",
                "failures": ["codex_review: command failed"],
                "cause_class": "redacted_backend_failure",
            }
        )
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["code"], "ALL_BACKENDS_UNAVAILABLE")
        self.assertEqual(result["data"]["cause_class"], "redacted_backend_failure")

    def test_unsupported_kind_raises(self) -> None:
        with self.assertRaises(ValueError):
            normalize_result({"kind": "invalid"})


if __name__ == "__main__":
    unittest.main()
