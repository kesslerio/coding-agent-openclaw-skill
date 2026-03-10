"""CLI entrypoint for shell wrappers using Python policy helpers."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from wrapper_policy.approval_transition import resolve_interactive_response
from wrapper_policy.plan_gate import resolve_plan_gate
from wrapper_policy.result_normalizer import normalize_result
from wrapper_policy.review_base import resolve_review_base


def _read_stdin_json() -> dict[str, Any]:
    raw = sys.stdin.read()
    return json.loads(raw) if raw.strip() else {}


def _emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, separators=(",", ":")))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="wrapper-policy")
    subparsers = parser.add_subparsers(dest="command", required=True)

    review_base = subparsers.add_parser("review-base")
    review_base.add_argument("--cwd", required=True)
    review_base.add_argument("--format", choices=("json", "raw"), default="json")

    subparsers.add_parser("plan-gate")
    subparsers.add_parser("approval-transition")
    subparsers.add_parser("normalize-result")

    args = parser.parse_args(argv)

    if args.command == "review-base":
        payload = resolve_review_base(args.cwd)
        if args.format == "raw":
            print(payload["data"]["base_branch"])
            return 0
        return _emit(payload)
    if args.command == "plan-gate":
        return _emit(resolve_plan_gate(_read_stdin_json()))
    if args.command == "approval-transition":
        payload = _read_stdin_json()
        return _emit(
            resolve_interactive_response(
                repo_path=payload["repo_path"],
                plan_path=payload["plan_path"],
                plan_id=payload["plan_id"],
                plan_status=payload["plan_status"],
                approval_response=payload["approval_response"],
            )
        )
    if args.command == "normalize-result":
        return _emit(normalize_result(_read_stdin_json()))

    parser.error("unsupported command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
