#requires -Version 7.0

<#
.SYNOPSIS
    Restarts a service. Exists to prove the guardrails work - this one is
    state-changing, so the host hides it unless you explicitly allow it.

.PARAMETER Name
    Service to restart.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, HelpMessage = 'Service to restart')]
    [string]$Name
)

if ($PSCmdlet.ShouldProcess($Name, 'Restart service')) {
    [PSCustomObject]@{ Service = $Name; Action = 'Restarted'; At = (Get-Date).ToString('u') }
}
