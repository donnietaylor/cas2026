#requires -Version 7.0

<#
.SYNOPSIS
    Thirty-minutes-before checklist for the Smarter Monitoring session.

.DESCRIPTION
    Checks everything the run of show depends on, in the order it will be needed,
    and tells you what to do about each failure rather than just going red.

    The last two checks are the ones that matter most, and they are the ones a
    normal preflight would skip: they confirm the OFFLINE path works. If Azure is
    healthy you will never notice they passed. If Azure is not healthy at 9am,
    they are the entire session.

.PARAMETER SkipLive
    Only run the checks that do not need network or Azure. Use this on a plane.

.EXAMPLE
    .\Preflight.ps1
    .\Preflight.ps1 -SkipLive
#>
[CmdletBinding()]
param(
    [switch]$SkipLive
)

$results = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = '',
        [string]$Fix = ''
    )
    $results.Add([PSCustomObject]@{
            Check  = $Name
            Status = $(if ($Ok) { 'PASS' } else { 'FAIL' })
            Detail = $Detail
            Fix    = $(if ($Ok) { '' } else { $Fix })
        })
}

$root = $PSScriptRoot
$psRoot = Join-Path $root 'powershell'
$scenario = Join-Path $root 'data' 'scenario-web-outage.json'

Write-Host "`nSmarter Monitoring - preflight`n" -ForegroundColor Magenta

# ---------------------------------------------------------------------------
# Local prerequisites
# ---------------------------------------------------------------------------

Add-Check 'PowerShell 7+' ($PSVersionTable.PSVersion.Major -ge 7) `
    $PSVersionTable.PSVersion.ToString() `
    'winget install Microsoft.PowerShell (pwsh, not powershell.exe)'

$moduleNames = @('EventNormalizer', 'Grounding', 'AiEnrichment', 'IncidentSink')
$moduleErrors = @()
foreach ($name in $moduleNames) {
    $path = Join-Path $psRoot 'modules' "$name.psm1"
    if (-not (Test-Path -LiteralPath $path)) { $moduleErrors += "$name missing"; continue }
    try { Import-Module $path -Force -ErrorAction Stop }
    catch { $moduleErrors += "$name : $($_.Exception.Message)" }
}
Add-Check 'Pipeline modules import' ($moduleErrors.Count -eq 0) `
    $(if ($moduleErrors) { $moduleErrors -join '; ' } else { "$($moduleNames.Count) modules" }) `
    'Fix the parse error before anything else - nothing downstream works.'

# Every function the Function app and the local harness actually call.
$required = @(
    'ConvertFrom-AzureMonitorAlert', 'ConvertFrom-OtelSpan', 'ConvertFrom-GenericWebhook',
    'Get-CorrelationKey', 'Get-EventFingerprint', 'Get-GroundingContext',
    'Invoke-AiEnrichment', 'New-UnenrichedIncident', 'Publish-Incident'
)
$missing = @($required | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
Add-Check 'Exported functions resolve' ($missing.Count -eq 0) `
    $(if ($missing) { "missing: $($missing -join ', ')" } else { "$($required.Count) functions" }) `
    'Check Export-ModuleMember at the bottom of the offending module.'

Add-Check 'Scenario file present' (Test-Path -LiteralPath $scenario) `
    $(if (Test-Path -LiteralPath $scenario) { Split-Path $scenario -Leaf } else { 'not found' }) `
    'The cold open and every offline demo replay from this file.'

# ---------------------------------------------------------------------------
# Demo hygiene
# ---------------------------------------------------------------------------

$stateDir = $env:INCIDENT_STATE_DIR ?? (Join-Path ([IO.Path]::GetTempPath()) 'cas2026-incidents')
$stateCount = if (Test-Path -LiteralPath $stateDir) {
    @(Get-ChildItem -LiteralPath $stateDir -Filter '*.json' -ErrorAction SilentlyContinue).Count
}
else { 0 }
Add-Check 'Incident state clear' ($stateCount -eq 0) `
    "$stateCount suppression marker(s) in $stateDir" `
    "Remove-Item '$stateDir' -Recurse -Force   # otherwise the cold open publishes ZERO incidents"

$outputFile = $env:INCIDENT_OUTPUT_FILE
if ($outputFile -and (Test-Path -LiteralPath $outputFile)) {
    Add-Check 'Incident output file clear' $false `
        "$outputFile exists" `
        "Remove-Item '$outputFile'  # so the audience sees only today's run"
}
else {
    Add-Check 'Incident output file clear' $true 'clean'
}

# ---------------------------------------------------------------------------
# Live Azure - skippable
# ---------------------------------------------------------------------------

if ($SkipLive) {
    Write-Host "  (skipping live Azure checks)`n" -ForegroundColor DarkGray
}
else {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    Add-Check 'Azure signed in' ([bool]$context) `
        $(if ($context) { "$($context.Account.Id) / $($context.Subscription.Name)" } else { 'no context' }) `
        'Connect-AzAccount'

    $endpoint = $env:AZURE_OPENAI_ENDPOINT
    $deployment = $env:AZURE_OPENAI_DEPLOYMENT
    Add-Check 'Azure OpenAI configured' ([bool]$endpoint -and [bool]$deployment) `
        "$endpoint / $deployment" `
        'Set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_DEPLOYMENT.'

    if ($endpoint -and $deployment) {
        # Actually call it. "The variable is set" is not the same as "it answers",
        # and the difference shows up in front of the room.
        try {
            $apiVersion = $env:AZURE_OPENAI_API_VERSION ?? '2024-10-21'
            $uri = "$($endpoint.TrimEnd('/'))/openai/deployments/$deployment/chat/completions?api-version=$apiVersion"

            $headers = @{ 'Content-Type' = 'application/json' }
            if ($env:AZURE_OPENAI_API_KEY) { $headers['api-key'] = $env:AZURE_OPENAI_API_KEY }
            else { $headers['Authorization'] = "Bearer $(Get-AzureAccessToken -Resource 'https://cognitiveservices.azure.com')" }

            # Exercise Structured Outputs specifically - a deployment that chats
            # fine but rejects json_schema fails Demo 5 and nothing before it.
            $body = @{
                messages        = @(@{ role = 'user'; content = 'Reply with the word ok.' })
                max_tokens      = 20
                response_format = @{
                    type        = 'json_schema'
                    json_schema = @{
                        name   = 'preflight'
                        strict = $true
                        schema = @{
                            type                 = 'object'
                            additionalProperties = $false
                            required             = @('status')
                            properties           = @{ status = @{ type = 'string' } }
                        }
                    }
                }
            } | ConvertTo-Json -Depth 15

            $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers `
                -Body $body -TimeoutSec 25 -ErrorAction Stop

            $null = $response.choices[0].message.content | ConvertFrom-Json
            Add-Check 'Azure OpenAI answers (structured outputs)' $true "$deployment responded"
        }
        catch {
            Add-Check 'Azure OpenAI answers (structured outputs)' $false `
                $_.Exception.Message `
                'If json_schema is rejected, your model/API version does not support Structured Outputs - Demo 5 needs it.'
        }
    }

    Add-Check 'Event Hub connection set' ([bool]$env:EVENTHUB_CONNECTION) `
        $(if ($env:EVENTHUB_CONNECTION) { 'set' } else { 'not set' }) `
        'Only needed if you are pushing to the deployed Function via Send-TestEvent.ps1.'

    Add-Check 'Log Analytics workspace set' ([bool]$env:LOG_ANALYTICS_WORKSPACE_ID) `
        $(if ($env:LOG_ANALYTICS_WORKSPACE_ID) { 'set' } else { 'not set - grounding will skip KQL' }) `
        'Set LOG_ANALYTICS_WORKSPACE_ID for the full Demo 4.'

    Add-Check 'App Insights connection string set' ([bool]$env:APPLICATIONINSIGHTS_CONNECTION_STRING) `
        $(if ($env:APPLICATIONINSIGHTS_CONNECTION_STRING) { 'set' } else { 'not set' }) `
        'otel-demo/app.py needs this for the Demo 2 portal view.'
}

# ---------------------------------------------------------------------------
# The checks that save the session
# ---------------------------------------------------------------------------

try {
    $tempState = Join-Path ([IO.Path]::GetTempPath()) "cas-preflight-$([guid]::NewGuid().ToString('N').Substring(0,6))"
    $previousState = $env:INCIDENT_STATE_DIR
    $previousOutput = $env:INCIDENT_OUTPUT_FILE
    $env:INCIDENT_STATE_DIR = $tempState
    $env:INCIDENT_OUTPUT_FILE = $null

    # 6> $null swallows the pipeline's console narration; -PassThru gives us a real
    # object to assert on. Never scrape Write-Host output - it is not on a stream
    # you can capture, which is exactly the bug this check was written to catch.
    $run = & (Join-Path $psRoot 'Invoke-LocalPipeline.ps1') -Scenario $scenario -Offline -PassThru 6> $null

    $env:INCIDENT_STATE_DIR = $previousState
    $env:INCIDENT_OUTPUT_FILE = $previousOutput
    Remove-Item $tempState -Recurse -Force -ErrorAction SilentlyContinue

    Add-Check 'Offline pipeline runs' ($run.IncidentsPublished -gt 0) `
        "$($run.RawPayloads) payloads -> $($run.Events) events -> $($run.Groups) groups -> $($run.IncidentsPublished) incidents" `
        'The wifi-died path is broken. Fix this before you fix anything else.'

    # The cold open lives or dies on the top incident being critical. If the
    # recorded scenario ever drifts, this is where you find out - not on stage.
    $topSeverity = @($run.Severities)[0]
    Add-Check 'Cold open leads with a critical' ($topSeverity -eq 'critical') `
        "top incident severity: $topSeverity" `
        'The demo is far less convincing if the first thing on screen is a LOW.'
}
catch {
    Add-Check 'Offline pipeline runs' $false $_.Exception.Message `
        'The wifi-died path is broken. Fix this before you fix anything else.'
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$results | Format-Table Check, Status, Detail | Out-String -Width 160 | Write-Host

$failed = @($results | Where-Object Status -eq 'FAIL')

if ($failed) {
    Write-Host "$($failed.Count) check(s) failed:`n" -ForegroundColor Red
    foreach ($f in $failed) {
        Write-Host "  $($f.Check)" -ForegroundColor Red
        Write-Host "    $($f.Detail)" -ForegroundColor DarkGray
        if ($f.Fix) { Write-Host "    -> $($f.Fix)" -ForegroundColor Yellow }
    }
    Write-Host ''

    # A live-Azure failure is survivable; an offline failure is not.
    $fatal = @($failed | Where-Object { $_.Check -in @('PowerShell 7+', 'Pipeline modules import', 'Exported functions resolve', 'Scenario file present', 'Offline pipeline runs') })
    if ($fatal) {
        Write-Host 'At least one failure breaks the offline path. Do not go on stage until it is green.' -ForegroundColor Red
        exit 1
    }

    Write-Host 'Offline path is intact - you can still run the whole session with -Offline.' -ForegroundColor Yellow
    exit 0
}

Write-Host 'All checks passed. Go get a coffee.' -ForegroundColor Green
