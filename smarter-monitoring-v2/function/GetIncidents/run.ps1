using namespace System.Net

param($Request, $TriggerMetadata)

<#
    GET /api/incidents?view=summary|graph|incidents|symptoms&hours=2

    Four shapes, one per visual on the workbook:

      summary    one big number each - the counters strip
      graph      nodes and edges - the causality picture
      incidents  one row per incident, with display strings already composed
      symptoms   one row per symptom, carrying its incident's fields (default)

    This endpoint decides the presentation. Workbooks color and lay out what they
    are given; they are bad at composing text. So anything the story needs said -
    "23 events, 4 symptoms", "ROOT CAUSE", "reviewed, unrelated" - is said here,
    where it is a string join instead of a fight with a formatter.

    CORS for https://portal.azure.com is set on the Function App itself. Don't add
    an Access-Control-Allow-Origin header here too: the platform adds one, and two
    of them is an error in the browser.
#>

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Correlation.psm1')

$severityRank = @{ critical = 4; error = 3; warning = 2; info = 1; normal = 0 }

$view = 'symptoms'
if ($Request.Query.view) { $view = "$($Request.Query.view)".ToLowerInvariant() }
$hours = 2
if ($Request.Query.hours) { $hours = [int]$Request.Query.hours }
$cutoff = [DateTime]::UtcNow.AddHours(-$hours).ToString('o')

function Get-TableRow {
    param([string]$Table, [string]$Filter)
    $escaped = [uri]::EscapeDataString($Filter)
    return @((Invoke-Table -Method Get -Path "$Table()?`$filter=$escaped").value)
}

# Built from the code point so the source file stays plain ASCII and can't be
# mangled by whatever encoding the zip deploy decides to use.
$bullet = [char]0x2022

function Format-Count {
    param([int]$Value, [string]$Noun)
    return "$Value $Noun$(if ($Value -ne 1) { 's' })"
}

function Format-Age {
    param([string]$Iso)
    if (-not $Iso) { return '' }
    $span = [DateTime]::UtcNow - ([datetime]$Iso).ToUniversalTime()
    if ($span.TotalSeconds -lt 90) { return "$([int]$span.TotalSeconds)s ago" }
    if ($span.TotalMinutes -lt 90) { return "$([int]$span.TotalMinutes)m ago" }
    return "$([int]$span.TotalHours)h ago"
}

function Write-Json {
    param($Rows, [int]$Status = 200)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = $Status
            ContentType = 'application/json'
            Body        = ($Rows | ConvertTo-Json -Depth 5 -AsArray)
        })
}

# --- Load ------------------------------------------------------------------
try {
    $incidents = @(Get-TableRow -Table 'Incidents' -Filter "Status eq 'open' and LastSeen ge '$cutoff'")

    # One read of the symptom table, then group in memory. Cheaper than a query
    # per incident, and this endpoint gets hit every time the workbook refreshes.
    $allSymptoms = @()
    # Filter on our own LastSeen string, not the system Timestamp: it is plain
    # ISO-8601, so a string comparison sorts correctly and there is no datetime
    # literal syntax to get wrong.
    if ($incidents.Count) { $allSymptoms = @(Get-TableRow -Table 'Events' -Filter "LastSeen ge '$cutoff'") }
    $byIncident = @{}
    foreach ($symptom in $allSymptoms) {
        $key = "$($symptom.PartitionKey)"
        if (-not $byIncident.ContainsKey($key)) { $byIncident[$key] = [System.Collections.Generic.List[object]]::new() }
        $byIncident[$key].Add($symptom)
    }

    $ordered = $incidents | Sort-Object `
        @{ Expression = { $severityRank["$($_.Severity)"] ?? 0 }; Descending = $true },
    @{ Expression = { "$($_.FirstSeen)" }; Descending = $false }
}
catch {
    Write-Json @(@{ error = "$($_.Exception.Message)" }) 500
    return
}

# --- summary: the counters strip -------------------------------------------
if ($view -eq 'summary') {
    $eventTotal = ($incidents | Measure-Object EventCount -Sum).Sum
    $symptomTotal = ($incidents | Measure-Object SymptomCount -Sum).Sum
    $criticalCount = @($incidents | Where-Object { "$($_.Severity)" -in 'critical', 'error' }).Count
    # Distinct causes, not incidents carrying one. Seven incidents sharing two
    # root causes is "2 root causes found" - counting incidents would print 7 and
    # quietly turn the headline number into a restatement of "open incidents".
    $causeCount = @($incidents | ForEach-Object { "$($_.RootCause)" } |
            Where-Object { $_ } | Select-Object -Unique).Count
    $hostCount = @($allSymptoms | ForEach-Object { "$($_.Host)" } | Where-Object { $_ } | Select-Object -Unique).Count

    # Tone is a separate column so the tile can be colored by something other
    # than the number it displays. Thresholds evaluate the column they are on,
    # and "12" is not intrinsically good or bad.
    Write-Json @(
        @{ Label = 'Events ingested'; Value = "$([int]$eventTotal)"; Tone = 'info'; Sort = 1 }
        @{ Label = 'Distinct symptoms'; Value = "$([int]$symptomTotal)"; Tone = 'info'; Sort = 2 }
        @{ Label = 'Open incidents'; Value = "$($incidents.Count)"; Tone = $(if ($incidents.Count) { 'warn' } else { 'good' }); Sort = 3 }
        @{ Label = 'Needing attention'; Value = "$criticalCount"; Tone = $(if ($criticalCount) { 'bad' } else { 'good' }); Sort = 4 }
        @{ Label = 'Root causes found'; Value = "$causeCount"; Tone = $(if ($causeCount) { 'good' } else { 'info' }); Sort = 5 }
        @{ Label = 'Hosts reporting'; Value = "$hostCount"; Tone = 'info'; Sort = 6 }
    )
    return
}

# --- graph: the causality picture -------------------------------------------
# One row per incident. A row carries its node and, where it has one, the edge
# pointing at it from its cause. Incidents the AI reviewed and left alone are
# hung off a single grey hub: a workbook graph draws edges, so an unconnected
# node has nothing to render and the red herrings - the most interesting thing
# on the picture - would silently vanish.
if ($view -eq 'graph') {
    $rows = [System.Collections.Generic.List[object]]::new()
    $hub = 'reviewed-unrelated'
    $loose = 0

    foreach ($incident in $ordered) {
        $id = "$($incident.RowKey)"
        $label = "$($incident.Title)"
        if ($label.Length -gt 46) { $label = $label.Substring(0, 44) + '..' }

        $role = 'Unassessed'
        $source = ''
        if ($incident.ParentIncidentId) { $role = 'Symptom'; $source = "$($incident.ParentIncidentId)" }
        elseif ($incident.RootCause) { $role = 'ROOT CAUSE' }
        elseif ("$($incident.Assessment)" -like 'Reviewed, unrelated*') { $role = 'Unrelated'; $source = $hub; $loose++ }
        elseif ("$($incident.Assessment)" -like 'Standalone*') { $role = 'Standalone'; $source = $hub; $loose++ }
        else { $source = $hub; $loose++ }

        $rows.Add([ordered]@{
                Id       = $id
                Label    = $label
                Role     = $role
                Severity = "$($incident.Severity)"
                Events   = [int]$incident.EventCount
                Symptoms = [int]$incident.SymptomCount
                SourceId = $source
                TargetId = $id
            })
    }

    if ($loose) {
        $rows.Add([ordered]@{
                Id       = $hub
                Label    = 'Reviewed, not connected'
                Role     = "$loose incident$(if ($loose -ne 1) { 's' })"
                Severity = 'normal'
                Events   = 0
                Symptoms = 0
                SourceId = ''
                TargetId = $hub
            })
    }

    if ($rows.Count -eq 0) {
        $rows.Add([ordered]@{
                Id = 'quiet'; Label = 'All systems normal'; Role = 'nothing open'
                Severity = 'normal'; Events = 0; Symptoms = 0; SourceId = ''; TargetId = 'quiet'
            })
    }
    Write-Json $rows
    return
}

# --- incidents: one row per incident, display-ready -------------------------
if ($view -eq 'incidents') {
    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($incident in $ordered) {
        $symptoms = @($byIncident["$($incident.RowKey)"])
        $hosts = @($symptoms | ForEach-Object { if ($_.Host) { "$($_.Host)" } else { "$($_.Service)" } } |
                Where-Object { $_ } | Select-Object -Unique)
        $tools = @($symptoms | ForEach-Object { "$($_.Service)" } | Where-Object { $_ } | Select-Object -Unique)
        $keys = @("$($incident.CorrelationKeys)" -split ';' | Where-Object { $_ })

        $stats = @(
            (Format-Count ([int]$incident.EventCount) 'event')
            (Format-Count ([int]$incident.SymptomCount) 'symptom')
            (Format-Age "$($incident.LastSeen)")
        ) -join "  $bullet  "

        # Only the cause carries the explanation. Repeating the same paragraph on
        # every downstream tile is four hundred words of the same sentence on a
        # projector; "Downstream of X" is what those tiles are actually for.
        $action = "$($incident.RecommendedAction)"
        $status =
        if ($incident.ParentIncidentId) { "$($incident.Assessment)" }
        elseif ($incident.RootCause) {
            "ROOT CAUSE: $($incident.RootCause)$(if ($action) { "$bullet$bullet DO NOW: $action" })"
        }
        elseif ($incident.Assessment) {
            "$($incident.Assessment)$(if ($action) { "$bullet$bullet $action" })"
        }
        else { 'correlated on ' + ($keys -join ', ') }

        $rows.Add([ordered]@{
                IncidentId        = "$($incident.RowKey)"
                Severity          = "$($incident.Severity)"
                SeverityRank      = $severityRank["$($incident.Severity)"] ?? 0
                Headline          = "$($incident.Title)"
                Where             = ($hosts -join ', ')
                Tools             = ($tools -join ', ')
                Stats             = $stats
                Status            = $status
                EventCount        = [int]$incident.EventCount
                SymptomCount      = [int]$incident.SymptomCount
                CorrelatedOn      = ($keys -join ', ')
                LastSeen          = "$($incident.LastSeen)"
                Assessment        = "$($incident.Assessment)"
                RootCause         = "$($incident.RootCause)"
                RecommendedAction = "$($incident.RecommendedAction)"
                Confidence        = "$($incident.Confidence)"
                ParentIncidentId  = "$($incident.ParentIncidentId)"
            })
    }

    if ($rows.Count -eq 0) {
        $rows.Add([ordered]@{
                IncidentId = ''; Severity = 'normal'; SeverityRank = 0
                Headline = 'All systems normal'; Where = ''; Tools = ''
                Stats = "nothing open in the last $hours hour(s)"
                Status = 'The pipeline is running and has nothing to report.'
                EventCount = 0; SymptomCount = 0; CorrelatedOn = ''; LastSeen = ''
                Assessment = ''; RootCause = ''; RecommendedAction = ''; Confidence = ''
                ParentIncidentId = ''
            })
    }
    Write-Json $rows
    return
}

# --- symptoms: the drill-down grid ------------------------------------------
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($incident in $ordered) {
    foreach ($symptom in (@($byIncident["$($incident.RowKey)"]) | Sort-Object FirstSeen)) {
        $rows.Add([ordered]@{
                IncidentId   = "$($incident.RowKey)"
                Incident     = "$($incident.Title)"
                Severity     = "$($incident.Severity)"
                SeverityRank = $severityRank["$($incident.Severity)"] ?? 0
                Tool         = "$($symptom.Service)"
                Host         = "$(if ($symptom.Host) { $symptom.Host } else { $symptom.Service })"
                Symptom      = "$($symptom.Title)"
                Seen         = [int]$symptom.Count
                Source       = "$($symptom.Source)"
                Detail       = "$($symptom.Message)"
                LastSeen     = "$($symptom.LastSeen)"
            })
    }
}

if ($rows.Count -eq 0) {
    $rows.Add([ordered]@{
            IncidentId = ''; Incident = 'All systems normal'; Severity = 'normal'; SeverityRank = 0
            Tool = ''; Host = ''; Symptom = "No open incidents in the last $hours hour(s)"
            Seen = 0; Source = ''; Detail = ''; LastSeen = [DateTime]::UtcNow.ToString('o')
        })
}
Write-Json $rows
