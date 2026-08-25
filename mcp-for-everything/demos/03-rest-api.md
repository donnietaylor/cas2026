# Demo 3 – Wrapping a REST API

This demo shows how to wrap a public REST API as MCP tools.

## Steps

### 1. Pick a REST API

We use the public [Open-Meteo weather API](https://open-meteo.com/) (no key required).

### 2. Add an API tool

```js
server.tool(
  "get_weather",
  {
    latitude: z.number(),
    longitude: z.number(),
  },
  async ({ latitude, longitude }) => {
    const url =
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${latitude}&longitude=${longitude}` +
      `&current=temperature_2m,wind_speed_10m`;
    const response = await fetch(url);
    const data = await response.json();
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(data.current, null, 2),
        },
      ],
    };
  }
);
```

### 3. Try it out

Ask the agent: **"What is the current weather in Austin, TX?"**

The agent will look up the coordinates and call `get_weather`.
