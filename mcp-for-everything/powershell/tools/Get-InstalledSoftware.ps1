#requires -Version 7.0

<#
.SYNOPSIS
    Lists installed software on a Windows machine by reading the Uninstall
    registry keys, the same place Add/Remove Programs reads from.

.DESCRIPTION
    The registry is the oldest structured data store on the box and there is
    no web API in front of it. The Uninstall keys under HKLM (64-bit and
    32-bit) are how every inventory product on earth builds its software list.
    Reading them is a one-liner; making the result useful is a filter.

.PARAMETER Name
    Filter on display name, wildcards allowed.

.PARAMETER Publisher
    Filter on publisher, wildcards allowed.

.PARAMETER InstalledAfter
    Only return software installed on or after this date.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Display name filter, wildcards allowed')]
    [string]$Name = '*',

    [Parameter(HelpMessage = 'Publisher filter, wildcards allowed')]
    [string]$Publisher = '*',

    [Parameter(HelpMessage = 'Only software installed on or after this date')]
    [datetime]$InstalledAfter = [datetime]::MinValue
)

if (-not $IsWindows) {
    throw 'Get-InstalledSoftware reads the Windows registry and needs Windows.'
}

$keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
    ForEach-Object {
        # InstallDate is a yyyyMMdd string when it is present at all.
        $installed = $null
        if ($_.InstallDate -match '^\d{8}$') {
            $installed = [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null)
        }
        [PSCustomObject]@{
            Name        = $_.DisplayName
            Version     = $_.DisplayVersion
            Publisher   = $_.Publisher
            InstallDate = if ($installed) { $installed.ToString('yyyy-MM-dd') } else { $null }
            Is64Bit     = ($_.PSPath -notmatch 'WOW6432Node')
        }
    } |
    Where-Object { $_.Name -like $Name -and ($_.Publisher ?? '') -like $Publisher } |
    Where-Object { -not $_.InstallDate -or [datetime]$_.InstallDate -ge $InstalledAfter } |
    Sort-Object Name -Unique
