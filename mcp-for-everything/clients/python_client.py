"""
Demo 6: the same MCP server, driven from plain Python instead of an editor.

    python clients/python_client.py
"""

import asyncio

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

URL = "http://localhost:8931/mcp"


async def main() -> None:
    async with streamablehttp_client(URL) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()

            tools = await session.list_tools()
            print(f"{len(tools.tools)} tools available:\n")
            for tool in tools.tools:
                access = "read-only" if tool.annotations.readOnlyHint else "CHANGES STATE"
                print(f"  {tool.name:<28} {access}")

            print("\nCalling Read-LegacyReport (HELD orders only):\n")
            result = await session.call_tool("Read-LegacyReport", {"Status": "HELD"})
            print(result.content[0].text)


if __name__ == "__main__":
    asyncio.run(main())
