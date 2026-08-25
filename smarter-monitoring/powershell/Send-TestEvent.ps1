#requires -Version 7.0

<#
.SYNOPSIS
    Replays a recorded scenario into the real Event Hub, so the deployed Function
    processes it. The on-stage version of "make something happen."

.PARAMETER Scenario
    Scenario JSON to replay.

.PARAMETER First
    Only send the first N payloads (use -First 1 for a warm-up ping).

.PARAMETER DelayMs
    Pause between payloads, to make the arrival look realistic in the logs.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Scenario = (Join-Path $PSScriptRoot '..' 'data' 'scenario-web-outage.json'),
    [int]$First = 0,
    [int]$DelayMs = 400
)

$ErrorActionPreference = 'Stop'

if (-not $env:EVENTHUB_CONNECTION) { throw 'EVENTHUB_CONNECTION is not set.' }

Add-Type -AssemblyName System.Net.Http
$data = Get-Content -LiteralPath $Scenario -Raw | ConvertFrom-Json
$payloads = if ($First -gt 0) { @($data.payloads)[0..($First - 1)] } else { @($data.payloads) }

# Parse the SAS connection string and mint a token. Doing this by hand rather than
# with a module keeps the demo dependency-free and shows what the SDK is doing.
$parts = @{}
foreach ($segment in $env:EVENTHUB_CONNECTION -split ';') {
    if ($segment -match '^([^=]+)=(.*)$') { $parts[$Matches[1]] = $Matches[2] }
}
$namespace = ([uri]$parts['Endpoint']).Host
$hubName = $env:EVENTHUB_NAME ?? 'monitoring-events'
$resource = [uri]::EscapeDataString("https://$namespace/$hubName")
$expiry = [DateTimeOffset]::UtcNow.AddMinutes(20).ToUnixTimeSeconds()

$hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($parts['SharedAccessKey']))
$signature = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$resource`n$expiry")))
$sas = "SharedAccessSignature sr=$resource&sig=$([uri]::EscapeDataString($signature))&se=$expiry&skn=$($parts['SharedAccessKeyName'])"

$uri = "https://$namespace/$hubName/messages?api-version=2014-01"
$sent = 0

foreach ($item in $payloads) {
    $body = $item.payload | ConvertTo-Json -Depth 20 -Compress
    if ($PSCmdlet.ShouldProcess($hubName, "send $($item.type) event")) {
        Invoke-RestMethod -Uri $uri -Method Post -Body $body `
            -Headers @{ Authorization = $sas; 'Content-Type' = 'application/json' } `
            -TimeoutSec 15 -ErrorAction Stop | Out-Null
        $sent++
        Write-Host "  -> sent $($item.type)" -ForegroundColor DarkGray
    }
    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "Sent $sent payload(s) to $hubName." -ForegroundColor Green
