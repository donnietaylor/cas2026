using namespace System.Net

param($Request, $TriggerMetadata)

<#
    GET /api/incidents?view=raw|summary|sources|tree|incidents|symptoms&hours=2

    Shapes, one per visual on the workbook:

      raw        every event as it arrived, nothing merged - the firehose
      summary    the funnel - four numbers, one per stage of the pipeline
      sources    events per reporting tool, for the bar chart
      tree       cause -> incident -> symptom, flat rows for a grouped grid
      incidents  one row per incident (tiles)
      symptoms   one row per symptom (default)

    This endpoint decides the presentation. Workbooks color and lay out what they
    are given; they are bad at composing text. So anything the story needs said -
    "23 events, 4 symptoms", "ROOT CAUSE", "reviewed, unrelated" - is said here,
    where it is a string join instead of a fight with a formatter.

    CORS for https://portal.azure.com is set on the Function App itself. Don't add
    an Access-Control-Allow-Origin header here too: the platform adds one, and two
    of them is an error in the browser.
#>

Import-Module (Join-Path $PSScriptRoot '..' 'Modules' 'Pipeline' 'Plumbing.psm1')

$severityRank = @{ critical = 4; error = 3; warning = 2; info = 1; normal = 0 }

$view = 'symptoms'
if ($Request.Query.view) { $view = "$($Request.Query.view)".ToLowerInvariant() }
$hours = 2
if ($Request.Query.hours) { $hours = [int]$Request.Query.hours }
$cutoff = [DateTime]::UtcNow.AddHours(-$hours).ToString('o')

function Find-TableRow {
    # A filter query. Not the module's Get-TableRow, which is a point read.
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
    $incidents = @(Find-TableRow -Table 'Incidents' -Filter "Status eq 'open' and LastSeen ge '$cutoff'")

    # One read of the symptom table, then group in memory. Cheaper than a query
    # per incident, and this endpoint gets hit every time the workbook refreshes.
    $allSymptoms = @()
    # Filter on our own LastSeen string, not the system Timestamp: it is plain
    # ISO-8601, so a string comparison sorts correctly and there is no datetime
    # literal syntax to get wrong.
    if ($incidents.Count) { $allSymptoms = @(Find-TableRow -Table 'Events' -Filter "LastSeen ge '$cutoff'") }
    $byIncident = @{}
    foreach ($symptom in $allSymptoms) {
        $key = "$($symptom.PartitionKey)"
        if (-not $byIncident.ContainsKey($key)) { $byIncident[$key] = [System.Collections.Generic.List[object]]::new() }
        $byIncident[$key].Add($symptom)
    }

    # Severity, headline and totals are not stored on the incident row; they
    # are worked out from its symptoms here, the same way the AI brief does it.
    foreach ($incident in $incidents) {
        $null = Measure-Incident -Incident $incident -Symptoms @($byIncident["$($incident.RowKey)"])
    }

    $ordered = $incidents | Sort-Object `
        @{ Expression = { $severityRank["$($_.Severity)"] ?? 0 }; Descending = $true },
    @{ Expression = { "$($_.FirstSeen)" }; Descending = $false }
}
catch {
    Write-Json @(@{ error = "$($_.Exception.Message)" }) 500
    return
}

# --- raw: the firehose, before any of this happened --------------------------
# Deliberately unhelpful. No grouping, no counts, no severity ordering - just
# what arrived, newest first, the way it lands in a console at 3am. This is the
# "can you spot the cause" screen, and it only works if it is genuinely hard to
# read.
if ($view -eq 'raw') {
    $bucket = [DateTime]::UtcNow.AddHours(-$hours).ToString('yyyyMMddHHmm')
    $filter = [uri]::EscapeDataString("PartitionKey ge '$bucket'")
    $arrived = @((Invoke-Table -Method Get -Path "RawEvents()?`$filter=$filter").value)

    $rows = $arrived |
        Sort-Object { (ConvertTo-Utc $_.Time) } -Descending |
        Select-Object -First 500 |
        ForEach-Object {
            [ordered]@{
                Time     = (ConvertTo-Utc $_.Time).ToLocalTime().ToString('HH:mm:ss')
                Severity = "$($_.Severity)"
                Source   = "$($_.Source)"
                Tool     = "$($_.Tool)"
                Host     = "$(if ($_.Host) { $_.Host } else { $_.Tool })"
                Event    = "$($_.Title)"
                Detail   = "$($_.Message)"
            }
        }

    if (-not $rows) {
        $rows = @([ordered]@{
                Time = ''; Severity = 'normal'; Source = ''; Tool = ''; Host = ''
                Event = "Nothing has arrived in the last $hours hour(s)"; Detail = ''
            })
    }
    Write-Json @($rows)
    return
}

# --- summary: the counters strip -------------------------------------------
if ($view -eq 'summary') {
    $eventTotal = ($incidents | Measure-Object EventCount -Sum).Sum
    $symptomTotal = ($incidents | Measure-Object SymptomCount -Sum).Sum
    # Distinct causes, not incidents carrying one. Seven incidents sharing two
    # root causes is "2 root causes" - counting incidents would print 7 and
    # quietly turn the headline number into a restatement of "open incidents".
    $causeCount = @($incidents | ForEach-Object { "$($_.RootCause)" } |
            Where-Object { $_ } | Select-Object -Unique).Count

    # The funnel, in the order the pipeline does the work. Every number is
    # smaller than the one before it, and that shrinking is the whole argument:
    # raw events, then what is actually distinct, then what is actually one
    # problem, then what to go and fix. Tone drives the tile colour, since
    # thresholds evaluate the column they sit on and "13" is not good or bad.
    Write-Json @(
        @{ Label = 'Events ingested'; Value = "$([int]$eventTotal)"; Tone = 'info'; Sort = 1 }
        @{ Label = 'Unique symptoms'; Value = "$([int]$symptomTotal)"; Tone = 'info'; Sort = 2 }
        @{ Label = 'Correlated incidents'; Value = "$($incidents.Count)"; Tone = $(if ($incidents.Count) { 'warn' } else { 'good' }); Sort = 3 }
        @{ Label = 'Root causes'; Value = "$causeCount"; Tone = $(if ($causeCount) { 'good' } else { 'info' }); Sort = 4 }
    )
    return
}

# --- sources: what reported, and how loudly ---------------------------------
if ($view -eq 'sources') {
    $rows = $allSymptoms | Group-Object { "$($_.Service)" } | Where-Object { $_.Name } |
        ForEach-Object {
            @{
                Tool   = $_.Name
                Events = [int](($_.Group | Measure-Object Count -Sum).Sum)
            }
        } | Sort-Object { $_.Events } -Descending

    if (-not $rows) { $rows = @(@{ Tool = 'nothing reporting'; Events = 0 }) }
    Write-Json @($rows)
    return
}

# --- tree: cause -> incident -> symptom -------------------------------------
# One row per symptom, carrying the two labels the grid groups on. Flat, because
# a workbook grid builds its own tree from repeated column values - the grouped
# columns are then hidden, so the repetition never reaches the screen.
if ($view -eq 'tree') {
    $rows = [System.Collections.Generic.List[object]]::new()

    # Cause first, then its downstream incidents, then everything reviewed and
    # left alone. Grids preserve the order they are given.
    $byId = @{}
    foreach ($incident in $incidents) { $byId["$($incident.RowKey)"] = $incident }

    $causes = @($ordered | Where-Object { $_.RootCause -and -not $_.ParentIncidentId })
    $order = [System.Collections.Generic.List[object]]::new()
    $placed = @{}

    foreach ($cause in $causes) {
        $order.Add(@{ Incident = $cause; Cause = $cause; Rank = 0 })
        $placed["$($cause.RowKey)"] = $true
        foreach ($child in ($ordered | Where-Object { "$($_.ParentIncidentId)" -eq "$($cause.RowKey)" })) {
            $order.Add(@{ Incident = $child; Cause = $cause; Rank = 1 })
            $placed["$($child.RowKey)"] = $true
        }
    }
    foreach ($incident in $ordered) {
        if ($placed["$($incident.RowKey)"]) { continue }
        $order.Add(@{ Incident = $incident; Cause = $null; Rank = 2 })
    }

    $group = 0
    $lastCause = '~'
    foreach ($entry in $order) {
        $incident = $entry.Incident
        $cause = $entry.Cause

        if ($cause) {
            $causeId = "$($cause.RowKey)"
            $action = "$($cause.RecommendedAction)"
            $cluster = "ROOT CAUSE  $($cause.RootCause)"
            if ($action) { $cluster += "     DO NOW  $action" }
        }
        else {
            $causeId = 'unrelated'
            $cluster = 'REVIEWED, NOT CONNECTED  -  no mechanism links these to anything else'
        }
        if ($causeId -ne $lastCause) { $group++; $lastCause = $causeId }

        $role = switch ($entry.Rank) {
            0 { 'cause' }
            1 { 'symptom of the above' }
            default { if ($incident.RootCause) { 'standalone' } else { 'unrelated' } }
        }

        # The role rides in the incident's label rather than its own column: the
        # grid repeats a column's value on every child row, and "symptom of the
        # above" printed eleven times is exactly the noise this is meant to cut.
        $label = switch ($entry.Rank) {
            0 { "CAUSE  -  $($incident.Title)" }
            1 { "symptom  -  $($incident.Title)" }
            default { "$($incident.Title)" }
        }

        foreach ($symptom in (@($byIncident["$($incident.RowKey)"]) | Sort-Object { -[int]$_.Count })) {
            $rows.Add([ordered]@{
                    Cluster  = $cluster
                    Incident = $label
                    Role     = $role
                    Severity = "$($incident.Severity)"
                    Tool     = "$($symptom.Service)"
                    Host     = "$(if ($symptom.Host) { $symptom.Host } else { $symptom.Service })"
                    Symptom  = "$($symptom.Title)"
                    Seen     = [int]$symptom.Count
                    Order    = $group * 1000 + $entry.Rank
                })
        }
    }

    if ($rows.Count -eq 0) {
        $rows.Add([ordered]@{
                Cluster = 'ALL SYSTEMS NORMAL'; Incident = 'Nothing open'; Role = ''
                Severity = 'normal'; Tool = ''; Host = ''; Symptom = "Nothing in the last $hours hour(s)"
                Seen = 0; Order = 0
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
