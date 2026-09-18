<#
    The third question: is this the same PROBLEM as that other incident?

    Correlation.psm1 already did everything that can be done with facts -
    same fingerprint, same host, same resource. What it cannot do is read
    "Nightly backup of sql-prod-03 still running" on backup-01 and connect it to
    "Disk read latency 480 ms" on sql-prod-03, because those two share no key.
    The link exists only in the English.

    So this pass hands every open incident to the model at once and asks three
    questions:

        which of these are one problem
        which one is the cause
        what should the on-call person do first

    and, just as importantly, which of them are unrelated. A correlator that
    connects everything is as useless as one that connects nothing, and the
    firewall's packet loss during carrier maintenance is there to be left alone.

    Results are written back onto the incident rows. Nothing here creates or
    merges incidents - Correlation.psm1 owns identity, and a model that
    can rewrite identity is a model that can lose your data.
#>

Import-Module (Join-Path $PSScriptRoot 'Plumbing.psm1')

$script:MetaPartition = 'meta'
$script:MetaRow = 'analysis'

function Invoke-OpenAI {
    <#
    .SYNOPSIS
        One chat completion against Azure OpenAI, authenticated with the Function's
        managed identity. No key anywhere.
    #>
    param(
        [Parameter(Mandatory)][string]$System,
        [Parameter(Mandatory)][string]$User,
        [int]$MaxTokens = 2000
    )

    $endpoint = $env:AZURE_OPENAI_ENDPOINT
    $deployment = $env:AZURE_OPENAI_DEPLOYMENT
    if (-not $endpoint -or -not $deployment) { throw 'AZURE_OPENAI_ENDPOINT or AZURE_OPENAI_DEPLOYMENT is not set.' }

    $uri = "$($endpoint.TrimEnd('/'))/openai/deployments/$deployment/chat/completions?api-version=2024-10-21"

    $body = @{
        messages        = @(
            @{ role = 'system'; content = $System }
            @{ role = 'user'; content = $User }
        )
        # Zero temperature: on stage the same events should produce the same
        # answer twice in a row.
        temperature     = 0
        max_tokens      = $MaxTokens
        response_format = @{ type = 'json_object' }
    }

    $response = Invoke-RestMethod -Uri $uri -Method Post -TimeoutSec 120 -ContentType 'application/json' `
        -Headers @{ Authorization = "Bearer $(Get-ResourceToken -Resource 'https://cognitiveservices.azure.com/')" } `
        -Body ($body | ConvertTo-Json -Depth 10)

    return [PSCustomObject]@{
        Content = $response.choices[0].message.content
        Usage   = $response.usage
    }
}

function ConvertFrom-ModelJson {
    # response_format asks for pure JSON, but a fenced block costs nothing to survive.
    param([string]$Text)
    $clean = "$Text".Trim()
    if ($clean -match '(?s)```(?:json)?\s*(.+?)\s*```') { $clean = $Matches[1] }
    return $clean | ConvertFrom-Json -Depth 20
}

$script:SystemPrompt = @'
You are the correlation stage of an IT monitoring pipeline. You are given the
incidents that are currently open. Each one has already been de-duplicated and
grouped by shared hosts and resources, so incidents
that share a host are ALREADY one incident. Your job is the part that needs
judgement.

Decide three things.

1. GROUPING. Which of these incidents are manifestations of a single underlying
   problem?

   Do not look for a shared host or a shared resource. Anything that shared one
   has ALREADY been grouped before you saw it. Every grouping left for you to
   make is between incidents on different hosts, reported by different tools,
   with nothing in common but their words. "No direct host or service link" is
   therefore never a reason to leave incidents ungrouped - it is the normal state
   of every pair you are being asked about.

   The link lives in the evidence text. Look for an entity named in one
   incident's evidence that is the subject of another: a job that says it is
   reading from a host that is itself reporting trouble; a certificate,
   gateway or load balancer named as the path that other services fail through;
   a dependency named in an error message that matches another incident's
   subject. A device that terminates or fronts traffic for other services is
   connected to their failures even though it shares no host with them.

   What is NOT a reason to group: two things failing at the same time.
   Infrastructure is always partly on fire, and coincidence is common.

2. CAUSE. Within a group, which incident is the cause and which are downstream?
   The cause is frequently the LOWEST severity item in the group - a warning
   about a job that overran, on a host nobody is paging about, while the
   criticals are all downstream symptoms. Do not assume the loudest is the cause.

3. ACTION. For each group, the single most useful thing an on-call engineer
   should do first to shorten time to resolution. Be concrete and operational:
   name the job, service, host or setting to act on. "Investigate the database"
   is useless. "Kill job SQL-NIGHTLY-FULL on backup-01, then recycle the
   application pool" is useful.

A CLUSTER MUST CONTAIN AT LEAST TWO INCIDENTS. A cluster is a claim that
separate incidents are one problem. An incident with no mechanism connecting it
to any other goes in "unrelated" - including when it is a real and serious
problem on its own. "Unrelated" does not mean "unimportant", it means "not part
of a larger picture".

Both mistakes cost the on-call engineer real time, and they are not symmetric in
how they look. Grouping things that merely coincide sends people chasing a
cause that does not exist. Splitting one outage into six incidents is the
problem this pipeline was built to solve, and doing it while writing "no direct
host link" as the reason is the worst answer available, because the shared host
was never going to be there.

Things that almost always belong in unrelated: capacity and utilization trends
that are below any failure threshold, pending reboots and patch state, known or
scheduled maintenance, test artifacts, and anything that is not currently
causing a failure. Do not manufacture a cause for these. Say what it is, in one
line, and move on.

Ground everything in the evidence text you are given. Do not invent hosts, jobs,
error codes or timings that do not appear in it. If the evidence is too thin to
support a conclusion, say so and use low confidence.

Reply with JSON only, in exactly this shape:

{
  "clusters": [
    {
      "incidentIds": ["inc-aaa", "inc-bbb"],
      "causeIncidentId": "inc-aaa",
      "rootCause": "one or two sentences, plain English, naming the mechanism",
      "recommendedAction": "the first concrete step, naming what to act on",
      "confidence": "high | medium | low",
      "evidence": "the specific facts from the input that support this, briefly"
    }
  ],
  "unrelated": [
    {
      "incidentId": "inc-ccc",
      "assessment": "one line on what this is and why it stands alone",
      "nextStep": "optional - one concrete step, only if there is an obvious one"
    }
  ]
}

Every incident id you were given must appear exactly once, in a cluster or in
unrelated.
'@

function Get-IncidentBrief {
    <#
    .SYNOPSIS
        What the model gets to see: the incidents, and the evidence under each.

        Trimmed deliberately. Row keys, ETags and correlation-key strings are
        pipeline plumbing - they add tokens and invite the model to reason about
        our data model instead of the outage.
    #>
    param([Parameter(Mandatory)]$Incidents, [int]$MaxSymptoms = 6)

    $brief = foreach ($incident in $Incidents) {
        $filter = [uri]::EscapeDataString("PartitionKey eq '$(ConvertTo-TableLiteral $incident.RowKey)'")
        $all = @((Invoke-Table -Method Get -Path "Events()?`$filter=$filter").value)
        # Attaches Severity, Title and the totals to $incident; the caller's
        # copy is the same object, so it can read the headline back later.
        $null = Measure-Incident -Incident $incident -Symptoms $all
        $symptoms = $all | Sort-Object { [int]$_.Count } -Descending | Select-Object -First $MaxSymptoms

        [ordered]@{
            id        = "$($incident.RowKey)"
            severity  = "$($incident.Severity)"
            headline  = "$($incident.Title)"
            firstSeen = (ConvertTo-Utc $incident.FirstSeen).ToString('o')
            lastSeen  = (ConvertTo-Utc $incident.LastSeen).ToString('o')
            events    = [int]$incident.EventCount
            evidence  = @(foreach ($symptom in $symptoms) {
                    $text = "$($symptom.Message)"
                    if ($text.Length -gt 400) { $text = $text.Substring(0, 400) + '...' }
                    [ordered]@{
                        reportedBy = "$($symptom.Service)"
                        host       = "$($symptom.Host)"
                        what       = "$($symptom.Title)"
                        detail     = $text
                        timesSeen  = [int]$symptom.Count
                    }
                })
        }
    }
    return @($brief)
}

function Write-IncidentVerdict {
    <#
    .SYNOPSIS
        Write one incident's verdict back. A merge only touches the fields it
        sends, and none of these is a counter, so it is unconditional.

        TouchedAt is deliberately NOT set here. It is the "changed since the last
        analysis" marker; setting it would make every pass schedule the next one.
    #>
    param([Parameter(Mandatory)][string]$IncidentId, [Parameter(Mandatory)][hashtable]$Fields)

    $path = "Incidents(PartitionKey='incident',RowKey='$(ConvertTo-TableLiteral $IncidentId)')"
    try { $null = Invoke-Table -Method Merge -Path $path -Body $Fields }
    catch {
        # 404: the row was reset out from under us mid-pass. Nothing to say.
        if ((Get-HttpStatus $_) -ne 404) { throw }
    }
}

function Invoke-IncidentAnalysis {
    <#
    .SYNOPSIS
        Analyse the currently open incidents and write the verdicts back.

    .PARAMETER Force
        Run even when nothing has changed since the last pass. The scheduled run
        skips a quiet minute; the demo button does not want to be told "nothing
        has changed" in front of an audience.
    #>
    [CmdletBinding()]
    param(
        [int]$WindowMinutes = 60,
        [switch]$Force
    )

    $started = [DateTime]::UtcNow
    $cutoff = $started.AddMinutes(-$WindowMinutes).ToString('o')
    $incidents = @(Get-OpenIncident -Since $cutoff)

    if ($incidents.Count -lt 1) {
        return [PSCustomObject]@{ Status = 'nothing-open'; Incidents = 0; Clusters = 0 }
    }

    $meta = Get-TableRow -Table 'Incidents' -Partition $script:MetaPartition -Row $script:MetaRow
    $lastRun = ConvertTo-Utc $meta.LastRun
    $newest = ($incidents | ForEach-Object { ConvertTo-Utc $_.TouchedAt } | Sort-Object -Descending | Select-Object -First 1)
    if (-not $Force -and $meta.LastRun -and $newest -le $lastRun) {
        return [PSCustomObject]@{ Status = 'no-change'; Incidents = $incidents.Count; Clusters = 0 }
    }

    $brief = Get-IncidentBrief -Incidents $incidents
    $result = Invoke-OpenAI -System $script:SystemPrompt -User ($brief | ConvertTo-Json -Depth 8)
    $verdict = ConvertFrom-ModelJson $result.Content

    $now = [DateTime]::UtcNow.ToString('o')
    $byId = @{}
    foreach ($incident in $incidents) { $byId["$($incident.RowKey)"] = $incident }
    $seen = @{}

    foreach ($cluster in @($verdict.clusters)) {
        $ids = @($cluster.incidentIds | Where-Object { $byId.ContainsKey("$_") })
        if (-not $ids) { continue }

        # A cluster of one is not a correlation, whatever the model decided to
        # call it. Keep its reasoning as an assessment, but do not let it count
        # as a root cause - otherwise "root causes found" becomes a count of
        # incidents and the number stops meaning anything.
        if ($ids.Count -eq 1) {
            $seen[$ids[0]] = $true
            Write-IncidentVerdict -IncidentId $ids[0] -Fields @{
                RootCause         = ''
                RecommendedAction = "$($cluster.recommendedAction)"
                Confidence        = "$($cluster.confidence)"
                Evidence          = "$($cluster.evidence)"
                Assessment        = "Standalone - $($cluster.rootCause)"
                ParentIncidentId  = ''
                AnalyzedAt        = $now
            }
            continue
        }

        $causeId = "$($cluster.causeIncidentId)"
        if (-not $byId.ContainsKey($causeId)) { $causeId = $ids[0] }
        $causeHeadline = "$($byId[$causeId].Title)"

        foreach ($id in $ids) {
            $seen[$id] = $true
            $isCause = $id -eq $causeId
            Write-IncidentVerdict -IncidentId $id -Fields @{
                RootCause         = "$($cluster.rootCause)"
                RecommendedAction = "$($cluster.recommendedAction)"
                Confidence        = "$($cluster.confidence)"
                Evidence          = "$($cluster.evidence)"
                Assessment        = $(if ($isCause) {
                        if ($ids.Count -gt 1) { "Cause of $($ids.Count - 1) other incident(s)" } else { 'Standalone problem' }
                    }
                    else { "Downstream of: $causeHeadline" })
                ParentIncidentId  = $(if ($isCause) { '' } else { $causeId })
                AnalyzedAt        = $now
            }
        }
    }

    foreach ($item in @($verdict.unrelated)) {
        $id = "$($item.incidentId)"
        if (-not $byId.ContainsKey($id) -or $seen[$id]) { continue }
        $seen[$id] = $true
        Write-IncidentVerdict -IncidentId $id -Fields @{
            RootCause         = ''
            RecommendedAction = "$($item.nextStep)"
            Confidence        = ''
            Evidence          = ''
            Assessment        = "Reviewed, unrelated - $($item.assessment)"
            ParentIncidentId  = ''
            AnalyzedAt        = $now
        }
    }

    # Anything the model forgot. Saying nothing is better than leaving a verdict
    # from a previous, different outage sitting on the tile.
    foreach ($id in $byId.Keys) {
        if ($seen[$id]) { continue }
        Write-IncidentVerdict -IncidentId $id -Fields @{
            Assessment = 'Not assessed in the last pass'
            AnalyzedAt = $now
        }
    }

    $marker = @{
        PartitionKey = $script:MetaPartition
        RowKey       = $script:MetaRow
        LastRun      = $started.ToString('o')
        Incidents    = $incidents.Count
        Clusters     = @($verdict.clusters | Where-Object { @($_.incidentIds).Count -gt 1 }).Count
        PromptTokens = [int]$result.Usage.prompt_tokens
        TotalTokens  = [int]$result.Usage.total_tokens
    }
    if ($meta) { $null = Invoke-Table -Method Merge -Path "Incidents(PartitionKey='$script:MetaPartition',RowKey='$script:MetaRow')" -Body $marker }
    else { $null = Invoke-Table -Method Post -Path 'Incidents' -Body $marker }

    return [PSCustomObject]@{
        Status      = 'analyzed'
        Incidents   = $incidents.Count
        Clusters    = @($verdict.clusters | Where-Object { @($_.incidentIds).Count -gt 1 }).Count
        Unrelated   = @($verdict.unrelated).Count
        TotalTokens = [int]$result.Usage.total_tokens
        Seconds     = [math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 1)
        Verdict     = $verdict
    }
}

Export-ModuleMember -Function Invoke-IncidentAnalysis, Invoke-OpenAI, Get-IncidentBrief, ConvertFrom-ModelJson
