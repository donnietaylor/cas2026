#requires -Version 7.0

<#
.SYNOPSIS
    Runs the whole pipeline locally against a recorded scenario. No Azure required
    for the correlation stages; Azure OpenAI only for the enrichment stage.

.DESCRIPTION
    This is the rehearsal harness and the on-stage safety net. Same normalizers,
    same correlation, same sink as the deployed Function - only the trigger differs.

    Use -Offline to stub the AI call with a recorded response so the entire demo
    runs with no network at all.

.PARAMETER Scenario
    Path to a scenario JSON file (see ../data).

.PARAMETER Offline
    Skip Azure OpenAI and use the recorded enrichment in the scenario file.

.PARAMETER ShowStages
    Print the intermediate stages - raw, normalized, correlated - not just the result.

.PARAMETER PassThru
    Emit a summary object describing the run. Everything else this script prints
    goes to the host via Write-Host, which is deliberately not capturable - so if
    you need to assert on a run (Preflight.ps1 does), use this rather than
    scraping the console output.

.EXAMPLE
    ./Invoke-LocalPipeline.ps1 -Scenario ../data/scenario-web-outage.json -Offline -ShowStages

.EXAMPLE
    $run = ./Invoke-LocalPipeline.ps1 -Offline -PassThru 6> $null
    $run.IncidentsPublished
#>
[CmdletBinding()]
param(
    [string]$Scenario = (Join-Path $PSScriptRoot '..' 'data' 'scenario-web-outage.json'),
    [switch]$Offline,
    [switch]$ShowStages,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules' 'EventNormalizer.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'modules' 'AiEnrichment.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'modules' 'IncidentSink.psm1') -Force

$data = Get-Content -LiteralPath $Scenario -Raw | ConvertFrom-Json

Write-Host "`n=== Scenario: $($data.name) ===" -ForegroundColor Magenta
Write-Host $data.description

# -- Stage 1: ingest + normalize -------------------------------------------

$events = [System.Collections.Generic.List[object]]::new()

foreach ($item in $data.payloads) {
    switch ($item.type) {
        'azure-monitor' { $events.Add((ConvertFrom-AzureMonitorAlert -Payload $item.payload)) }
        'otel' { foreach ($e in (ConvertFrom-OtelSpan -Payload $item.payload)) { $events.Add($e) } }
        'webhook' { $events.Add((ConvertFrom-GenericWebhook -Payload $item.payload)) }
        default { Write-Warning "Unknown payload type: $($item.type)" }
    }
}

Write-Host "`n[1] Ingested and normalized $($events.Count) events from $($data.payloads.Count) raw payloads." -ForegroundColor Green

if ($ShowStages) {
    $events | Select-Object Source, Severity, Title, ResourceId, TraceId |
        Format-Table | Out-String -Width 200 | Write-Host
}

# -- Stage 2: deterministic correlation ------------------------------------

$groups = $events | Group-Object { Get-CorrelationKey -Event $_ }

Write-Host "[2] Deterministic correlation: $($events.Count) events -> $($groups.Count) groups (no AI involved)." -ForegroundColor Green

if ($ShowStages) {
    foreach ($g in $groups) {
        Write-Host "     $($g.Name)  ->  $($g.Count) event(s)"
    }
}

# -- Stage 3: AI enrichment -------------------------------------------------

$incidents = [System.Collections.Generic.List[object]]::new()

foreach ($group in $groups) {
    if ($Offline) {
        # Recorded response keyed by correlation key; falls back to the
        # un-enriched incident so the pipeline still produces something.
        $recorded = $data.recordedEnrichment.PSObject.Properties |
            Where-Object { $_.Name -eq $group.Name } |
            Select-Object -First 1

        if ($recorded) {
            $r = $recorded.Value
            $incidents.Add([PSCustomObject]@{
                    Id                = "inc-$((Get-Date).ToString('yyyyMMdd'))-$([guid]::NewGuid().ToString('N').Substring(0,6))"
                    Severity          = $r.severity
                    Title             = $r.title
                    RootCause         = $r.rootCause
                    RecommendedAction = $r.recommendedAction
                    Confidence        = $r.confidence
                    RelatedEventIds   = @($group.Group.Id)
                    EventCount        = $group.Count
                    Fingerprint       = Get-EventFingerprint -Events $group.Group
                    CreatedAt         = (Get-Date).ToUniversalTime().ToString('o')
                    EnrichedBy        = 'recorded (offline mode)'
                })
        }
        else {
            $incidents.Add((New-UnenrichedIncident -Events $group.Group -Reason 'offline mode, no recorded response'))
        }
    }
    else {
        foreach ($inc in (Invoke-AiEnrichment -Events $group.Group -Context $data.groundingContext)) {
            $incidents.Add($inc)
        }
    }
}

$mode = if ($Offline) { 'recorded' } else { 'Azure OpenAI' }
Write-Host "[3] AI enrichment ($mode): $($groups.Count) groups -> $($incidents.Count) incidents." -ForegroundColor Green

# -- Stage 4: publish -------------------------------------------------------

Write-Host "[4] Publishing to sinks..." -ForegroundColor Green

# Severity order, not group order. The whole promise of this pipeline is that the
# on-call engineer reads the top of the list and stops - so the top of the list
# had better be the thing that matters.
$ordered = $incidents | Sort-Object {
    switch ($_.Severity) { 'critical' { 0 } 'high' { 1 } 'medium' { 2 } default { 3 } }
}

$published = 0
foreach ($incident in $ordered) {
    $result = Publish-Incident -Incident $incident
    if ($result.Published) { $published++ }
}

# -- Summary ----------------------------------------------------------------

Write-Host ''
Write-Host ('-' * 68)
Write-Host ("  {0} raw payloads -> {1} events -> {2} groups -> {3} incidents published" -f `
        $data.payloads.Count, $events.Count, $groups.Count, $published) -ForegroundColor Magenta
Write-Host ('-' * 68)
Write-Host ''

if ($PassThru) {
    [PSCustomObject]@{
        Scenario           = $data.name
        RawPayloads        = $data.payloads.Count
        Events             = $events.Count
        Groups             = $groups.Count
        Incidents          = $incidents.Count
        IncidentsPublished = $published
        Mode               = $mode
        Severities         = @($ordered.Severity)
    }
}
