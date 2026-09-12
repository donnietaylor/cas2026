#requires -Version 7.4
#requires -Modules Az.Accounts, Az.Storage

<#
.SYNOPSIS
    Empties the Incidents and Events tables. Use between rehearsals.

.DESCRIPTION
    Incident ids are derived from the correlation key, so they are stable: running
    the story twice inside the window adds to the same incidents rather than
    making new ones. That is correct behaviour and wrong for a rehearsal, where
    you want the counts to start at zero and the tiles to appear one at a time.

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
        -Permission 'rld' -ExpiryTime (Get-Date).AddMinutes(15)).TrimStart('?')

$endpoint = "https://$StorageAccountName.table.core.windows.net"
$headers = @{ Accept = 'application/json;odata=nometadata' }

$rows = @{}
foreach ($table in 'Incidents', 'Events') {
    $rows[$table] = @((Invoke-RestMethod -Uri "$endpoint/$table()?$sas" -Headers $headers).value)
}

$total = ($rows.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
if ($total -eq 0) { Write-Host 'Already empty.' -ForegroundColor DarkGray; return }

Write-Host "About to delete $($rows.Incidents.Count) incident(s) and $($rows.Events.Count) symptom row(s) from $StorageAccountName." -ForegroundColor Yellow
if (-not $Force) {
    if ((Read-Host 'Type y to continue') -ne 'y') { Write-Host 'Cancelled.'; return }
}

foreach ($table in 'Incidents', 'Events') {
    foreach ($row in $rows[$table]) {
        $pk = [uri]::EscapeDataString(($row.PartitionKey -replace "'", "''"))
        $rk = [uri]::EscapeDataString(($row.RowKey -replace "'", "''"))
        $uri = "$endpoint/$table(PartitionKey='$pk',RowKey='$rk')?$sas"
        Invoke-RestMethod -Uri $uri -Method Delete -Headers ($headers + @{ 'If-Match' = '*' }) | Out-Null
    }
    Write-Host "  $table cleared ($($rows[$table].Count) rows)"
}

Write-Host 'Pipeline reset.' -ForegroundColor Green
