# Demo 4 – Flat Files as Tools

This demo shows how to expose CSV and JSON files as MCP tools.

## Steps

### 1. Add sample data files

`data/inventory.csv`:
```
id,sku,name,quantity
1,WGT-001,Widget A,150
2,GDG-001,Gadget B,42
3,WGT-002,Widget C,88
```

### 2. Add a CSV tool

```js
import { parse } from "csv-parse/sync";
import { readFileSync } from "fs";

server.tool("get_inventory", { sku: z.string().optional() }, async ({ sku }) => {
  const raw = readFileSync("data/inventory.csv", "utf8");
  let rows = parse(raw, { columns: true });
  if (sku) rows = rows.filter((r) => r.sku === sku);
  return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
});
```

### 3. Add a JSON tool

`data/config.json`:
```json
{ "warehouse": "Austin", "reorder_threshold": 50 }
```

```js
server.tool("get_config", {}, async () => {
  const data = JSON.parse(readFileSync("data/config.json", "utf8"));
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
});
```

### 4. Try it out

Ask the agent: **"Which items are below the reorder threshold?"**
