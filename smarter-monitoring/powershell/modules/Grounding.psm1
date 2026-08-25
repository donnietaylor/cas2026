<#
    Grounding: give the model facts instead of asking it to guess.

    This is the module that separates a demo from something you would actually
    run. An LLM handed twelve alert titles and nothing else will produce a
    confident, fluent, plausible root cause - and it will be guessing, because
    guessing is all you gave it room to do.

    So before we ask for judgment, we go and get:
      * what these resources actually are, and how they relate (Resource Graph)
      * what changed recently (deployments - the answer is "a deploy" far more
        often than anything else)
      * what the telemetry around the alert window actually says (Log Analytics)

    Everything here is read-only, cheap, and cached per batch.
#>

Set-StrictMode -Version Latest

function Get-GroundingContext {
    <#
    .SYNOPSIS
        Build the grounding facts for a batch of events.

    .PARAMETER Events
        The normalized events in this batch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Events,
        [switch]$SkipLogAnalytics
    )

    $resourceIds = @(
        $Events |
            Where-Object { $_.ResourceId } |
            Select-Object -ExpandProperty ResourceId -Unique
    )

    $context = [ordered]@{
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        resources   = @()
        deployments = @()
        signals     = @()
    }

    if ($resourceIds.Count -eq 0) { return [PSCustomObject]$context }

    try {
        $context.resources = @(Get-ResourceFacts -ResourceIds $resourceIds)
    }
    catch {
        Write-Warning "Resource Graph lookup failed: $($_.Exception.Message)"
    }

    try {
        $context.deployments = @(Get-RecentDeployment -ResourceIds $resourceIds -Hours 4)
    }
    catch {
        Write-Warning "Deployment lookup failed: $($_.Exception.Message)"
    }

    if (-not $SkipLogAnalytics -and $env:LOG_ANALYTICS_WORKSPACE_ID) {
        try {
            $context.signals = @(Get-CorrelatedSignal -ResourceIds $resourceIds)
        }
        catch {
            Write-Warning "Log Analytics query failed: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]$context
}

function Get-ResourceFacts {
    <#
    .SYNOPSIS
        What are these resources, who owns them, and what tier are they?

    .DESCRIPTION
        One Resource Graph query for the whole batch. Tags matter more than they
        look: "owner" and "environment" are the difference between "sql-prod-03
        is saturated" and "sql-prod-03, owned by the data team, in production,
        is saturated" - and only one of those routes correctly.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$ResourceIds)

    $quoted = ($ResourceIds | ForEach-Object { "'$($_.ToLower())'" }) -join ','

    $query = @"
Resources
| where tolower(id) in ($quoted)
| project id, name, type, location, resourceGroup, subscriptionId,
          owner = tostring(tags['owner']),
          environment = tostring(tags['environment']),
          sku = tostring(properties.sku.name)
"@

    $token = Get-AzureAccessToken -Resource 'https://management.azure.com'
    $body = @{ query = $query } | ConvertTo-Json -Depth 5

    $response = Invoke-RestMethod `
        -Uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' `
        -Method Post `
        -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } `
        -Body $body -TimeoutSec 20 -ErrorAction Stop

    return $response.data
}

function Get-RecentDeployment {
    <#
    .SYNOPSIS
        What changed in the last few hours?

    .DESCRIPTION
        If you only add one grounding source, add this one. The honest base rate
        for "why did production break" is "somebody deployed something," and a
        model that can see a deploy landed fourteen minutes before the first
        alert will find the real answer far more often than one that cannot.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$ResourceIds,
        [int]$Hours = 4
    )

    $groups = @(
        $ResourceIds |
            ForEach-Object { ($_ -split '/resourceGroups/')[1] -split '/' | Select-Object -First 1 } |
            Where-Object { $_ } |
            Select-Object -Unique
    )

    $token = Get-AzureAccessToken -Resource 'https://management.azure.com'
    $since = (Get-Date).ToUniversalTime().AddHours(-$Hours)
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($group in $groups) {
        $subscription = ($ResourceIds[0] -split '/')[2]
        $uri = "https://management.azure.com/subscriptions/$subscription/resourceGroups/$group" +
               "/providers/Microsoft.Resources/deployments?api-version=2021-04-01&`$top=10"

        $response = Invoke-RestMethod -Uri $uri -Method Get `
            -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 20 -ErrorAction Stop

        foreach ($deployment in $response.value) {
            $timestamp = [datetime]$deployment.properties.timestamp
            if ($timestamp -lt $since) { continue }
            $results.Add([PSCustomObject]@{
                    Name          = $deployment.name
                    ResourceGroup = $group
                    Timestamp     = $timestamp.ToString('o')
                    State         = $deployment.properties.provisioningState
                    MinutesAgo    = [int]((Get-Date).ToUniversalTime() - $timestamp).TotalMinutes
                })
        }
    }

    return $results | Sort-Object Timestamp -Descending
}

function Get-CorrelatedSignal {
    <#
    .SYNOPSIS
        Pull the actual telemetry around the alert window from Log Analytics.

    .DESCRIPTION
        The alert says a threshold was crossed. The logs say what was happening.
        Those are different questions, and the second one is what the on-call
        engineer would go and look at - so look at it for them, and hand the
        model the result instead of the threshold alone.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$ResourceIds,
        [int]$WindowMinutes = 15
    )

    $workspace = $env:LOG_ANALYTICS_WORKSPACE_ID
    if (-not $workspace) { throw 'LOG_ANALYTICS_WORKSPACE_ID is not set.' }

    $quoted = ($ResourceIds | ForEach-Object { "'$($_.ToLower())'" }) -join ','

    $query = @"
union isfuzzy=true AppExceptions, AppRequests, AzureDiagnostics
| where TimeGenerated > ago(${WindowMinutes}m)
| where tolower(_ResourceId) in ($quoted)
| summarize Count = count(),
            Sample = any(coalesce(column_ifexists('ExceptionType', ''),
                                  column_ifexists('OperationName', ''), ''))
          by Type, bin(TimeGenerated, 5m)
| order by Count desc
| take 25
"@

    $token = Get-AzureAccessToken -Resource 'https://api.loganalytics.io'
    $body = @{ query = $query } | ConvertTo-Json

    $response = Invoke-RestMethod `
        -Uri "https://api.loganalytics.io/v1/workspaces/$workspace/query" `
        -Method Post `
        -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } `
        -Body $body -TimeoutSec 30 -ErrorAction Stop

    $table = $response.tables[0]
    if (-not $table) { return @() }

    return $table.rows | ForEach-Object {
        $row = $_
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $table.columns.Count; $i++) {
            $obj[$table.columns[$i].name] = $row[$i]
        }
        [PSCustomObject]$obj
    }
}

Export-ModuleMember -Function Get-GroundingContext, Get-ResourceFacts,
    Get-RecentDeployment, Get-CorrelatedSignal
