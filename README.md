# Cloud and AI Summit 2026

This repository contains demos, presentations, and other materials for two sessions at Cloud and AI Summit 2026.

---

## Sessions

### 1. MCP for Everything: Turning Any Data Source into an AI-Ready Tool

Model Context Protocol (MCP) has rapidly become the standard way to make data and systems usable by AI agents and developer tools. In this session, we'll walk through building an MCP server that exposes real-world sources such as databases, APIs, flat files, and even legacy systems. We will show how to query and use them directly from tools like VS Code and agent frameworks. You'll leave knowing how to make almost any system MCP-enabled and ready for modern AI workflows.

📁 [Session materials →](./mcp-for-everything/)

---

### 2. Smarter Monitoring: Building an AI-Enhanced Event Pipeline

Monitoring and observability platforms generate endless alerts, but teams still have to hunt for the real problem. In this session, you'll see how to build an AI-enhanced event pipeline that turns raw telemetry from your monitoring and observability tools into actionable insight. We'll cover ingesting events from multiple sources, including environments that use OpenTelemetry, then correlating and enriching them with AI so downstream systems receive clear, prioritized incidents instead of noise, helping teams cut alert fatigue and respond faster.

📁 [Session materials →](./smarter-monitoring/)

---

## Repository Structure

```
cas2026/
├── mcp-for-everything/        # Session 1: MCP server demos and examples
│   ├── README.md
│   ├── src/                   # MCP server source code
│   └── demos/                 # Step-by-step demo scripts
└── smarter-monitoring/        # Session 2: AI-enhanced event pipeline demos
    ├── README.md
    ├── src/                   # Pipeline source code
    └── demos/                 # Step-by-step demo scripts
```