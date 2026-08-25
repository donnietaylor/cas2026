<#
    Where incidents go.

    ServiceNow is the target system for this session, but nothing here is wired to
    a real instance - we emit the exact payload their Table API expects and post it
    to a webhook you can watch. That is deliberate: the interesting part is the
    shape and the suppression logic, not the credentials.
#>

Set-StrictMode -Version Latest

# ServiceNow urgency/impact are 1=High, 2=Medium, 3=Low.
$script:SeverityMap = @{
    critical = @{ Urgency = 1; Impact = 1 }
    high     = @{ Urgency = 1; Impact = 2 }
    medium   = @{ Urgency = 2; Impact = 3 }
    low      = @{ Urgency = 3; Impact = 3 }
}

function ConvertTo-ServiceNowIncident {
    <#
    .SYNOPSIS
        Map an enriched incident onto the ServiceNow incident table schema.

    .DESCRIPTION
        Two fields carry the weight here.

        correlation_id gets our fingerprint, which is how ServiceNow itself
        deduplicates - post the same correlation_id twice and you update the
        existing ticket rather than opening a second one. Belt and braces with
        our own suppression window.

        work_notes carries the AI's reasoning AND its confidence, explicitly
        labelled as machine-generated. The on-call engineer must be able to tell
        at a glance which parts a model wrote. Never launder an AI guess into
        something that reads like an established fact.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Incident)

    $map = $script:SeverityMap[$Incident.Severity] ?? @{ Urgency = 3; Impact = 3 }

    [ordered]@{
        short_description = $Incident.Title
        description       = $Incident.RootCause
        urgency           = $map.Urgency
        impact            = $map.Impact
        category          = 'Infrastructure'
        contact_type      = 'Monitoring'
        correlation_id    = $Incident.Fingerprint
        assignment_group  = $env:SERVICENOW_ASSIGNMENT_GROUP ?? 'Platform Operations'
        work_notes        = @(
            "[AI-GENERATED ANALYSIS - confidence: $($Incident.Confidence)]"
            ''
            "Root cause: $($Incident.RootCause)"
            "Recommended action: $($Incident.RecommendedAction)"
            ''
            "Correlated from $($Incident.EventCount) event(s): $($Incident.RelatedEventIds -join ', ')"
            "Enriched by: $($Incident.EnrichedBy)"
        ) -join "`n"
        u_source_events   = ($Incident.RelatedEventIds -join ',')
        u_ai_confidence   = $Incident.Confidence
    }
}

function Test-IncidentSuppressed {
    <#
    .SYNOPSIS
        Have we already raised this exact incident recently?

    .DESCRIPTION
        Table Storage keyed on the fingerprint. Cheap, durable, and the difference
        between "AI reduced our alert noise" and "AI opened 340 tickets overnight",
        which is a very different conference talk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [int]$SuppressionMinutes = 60
    )

    $stateDir = $env:INCIDENT_STATE_DIR ?? (Join-Path ([IO.Path]::GetTempPath()) 'cas2026-incidents')
    $null = New-Item -ItemType Directory -Path $stateDir -Force
    $marker = Join-Path $stateDir "$Fingerprint.json"

    if (Test-Path -LiteralPath $marker) {
        $seen = (Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json).lastSeen
        $age = (Get-Date).ToUniversalTime() - [datetime]$seen
        if ($age.TotalMinutes -lt $SuppressionMinutes) {
            return $true
        }
    }

    @{ lastSeen = (Get-Date).ToUniversalTime().ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding utf8

    return $false
}

function Publish-Incident {
    <#
    .SYNOPSIS
        Send an incident to every configured sink.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][object]$Incident,
        [switch]$SkipSuppression
    )

    if (-not $SkipSuppression) {
        if (Test-IncidentSuppressed -Fingerprint $Incident.Fingerprint) {
            Write-Warning "Suppressed duplicate incident (fingerprint $($Incident.Fingerprint))."
            return [PSCustomObject]@{ Published = $false; Reason = 'suppressed'; Incident = $Incident }
        }
    }

    $payload = ConvertTo-ServiceNowIncident -Incident $Incident

    # Console sink - the one the audience actually watches.
    $colour = switch ($Incident.Severity) {
        'critical' { 'Red' }
        'high' { 'Yellow' }
        'medium' { 'Cyan' }
        default { 'Gray' }
    }
    Write-Host ''
    Write-Host "[$($Incident.Severity.ToUpper())] $($Incident.Title)" -ForegroundColor $colour
    Write-Host "  Root cause : $($Incident.RootCause)"
    Write-Host "  Action     : $($Incident.RecommendedAction)"
    Write-Host "  Confidence : $($Incident.Confidence)   Events: $($Incident.EventCount)   FP: $($Incident.Fingerprint)"

    # File sink - NDJSON, for replay and for showing the raw payload on screen.
    if ($env:INCIDENT_OUTPUT_FILE) {
        $dir = Split-Path $env:INCIDENT_OUTPUT_FILE -Parent
        if ($dir) { $null = New-Item -ItemType Directory -Path $dir -Force }
        ($payload | ConvertTo-Json -Depth 10 -Compress) |
            Add-Content -LiteralPath $env:INCIDENT_OUTPUT_FILE -Encoding utf8
    }

    # Webhook sink - a real ServiceNow instance would be
    # https://<instance>.service-now.com/api/now/table/incident
    if ($env:INCIDENT_WEBHOOK_URL) {
        if ($PSCmdlet.ShouldProcess($env:INCIDENT_WEBHOOK_URL, 'POST incident')) {
            try {
                Invoke-RestMethod -Uri $env:INCIDENT_WEBHOOK_URL -Method Post `
                    -ContentType 'application/json' `
                    -Body ($payload | ConvertTo-Json -Depth 10) `
                    -TimeoutSec 10 -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Warning "Incident webhook delivery failed: $($_.Exception.Message)"
            }
        }
    }

    return [PSCustomObject]@{ Published = $true; Payload = $payload; Incident = $Incident }
}

Export-ModuleMember -Function ConvertTo-ServiceNowIncident, Test-IncidentSuppressed, Publish-Incident
