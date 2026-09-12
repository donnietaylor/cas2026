#requires -Version 7.0

<#
.SYNOPSIS
    Calls the store API's /checkout on a loop, so there's steady traffic to break.

.EXAMPLE
    ./Start-Traffic.ps1

    # In another terminal:
    Invoke-RestMethod http://127.0.0.1:5000/break
    Invoke-RestMethod http://127.0.0.1:5000/fix
#>
[CmdletBinding()]
param(
    [string]$BaseUri = 'http://127.0.0.1:5000',
    [double]$IntervalSeconds = 1
)

Write-Host "Calling $BaseUri/checkout every $IntervalSeconds s. Ctrl+C to stop.`n"

while ($true) {
    $time = Get-Date -Format 'HH:mm:ss'
    try {
        $response = Invoke-WebRequest -Uri "$BaseUri/checkout" -SkipHttpErrorCheck -TimeoutSec 10
        $color = if ($response.StatusCode -lt 400) { 'Green' } else { 'Red' }
        Write-Host "$time  checkout  $($response.StatusCode)" -ForegroundColor $color
    }
    catch {
        Write-Host "$time  store API not reachable - is store_api.py running?" -ForegroundColor Yellow
    }
    Start-Sleep -Milliseconds ([int]($IntervalSeconds * 1000))
}
