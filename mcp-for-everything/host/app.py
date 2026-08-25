"""
MCP for Everything - the host.

FastAPI + uvicorn in front, PowerShell 7 behind. Roughly 150 lines of Python
that you write once and then never touch again; from that point on, adding a
capability means writing a .ps1 file.

Run:
    uvicorn app:app --reload --port 8931

Endpoints:
    /mcp      Streamable HTTP MCP endpoint (point VS Code / Claude here)
    /         Human-readable tool browser - useful on a projector
    /healthz  Liveness + tool count + any manifest problems
"""

from __future__ import annotations

import contextlib
import logging
from typing import Any

import mcp.types as types
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from mcp.server.lowlevel import Server
from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
from starlette.routing import Mount

from registry import registry
from runner import run_tool
from security import ToolDenied, audit, enforce, fence_output, is_allowed
from settings import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s %(name)s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("mcp.host")

mcp_server: Server = Server("mcp-for-everything")


# ---------------------------------------------------------------------------
# MCP handlers - both are fully dynamic; no tool is named in this file
# ---------------------------------------------------------------------------


@mcp_server.list_tools()
async def list_tools() -> list[types.Tool]:
    await registry.ensure_current()

    tools: list[types.Tool] = []
    for spec in registry.all():
        # Hide state-changing tools the policy would refuse anyway. Better the
        # model never sees them than calls them and gets a denial.
        allowed, _ = is_allowed(spec)
        if not allowed:
            continue

        tools.append(
            types.Tool(
                name=spec.name,
                description=spec.description,
                inputSchema=spec.input_schema,
                annotations=types.ToolAnnotations(
                    # These come straight from the verb and SupportsShouldProcess.
                    readOnlyHint=spec.read_only,
                    destructiveHint=spec.destructive,
                    idempotentHint=spec.read_only,
                    openWorldHint=True,
                ),
            )
        )
    return tools


@mcp_server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[types.ContentBlock]:
    await registry.ensure_current()

    spec = registry.get(name)
    if spec is None:
        raise ValueError(f"Unknown tool: {name}")

    try:
        enforce(spec)
    except ToolDenied as denial:
        audit(name, arguments, ok=False, error=str(denial))
        raise ValueError(str(denial)) from denial

    log.info("-> %s %s", name, arguments)
    result = await run_tool(spec.script_path, arguments)

    audit(
        name,
        arguments,
        ok=result.ok,
        duration_ms=result.duration_ms,
        error=(result.error or {}).get("message") if not result.ok else None,
    )

    if result.stderr:
        log.warning("%s stderr: %s", name, result.stderr[:500])

    log.info("<- %s ok=%s in %dms", name, result.ok, result.duration_ms)

    return [types.TextContent(type="text", text=fence_output(name, result.to_payload()))]


# ---------------------------------------------------------------------------
# HTTP plumbing
# ---------------------------------------------------------------------------

session_manager = StreamableHTTPSessionManager(app=mcp_server, json_response=False, stateless=True)


@contextlib.asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        await registry.refresh(force=True)
    except Exception as exc:  # noqa: BLE001 - fail loudly at startup, not mid-demo
        log.error("Could not load the tool manifest at startup: %s", exc)
    async with session_manager.run():
        log.info("MCP endpoint ready on http://%s:%s/mcp", settings.host, settings.port)
        yield


app = FastAPI(title="MCP for Everything", version="1.0.0", lifespan=lifespan)


@app.middleware("http")
async def bearer_auth(request: Request, call_next):
    """Optional shared-secret gate. Off for localhost demos, on for anything else."""
    if settings.bearer_token and request.url.path.startswith("/mcp"):
        supplied = request.headers.get("authorization", "")
        if supplied != f"Bearer {settings.bearer_token}":
            return JSONResponse({"error": "Unauthorized"}, status_code=401)
    return await call_next(request)


@app.get("/healthz")
async def healthz():
    await registry.ensure_current()
    return {
        "status": "ok",
        "pwsh": settings.pwsh,
        "toolsDir": str(settings.tools_dir),
        "toolCount": len(registry.all()),
        "writeToolsEnabled": settings.allow_write_tools,
        "problems": registry.problems,
    }


@app.get("/", response_class=HTMLResponse)
async def tool_browser():
    """A projector-friendly view of what the model can see right now."""
    await registry.ensure_current()

    rows = []
    for spec in registry.all():
        badge = (
            '<span class="ro">read-only</span>'
            if spec.read_only
            else '<span class="rw">changes state</span>'
        )
        params = ", ".join((spec.input_schema.get("properties") or {}).keys()) or "-"
        rows.append(
            f"<tr><td><code>{spec.name}</code></td><td>{spec.description}</td>"
            f"<td><code>{params}</code></td><td>{badge}</td></tr>"
        )

    problems = "".join(
        f"<li><code>{p.get('file')}</code>: {p.get('error')}</li>" for p in registry.problems
    )
    problems_block = f"<h2>Problems</h2><ul>{problems}</ul>" if problems else ""

    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>MCP for Everything</title>
<style>
 body {{ font-family: ui-sans-serif, system-ui, sans-serif; margin: 2rem auto; max-width: 60rem;
        line-height: 1.5; color: #14181f; background: #fbfbfd; }}
 table {{ border-collapse: collapse; width: 100%; }}
 th, td {{ text-align: left; padding: .55rem .7rem; border-bottom: 1px solid #e3e6ec; vertical-align: top; }}
 th {{ font-size: .78rem; text-transform: uppercase; letter-spacing: .05em; color: #5b6472; }}
 code {{ font-family: ui-monospace, monospace; font-size: .88em; }}
 .ro {{ color: #17603a; background: #e4f5eb; padding: .1rem .45rem; border-radius: 999px; font-size: .78rem; }}
 .rw {{ color: #8a2b12; background: #fdeae3; padding: .1rem .45rem; border-radius: 999px; font-size: .78rem; }}
 .meta {{ color: #5b6472; font-size: .9rem; }}
</style></head><body>
<h1>MCP for Everything</h1>
<p class="meta">{len(registry.all())} tools from <code>{settings.tools_dir}</code> &middot;
 PowerShell at <code>{settings.pwsh}</code> &middot;
 write tools {"enabled" if settings.allow_write_tools else "disabled"}</p>
<table><thead><tr><th>Tool</th><th>Description</th><th>Parameters</th><th>Access</th></tr></thead>
<tbody>{"".join(rows)}</tbody></table>
{problems_block}
</body></html>"""


# The MCP endpoint is a raw ASGI app (it speaks its own streaming protocol), so
# it is mounted directly rather than wrapped in a FastAPI route.
app.router.routes.append(Mount("/mcp", app=session_manager.handle_request))


if __name__ == "__main__":
    uvicorn.run(app, host=settings.host, port=settings.port)
