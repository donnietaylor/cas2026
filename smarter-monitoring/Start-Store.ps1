<#
.SYNOPSIS
    Starts (or stops) the store-api demo app and, optionally, its traffic loop.

.DESCRIPTION
    - Creates store-api\.venv and installs requirements.txt if the venv is missing.
    - Opens store_api.py in its own window titled "store-api" so its log is visible.
    - With -Traffic, also opens Start-Traffic.ps1 in a window titled "store-traffic".
    - Waits for port 5000, makes one warm-up checkout, and prints the URLs.
    Running it again while the store is up just reports that it's running.

    No Azure sign-in needed: store_api.py has its App Insights connection string
    built in (APPLICATIONINSIGHTS_CONNECTION_STRING overrides it if set).

.EXAMPLE
    .\Start-Store.ps1 -Traffic     # store + traffic loop
.EXAMPLE
    .\Start-Store.ps1 -Stop        # close both windows
#>
[CmdletBinding(DefaultParameterSetName = 'Start')]
param(
    [Parameter(ParameterSetName = 'Start')][switch]$Traffic,
    [Parameter(ParameterSetName = 'Stop')][switch]$Stop
)

$ErrorActionPreference = 'Stop'

$storeDir  = Join-Path $PSScriptRoot 'store-api'
$py        = Join-Path $storeDir '.venv\Scripts\python.exe'
$appPath   = Join-Path $storeDir 'store_api.py'
$trafficPs1 = Join-Path $storeDir 'Start-Traffic.ps1'
$stateFile = Join-Path ([IO.Path]::GetTempPath()) 'store-api.windows.json'
$port      = 5000                        # store_api.py: app.run(host="127.0.0.1", port=5000)
$baseUri   = "http://127.0.0.1:$port"    # 127.0.0.1, not localhost - avoids the IPv6-first delay

function Get-Listener {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Start-Window {
    param([string]$Title, [string]$Command)
    $full    = "`$Host.UI.RawUI.WindowTitle = '$Title'; $Command"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($full))
    Start-Process pwsh -ArgumentList '-NoLogo', '-NoExit', '-EncodedCommand', $encoded -PassThru
}

# ---------------------------------------------------------------- Stop
if ($Stop) {
    if (Test-Path $stateFile) {
        foreach ($id in (Get-Content $stateFile | ConvertFrom-Json)) {
            Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        }
        Remove-Item $stateFile -ErrorAction SilentlyContinue
    }
    $l = Get-Listener
    if ($l) { Stop-Process -Id $l.OwningProcess -Force -ErrorAction SilentlyContinue }
    Write-Host "store-api stopped." -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------- Already running?
if (Get-Listener) {
    $state = try { (Invoke-RestMethod "$baseUri/" -TimeoutSec 5).payments } catch { 'unknown' }
    Write-Host "store-api is already running at $baseUri (payments: $state)" -ForegroundColor Green
    Write-Host "Stop it with: .\Start-Store.ps1 -Stop" -ForegroundColor DarkGray
    return
}

# ---------------------------------------------------------------- venv
if (-not (Test-Path $py)) {
    Write-Host 'Creating venv and installing requirements...' -ForegroundColor Cyan
    $venv = Join-Path $storeDir '.venv'
    if (Get-Command py -ErrorAction SilentlyContinue) { py -3 -m venv $venv } else { python -m venv $venv }
    & $py -m pip install --quiet --upgrade pip
    & $py -m pip install --quiet -r (Join-Path $storeDir 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'pip install failed - check network and requirements.txt' }
}

# ---------------------------------------------------------------- Launch store
$env:PYTHONUNBUFFERED = '1'   # inherited by the child window, so the Flask log shows live
$windows = @()
$store = Start-Window -Title 'store-api' -Command "Set-Location '$storeDir'; & '$py' '$appPath'"
$windows += $store.Id

$up = $false
foreach ($i in 1..40) {
    Start-Sleep -Milliseconds 500
    if (Get-Listener) { $up = $true; break }
    if ($store.HasExited) { break }
}
$windows | ConvertTo-Json | Set-Content $stateFile
if (-not $up) {
    throw "store-api did not start listening on port $port within 20 s - check the 'store-api' window."
}

# Warm-up so the first checkout on stage isn't the cold one
$r = Invoke-WebRequest "$baseUri/checkout" -SkipHttpErrorCheck -TimeoutSec 10
$color = if ($r.StatusCode -lt 400) { 'Green' } else { 'Yellow' }
Write-Host "warm-up /checkout -> $($r.StatusCode)" -ForegroundColor $color

# ---------------------------------------------------------------- Traffic loop
if ($Traffic) {
    $t = Start-Window -Title 'store-traffic' -Command "& '$trafficPs1' -BaseUri '$baseUri'"
    $windows += $t.Id
    $windows | ConvertTo-Json | Set-Content $stateFile
}

Write-Host ''
Write-Host "store-api running at $baseUri" -ForegroundColor Green
Write-Host "  Break:  .\Break-Everything.ps1        (or $baseUri/break)"
Write-Host "  Fix:    .\Break-Everything.ps1 -Fix   (or $baseUri/fix)"
Write-Host "  Stop:   .\Start-Store.ps1 -Stop" -ForegroundColor DarkGray
