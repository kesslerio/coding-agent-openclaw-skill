"""Review-base resolution for wrapper shells."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import subprocess

from wrapper_policy.errors import success


@dataclass(frozen=True)
class GitState:
    inside_repo: bool
    current_branch: str | None
    remote_head: str | None
    ordered_refs: list[str]


def _run_git(cwd: str, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=False,
        text=True,
        capture_output=True,
    )


def collect_git_state(cwd: str) -> GitState:
    repo_path = str(Path(cwd).resolve())
    git_dir = _run_git(repo_path, "rev-parse", "--git-dir")
    if git_dir.returncode != 0:
        return GitState(
            inside_repo=False,
            current_branch=None,
            remote_head=None,
            ordered_refs=[],
        )

    current_branch_raw = _run_git(repo_path, "rev-parse", "--abbrev-ref", "HEAD")
    current_branch = current_branch_raw.stdout.strip() if current_branch_raw.returncode == 0 else ""
    if current_branch == "HEAD":
        current_branch = ""

    remote_head_raw = _run_git(repo_path, "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD")
    remote_head = remote_head_raw.stdout.strip() if remote_head_raw.returncode == 0 else ""
    if remote_head.startswith("refs/remotes/origin/"):
        remote_head = remote_head.removeprefix("refs/remotes/origin/")

    refs_raw = _run_git(
        repo_path,
        "for-each-ref",
        "--format=%(refname:short)",
        "refs/heads",
        "refs/remotes/origin",
    )
    ordered_refs: list[str] = []
    seen: set[str] = set()
    if refs_raw.returncode == 0:
        for line in refs_raw.stdout.splitlines():
            ref = line.strip()
            if not ref or ref == "origin/HEAD":
                continue
            if ref.startswith("origin/"):
                ref = ref.removeprefix("origin/")
            if ref not in seen:
                ordered_refs.append(ref)
                seen.add(ref)

    return GitState(
        inside_repo=True,
        current_branch=current_branch or None,
        remote_head=remote_head or None,
        ordered_refs=ordered_refs,
    )


def select_review_base(state: GitState) -> str:
    if not state.inside_repo:
        return "main"

    if state.remote_head and state.remote_head != state.current_branch:
        return state.remote_head

    for candidate in ("main", "master", "trunk"):
        if candidate in state.ordered_refs and candidate == state.current_branch:
            return candidate

    for candidate in ("main", "master", "trunk"):
        if candidate in state.ordered_refs and candidate != state.current_branch:
            return candidate

    for candidate in state.ordered_refs:
        if candidate != state.current_branch:
            return candidate

    if state.current_branch:
        return state.current_branch

    return "main"


def resolve_review_base(cwd: str) -> dict[str, object]:
    state = collect_git_state(cwd)
    return success({"base_branch": select_review_base(state)})

