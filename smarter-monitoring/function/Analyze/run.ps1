using namespace System.Net

param($Request, $TriggerMetadata)

# GET|POST /api/analyze   - run the AI pass now and return what it decided.
#
# The timer does the same work on its own schedule. This exists so the analysis
# can be fired on cue rather than waited for, and so the reasoning can be put on
# screen instead of only its conclusions.

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Ai.psm1')

try {
    $result = Invoke-IncidentAnalysis -Force
    Write-Host ("ANALYSIS {0} incidents={1} clusters={2} tokens={3} {4}s" -f `
            $result.Status, $result.Incidents, $result.Clusters, $result.TotalTokens, $result.Seconds)

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::OK
            ContentType = 'application/json'
            Body        = ($result | ConvertTo-Json -Depth 20)
        })
}
catch {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [HttpStatusCode]::InternalServerError
            ContentType = 'application/json'
            Body        = (@{ error = "$($_.Exception.Message)" } | ConvertTo-Json)
        })
}
