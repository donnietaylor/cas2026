#requires -Version 7.0

<#
.SYNOPSIS
    Reports Windows service state and recent error-level event log entries from
    a server, via CIM. No agent installed, no API, nothing to buy.

.DESCRIPTION
    The other half of "Everything": the box itself.

    CIM/WMI has been sitting on every Windows server since NT 4, quietly able to
    answer almost any question you have about that machine. It has no REST API
    and it never will. Wrapping it takes one script.

    Runs against the local machine by default; -ComputerName uses WinRM.

.PARAMETER ComputerName
    Server to query. Defaults to the local machine.

.PARAMETER Name
    Service name filter; supports wildcards.

.PARAMETER OnlyProblems
    Return only services that are set to start automatically but are not running.

.PARAMETER IncludeRecentErrors
    Also return error-level System event log entries from the last 24 hours.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Server to query; defaults to local machine')]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter(HelpMessage = 'Service name filter, supports wildcards')]
    [string]$Name = '*',

    [Parameter(HelpMessage = 'Only auto-start services that are not running')]
    [switch]$OnlyProblems,

    [Parameter(HelpMessage = 'Include error events from the last 24 hours')]
    [switch]$IncludeRecentErrors
)

Import-Module (Join-Path $PSScriptRoot '..' 'CasDemo.psm1') -Force

if (-not $IsWindows) {
    # Keeps the repo honest on macOS/Linux and keeps rehearsal possible anywhere.
    if (Test-DemoMode) {
        return Get-DemoFallback -Name 'service-health' -Reason 'CIM is Windows-only and this host is not Windows'
    }
    throw 'Get-ServiceHealth requires Windows (CIM). Set CAS_DEMO_MODE=true to use canned data.'
}

Invoke-WithFallback -Name 'service-health' -Live {

    $cimArgs = @{ ClassName = 'Win32_Service'; ErrorAction = 'Stop' }
    if ($ComputerName -and $ComputerName -ne $env:COMPUTERNAME) {
        $cimArgs['ComputerName'] = $ComputerName
    }

    $services = Get-CimInstance @cimArgs |
        Where-Object { $_.Name -like $Name -or $_.DisplayName -like $Name } |
        ForEach-Object {
            [PSCustomObject]@{
                Name        = $_.Name
                DisplayName = $_.DisplayName
                State       = $_.State
                StartMode   = $_.StartMode
                StartName   = $_.StartName
                Unhealthy   = ($_.StartMode -eq 'Auto' -and $_.State -ne 'Running')
            }
        }

    if ($OnlyProblems) { $services = $services | Where-Object Unhealthy }

    $output = [ordered]@{
        ComputerName = $ComputerName
        QueriedAt    = (Get-Date).ToString('u')
        ServiceCount = @($services).Count
        Services     = @($services | Sort-Object Name)
    }

    if ($IncludeRecentErrors) {
        $output['RecentErrors'] = @(
            Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{
                LogName   = 'System'
                Level     = 2
                StartTime = (Get-Date).AddHours(-24)
            } -MaxEvents 20 -ErrorAction SilentlyContinue |
                ForEach-Object {
                    [PSCustomObject]@{
                        TimeCreated  = $_.TimeCreated.ToString('u')
                        ProviderName = $_.ProviderName
                        Id           = $_.Id
                        Message      = ($_.Message -split "`n")[0].Trim()
                    }
                }
        )
    }

    [PSCustomObject]$output
}
