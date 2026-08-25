# MCP for Everything: Turning Any Data Source into an AI-Ready Tool

## Session Overview

Model Context Protocol (MCP) has rapidly become the standard way to make data and systems usable by AI agents and developer tools. In this session, we'll walk through building an MCP server that exposes real-world sources such as databases, APIs, flat files, and even legacy systems. We will show how to query and use them directly from tools like VS Code and agent frameworks. You'll leave knowing how to make almost any system MCP-enabled and ready for modern AI workflows.

## What You'll Learn

- What MCP is and why it matters for AI workflows
- How to build an MCP server from scratch
- Connecting MCP to real-world data sources:
  - Relational databases (SQLite, PostgreSQL)
  - REST APIs
  - Flat files (CSV, JSON)
  - Legacy systems
- Using your MCP server with VS Code and agent frameworks
- Best practices for MCP server design

## Prerequisites

- Node.js 18+ or Python 3.11+
- Basic familiarity with REST APIs
- A code editor (VS Code recommended)

## Getting Started

```bash
cd src
npm install       # or: pip install -r requirements.txt
npm start         # or: python server.py
```

## Demo Walkthrough

See the [`demos/`](./demos/) directory for step-by-step demo scripts used during the session.

1. [Demo 1 – Hello MCP: Your First Server](./demos/01-hello-mcp.md)
2. [Demo 2 – Exposing a Database](./demos/02-database.md)
3. [Demo 3 – Wrapping a REST API](./demos/03-rest-api.md)
4. [Demo 4 – Flat Files as Tools](./demos/04-flat-files.md)
5. [Demo 5 – Legacy System Integration](./demos/05-legacy.md)
6. [Demo 6 – Using with VS Code and Agent Frameworks](./demos/06-agents.md)

## Resources

- [Model Context Protocol specification](https://spec.modelcontextprotocol.io)
- [MCP SDK for TypeScript](https://github.com/modelcontextprotocol/typescript-sdk)
- [MCP SDK for Python](https://github.com/modelcontextprotocol/python-sdk)
