"""
Runs a PowerShell tool in a child process and brings back a structured result.

The entire Python-to-PowerShell contract lives in this file, and it is short on
purpose: arguments go in as JSON on stdin, one JSON envelope comes back on
stdout. No shell, no string concatenation, no quoting rules to get wrong.
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from settings import settings

log = logging.getLogger("mcp.runner")


@dataclass
class ToolResult:
    ok: bool
    tool: str
    result: Any = None
    error: dict[str, Any] | None = None
    warnings: list[str] | None = None
    duration_ms: int = 0
    stderr: str = ""

    def to_payload(self) -> dict[str, Any]:
        """What the model actually sees. Keep it clean and predictable."""
        if self.ok:
            payload: dict[str, Any] = {"ok": True, "result": self.result}
            if self.warnings:
                payload["warnings"] = self.warnings
            return payload
        return {
            "ok": False,
            "error": self.error or {"message": "Unknown failure"},
        }


class ToolExecutionError(RuntimeError):
    pass


def _parse_envelope(stdout_text: str) -> dict[str, Any] | None:
    """
    Parse the JSON envelope, tolerating junk printed ahead of it.

    _invoke.ps1 suppresses the warning and information streams so this should not
    be needed. But "should not be needed" is doing a lot of work in a room with
    four hundred people in it: any module a tool imports can print a banner, and
    one stray line should degrade to a log warning, not fail the tool call.

    Strategy: try the whole string, then fall back to the last balanced {...}.
    """
    try:
        return json.loads(stdout_text)
    except json.JSONDecodeError:
        pass

    start = stdout_text.find("{")
    while start != -1:
        try:
            envelope, _ = json.JSONDecoder().raw_decode(stdout_text[start:])
        except json.JSONDecodeError:
            start = stdout_text.find("{", start + 1)
            continue
        if isinstance(envelope, dict) and "ok" in envelope:
            log.warning(
                "Recovered the tool envelope after %d bytes of stream noise. "
                "Something in the tool is writing to stdout.",
                start,
            )
            return envelope
        start = stdout_text.find("{", start + 1)

    return None


async def run_tool(script_path: Path, arguments: dict[str, Any]) -> ToolResult:
    """Invoke one tool script via _invoke.ps1."""
    payload = json.dumps(arguments or {})

    argv = [
        settings.pwsh,
        "-NoProfile",        # never load the user's profile - it is not reproducible
        "-NonInteractive",   # a prompt in a child process is a hung demo
        "-NoLogo",
        "-ExecutionPolicy", "Bypass",
        "-File", str(settings.invoke_script),
        "-ToolPath", str(script_path),
    ]

    proc = await asyncio.create_subprocess_exec(
        *argv,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=str(settings.powershell_root),
    )

    try:
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(payload.encode("utf-8")),
            timeout=settings.timeout_seconds,
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        return ToolResult(
            ok=False,
            tool=script_path.stem,
            error={
                "message": (
                    f"Tool timed out after {settings.timeout_seconds:g}s and was terminated."
                ),
                "type": "Timeout",
            },
        )

    stderr_text = stderr.decode("utf-8", errors="replace").strip()
    stdout_text = stdout.decode("utf-8", errors="replace").strip()

    if not stdout_text:
        return ToolResult(
            ok=False,
            tool=script_path.stem,
            error={
                "message": "Tool produced no output.",
                "type": "EmptyOutput",
                "stderr": stderr_text[:2000],
            },
            stderr=stderr_text,
        )

    envelope = _parse_envelope(stdout_text)
    if envelope is None:
        return ToolResult(
            ok=False,
            tool=script_path.stem,
            error={
                "message": (
                    "Tool stdout was not valid JSON. A tool must emit objects, not text - "
                    "check for Write-Host in the script."
                ),
                "type": "MalformedOutput",
                "stdout": stdout_text[:2000],
            },
            stderr=stderr_text,
        )

    return ToolResult(
        ok=bool(envelope.get("ok")),
        tool=envelope.get("tool", script_path.stem),
        result=envelope.get("result"),
        error=envelope.get("error"),
        warnings=envelope.get("warnings") or [],
        duration_ms=int(envelope.get("durationMs", 0)),
        stderr=stderr_text,
    )
