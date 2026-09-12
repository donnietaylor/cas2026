param($eventHubMessages, $TriggerMetadata)

# Read the hub, normalize, drop successes, correlate into incidents.
# The AI pass runs separately, over the incidents this produces.

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Pipeline.psm1')
Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Correlation.psm1')

# Write-Host, not Write-Information: the Functions PowerShell worker leaves
# $InformationPreference at SilentlyContinue, so Write-Information output is
# discarded. Write-Host always reaches the logs (at Information level).
$windowMinutes = [int]($env:CORRELATION_WINDOW_MINUTES ?? 15)

$kept = 0
$dropped = 0
$outcomes = @{}

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

        try {
            $result = Add-EventToIncident -Event $pipelineEvent -WindowMinutes $windowMinutes
            $outcomes[$result.Outcome] = ($outcomes[$result.Outcome] ?? 0) + 1

            # Only transitions are logged per event. Repeats of a known symptom
            # would drown the log at demo traffic rates - their count lives in
            # the Events table instead.
            if ($result.Outcome -ne 'deduped') {
                Write-Host "$($result.Outcome.ToUpper()) $($result.IncidentId) [$($result.Fingerprint)] $($pipelineEvent.Severity) $($pipelineEvent.Title)"
            }
        }
        catch {
            # Correlation failing must not cost us the event's visibility.
            Write-Warning "Correlation failed for '$($pipelineEvent.Title)': $($_.Exception.Message)"
            Write-Host "EVENT $($pipelineEvent | ConvertTo-Json -Compress)"
        }
    }
}

$summary = ($outcomes.Keys | Sort-Object | ForEach-Object { "$_=$($outcomes[$_])" }) -join ' '
Write-Host "BATCH messages=$(@($eventHubMessages).Count) kept=$kept successes-dropped=$dropped $summary"
