# Demo 2 – Exposing a Database

This demo shows how to expose a SQLite database as MCP tools so AI agents can query it directly.

## Steps

### 1. Set up the database

```bash
sqlite3 demo.db < schema.sql
```

`schema.sql`:
```sql
CREATE TABLE products (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT,
  price REAL
);

INSERT INTO products VALUES
  (1, 'Widget A', 'Widgets', 9.99),
  (2, 'Gadget B', 'Gadgets', 24.99),
  (3, 'Widget C', 'Widgets', 14.99);
```

### 2. Add database tools to the MCP server

```js
import Database from "better-sqlite3";

const db = new Database("demo.db");

server.tool(
  "query_products",
  {
    category: z.string().optional(),
    max_price: z.number().optional(),
  },
  async ({ category, max_price }) => {
    let sql = "SELECT * FROM products WHERE 1=1";
    const params = [];
    if (category) { sql += " AND category = ?"; params.push(category); }
    if (max_price !== undefined) { sql += " AND price <= ?"; params.push(max_price); }
    const rows = db.prepare(sql).all(...params);
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }
);
```

### 3. Try it out

Ask the agent: **"Show me all widgets under $12"**
