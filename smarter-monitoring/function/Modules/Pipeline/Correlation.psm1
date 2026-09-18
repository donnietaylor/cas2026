<#
    Correlation: turn a stream of failure events into a handful of incidents.

    Two questions, asked of every event, and the writes that record the
    answers. Table access lives in Plumbing.psm1.

      Is this the same symptom?    Get-Fingerprint  -> the Events row key
      Is this the same incident?   Get-PrimaryKey   -> the Events partition,
                                   Get-IncidentId      and the Incidents row

    Both are answered from facts the event carries. No model is involved; the
    third question - is this the same PROBLEM as that other incident - needs
    one, and lives in Ai.psm1.

    IDENTITY IS DERIVED, NOT INVENTED

    An incident's id is a hash of its primary correlation key, so every worker
    that sees an event for host:sql-prod-03 computes the same id and they all
    write to the same row. That matters because a hub with two partitions hands
    events to two invocations at once: with generated ids, both would look for an
    open incident, both would miss, and both would create one. You end up with
    three "backup overran" incidents on the dashboard and a model being asked to
    clean up after us.

    Primary key order is host > resource > service > trace. Trace is last on
    purpose - it is the most precise key and the worst grouping key, since every
    request has its own. The other keys an event carries are still recorded on
    the incident for the AI pass to reason over.

    Matching for each event:
      1. known fingerprint in this incident, seen inside the window -> count it
      2. otherwise                                                  -> new symptom
    and the incident is created, or revived if it has gone quiet longer than the
    window.

    THE INCIDENT ROW STORES NO TOTALS

    No event count, no symptom count, no severity, no headline. Those are all
    computed from the symptom rows whenever something asks (Measure-Incident,
    in Plumbing.psm1). The only counter anywhere is Count on a symptom row, and
    it is the one write that has to be conditional.
#>

Import-Module (Join-Path $PSScriptRoot 'Plumbing.psm1')

function Get-Fingerprint {
    <#
    .SYNOPSIS
        What makes two events "the same failure happening again".

        Every run of digits is collapsed, so a title carrying a duration, a count
        or an address doesn't split one symptom into hundreds. "480 ms" and
        "8 ms" are the same symptom; the numbers live in the message.

        The tradeoff is real: "Port 22 closed" and "Port 443 closed" also
        collapse together. Worth it - values in titles are far more common than
        identities, and the host and source are already part of the seed.
    #>
    param([Parameter(Mandatory)]$Event)

    $title = ($Event.Title -replace '\d+', 'N')
    $seed = "$($Event.Source)|$($Event.Kind)|$title|$($Event.ResourceId)|$($Event.Host)".ToLowerInvariant()
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($seed))
    return [Convert]::ToHexString($hash).Substring(0, 16).ToLowerInvariant()
}

function Get-EventKey {
    <#
    .SYNOPSIS
        Every key an event can be correlated on. These are facts, not guesses -
        which is why no model is needed to answer the first two questions.
    #>
    param([Parameter(Mandatory)]$Event)

    # Same order as Get-PrimaryKey: whatever identifies the incident should be
    # the first thing shown under "correlated on", not a resource id nobody can
    # read from the back of a room.
    $keys = @()
    if ($Event.Host) { $keys += "host:$($Event.Host)".ToLowerInvariant() }
    if ($Event.ResourceId) { $keys += "resource:$($Event.ResourceId)".ToLowerInvariant() }
    if ($Event.Service) { $keys += "service:$($Event.Service)".ToLowerInvariant() }
    if ($Event.TraceId) { $keys += "trace:$($Event.TraceId)".ToLowerInvariant() }
    return $keys
}

function Get-PrimaryKey {
    <#
    .SYNOPSIS
        The one key that decides which incident this event belongs to.

        Host first, then resource. A dependency span that names the host it
        called belongs with that host's other failures, not with the app's -
        which is how the store-api's failing database call lands inside the
        sql-prod-03 incident instead of forming an island.

        Trace comes last because it is per-request: grouping on it would give
        every failed checkout its own incident.
    #>
    param([Parameter(Mandatory)]$Event)

    if ($Event.Host) { return "host:$($Event.Host)".ToLowerInvariant() }
    if ($Event.ResourceId) { return "resource:$($Event.ResourceId)".ToLowerInvariant() }
    if ($Event.Service) { return "service:$($Event.Service)".ToLowerInvariant() }
    if ($Event.TraceId) { return "trace:$($Event.TraceId)".ToLowerInvariant() }
    return "source:$($Event.Source)".ToLowerInvariant()
}

function Get-IncidentId {
    param([Parameter(Mandatory)][string]$PrimaryKey)
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($PrimaryKey))
    return 'inc-' + [Convert]::ToHexString($hash).Substring(0, 12).ToLowerInvariant()
}

function New-Incident {
    <#
    .SYNOPSIS
        Create the incident row, or revive it if this key has been quiet longer
        than the window. Returns 'new-incident', or $null if it was already live.
    #>
    param(
        [Parameter(Mandatory)][string]$IncidentId,
        [Parameter(Mandatory)]$Event,
        [Parameter(Mandatory)][string]$Now,
        [Parameter(Mandatory)][datetime]$Cutoff
    )

    $existing = Get-TableRow -Table 'Incidents' -Partition 'incident' -Row $IncidentId
    if ($existing -and (ConvertTo-Utc $existing.LastSeen) -ge $Cutoff -and "$($existing.Status)" -eq 'open') {
        return $null
    }

    $row = @{
        PartitionKey      = 'incident'
        RowKey            = $IncidentId
        Status            = 'open'
        CorrelationKeys   = ((Get-EventKey $Event) -join ';')
        FirstSeen         = $Now
        LastSeen          = $Now
        TouchedAt         = $Now
        # A revived incident starts over: last week's root cause is not this
        # morning's, and leaving it there would be worse than saying nothing.
        AnalyzedAt        = ''
        Assessment        = ''
        RootCause         = ''
        RecommendedAction = ''
        Confidence        = ''
        Evidence          = ''
        ParentIncidentId  = ''
    }

    if ($existing) {
        $path = "Incidents(PartitionKey='incident',RowKey='$(ConvertTo-TableLiteral $IncidentId)')"
        $null = Invoke-Table -Method Merge -Path $path -Body $row
        return 'new-incident'
    }

    try {
        $null = Invoke-Table -Method Post -Path 'Incidents' -Body $row
        return 'new-incident'
    }
    catch {
        # 409: another worker created it a millisecond ago. That is the whole
        # point of deriving the id - we both meant the same row.
        if ((Get-HttpStatus $_) -eq 409) { return $null }
        throw
    }
}

function Write-RawEvent {
    <#
    .SYNOPSIS
        Keep the event exactly as it arrived, before anything is merged away.

        The rest of this module exists to make 168 events into 13 incidents. That
        is the right thing to do and it destroys the evidence of how bad the raw
        stream was, which is the thing worth showing someone first. So the stream
        is kept too, unaggregated, in its own table.

        Partitioned by minute so a "last N minutes" read touches a handful of
        partitions. Row keys count DOWN from max ticks, so a plain listing comes
        back newest first without sorting anything.
    #>
    param([Parameter(Mandatory)]$Event, [Parameter(Mandatory)][datetime]$Now)

    $message = "$($Event.Message)"
    if ($message.Length -gt 500) { $message = $message.Substring(0, 500) }

    $descending = [DateTime]::MaxValue.Ticks - $Now.Ticks

    $null = Invoke-Table -Method Post -Path 'RawEvents' -Body @{
        PartitionKey = $Now.ToString('yyyyMMddHHmm')
        RowKey       = "$($descending.ToString('D19'))-$([guid]::NewGuid().ToString('N').Substring(0, 6))"
        Time         = $Now.ToString('o')
        Source       = "$($Event.Source)"
        Kind         = "$($Event.Kind)"
        Severity     = "$($Event.Severity)"
        Tool         = "$(if ($Event.Service) { $Event.Service } else { $Event.Source })"
        Host         = "$($Event.Host)"
        Title        = "$($Event.Title)"
        Message      = $message
    }
}

function Add-EventToIncident {
    <#
    .SYNOPSIS
        Correlate one normalized event. Returns what happened, so the caller can log it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Event,
        [int]$WindowMinutes = 15
    )

    $nowUtc = [DateTime]::UtcNow
    $now = $nowUtc.ToString('o')
    $cutoffUtc = $nowUtc.AddMinutes(-$WindowMinutes)

    $incidentId = Get-IncidentId (Get-PrimaryKey $Event)
    $fingerprint = Get-Fingerprint $Event

    $outcome = New-Incident -IncidentId $incidentId -Event $Event -Now $now -Cutoff $cutoffUtc

    $symptomPath = "Events(PartitionKey='$(ConvertTo-TableLiteral $incidentId)',RowKey='$fingerprint')"
    $symptom = Get-TableRow -Table 'Events' -Partition $incidentId -Row $fingerprint

    if (-not $outcome -and $symptom -and (ConvertTo-Utc $symptom.LastSeen) -ge $cutoffUtc) {
        # Known symptom, still inside the window: count it. This is the one
        # counter in the pipeline, so it is the one write that checks the ETag -
        # two workers adding to the same row at the same instant would otherwise
        # lose a count. 412 means someone else got there first: read, retry.
        $count = 0
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                $count = [int]$symptom.Count + 1
                $null = Invoke-Table -Method Merge -Path $symptomPath -IfMatch $symptom.'odata.etag' `
                    -Body @{ Count = $count; LastSeen = $now }
                break
            }
            catch {
                if ((Get-HttpStatus $_) -ne 412 -or $attempt -eq 6) { throw }
                Start-Sleep -Milliseconds (40 * $attempt)
                $symptom = Get-TableRow -Table 'Events' -Partition $incidentId -Row $fingerprint
            }
        }
        $result = 'deduped'
    }
    else {
        $message = "$($Event.Message)"
        if ($message.Length -gt 2000) { $message = $message.Substring(0, 2000) }

        $null = Invoke-Table -Method Post -Path 'Events' -Body @{
            PartitionKey = $incidentId
            RowKey       = $fingerprint
            Source       = $Event.Source
            Kind         = $Event.Kind
            Severity     = $Event.Severity
            Title        = $Event.Title
            Message      = $message
            Service      = $Event.Service
            Host         = $Event.Host
            ResourceId   = $Event.ResourceId
            TraceId      = $Event.TraceId
            SpanId       = $Event.SpanId
            ParentSpanId = $Event.ParentSpanId
            Count        = 1
            FirstSeen    = $now
            LastSeen     = $now
        }
        $count = 1
        $result = $outcome ?? 'new-symptom'
    }

    # Touch the incident so the dashboard sees it move and the AI pass knows to
    # look again. Nothing here is a counter, so this merge is unconditional.
    $null = Invoke-Table -Method Merge -Body @{ LastSeen = $now; TouchedAt = $now } `
        -Path "Incidents(PartitionKey='incident',RowKey='$(ConvertTo-TableLiteral $incidentId)')"

    return [PSCustomObject]@{
        IncidentId = $incidentId; Fingerprint = $fingerprint
        Outcome    = $result; Count = $count
    }
}

Export-ModuleMember -Function Add-EventToIncident, Write-RawEvent, Get-Fingerprint, Get-EventKey, Get-PrimaryKey,
Get-IncidentId, New-Incident
