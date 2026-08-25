"""
Tool registry: asks PowerShell what tools exist, and re-asks when they change.

The Python here never knows the name of a single tool at author time. Drop a
.ps1 in powershell/tools and it appears; delete it and it is gone. That is the
whole point of the session - the schema lives with the script.
"""

from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from settings import settings

log = logging.getLogger("mcp.registry")


@dataclass
class ToolSpec:
    name: str
    description: str
    script_path: Path
    input_schema: dict[str, Any]
    read_only: bool
    destructive: bool
    verb: str

    @property
    def is_write(self) -> bool:
        return not self.read_only


class Registry:
    def __init__(self) -> None:
        self._tools: dict[str, ToolSpec] = {}
        self._problems: list[dict[str, str]] = []
        self._fingerprint: tuple | None = None
        self._lock = asyncio.Lock()

    # -- change detection ---------------------------------------------------

    def _scan_fingerprint(self) -> tuple:
        """Cheap signature of the tools folder: (name, mtime, size) for each file."""
        if not settings.tools_dir.exists():
            return ()
        return tuple(
            sorted(
                (p.name, p.stat().st_mtime_ns, p.stat().st_size)
                for p in settings.tools_dir.glob("*.ps1")
                if not p.name.startswith("_")
            )
        )

    # -- loading ------------------------------------------------------------

    async def _generate_manifest(self) -> dict[str, Any]:
        argv = [
            settings.pwsh,
            "-NoProfile",
            "-NonInteractive",
            "-NoLogo",
            "-ExecutionPolicy", "Bypass",
            "-File", str(settings.manifest_script),
            "-ToolPath", str(settings.tools_dir),
        ]
        proc = await asyncio.create_subprocess_exec(
            *argv,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(settings.powershell_root),
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)

        if proc.returncode != 0:
            raise RuntimeError(
                "Get-ToolManifest.ps1 failed:\n"
                + stderr.decode("utf-8", errors="replace")[:4000]
            )

        text = stdout.decode("utf-8", errors="replace").strip()
        if not text:
            raise RuntimeError("Get-ToolManifest.ps1 produced no output.")
        return json.loads(text)

    async def refresh(self, force: bool = False) -> None:
        async with self._lock:
            fingerprint = self._scan_fingerprint()
            if not force and fingerprint == self._fingerprint and self._tools:
                return

            manifest = await self._generate_manifest()

            tools: dict[str, ToolSpec] = {}
            for entry in manifest.get("tools", []):
                spec = ToolSpec(
                    name=entry["name"],
                    description=entry.get("description", ""),
                    script_path=Path(entry["scriptPath"]),
                    input_schema=entry.get("inputSchema") or {"type": "object", "properties": {}},
                    read_only=bool(entry.get("readOnly", False)),
                    destructive=bool(entry.get("destructive", False)),
                    verb=entry.get("verb", ""),
                )
                tools[spec.name] = spec

            self._tools = tools
            self._problems = manifest.get("problems", []) or []
            self._fingerprint = fingerprint

            log.info("Loaded %d PowerShell tools from %s", len(tools), settings.tools_dir)
            for problem in self._problems:
                # Loud, because a silently-broken tool description is the worst
                # kind of demo failure: everything "works" and nothing is useful.
                log.warning("Tool problem in %s: %s", problem.get("file"), problem.get("error"))

    async def ensure_current(self) -> None:
        if settings.hot_reload:
            await self.refresh()
        elif not self._tools:
            await self.refresh(force=True)

    # -- access -------------------------------------------------------------

    def all(self) -> list[ToolSpec]:
        return sorted(self._tools.values(), key=lambda t: t.name)

    def get(self, name: str) -> ToolSpec | None:
        return self._tools.get(name)

    @property
    def problems(self) -> list[dict[str, str]]:
        return list(self._problems)


registry = Registry()
