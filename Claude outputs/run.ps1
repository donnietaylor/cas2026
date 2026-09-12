param($eventHubMessages, $TriggerMetadata)

# Step 1 of the pipeline: read the hub, normalize, drop successes, log.
# Correlation (tables) and the AI step get added on top of this.

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Pipeline.psm1')

$kept = 0
$dropped = 0

foreach ($message in @($eventHubMessages)) {
    # The trigger hands us strings; the worker sometimes pre-parses JSON.
    $payload = $message
    if ($message -is [string]) {
        try { $payload = $message | ConvertFrom-Json -Depth 50 }
        catch { Write-Warning "Skipped a message that isn't JSON."; continue }
    }

    Write-RawSample $payload

    foreach ($pipelineEvent in @(ConvertTo-PipelineEvent -Payload $payload)) {
        if ($pipelineEvent.Success) { $dropped++; continue }
        $kept++
        Write-Information "EVENT $($pipelineEvent | ConvertTo-Json -Compress)"
    }
}

Write-Information "BATCH messages=$(@($eventHubMessages).Count) kept=$kept successes-dropped=$dropped"
