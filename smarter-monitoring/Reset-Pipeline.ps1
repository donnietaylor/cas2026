#requires -Version 7.4
#requires -Modules Az.Accounts, Az.Storage

<#
.SYNOPSIS
    Empties the Incidents, Events and RawEvents tables. Use between rehearsals.

.DESCRIPTION
    Incident ids are derived from the correlation key, so they are stable: running
    the story twice inside the window adds to the same incidents rather than
    making new ones. That is correct behaviour and wrong for a rehearsal, where
    you want the counts to start at zero and the tiles to appear one at a time.

    Reads are paginated (Table Storage caps a query at 1000 rows per page and
    hands back a continuation token), and deletes go out as entity group
    transactions: up to 100 rows per HTTPS round trip, grouped by PartitionKey.
    Clearing a full rehearsal is a few seconds rather than a few minutes.

    Only the pipeline's own state is removed. Nothing in Event Hubs, Application
    Insights or the Function App is touched.

.EXAMPLE
    ./Reset-Pipeline.ps1

.EXAMPLE
    ./Reset-Pipeline.ps1 -Force     # no confirmation prompt
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-cas2026-monitoring',
    [string]$StorageAccountName,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$sub = (Get-AzContext).Subscription.Id
if (-not $sub) { throw 'Run Connect-AzAccount first.' }
if (-not $StorageAccountName) { $StorageAccountName = "stcas26$($sub.Substring(0, 6))" }

$key = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key
$sas = (New-AzStorageAccountSASToken -Context $ctx -Service Table -ResourceType Service, Container, Object `
        -Permission 'rld' -ExpiryTime (Get-Date).AddMinutes(30)).TrimStart('?')

$endpoint = "https://$StorageAccountName.table.core.windows.net"
$tables   = 'Incidents', 'Events', 'RawEvents'
$headers  = @{
    Accept                 = 'application/json;odata=nometadata'
    'x-ms-version'         = '2021-04-10'
    'DataServiceVersion'   = '3.0;NetFx'
    'MaxDataServiceVersion' = '3.0;NetFx'
}

# ---------------------------------------------------------------- read -------
# A table query returns at most 1000 rows. More than that and the service sets
# x-ms-continuation-NextPartitionKey / NextRowKey and expects them echoed back
# as query parameters. Ignore them and you silently under-count and under-clear.
function Get-AllRows {
    param([Parameter(Mandatory)][string]$Table)

    $rows = [System.Collections.Generic.List[object]]::new()
    $base = "$endpoint/$Table()?$sas&`$select=PartitionKey,RowKey"
    $next = $base

    while ($next) {
        $resp = Invoke-WebRequest -Uri $next -Headers $headers -Method Get
        foreach ($row in ($resp.Content | ConvertFrom-Json).value) { $rows.Add($row) }

        $next = $null
        if ($resp.Headers.ContainsKey('x-ms-continuation-NextPartitionKey')) {
            $npk = @($resp.Headers['x-ms-continuation-NextPartitionKey'])[0]
            $next = $base + "&NextPartitionKey=$([uri]::EscapeDataString($npk))"
            if ($resp.Headers.ContainsKey('x-ms-continuation-NextRowKey')) {
                $nrk = @($resp.Headers['x-ms-continuation-NextRowKey'])[0]
                $next += "&NextRowKey=$([uri]::EscapeDataString($nrk))"
            }
        }
    }
    return $rows
}

# --------------------------------------------------------------- delete ------
# An entity group transaction is a multipart/mixed POST to /$batch: one changeset
# holding up to 100 operations, all of which must share a PartitionKey. The line
# endings have to be CRLF - the service parses the body as raw HTTP.
function Invoke-DeleteBatch {
    param(
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)][object[]]$Rows
    )

    $batchId = "batch_$([guid]::NewGuid())"
    $setId   = "changeset_$([guid]::NewGuid())"
    $nl      = "`r`n"

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("--$batchId$nl")
    [void]$sb.Append("Content-Type: multipart/mixed; boundary=$setId$nl$nl")

    foreach ($row in $Rows) {
        $pk  = [uri]::EscapeDataString(($row.PartitionKey -replace "'", "''"))
        $rk  = [uri]::EscapeDataString(($row.RowKey -replace "'", "''"))
        $uri = "$endpoint/$Table(PartitionKey='$pk',RowKey='$rk')?$sas"

        [void]$sb.Append("--$setId$nl")
        [void]$sb.Append("Content-Type: application/http$nl")
        [void]$sb.Append("Content-Transfer-Encoding: binary$nl$nl")
        [void]$sb.Append("DELETE $uri HTTP/1.1$nl")
        [void]$sb.Append("Accept: application/json;odata=nometadata$nl")
        [void]$sb.Append("If-Match: *$nl$nl")
    }

    [void]$sb.Append("--$setId--$nl")
    [void]$sb.Append("--$batchId--$nl")

    $resp = Invoke-WebRequest -Uri ($endpoint + '/$batch?' + $sas) -Method Post `
        -ContentType "multipart/mixed; boundary=$batchId" `
        -Headers $headers -Body $sb.ToString()

    # The batch itself returns 202 even when an operation inside it failed, so
    # the per-operation status lines in the response body are the real answer.
    # 404 is fine: something else already deleted the row.
    $bad = [regex]::Matches($resp.Content, 'HTTP/1\.1 (\d{3})') |
        ForEach-Object { [int]$_.Groups[1].Value } |
        Where-Object { $_ -ge 400 -and $_ -ne 404 }

    if ($bad) {
        $snippet = $resp.Content.Substring(0, [Math]::Min(600, $resp.Content.Length))
        throw "$Table batch returned $($bad -join ', ').`n$snippet"
    }
}

function Remove-AllRows {
    param(
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows
    )

    if ($Rows.Count -eq 0) { return }
    $done = 0

    foreach ($group in ($Rows | Group-Object PartitionKey)) {
        $items = @($group.Group)
        for ($i = 0; $i -lt $items.Count; $i += 100) {
            $chunk = $items[$i..([Math]::Min($i + 99, $items.Count - 1))]
            Invoke-DeleteBatch -Table $Table -Rows $chunk
            $done += $chunk.Count
            Write-Host "`r  $Table cleared ($done/$($Rows.Count) rows)" -NoNewline
        }
    }
    Write-Host ''
}

# ----------------------------------------------------------------- run -------
$rows = @{}
foreach ($table in $tables) { $rows[$table] = @(Get-AllRows -Table $table) }

$total = ($rows.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
if ($total -eq 0) { Write-Host 'Already empty.' -ForegroundColor DarkGray; return }

Write-Host ("About to delete $($rows.Incidents.Count) incident(s), $($rows.Events.Count) symptom row(s) " +
    "and $($rows.RawEvents.Count) raw event(s) from $StorageAccountName.") -ForegroundColor Yellow
if (-not $Force) {
    if ((Read-Host 'Type y to continue') -ne 'y') { Write-Host 'Cancelled.'; return }
}

foreach ($table in $tables) { Remove-AllRows -Table $table -Rows $rows[$table] }

Write-Host 'Pipeline reset.' -ForegroundColor Green
