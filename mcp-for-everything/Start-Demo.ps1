#requires -Version 7.0

<#
.SYNOPSIS
    Starts the MCP host. One command, so there is nothing to fumble on stage.

.PARAMETER AllowWriteTools
    Enable state-changing tools (Demo 5, act 1).

.PARAMETER DemoMode
    Use canned data for Azure/SQL/Entra instead of live calls.
#>
[CmdletBinding()]
param(
    [switch]$AllowWriteTools,
    [switch]$DemoMode,
    [int]$Port = 8931
)

$ErrorActionPreference = 'Stop'
$host_dir = Join-Path $PSScriptRoot 'host'

if ($AllowWriteTools) {
    $env:ALLOW_WRITE_TOOLS = 'true'
    $env:WRITE_TOOL_ALLOWLIST = 'Restart-DemoService'
    Write-Host 'Write tools ENABLED (Restart-DemoService allowlisted).' -ForegroundColor Yellow
}
else {
    $env:ALLOW_WRITE_TOOLS = 'false'
}

if ($DemoMode) {
    $env:CAS_DEMO_MODE = 'true'
    Write-Host 'DEMO MODE - external systems return canned data.' -ForegroundColor Yellow
}

$env:PORT = $Port

Push-Location $host_dir
try {
    Write-Host "Tool browser : http://localhost:$Port"      -ForegroundColor Cyan
    Write-Host "MCP endpoint : http://localhost:$Port/mcp`n" -ForegroundColor Cyan
    python -m uvicorn app:app --host 127.0.0.1 --port $Port
}
finally { Pop-Location }
