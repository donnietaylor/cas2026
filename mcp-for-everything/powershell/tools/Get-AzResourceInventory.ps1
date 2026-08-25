#requires -Version 7.0

<#
.SYNOPSIS
    Inventories Azure resources across your subscriptions using Resource Graph.
    Ask things like "what public IPs do we have in East US that aren't attached
    to anything" and get a real answer from your real tenant.

.DESCRIPTION
    Uses Azure Resource Graph, which is the right tool for this: one KQL query
    across every subscription you can see, in about a second. Az.ResourceGraph
    is the only Az module this needs - do not import the whole Az meta-module,
    it takes long enough to load that the audience will notice.

.PARAMETER ResourceType
    Azure resource type to filter on, e.g. microsoft.compute/virtualmachines.

.PARAMETER Location
    Azure region to filter on, e.g. eastus.

.PARAMETER Top
    Maximum number of resources to return.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Azure resource type, e.g. microsoft.compute/virtualmachines')]
    [string]$ResourceType,

    [Parameter(HelpMessage = 'Azure region, e.g. eastus')]
    [string]$Location,

    [ValidateRange(1, 200)]
    [int]$Top = 25
)

Import-Module (Join-Path $PSScriptRoot '..' 'CasDemo.psm1') -Force

$filters = @()
if ($ResourceType) { $filters += "type =~ '$ResourceType'" }
if ($Location) { $filters += "location =~ '$Location'" }
$where = if ($filters) { '| where ' + ($filters -join ' and ') } else { '' }

$query = @"
Resources
$where
| project name, type, location, resourceGroup, subscriptionId, tags
| order by name asc
| limit $Top
"@

Invoke-WithFallback -Name 'az-resources' -Live {
    Import-Module Az.ResourceGraph -ErrorAction Stop

    $results = Search-AzGraph -Query $query -ErrorAction Stop

    $results | ForEach-Object {
        [PSCustomObject]@{
            Name          = $_.name
            Type          = $_.type
            Location      = $_.location
            ResourceGroup = $_.resourceGroup
            Owner         = $_.tags.owner ?? '(untagged)'
            Environment   = $_.tags.environment ?? '(untagged)'
        }
    }
}
