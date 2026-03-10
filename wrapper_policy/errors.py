"""Structured response helpers for wrapper policy commands."""

from __future__ import annotations

from typing import Any


def success(data: dict[str, Any]) -> dict[str, Any]:
    return {"ok": True, "data": data}


def error(
    code: str,
    message: str,
    *,
    context: dict[str, Any] | None = None,
    remediation: list[str] | None = None,
    data: Any = None,
) -> dict[str, Any]:
    return {
        "ok": False,
        "error": {
            "code": code,
            "message": message,
            "context": context or {},
            "remediation": remediation or [],
        },
        "data": data,
    }

