<#
    Plumbing: everything the pipeline needs that knows nothing about correlation.

    Azure Table Storage over REST with the Function's managed identity (no keys,
    no SDK), the bearer-token cache behind it, one shared query, and the small
    conversions every other module leans on. Nothing here decides what belongs
    together; if a function in this file starts to, it has wandered out of
    Correlation.psm1.

    Two Azure Storage tables, reached the same way:

      Events     one row per *symptom*, not per raw event.
                 PartitionKey = incident id, RowKey = fingerprint, Count = how
                 many times it has happened. 300 identical checkout failures are
                 one row with Count 300.

      Incidents  one row per group. PartitionKey 'incident', RowKey = incident id.
                 Holds the keys it owns, first/last seen, totals, and later the
                 AI pass's root cause.

      RawEvents  every event exactly as it arrived, partitioned by minute.

    Plus Measure-Incident, the one read-side calculation everyone shares.
#>

$script:Tokens = @{}

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

function Get-OpenIncident {
    param([Parameter(Mandatory)][string]$Since)
    $filter = [uri]::EscapeDataString("Status eq 'open' and LastSeen ge '$(ConvertTo-TableLiteral $Since)'")
    return @((Invoke-Table -Method Get -Path "Incidents()?`$filter=$filter").value)
}

function Measure-Incident {
    <#
    .SYNOPSIS
        What the incident row deliberately does not store: its severity, its
        headline, and its totals. Worked out from the symptom rows every time
        something asks, and attached to the incident object as properties.

        Kept off the row so that nothing on it is a counter two workers could
        race to update. The dashboard, the AI brief and Show-Incidents all call
        this, so they cannot disagree about what an incident looks like.
    #>
    param(
        [Parameter(Mandatory)]$Incident,
        [AllowEmptyCollection()][object[]]$Symptoms = @()
    )

    $rank = @{ critical = 4; error = 3; warning = 2; info = 1 }
    $worst = $Symptoms |
        Sort-Object { -($rank["$($_.Severity)"] ?? 0) }, { -[int]$_.Count } |
        Select-Object -First 1

    $Incident | Add-Member -Force -NotePropertyMembers @{
        Severity     = "$(if ($worst) { $worst.Severity } else { 'info' })"
        Title        = "$(if ($worst) { $worst.Title } else { $Incident.RowKey })"
        EventCount   = [int](($Symptoms | Measure-Object Count -Sum).Sum)
        SymptomCount = [int]$Symptoms.Count
    }
    return $Incident
}

Export-ModuleMember -Function Invoke-Table, Get-TableRow, Get-OpenIncident, Measure-Incident, Get-ResourceToken,
Get-StorageToken, Get-HttpStatus, ConvertTo-TableLiteral, ConvertTo-Utc
