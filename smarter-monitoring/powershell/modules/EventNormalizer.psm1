<#
    Normalizers: every source in, one Event shape out.

    Boring on purpose. This is the layer that decides whether the rest of the
    pipeline is pleasant or miserable, and the single most important field it
    produces is TraceId - see Get-CorrelationKey below for why.
#>

# Deliberately NOT Set-StrictMode -Version Latest in this module.
#
# Strict mode turns "property does not exist" into a terminating error, and this
# module's entire job is reading JSON from systems that add and drop fields
# whenever they feel like it. A missing optional field must produce $null and a
# degraded event, not an exception that drops the batch. The other modules in
# this pipeline do run strict.

function New-PipelineEvent {
    <#
    .SYNOPSIS
        The one canonical event shape. Everything normalizes into this.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Title,
        [string]$Description = '',
        [ValidateSet('critical', 'error', 'warning', 'info')]
        [string]$Severity = 'info',
        [hashtable]$Labels = @{},
        [string]$ResourceId = '',
        [string]$TraceId = '',
        [datetime]$Timestamp = (Get-Date).ToUniversalTime(),
        [object]$Raw = $null
    )

    [PSCustomObject]@{
        Id          = "evt-$([guid]::NewGuid().ToString('N').Substring(0,10))"
        Source      = $Source
        Severity    = $Severity
        Title       = $Title
        Description = $Description
        Labels      = $Labels
        ResourceId  = $ResourceId
        TraceId     = $TraceId
        Timestamp   = $Timestamp.ToString('o')
        Raw         = $Raw
    }
}

function ConvertFrom-AzureMonitorAlert {
    <#
    .SYNOPSIS
        Azure Monitor Common Alert Schema -> pipeline event.

    .DESCRIPTION
        Use the Common Alert Schema. Turn it on in the action group. Without it
        every alert type hands you a different payload shape and you will write
        a normalizer per alert rule, forever.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Payload)

    $essentials = $Payload.data.essentials
    if (-not $essentials) { throw 'Not a Common Alert Schema payload (no data.essentials).' }

    # Azure severities are Sev0..Sev4, lowest number is worst.
    $severity = switch ($essentials.severity) {
        'Sev0' { 'critical' }
        'Sev1' { 'critical' }
        'Sev2' { 'error' }
        'Sev3' { 'warning' }
        default { 'info' }
    }

    $resourceId = @($essentials.alertTargetIDs)[0] ?? ''

    New-PipelineEvent -Source 'azure-monitor' `
        -Severity $severity `
        -Title $essentials.alertRule `
        -Description ($essentials.description ?? $essentials.monitorCondition ?? '') `
        -ResourceId $resourceId `
        -Labels @{
            signalType       = [string]$essentials.signalType
            monitorCondition = [string]$essentials.monitorCondition
            resourceName     = ($resourceId -split '/')[-1]
            resourceGroup    = [string]$essentials.configurationItems
        } `
        -Timestamp ([datetime]($essentials.firedDateTime ?? (Get-Date).ToUniversalTime())) `
        -Raw $Payload
}

function ConvertFrom-OtelSpan {
    <#
    .SYNOPSIS
        OTLP span (JSON encoding) -> pipeline event. Error spans only.

    .DESCRIPTION
        The reason OpenTelemetry is in this session and not just name-checked:
        a span carries a trace ID. That turns "these alerts might be related"
        into "these alerts are provably the same request path." Deterministic
        correlation, no model required.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Payload)

    $events = [System.Collections.Generic.List[object]]::new()

    foreach ($resourceSpan in @($Payload.resourceSpans)) {
        # Resource attributes tell us WHICH service; span tells us what broke.
        $serviceName = 'unknown'
        foreach ($attr in @($resourceSpan.resource.attributes)) {
            if ($attr.key -eq 'service.name') { $serviceName = $attr.value.stringValue }
        }

        foreach ($scopeSpan in @($resourceSpan.scopeSpans)) {
            foreach ($span in @($scopeSpan.spans)) {

                # STATUS_CODE_ERROR is 2 in the enum; the JSON encoding uses either.
                $code = $span.status.code
                if ($code -ne 2 -and $code -ne 'STATUS_CODE_ERROR') { continue }

                $attributes = @{}
                foreach ($attr in @($span.attributes)) {
                    $value = $attr.value.stringValue ?? $attr.value.intValue ?? $attr.value.boolValue
                    $attributes[$attr.key] = [string]$value
                }

                # OTLP timestamps are unix nanoseconds.
                $startNs = [long]($span.startTimeUnixNano ?? 0)
                $timestamp = if ($startNs -gt 0) {
                    [DateTimeOffset]::FromUnixTimeMilliseconds([long]($startNs / 1e6)).UtcDateTime
                }
                else { (Get-Date).ToUniversalTime() }

                $events.Add((New-PipelineEvent -Source 'otel' `
                    -Severity 'error' `
                    -Title "Span failed: $($span.name)" `
                    -Description ($span.status.message ?? '') `
                    -TraceId ([string]$span.traceId) `
                    -Labels ($attributes + @{ 'service.name' = $serviceName }) `
                    -Timestamp $timestamp `
                    -Raw $span))
            }
        }
    }

    return $events
}

function ConvertFrom-GenericWebhook {
    <#
    .SYNOPSIS
        Catch-all for third-party monitoring webhooks (Datadog, Nagios, whatever).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Payload)

    New-PipelineEvent -Source 'webhook' `
        -Severity ([string]($Payload.severity ?? 'info')) `
        -Title ([string]($Payload.title ?? $Payload.alertname ?? 'Unknown alert')) `
        -Description ([string]($Payload.description ?? $Payload.message ?? '')) `
        -Labels @{ host = [string]($Payload.host ?? '') } `
        -Raw $Payload
}

function Get-CorrelationKey {
    <#
    .SYNOPSIS
        Group events deterministically BEFORE any AI is involved.

    .DESCRIPTION
        The most important function in the pipeline, and it contains no AI at all.

        Correlate on what you actually know:
          1. trace ID    - provably the same request path (thank you, OpenTelemetry)
          2. resource ID - provably the same Azure resource
          3. host label  - probably the same machine

        Only what survives this still needs judgment. Handing an LLM twelve
        alerts and asking "are these related?" when four of them share a trace ID
        is paying a model to do arithmetic.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Event)

    if ($Event.TraceId) { return "trace:$($Event.TraceId)" }
    if ($Event.ResourceId) { return "resource:$($Event.ResourceId)" }
    if ($Event.Labels.host) { return "host:$($Event.Labels.host)" }
    if ($Event.Labels.resourceName) { return "resource:$($Event.Labels.resourceName)" }
    return "title:$($Event.Title)"
}

function Get-EventFingerprint {
    <#
    .SYNOPSIS
        Stable hash used to suppress duplicate incidents across windows.

    .DESCRIPTION
        Without this you open a new ticket every window for the same ongoing
        problem, and you have automated alert fatigue instead of fixing it.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Events)

    $signature = (
        $Events |
            ForEach-Object { "$($_.Title)|$($_.ResourceId)" } |
            Sort-Object -Unique
    ) -join ';'

    $bytes = [Text.Encoding]::UTF8.GetBytes($signature)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).Substring(0, 16).ToLower()
}

Export-ModuleMember -Function New-PipelineEvent, ConvertFrom-AzureMonitorAlert,
    ConvertFrom-OtelSpan, ConvertFrom-GenericWebhook, Get-CorrelationKey, Get-EventFingerprint
