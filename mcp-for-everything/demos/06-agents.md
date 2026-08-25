# Demo 6 – Using with VS Code and Agent Frameworks

This demo shows how to connect your MCP server to VS Code Copilot and a Python agent framework.

## VS Code

### 1. Register the server in VS Code settings

`.vscode/mcp.json` (workspace-level):
```json
{
  "servers": {
    "cas2026-demo": {
      "type": "stdio",
      "command": "node",
      "args": ["${workspaceFolder}/mcp-for-everything/src/server.js"]
    }
  }
}
```

### 2. Use tools in Copilot Chat

Open Copilot Chat in **Agent mode** and ask any question that triggers one of your tools.  
Copilot will automatically discover available tools and call them as needed.

## Python Agent Framework (using `mcp` + `openai`)

```python
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    server_params = StdioServerParameters(
        command="node",
        args=["mcp-for-everything/src/server.js"],
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print("Available tools:", [t.name for t in tools.tools])

asyncio.run(main())
```

### Key Takeaway

MCP decouples tool implementation from tool consumption — the same server works with VS Code, Python agents, and any other MCP-compatible client.
