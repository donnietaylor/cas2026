<#
    Shared helpers for the demo tools.

    The important one is Get-DemoFallback. Every tool that reaches out to a real
    system (Azure, SQL, Entra) calls it when the real call fails. If CAS_DEMO_MODE
    is on, the tool returns realistic canned data and a warning saying so.

    This is not laziness. It is the difference between "the conference wifi died
    and my session is over" and "the conference wifi died, here is the same shape
    of data, let's keep going." Set CAS_DEMO_MODE=true and rehearse on a plane.
#>

function Test-DemoMode {
    <# Is the safety net armed? #>
    [CmdletBinding()]
    param()
    return ($env:CAS_DEMO_MODE -in @('1', 'true', 'True', 'yes', 'on'))
}

function Get-DemoFallback {
    <#
    .SYNOPSIS
        Return canned data for a tool when the live system is unreachable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Reason = 'Live system unavailable'
    )

    $path = Join-Path $PSScriptRoot "../data/$Name.json"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "$Reason (and no demo fallback exists at data/$Name.json)"
    }

    Write-Warning "DEMO MODE: $Reason. Returning canned data from data/$Name.json."
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function Invoke-WithFallback {
    <#
    .SYNOPSIS
        Run a live query; fall back to canned data if it fails and demo mode is on.

    .EXAMPLE
        Invoke-WithFallback -Name 'az-resources' -Live { Search-AzGraph -Query $q }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Live
    )

    try {
        return & $Live
    }
    catch {
        if (Test-DemoMode) {
            return Get-DemoFallback -Name $Name -Reason $_.Exception.Message
        }
        throw
    }
}

Export-ModuleMember -Function Test-DemoMode, Get-DemoFallback, Invoke-WithFallback
