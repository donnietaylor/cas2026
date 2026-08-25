# Demo 5 – Legacy System Integration

This demo shows how to expose a legacy system (simulated as a command-line tool or old SOAP/XML API) through MCP.

## Steps

### 1. Simulate a legacy CLI tool

`legacy/report.sh`:
```bash
#!/bin/bash
# Simulates a legacy reporting tool
echo "REPORT DATE: $(date +%Y-%m-%d)"
echo "TOTAL_ORDERS=482"
echo "OPEN_TICKETS=17"
echo "SLA_BREACHES=3"
```

```bash
chmod +x legacy/report.sh
```

### 2. Wrap it as an MCP tool

```js
import { execSync } from "child_process";

server.tool("get_legacy_report", {}, async () => {
  const output = execSync("bash legacy/report.sh").toString();
  return { content: [{ type: "text", text: output }] };
});
```

### 3. Try it out

Ask the agent: **"How many open tickets do we have today according to the legacy system?"**

### Key Takeaway

If a system produces text output — via CLI, file, or network — you can wrap it in MCP without modifying the legacy system at all.
