#requires -Version 7.0

<#
.SYNOPSIS
    Prints the generated tool manifest as a table. Demo 2's opening move.
#>
[CmdletBinding()]
param([switch]$Json)

$manifest = & (Join-Path $PSScriptRoot 'powershell' 'Get-ToolManifest.ps1') | ConvertFrom-Json

if ($Json) { $manifest | ConvertTo-Json -Depth 20; return }

$manifest.tools | ForEach-Object {
    [PSCustomObject]@{
        Tool       = $_.name
        Access     = if ($_.readOnly) { 'read-only' } else { 'CHANGES STATE' }
        Parameters = ($_.inputSchema.properties.PSObject.Properties.Name -join ', ')
        Required   = ($_.inputSchema.required -join ', ')
    }
} | Format-Table | Out-String -Width 160
# Fixed width rather than -AutoSize: predictable on a projector, and it still
# renders when there is no console attached (piping to a file, CI checks).

if ($manifest.problems) {
    Write-Host "`nProblems:" -ForegroundColor Yellow
    $manifest.problems | ForEach-Object { Write-Host "  $($_.file): $($_.error)" -ForegroundColor Yellow }
}
