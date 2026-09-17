# Extras

Tools that work but are not on the run-of-show. Copy any of them into `../tools/`
and they are live on the next tool list (VS Code needs a reload to see them).

| Script | What | Needs |
|---|---|---|
| `Get-OutageExcuse.ps1` | Scrapes the BOFH Excuse Server (a Perl CGI running since 1995, no API). Falls back to a built-in list if the server is down. | internet |
| `Test-IsItDns.ps1` | No parameters. Returns `IsItDns = $true`. A complete MCP tool with an empty schema. | Windows (`Resolve-DnsName`) |
| `Get-AzResourceInventory.ps1` | Azure Resource Graph query across subscriptions. | `Az.ResourceGraph`, `Connect-AzAccount` |
| `Get-EntraStaleAccount.ps1` | Accounts with no sign-in for N days. | `Microsoft.Graph.Users`, `Connect-MgGraph` |

The Azure/Entra ones were cut from the session because they talk to things that
already have a perfectly good API, which is the opposite of the point.

Good moments for the first two, if you want them:

- After `Get-ServiceHealth` finds a stopped service: *"What do I tell the users?"*
- Anywhere someone mentions a network problem: Copilot will reach for `Test-IsItDns`
  on its own if it is in the folder. Do not prompt it; wait.
