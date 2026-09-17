#requires -Version 7.0

<#
.SYNOPSIS
    Runs one tool exactly the way the host does, without the host or the AI.
    The first thing to reach for when a tool misbehaves.

.DESCRIPTION
    Pipes the JSON arguments into _invoke.ps1 over real stdin (a child pwsh),
    which is what the Python host does. Piping into _invoke.ps1 directly from a
    PowerShell prompt does not work - PowerShell binds pipeline input to
    parameters, it does not feed Console.In - so use this instead.

.PARAMETER Name
    Tool name, i.e. the script file name without .ps1. Tab-completes.

.PARAMETER Arguments
    JSON object of arguments, or a hashtable.

.PARAMETER Raw
    Print the JSON envelope instead of a table.

.EXAMPLE
    .\Invoke-Tool.ps1 Get-Greeting '{"Name":"Donnie","Style":"Texan"}'
    .\Invoke-Tool.ps1 Read-LegacyReport @{ Status = 'HELD' }
    .\Invoke-Tool.ps1 Get-SqlInventory @{ BelowReorderPoint = $true } -Raw
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        Get-ChildItem (Join-Path $PSScriptRoot 'powershell' 'tools') -Filter "$word*.ps1" | ForEach-Object BaseName
    })]
    [string]$Name,

    [Parameter(Position = 1)]
    [object]$Arguments = '{}',

    [switch]$Raw
)

$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'powershell' 'tools' "$Name.ps1"
if (-not (Test-Path -LiteralPath $tool)) {
    # Allow a path too, so the fallback/ scripts can be tested before they are tools.
    if (Test-Path -LiteralPath $Name) { $tool = (Resolve-Path $Name).Path }
    else { throw "No tool called '$Name' in powershell/tools/ and no file at that path." }
}
if ([IO.Path]::GetExtension($tool) -ne '.ps1') {
    # PowerShell will hand a .txt to the shell's file association rather than run it.
    $copy = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetFileNameWithoutExtension($tool) + '.ps1')
    Copy-Item -LiteralPath $tool -Destination $copy -Force
    $tool = $copy
}

$json = if ($Arguments -is [string]) { $Arguments } else { $Arguments | ConvertTo-Json -Compress }
$pwsh = (Get-Process -Id $PID).Path

$envelope = $json | & $pwsh -NoProfile -NonInteractive -NoLogo -File (Join-Path $PSScriptRoot 'powershell' '_invoke.ps1') -ToolPath $tool

if ($Raw) { return $envelope }

$r = $envelope | ConvertFrom-Json
foreach ($w in $r.warnings) { Write-Warning $w }
if (-not $r.ok) {
    Write-Host "FAILED: $($r.error.message)" -ForegroundColor Red
    if ($r.error.scriptLine) { Write-Host "   at: $($r.error.scriptLine)" -ForegroundColor DarkGray }
    return
}
Write-Host "$($r.tool): $($r.count) result(s) in $($r.durationMs) ms" -ForegroundColor Cyan
$r.result | Format-Table -AutoSize | Out-String -Width 200
