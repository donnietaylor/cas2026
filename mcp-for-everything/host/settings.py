"""
Configuration for the MCP host.

Everything is environment-driven so the same host can be pointed at a different
folder of PowerShell without editing Python. Copy .env.example to .env.
"""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent


def _bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _csv(name: str) -> list[str]:
    raw = os.environ.get(name, "").strip()
    return [item.strip() for item in raw.split(",") if item.strip()]


def _find_pwsh() -> str:
    """Locate PowerShell 7. Not powershell.exe - that is Windows PowerShell 5.1."""
    explicit = os.environ.get("PWSH_PATH")
    if explicit:
        return explicit
    found = shutil.which("pwsh")
    if found:
        return found
    # Common Windows install location when PATH has not been refreshed.
    fallback = Path(r"C:\Program Files\PowerShell\7\pwsh.exe")
    if fallback.exists():
        return str(fallback)
    raise RuntimeError(
        "PowerShell 7 not found. Install it (winget install Microsoft.PowerShell) "
        "or set PWSH_PATH to the full path of pwsh.exe."
    )


@dataclass(frozen=True)
class Settings:
    pwsh: str = field(default_factory=_find_pwsh)

    powershell_root: Path = field(
        default_factory=lambda: Path(
            os.environ.get("POWERSHELL_ROOT", REPO / "powershell")
        ).resolve()
    )

    # How long a single tool may run before we kill the process. A demo that
    # hangs is worse than a demo that fails, because a failure you can explain.
    timeout_seconds: float = field(
        default_factory=lambda: float(os.environ.get("TOOL_TIMEOUT_SECONDS", "45"))
    )

    # Re-scan the tools folder when a file changes, so you can add a tool live
    # on stage without restarting anything.
    hot_reload: bool = field(default_factory=lambda: _bool("HOT_RELOAD", True))

    # Safety rails. By default the host exposes read-only tools only; a
    # state-changing tool must be named explicitly. See docs/security.md.
    allow_write_tools: bool = field(
        default_factory=lambda: _bool("ALLOW_WRITE_TOOLS", False)
    )
    write_tool_allowlist: list[str] = field(default_factory=lambda: _csv("WRITE_TOOL_ALLOWLIST"))

    # Every tool call is appended here as JSONL. Non-negotiable: if an agent can
    # run commands on your estate, you want the receipts.
    audit_log: Path = field(
        default_factory=lambda: Path(
            os.environ.get("AUDIT_LOG", REPO / "logs" / "audit.jsonl")
        ).resolve()
    )

    # Optional bearer token for the HTTP endpoint. Off by default for localhost
    # demos; turn it on before this is reachable by anything else.
    bearer_token: str = field(default_factory=lambda: os.environ.get("MCP_BEARER_TOKEN", ""))

    host: str = field(default_factory=lambda: os.environ.get("HOST", "127.0.0.1"))
    port: int = field(default_factory=lambda: int(os.environ.get("PORT", "8931")))

    @property
    def manifest_script(self) -> Path:
        return self.powershell_root / "Get-ToolManifest.ps1"

    @property
    def invoke_script(self) -> Path:
        return self.powershell_root / "_invoke.ps1"

    @property
    def tools_dir(self) -> Path:
        return self.powershell_root / "tools"


settings = Settings()
