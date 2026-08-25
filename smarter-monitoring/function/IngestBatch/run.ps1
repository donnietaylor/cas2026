using namespace System.Collections.Generic

<#
    Event Hub triggered entry point.

    The batch IS the correlation window. Event Hubs hands us up to
    maxEventBatchSize events that arrived close together, which is exactly the
    grouping a tumbling window would have produced - without any state store,
    any Durable Functions orchestration, or any of the complexity that usually
    shows up here.

    If you need a guaranteed wall-clock window (say, "always exactly 60 seconds"),
    that is a Stream Analytics job in front of this Function, not a timer inside
    it. Say that on stage; someone will ask.
#>

param($eventHubMessages, $TriggerMetadata)

$ErrorActionPreference = 'Stop'

$batchId = [guid]::NewGuid().ToString('N').Substring(0, 8)
Write-Information "[$batchId] Received $($eventHubMessages.Count) raw events."

# -- normalize --------------------------------------------------------------

$events = [List[object]]::new()

foreach ($raw in $eventHubMessages) {
    try {
        $payload = if ($raw -is [string]) { $raw | ConvertFrom-Json } else { $raw }

        # Sniff the source rather than requiring the producer to tag it - Azure
        # Monitor action groups will not add a custom envelope for you.
        if ($payload.schemaId -eq 'azureMonitorCommonAlertSchema' -or $payload.data.essentials) {
            $events.Add((ConvertFrom-AzureMonitorAlert -Payload $payload))
        }
        elseif ($payload.resourceSpans) {
            foreach ($e in (ConvertFrom-OtelSpan -Payload $payload)) { $events.Add($e) }
        }
        else {
            $events.Add((ConvertFrom-GenericWebhook -Payload $payload))
        }
    }
    catch {
        # One malformed message must not poison the batch. Log it and move on -
        # otherwise a single bad producer stops the entire pipeline, which is a
        # far worse outage than the one it was trying to report.
        Write-Warning "[$batchId] Skipped unparseable event: $($_.Exception.Message)"
    }
}

if ($events.Count -eq 0) {
    Write-Information "[$batchId] Nothing to process."
    return
}

# -- deterministic correlation ---------------------------------------------

$groups = $events | Group-Object { Get-CorrelationKey -Event $_ }
Write-Information "[$batchId] $($events.Count) events -> $($groups.Count) groups."

# -- enrich + publish -------------------------------------------------------

$context = Get-GroundingContext -Events $events

foreach ($group in $groups) {
    try {
        $incidents = Invoke-AiEnrichment -Events $group.Group -Context $context
        foreach ($incident in $incidents) {
            Publish-Incident -Incident $incident | Out-Null
        }
    }
    catch {
        Write-Error "[$batchId] Group '$($group.Name)' failed: $($_.Exception.Message)"
        # Degrade, do not drop.
        Publish-Incident -Incident (New-UnenrichedIncident -Events $group.Group -Reason $_.Exception.Message) | Out-Null
    }
}

Write-Information "[$batchId] Done."
