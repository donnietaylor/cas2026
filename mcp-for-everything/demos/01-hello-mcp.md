# Demo 1 – Hello MCP: Your First Server

This demo walks through creating a minimal MCP server with a single tool.

## Steps

### 1. Install the MCP SDK

```bash
npm install @modelcontextprotocol/sdk
```

### 2. Create a basic server

Create `server.js`:

```js
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "hello-mcp",
  version: "1.0.0",
});

server.tool("greet", { name: z.string() }, async ({ name }) => ({
  content: [{ type: "text", text: `Hello, ${name}! Welcome to MCP.` }],
}));

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 3. Run the server

```bash
node server.js
```

### 4. Connect from VS Code

Add the following to your VS Code MCP settings (`settings.json`):

```json
{
  "mcp": {
    "servers": {
      "hello-mcp": {
        "type": "stdio",
        "command": "node",
        "args": ["path/to/server.js"]
      }
    }
  }
}
```

### 5. Try it out

Open GitHub Copilot Chat in VS Code and ask: **"Greet me by name"**

The AI agent will call the `greet` tool on your MCP server.
