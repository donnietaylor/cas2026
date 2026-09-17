#requires -Version 7.0

<#
.SYNOPSIS
    Starts the MCP host. One command, so there is nothing to fumble on stage.

.DESCRIPTION
    Reads host/.env if it exists (KEY=VALUE lines) into the environment first,
    so SQL_CONNECTION_STRING and friends live in one gitignored file. The
    switches below override anything in .env.

.PARAMETER AllowWriteTools
    Enable state-changing tools (Demo 7).

.PARAMETER DemoMode
    Use canned data for the SQL tool instead of a live query.
#>
[CmdletBinding()]
param(
    [switch]$AllowWriteTools,
    [switch]$DemoMode,
    [int]$Port = 8931
)

$ErrorActionPreference = 'Stop'
$host_dir = Join-Path $PSScriptRoot 'host'

# .env is convenience, not config management. Lines are KEY=VALUE, # is a comment.
$dotenv = Join-Path $host_dir '.env'
if (Test-Path $dotenv) {
    Get-Content $dotenv | Where-Object { $_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' } | ForEach-Object {
        Set-Item -Path "env:$($Matches[1])" -Value $Matches[2]
    }
    Write-Host "Loaded $dotenv" -ForegroundColor DarkGray
}

if ($AllowWriteTools) {
    # One variable, naming one tool. There is no master switch to leave on.
    $env:WRITE_TOOL_ALLOWLIST = 'Restart-DemoService'
    Write-Host 'Write tools ENABLED (Restart-DemoService allowlisted).' -ForegroundColor Yellow
}
elseif (-not $env:WRITE_TOOL_ALLOWLIST) {
    $env:WRITE_TOOL_ALLOWLIST = ''
}

if ($DemoMode) {
    $env:CAS_DEMO_MODE = 'true'
    Write-Host 'DEMO MODE - the SQL tool returns canned data.' -ForegroundColor Yellow
}

$env:PORT = $Port

Push-Location $host_dir
try {
    Write-Host "MCP endpoint : http://localhost:$Port/mcp"     -ForegroundColor Cyan
    Write-Host "Health       : http://localhost:$Port/healthz`n" -ForegroundColor Cyan
    python -m uvicorn app:app --host 127.0.0.1 --port $Port
}
finally { Pop-Location }
