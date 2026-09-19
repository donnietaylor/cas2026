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
Add-Check 'Running on Windows' $IsWindows 'CIM, registry, netstat and quser demos need it'

# Prefer host\.venv over whatever 'python' happens to be on PATH: a fresh terminal
# has the global interpreter, which does not have the host's dependencies.
$venvPython = Join-Path $PSScriptRoot 'host' '.venv' 'Scripts' 'python.exe'
if (Test-Path $venvPython) {
    $pythonExe = $venvPython
    $pySource  = 'host\.venv'
}
else {
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    $pySource  = 'PATH (no venv found)'
}
Add-Check 'Python present' ([bool]$pythonExe) $(if ($pythonExe) { '{0} from {1}' -f ((& $pythonExe --version 2>&1 | Out-String).Trim()), $pySource } else { 'not found' })

# Out-String collapses this to ONE string. Array -match returns matching elements,
# not a boolean, and Add-Check then chokes on an Object[].
$depOut = if ($pythonExe) { (& $pythonExe -c "import mcp, fastapi; print('ok')" 2>&1 | Out-String).Trim() } else { 'no interpreter' }
Add-Check 'Python deps installed' ([bool]($depOut -match 'ok')) $depOut

$manifestRaw = & (Join-Path $PSScriptRoot 'powershell' 'Get-ToolManifest.ps1') 2>&1
try {
    $manifest = $manifestRaw | ConvertFrom-Json
    Add-Check 'Tool manifest generates' $true "$($manifest.tools.Count) tools"
    Add-Check 'No manifest problems' ($manifest.problems.Count -eq 0) ($manifest.problems.file -join ', ')
    Add-Check 'Live-add tool not already present' (-not ($manifest.tools.name -contains 'Get-LoggedOnUser')) 'delete tools/Get-LoggedOnUser.ps1 from the last rehearsal'
}
catch {
    Add-Check 'Tool manifest generates' $false "$manifestRaw"
}

$portFree = -not (Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue)
Add-Check "Port $Port available" $portFree $(if ($portFree) { 'free' } else { 'IN USE - kill the old host' })

$sqlOk = $false
if ($env:SQL_CONNECTION_STRING) {
    try {
        Import-Module SqlServer -ErrorAction Stop
        $null = Invoke-Sqlcmd -ConnectionString $env:SQL_CONNECTION_STRING -Query 'SELECT 1' -ErrorAction Stop -QueryTimeout 5
        $sqlOk = $true
    } catch { }
}
Add-Check 'SQL reachable' $sqlOk $(if ($sqlOk) { 'ok' } elseif ($env:SQL_CONNECTION_STRING) { 'connection failed - demo mode will cover it' } else { 'SQL_CONNECTION_STRING not set - demo mode will cover it' })

Add-Check 'Demo mode OFF' ($env:CAS_DEMO_MODE -ne 'true') ($env:CAS_DEMO_MODE ?? 'unset')
Add-Check 'Audit log empty' (-not (Test-Path (Join-Path $PSScriptRoot 'logs' 'audit.jsonl'))) 'Remove-Item logs/audit.jsonl'

$results | Format-Table | Out-String -Width 120 | Write-Host

$failed = @($results | Where-Object Status -eq 'FAIL')
if ($failed) {
    Write-Host "$($failed.Count) check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All checks passed.' -ForegroundColor Green
