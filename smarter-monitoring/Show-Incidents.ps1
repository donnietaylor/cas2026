#requires -Version 7.4
#requires -Modules Az.Accounts, Az.Storage

<#
.SYNOPSIS
    Prints what the pipeline has correlated: incidents, and the symptoms under each.

.DESCRIPTION
    Reads the Incidents and Events tables directly. A short-lived read-only SAS is
    minted from the account key, so it works whether or not your sign-in has been
    given a data-plane role on the storage account.

    Once the AI pass is in, root cause and recommended action show up here too.

.EXAMPLE
    ./Show-Incidents.ps1

.EXAMPLE
    ./Show-Incidents.ps1 -Hours 24 -All
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-cas2026-monitoring',
    [string]$StorageAccountName,
    [int]$Hours = 2,
    [switch]$All          # include closed incidents
)

$ErrorActionPreference = 'Stop'

$sub = (Get-AzContext).Subscription.Id
if (-not $sub) { throw 'Run Connect-AzAccount first.' }
if (-not $StorageAccountName) { $StorageAccountName = "stcas26$($sub.Substring(0, 6))" }

$key = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key
$sas = (New-AzStorageAccountSASToken -Context $ctx -Service Table -ResourceType Service, Container, Object `
        -Permission 'rl' -ExpiryTime (Get-Date).AddMinutes(15)).TrimStart('?')

$endpoint = "https://$StorageAccountName.table.core.windows.net"

function Get-Rows {
    param([string]$Table, [string]$Filter)
    $uri = "$endpoint/$Table()?$sas"
    if ($Filter) { $uri += '&$filter=' + [uri]::EscapeDataString($Filter) }
    return @((Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json;odata=nometadata' }).value)
}

$since = [DateTime]::UtcNow.AddHours(-$Hours).ToString('o')
$filter = "LastSeen ge '$since'"
if (-not $All) { $filter += " and Status eq 'open'" }

$incidents = Get-Rows -Table 'Incidents' -Filter $filter | Sort-Object FirstSeen
if (-not $incidents) {
    Write-Host "No incidents in the last $Hours hour(s)." -ForegroundColor DarkGray
    return
}

$severityColor = @{ critical = 'Red'; error = 'Red'; warning = 'Yellow'; info = 'Gray' }

foreach ($incident in $incidents) {
    $color = $severityColor[[string]$incident.Severity] ?? 'Gray'
    $first = ([datetime]$incident.FirstSeen).ToLocalTime().ToString('HH:mm:ss')
    $last = ([datetime]$incident.LastSeen).ToLocalTime().ToString('HH:mm:ss')

    Write-Host ''
    Write-Host ('{0}  {1}' -f $incident.RowKey, $incident.Severity.ToUpper()) -ForegroundColor $color
    Write-Host ('  {0}' -f $incident.Title)
    Write-Host ('  {0} events over {1} symptom(s), {2} to {3}' -f `
            $incident.EventCount, $incident.SymptomCount, $first, $last) -ForegroundColor DarkGray

    $keys = @("$($incident.CorrelationKeys)" -split ';' | Where-Object { $_ })
    if ($keys) { Write-Host ('  correlated on: {0}' -f ($keys -join ', ')) -ForegroundColor DarkGray }

    # Written by the AI pass; absent until it has run.
    if ($incident.Assessment) {
        $tone = if ($incident.RootCause) { 'Cyan' } else { 'DarkGray' }
        Write-Host ('  {0}' -f $incident.Assessment) -ForegroundColor $tone
    }
    if ($incident.RootCause) {
        Write-Host ''
        Write-Host ('  ROOT CAUSE  ({0} confidence)' -f $incident.Confidence) -ForegroundColor Cyan
        Write-Host ('  {0}' -f $incident.RootCause)
        if ($incident.RecommendedAction) { Write-Host ('  DO NOW: {0}' -f $incident.RecommendedAction) -ForegroundColor Cyan }
        if ($incident.Evidence) { Write-Host ('  because: {0}' -f $incident.Evidence) -ForegroundColor DarkGray }
    }

    Write-Host ''
    foreach ($symptom in (Get-Rows -Table 'Events' -Filter "PartitionKey eq '$($incident.RowKey)'" | Sort-Object FirstSeen)) {
        $where = if ($symptom.Host) { $symptom.Host } elseif ($symptom.Service) { $symptom.Service } else { '-' }
        Write-Host ('    x{0,-4} {1,-12} {2,-16} {3}' -f `
                $symptom.Count, $symptom.Source, $where, $symptom.Title) -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host ('{0} incident(s), {1} event(s) total.' -f `
        $incidents.Count, (($incidents | Measure-Object EventCount -Sum).Sum)) -ForegroundColor Green
