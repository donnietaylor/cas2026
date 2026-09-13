<#
    Correlation: turn a stream of failure events into a handful of incidents.

    Two Azure Storage tables, reached over REST with the Function's managed
    identity (no keys, no SDK):

      Events     one row per *symptom*, not per raw event.
                 PartitionKey = incident id, RowKey = fingerprint, Count = how
                 many times it has happened. 300 identical checkout failures are
                 one row with Count 300.

      Incidents  one row per group. PartitionKey 'incident', RowKey = incident id.
                 Holds the keys it owns, first/last seen, totals, and later the
                 AI pass's root cause.

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
#>

$script:Tokens = @{}
$script:SeverityRank = @{ critical = 4; error = 3; warning = 2; info = 1 }

function Get-ResourceToken {
    <#
    .SYNOPSIS
        A bearer token for one Azure resource, cached until it is nearly stale.
    #>
    param([Parameter(Mandatory)][string]$Resource)

    $cached = $script:Tokens[$Resource]
    if ($cached -and (Get-Date) -lt $cached.Expires) { return $cached.Token }

    $token =
    if ($env:IDENTITY_ENDPOINT -and $env:IDENTITY_HEADER) {
        # Managed identity, in Azure.
        $uri = "$($env:IDENTITY_ENDPOINT)?resource=$([uri]::EscapeDataString($Resource))&api-version=2019-08-01"
        (Invoke-RestMethod -Uri $uri -Headers @{ 'X-IDENTITY-HEADER' = $env:IDENTITY_HEADER } -TimeoutSec 20).access_token
    }
    else {
        # Local: whatever Connect-AzAccount has. Az.Accounts 5+ returns a SecureString.
        $raw = (Get-AzAccessToken -ResourceUrl $Resource).Token
        if ($raw -is [securestring]) { ConvertFrom-SecureString $raw -AsPlainText } else { $raw }
    }

    $script:Tokens[$Resource] = @{ Token = $token; Expires = (Get-Date).AddMinutes(30) }
    return $token
}

function Get-StorageToken { Get-ResourceToken -Resource 'https://storage.azure.com/' }

function Invoke-Table {
    <#
    .SYNOPSIS
        One call against the Table service. $Path is everything after the
        endpoint, e.g. "Incidents()?`$filter=..." or "Events(PartitionKey='a',RowKey='b')".

    .PARAMETER IfMatch
        ETag for a conditional Merge. '*' overwrites blindly; a real ETag makes the
        write fail with 412 if someone else got there first, which is how the
        counters survive two workers updating one incident at the same time.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('Get', 'Post', 'Merge', 'Delete')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body,
        [string]$IfMatch = '*'
    )

    $endpoint = $env:TABLE_ENDPOINT
    if (-not $endpoint) { throw 'TABLE_ENDPOINT is not set.' }

    $headers = @{
        Authorization  = "Bearer $(Get-StorageToken)"
        'x-ms-version' = '2021-04-10'
        'x-ms-date'    = [DateTime]::UtcNow.ToString('R')
        # minimalmetadata, not nometadata: it costs a few bytes and returns
        # odata.etag, which the conditional merges below need.
        Accept         = 'application/json;odata=minimalmetadata'
    }
    if ($Method -in 'Merge', 'Delete') { $headers['If-Match'] = $IfMatch }
    if ($Method -eq 'Post') { $headers['Prefer'] = 'return-no-content' }

    $params = @{
        Uri         = "$($endpoint.TrimEnd('/'))/$Path"
        Method      = $Method
        Headers     = $headers
        TimeoutSec  = 20
        ContentType = 'application/json'
    }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) }

    Invoke-RestMethod @params
}

function Get-HttpStatus {
    # The status code off a terminating Invoke-RestMethod error, or 0.
    param($ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.StatusCode) { return [int]$response.StatusCode }
    return 0
}

function ConvertTo-Utc {
    <#
    .SYNOPSIS
        A timestamp off a table row, as a comparable UTC DateTime.

        Necessary because Invoke-RestMethod runs the response through
        ConvertFrom-Json, which silently turns an ISO-8601 string into a
        [datetime]. So a column we wrote as a string comes back as a date, and
        "$($row.LastSeen)" renders it in the worker's locale - "09/12/2026
        20:24:29" - which compares against an ISO cutoff as less than everything.
        Every incident then looks stale, gets revived, and its symptom inserts
        collide. Compare dates as dates.
    #>
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
    if (-not "$Value") { return [datetime]::MinValue }
    return [datetime]::Parse("$Value", [cultureinfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal)
}

function ConvertTo-TableLiteral {
    # Single quotes are escaped by doubling them in OData filters.
    param([string]$Value)
    return ($Value -replace "'", "''")
}

function Get-TableRow {
    # A point read that returns $null instead of throwing when the row isn't there.
    param([Parameter(Mandatory)][string]$Table, [Parameter(Mandatory)][string]$Partition,
        [Parameter(Mandatory)][string]$Row)
    try {
        return Invoke-Table -Method Get -Path "$Table(PartitionKey='$(ConvertTo-TableLiteral $Partition)',RowKey='$(ConvertTo-TableLiteral $Row)')"
    }
    catch {
        if ((Get-HttpStatus $_) -eq 404) { return $null }
        throw
    }
}

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
        which is why this layer needs no model.
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

function Get-OpenIncident {
    param([Parameter(Mandatory)][string]$Since)
    $filter = [uri]::EscapeDataString("Status eq 'open' and LastSeen ge '$(ConvertTo-TableLiteral $Since)'")
    return @((Invoke-Table -Method Get -Path "Incidents()?`$filter=$filter").value)
}

function Update-Incident {
    <#
    .SYNOPSIS
        Roll an event into its incident: bump the totals, widen the keys, keep the
        worst severity and its headline, and mark it touched so the AI pass knows
        to look at it.

        Conditional on the row's ETag and retried, because two workers can be
        adding to the same incident at the same instant and a blind merge would
        silently lose one of the counts.
    #>
    param(
        [Parameter(Mandatory)][string]$IncidentId,
        [Parameter(Mandatory)]$Event,
        [Parameter(Mandatory)][string]$Now,
        [switch]$NewSymptom
    )

    $path = "Incidents(PartitionKey='incident',RowKey='$(ConvertTo-TableLiteral $IncidentId)')"

    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $incident = Invoke-Table -Method Get -Path $path
        $etag = $incident.'odata.etag'

        $keys = @($incident.CorrelationKeys -split ';' | Where-Object { $_ })
        foreach ($key in Get-EventKey $Event) { if ($keys -notcontains $key) { $keys += $key } }

        # The headline follows the worst thing in the incident, not the first
        # thing. An incident that opens on "disk latency" and escalates to "pool
        # exhausted" should not still be titled "disk latency" on the dashboard.
        $severity = $incident.Severity
        $title = $incident.Title
        if (($script:SeverityRank[$Event.Severity] ?? 0) -gt ($script:SeverityRank[$severity] ?? 0)) {
            $severity = $Event.Severity
            $title = $Event.Title
        }

        $update = @{
            LastSeen        = $Now
            EventCount      = [int]$incident.EventCount + 1
            SymptomCount    = [int]$incident.SymptomCount + $(if ($NewSymptom) { 1 } else { 0 })
            Severity        = $severity
            Title           = $title
            CorrelationKeys = ($keys -join ';')
            TouchedAt       = $Now
        }

        try {
            $null = Invoke-Table -Method Merge -Path $path -Body $update -IfMatch $etag
            return
        }
        catch {
            # 412: someone else updated the row between our read and our write.
            # Read it again and reapply - the other worker's count stays.
            if ((Get-HttpStatus $_) -ne 412 -or $attempt -eq 6) { throw }
            Start-Sleep -Milliseconds (40 * $attempt)
        }
    }
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

    $path = "Incidents(PartitionKey='incident',RowKey='$(ConvertTo-TableLiteral $IncidentId)')"
    $existing = Get-TableRow -Table 'Incidents' -Partition 'incident' -Row $IncidentId

    if ($existing -and (ConvertTo-Utc $existing.LastSeen) -ge $Cutoff -and "$($existing.Status)" -eq 'open') {
        return $null
    }

    $row = @{
        PartitionKey      = 'incident'
        RowKey            = $IncidentId
        Status            = 'open'
        Title             = $Event.Title
        Severity          = $Event.Severity
        CorrelationKeys   = ((Get-EventKey $Event) -join ';')
        FirstSeen         = $Now
        LastSeen          = $Now
        TouchedAt         = $Now
        EventCount        = 0
        SymptomCount      = 0
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
        $null = Invoke-Table -Method Merge -Path $path -Body $row -IfMatch $existing.'odata.etag'
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
    $cutoff = $cutoffUtc.ToString('o')

    $incidentId = Get-IncidentId (Get-PrimaryKey $Event)
    $fingerprint = Get-Fingerprint $Event

    $outcome = New-Incident -IncidentId $incidentId -Event $Event -Now $now -Cutoff $cutoffUtc

    # Known symptom of this incident, still inside the window? Count it.
    $symptom = Get-TableRow -Table 'Events' -Partition $incidentId -Row $fingerprint
    if (-not $outcome -and $symptom -and (ConvertTo-Utc $symptom.LastSeen) -ge $cutoffUtc) {
        $path = "Events(PartitionKey='$(ConvertTo-TableLiteral $incidentId)',RowKey='$fingerprint')"
        $count = 0
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                $count = [int]$symptom.Count + 1
                $null = Invoke-Table -Method Merge -Path $path -IfMatch $symptom.'odata.etag' `
                    -Body @{ Count = $count; LastSeen = $now }
                break
            }
            catch {
                if ((Get-HttpStatus $_) -ne 412 -or $attempt -eq 6) { throw }
                Start-Sleep -Milliseconds (40 * $attempt)
                $symptom = Get-TableRow -Table 'Events' -Partition $incidentId -Row $fingerprint
            }
        }
        Update-Incident -IncidentId $incidentId -Event $Event -Now $now
        return [PSCustomObject]@{
            IncidentId = $incidentId; Fingerprint = $fingerprint
            Outcome    = 'deduped'; Count = $count
        }
    }

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
    Update-Incident -IncidentId $incidentId -Event $Event -Now $now -NewSymptom

    return [PSCustomObject]@{
        IncidentId = $incidentId; Fingerprint = $fingerprint
        Outcome    = ($outcome ?? 'new-symptom'); Count = 1
    }
}

Export-ModuleMember -Function Add-EventToIncident, Write-RawEvent, Get-Fingerprint, Get-EventKey, Get-PrimaryKey,
Get-IncidentId, Get-OpenIncident, Get-TableRow, Get-HttpStatus, Invoke-Table, Get-ResourceToken,
ConvertTo-TableLiteral, ConvertTo-Utc
