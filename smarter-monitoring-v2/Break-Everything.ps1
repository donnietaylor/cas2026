#requires -Version 7.0

<#
.SYNOPSIS
    Breaks everything. One command, one outage.

.DESCRIPTION
    Runs the whole demo failure in order:

      1. Breaks the local store-api, so its OpenTelemetry traces start failing
         for real - failed requests, a failed dependency on sql-prod-03, and a
         timeout exception naming the host.
      2. Drives checkout traffic so those traces actually happen, and shows the
         500s in this window while they do.
      3. Fires the sixteen third-party signals from Send-Event.ps1 - the backup
         job, the disk, the locks, the pool, the certificate, and the red
         herrings.

    Which leaves three things to show: the events arriving, the app plainly
    broken, and the dashboard naming a cause nobody sent it.

    Run it again with -Fix to put the app back.

    The verb is not on the approved list. Neither is the situation.

.EXAMPLE
    ./Break-Everything.ps1

.EXAMPLE
    ./Break-Everything.ps1 -Fast      # no pauses between signals

.EXAMPLE
    ./Break-Everything.ps1 -Fix
#>
[CmdletBinding()]
param(
    [string]$AppUri = 'http://127.0.0.1:5000',
    [switch]$Fix,
    [switch]$Fast,
    [int]$Requests = 8,
    [switch]$NoApp,          # synthetic signals only - the laptop app isn't running
    [switch]$NoEvents        # break the app only - no third-party signals
)

$ErrorActionPreference = 'Stop'

function Invoke-Checkout {
    <#  A burst of real checkouts. Every one is a trace: request -> dependency
        on sql-prod-03 -> exception, all sharing an operation id.  #>
    param([int]$Count, [string]$Uri)

    $failed = 0
    for ($i = 1; $i -le $Count; $i++) {
        $time = Get-Date -Format 'HH:mm:ss'
        try {
            $response = Invoke-WebRequest -Uri "$Uri/checkout" -SkipHttpErrorCheck -TimeoutSec 15
            $code = $response.StatusCode
        }
        catch { $code = 0 }

        if ($code -ge 400 -or $code -eq 0) { $failed++ }
        $color = if ($code -eq 0) { 'DarkGray' } elseif ($code -lt 400) { 'Green' } else { 'Red' }
        $label = if ($code -eq 0) { 'unreachable' } else { $code }
        Write-Host ('  {0}  GET /checkout  {1}' -f $time, $label) -ForegroundColor $color
        Start-Sleep -Milliseconds 400
    }
    return $failed
}

function Test-App {
    param([string]$Uri)
    try { return (Invoke-RestMethod -Uri "$Uri/" -TimeoutSec 5) }
    catch { return $null }
}

$rule = '-' * 66

# --- put it back ------------------------------------------------------------
if ($Fix) {
    Write-Host ''
    Write-Host 'Healing the app' -ForegroundColor Green
    Write-Host $rule -ForegroundColor DarkGray

    if (-not (Test-App -Uri $AppUri)) {
        Write-Host "  store-api is not answering on $AppUri." -ForegroundColor Yellow
        return
    }
    $null = Invoke-RestMethod -Uri "$AppUri/fix" -TimeoutSec 10
    Write-Host '  payments: healthy' -ForegroundColor Green
    Write-Host ''
    $null = Invoke-Checkout -Count $Requests -Uri $AppUri
    Write-Host ''
    Write-Host 'Recovered. The incidents stay open until they age out of the window.' -ForegroundColor Green
    Write-Host ''
    return
}

# --- break it ---------------------------------------------------------------
Write-Host ''
Write-Host 'BREAKING EVERYTHING' -ForegroundColor Red
Write-Host $rule -ForegroundColor DarkGray

$appUp = $false
if (-not $NoApp) {
    $status = Test-App -Uri $AppUri
    if ($status) {
        $appUp = $true
        $null = Invoke-RestMethod -Uri "$AppUri/break" -TimeoutSec 10
        Write-Host '  store-api          payments backend broken' -ForegroundColor Red
    }
    else {
        Write-Host "  store-api is not answering on $AppUri - skipping the app." -ForegroundColor Yellow
        Write-Host '  (start it with: python store-api/store_api.py)' -ForegroundColor DarkGray
    }
}

# Real traffic, real traces, real failures. This is the OpenTelemetry half of
# the story and it has to happen before the synthetic signals, so that by the
# time the third-party tools "notice", the app is already down.
if ($appUp) {
    Write-Host ''
    Write-Host 'Live traffic against the broken app' -ForegroundColor Red
    Write-Host $rule -ForegroundColor DarkGray
    $failed = Invoke-Checkout -Count $Requests -Uri $AppUri
    Write-Host ''
    Write-Host ("  $failed of $Requests checkouts failed. Each one sent a trace: " +
        'request, dependency on sql-prod-03, timeout exception.') -ForegroundColor DarkGray
}

if (-not $NoEvents) {
    Write-Host ''
    Write-Host 'Third-party monitoring tools reporting' -ForegroundColor Yellow
    Write-Host $rule -ForegroundColor DarkGray
    & (Join-Path $PSScriptRoot 'Send-Event.ps1') -Story -Fast:$Fast
}

if ($appUp) {
    Write-Host ''
    Write-Host 'Still broken' -ForegroundColor Red
    Write-Host $rule -ForegroundColor DarkGray
    $null = Invoke-Checkout -Count ([Math]::Max(3, [int]($Requests / 2))) -Uri $AppUri
}

Write-Host ''
Write-Host $rule -ForegroundColor DarkGray
Write-Host 'Everything is broken.' -ForegroundColor Red
Write-Host ''
Write-Host '  the dashboard   Azure portal > Monitor > Workbooks > Monitoring pipeline'
Write-Host '  the terminal    ./Show-Incidents.ps1'
Write-Host '  put it back     ./Break-Everything.ps1 -Fix'
Write-Host ''
Write-Host '  The AI pass runs on its own within a minute, or force it now:' -ForegroundColor DarkGray
Write-Host '    Invoke-RestMethod https://func-cas26-193812.azurewebsites.net/api/analyze -Method Post' -ForegroundColor DarkGray
Write-Host ''
