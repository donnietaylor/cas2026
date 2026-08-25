/**
 * MCP for Everything – Demo Server
 * Cloud and AI Summit 2026
 *
 * Demonstrates exposing multiple data sources via the Model Context Protocol:
 *   - SQLite database
 *   - REST API (weather)
 *   - CSV flat file
 *   - Legacy CLI tool
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import Database from "better-sqlite3";
import { parse as parseCsv } from "csv-parse/sync";
import { readFileSync, existsSync } from "fs";
import { execSync } from "child_process";

// ---------------------------------------------------------------------------
// Server setup
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "mcp-for-everything",
  version: "1.0.0",
});

// ---------------------------------------------------------------------------
// Tool: greet (Hello MCP – Demo 1)
// ---------------------------------------------------------------------------

server.tool("greet", { name: z.string().describe("Your name") }, async ({ name }) => ({
  content: [{ type: "text", text: `Hello, ${name}! Welcome to MCP.` }],
}));

// ---------------------------------------------------------------------------
// Tool: query_products (Database – Demo 2)
// ---------------------------------------------------------------------------

const DB_PATH = new URL("../data/demo.db", import.meta.url).pathname;

if (existsSync(DB_PATH)) {
  const db = new Database(DB_PATH);

  server.tool(
    "query_products",
    {
      category: z.string().optional().describe("Filter by product category"),
      max_price: z.number().optional().describe("Maximum price filter"),
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
}

// ---------------------------------------------------------------------------
// Tool: get_weather (REST API – Demo 3)
// ---------------------------------------------------------------------------

server.tool(
  "get_weather",
  {
    latitude: z.number().describe("Latitude of the location"),
    longitude: z.number().describe("Longitude of the location"),
  },
  async ({ latitude, longitude }) => {
    const url =
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${latitude}&longitude=${longitude}` +
      `&current=temperature_2m,wind_speed_10m`;
    const response = await fetch(url);
    const data = await response.json();
    return { content: [{ type: "text", text: JSON.stringify(data.current, null, 2) }] };
  }
);

// ---------------------------------------------------------------------------
// Tool: get_inventory (Flat files – Demo 4)
// ---------------------------------------------------------------------------

const CSV_PATH = new URL("../data/inventory.csv", import.meta.url).pathname;

if (existsSync(CSV_PATH)) {
  server.tool(
    "get_inventory",
    { sku: z.string().optional().describe("Filter by SKU") },
    async ({ sku }) => {
      const raw = readFileSync(CSV_PATH, "utf8");
      let rows = parseCsv(raw, { columns: true });
      if (sku) rows = rows.filter((r) => r.sku === sku);
      return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
    }
  );
}

// ---------------------------------------------------------------------------
// Tool: get_legacy_report (Legacy CLI – Demo 5)
// ---------------------------------------------------------------------------

const LEGACY_SCRIPT = new URL("../legacy/report.sh", import.meta.url).pathname;

if (existsSync(LEGACY_SCRIPT)) {
  server.tool("get_legacy_report", {}, async () => {
    const output = execSync(`bash "${LEGACY_SCRIPT}"`).toString();
    return { content: [{ type: "text", text: output }] };
  });
}

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
