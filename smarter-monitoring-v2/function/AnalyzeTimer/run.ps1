param($Timer)

# Every minute, but only when something actually changed - Invoke-IncidentAnalysis
# compares the newest TouchedAt against the marker row and returns 'no-change'
# without calling the model. A quiet minute costs two table reads, not a
# completion.

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Ai.psm1')

try {
    $result = Invoke-IncidentAnalysis
    Write-Host ("ANALYSIS {0} incidents={1} clusters={2} unrelated={3} tokens={4} {5}s" -f `
            $result.Status, $result.Incidents, $result.Clusters, $result.Unrelated,
        $result.TotalTokens, $result.Seconds)
}
catch {
    # A failed analysis must never cost us the incidents themselves.
    Write-Warning "Analysis failed: $($_.Exception.Message)"
}
