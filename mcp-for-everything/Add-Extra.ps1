#requires -Version 7.0

<#
.SYNOPSIS
    Copies a tool from powershell/extras into powershell/tools so it goes live.
    Tab-completes the extras by name. -Reset removes everything it added.

.EXAMPLE
    .\Add-Extra.ps1 Test-IsItDns

.EXAMPLE
    .\Add-Extra.ps1 Get-OutageExcuse, Test-IsItDns

.EXAMPLE
    .\Add-Extra.ps1 -Reset
#>
[CmdletBinding(DefaultParameterSetName = 'Add')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Add')]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete)
        $root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        Get-ChildItem (Join-Path $root 'powershell' 'extras') -File -ErrorAction SilentlyContinue |
            Where-Object Name -match '\.ps1(\.txt)?$' |
            ForEach-Object { $_.Name -replace '\.ps1(\.txt)?$' } |
            Where-Object { $_ -like "$wordToComplete*" }
    })]
    [string[]]$Name,

    [Parameter(Mandatory, ParameterSetName = 'Reset')]
    [switch]$Reset
)

$extras = Join-Path $PSScriptRoot 'powershell' 'extras'
$tools  = Join-Path $PSScriptRoot 'powershell' 'tools'

# .ps1 extras are finished tools; .ps1.txt are the typed-live fallbacks. Both become .ps1 in tools/.
$available = Get-ChildItem $extras -File | Where-Object Name -match '\.ps1(\.txt)?$'

if ($Reset) {
    # Extras and session tools have no names in common, so anything matching an extra was added by this script.
    $names = $available.Name -replace '\.ps1(\.txt)?$', '.ps1'
    Get-ChildItem $tools -File | Where-Object Name -in $names | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName
        Write-Host "Removed $($_.Name)" -ForegroundColor DarkGray
    }
    return
}

foreach ($n in $Name) {
    $src = $available | Where-Object { ($_.Name -replace '\.ps1(\.txt)?$') -eq $n } | Select-Object -First 1
    if (-not $src) {
        Write-Warning "No extra named '$n'. Available: $(($available.Name -replace '\.ps1(\.txt)?$') -join ', ')"
        continue
    }

    $dest = Join-Path $tools "$n.ps1"
    Copy-Item -LiteralPath $src.FullName -Destination $dest -Force

    # The host re-reads the manifest when the file count or newest mtime in tools/ changes.
    # Copy-Item keeps the source's old timestamp, so stamp it now.
    (Get-Item -LiteralPath $dest).LastWriteTime = Get-Date

    Write-Host "Live: $n" -ForegroundColor Green
}
