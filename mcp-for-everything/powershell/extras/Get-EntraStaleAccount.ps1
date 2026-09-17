#requires -Version 7.0

<#
.SYNOPSIS
    Finds Entra ID accounts that have not signed in recently. The demo where the
    room goes quiet and someone asks "wait, should an AI be able to do that?"
    - which is exactly the question worth asking out loud.

.DESCRIPTION
    Deliberately read-only, deliberately scoped, deliberately audited.

    The point of this tool in the session is not the data. It is that the
    interesting security question about MCP is not the protocol - it is which
    identity the tool runs as. This server should hold a service principal with
    User.Read.All and nothing else. If it holds User.ReadWrite.All because that
    was easier, you have built a very polite way to disable your CEO's account.

.PARAMETER InactiveDays
    Flag accounts with no interactive sign-in in this many days.

.PARAMETER IncludeGuests
    Include guest (B2B) accounts in the results.

.PARAMETER Top
    Maximum number of accounts to return.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Days of inactivity to flag on')]
    [ValidateRange(1, 3650)]
    [int]$InactiveDays = 90,

    [Parameter(HelpMessage = 'Include guest (B2B) accounts')]
    [switch]$IncludeGuests,

    [ValidateRange(1, 200)]
    [int]$Top = 25
)

Import-Module (Join-Path $PSScriptRoot '..' 'CasDemo.psm1') -Force

$cutoff = (Get-Date).AddDays(-$InactiveDays).ToUniversalTime()

Invoke-WithFallback -Name 'entra-stale-accounts' -Live {
    Import-Module Microsoft.Graph.Users -ErrorAction Stop

    if (-not (Get-MgContext)) {
        throw 'Not connected to Microsoft Graph. Run Connect-MgGraph -Scopes User.Read.All,AuditLog.Read.All'
    }

    $filter = "signInActivity/lastSignInDateTime le $($cutoff.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    if (-not $IncludeGuests) { $filter += " and userType eq 'Member'" }

    Get-MgUser -Filter $filter -Top $Top -All:$false `
               -Property 'displayName,userPrincipalName,userType,accountEnabled,signInActivity' `
               -ErrorAction Stop |
        ForEach-Object {
            $last = $_.SignInActivity.LastSignInDateTime
            [PSCustomObject]@{
                DisplayName       = $_.DisplayName
                UserPrincipalName = $_.UserPrincipalName
                UserType          = $_.UserType
                Enabled           = $_.AccountEnabled
                LastSignIn        = if ($last) { $last.ToString('u') } else { 'never' }
                DaysInactive      = if ($last) { [int]((Get-Date) - $last).TotalDays } else { $null }
            }
        }
}
