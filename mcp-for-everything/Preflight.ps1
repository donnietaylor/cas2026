#requires -Version 7.0

<#
.SYNOPSIS
    Thirty-minutes-before checklist. Run it, fix what is red, then relax.
#>
[CmdletBinding()]
param([int]$Port = 8931)

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    $results.Add([PSCustomObject]@{ Check = $Name; Status = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail })
}

Add-Check 'PowerShell 7+' ($PSVersionTable.PSVersion.Major -ge 7) $PSVersionTable.PSVersion.ToString()

$python = Get-Command python -ErrorAction SilentlyContinue
Add-Check 'Python present' ([bool]$python) $(if ($python) { (python --version 2>&1) } else { 'not found' })

$mcp = python -c "import mcp, fastapi; print('ok')" 2>&1
Add-Check 'Python deps installed' ($mcp -match 'ok') "$mcp"

$manifestRaw = & (Join-Path $PSScriptRoot 'powershell' 'Get-ToolManifest.ps1') 2>&1
try {
    $manifest = $manifestRaw | ConvertFrom-Json
    Add-Check 'Tool manifest generates' $true "$($manifest.tools.Count) tools"
    Add-Check 'No manifest problems' ($manifest.problems.Count -eq 0) ($manifest.problems.file -join ', ')
}
catch {
    Add-Check 'Tool manifest generates' $false "$manifestRaw"
}

$portFree = -not (Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
Add-Check "Port $Port available" $portFree $(if ($portFree) { 'free' } else { 'IN USE - kill the old host' })

Add-Check 'Azure connected' ([bool](Get-AzContext -ErrorAction SilentlyContinue)) `
    ((Get-AzContext -ErrorAction SilentlyContinue).Account.Id ?? 'run Connect-AzAccount')

Add-Check 'Graph connected' ([bool](Get-MgContext -ErrorAction SilentlyContinue)) `
    ((Get-MgContext -ErrorAction SilentlyContinue).Account ?? 'run Connect-MgGraph')

Add-Check 'Demo mode OFF' ($env:CAS_DEMO_MODE -ne 'true') ($env:CAS_DEMO_MODE ?? 'unset')

$results | Format-Table | Out-String -Width 120 | Write-Host

$failed = @($results | Where-Object Status -eq 'FAIL')
if ($failed) {
    Write-Host "$($failed.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All checks passed. Go get a coffee.' -ForegroundColor Green
