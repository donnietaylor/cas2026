#requires -Version 7.4
#requires -Modules Az.Accounts, Az.Resources, Az.OperationalInsights, Az.ApplicationInsights, Az.EventHub, Az.Monitor, Az.CognitiveServices, Az.Storage, Az.Functions

<#
.SYNOPSIS
    Azure plumbing for the Smarter Monitoring session.

.DESCRIPTION
    Creates, if missing:
      - Resource group
      - Log Analytics workspace + Application Insights (workspace-based)
      - Event Hubs namespace (Standard) + hub + 'pipeline' consumer group
      - Send-only key on the hub, for the local event script
      - Diagnostic setting: App Insights requests/dependencies/exceptions -> Event Hubs
      - Action group -> Event Hubs (common alert schema) + one failed-requests alert
      - Azure OpenAI (AIServices resource) + one model deployment
      - The pipeline: storage account + Events/Incidents tables, a second App
        Insights for the Function's own logs, and a Flex Consumption Function App
        (PowerShell 7.4) with a managed identity and its role assignments
    Then publishes the Function code (Publish-Function.ps1).

    Safe to re-run: every step checks for the resource first.

.EXAMPLE
    Connect-AzAccount
    ./Deploy-Azure.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-cas2026-monitoring',
    [string]$Location = 'eastus',
    [string]$HubName = 'monitoring-events',
    [string]$ModelName = 'gpt-4.1-mini',
    [string]$ModelVersion = '2025-04-14',
    [int]$ModelCapacity = 30,  # thousands of tokens per minute
    [switch]$SkipPublish
)

$ErrorActionPreference = 'Stop'
# The Az cmdlets live in modules, which don't inherit this script's
# $ErrorActionPreference - so a failed New-Az* would log an error and keep going.
# Setting it as a default parameter reaches them. Explicit -ErrorAction still wins.
# (Clone first, so this stays inside the script and doesn't leak into your session.)
$PSDefaultParameterValues = $PSDefaultParameterValues.Clone()
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

$sub = (Get-AzContext).Subscription.Id
if (-not $sub) { throw 'Run Connect-AzAccount first.' }

# Globally unique names need a suffix. First 6 chars of the subscription ID:
# stable across re-runs, different per subscription.
$sfx = $sub.Substring(0, 6)
$names = @{
    Workspace    = "log-cas26-$sfx"
    AppInsights  = "appi-cas26-$sfx"
    PipelineLogs = "appi-cas26-pipeline-$sfx"
    Storage      = "stcas26$sfx"
    FunctionApp  = "func-cas26-$sfx"
    Namespace    = "evhns-cas26-$sfx"
    OpenAI       = "aoai-cas26-$sfx"
    ActionGroup  = 'ag-cas26-eventhub'
    Alert        = 'app-failed-requests'
    SenderRule   = 'local-sender'
}

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# --- Resource group ---------------------------------------------------------
Step "Resource group $ResourceGroupName"
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    $null = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

# --- Log Analytics + Application Insights -----------------------------------
Step "Log Analytics $($names.Workspace)"
$law = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $names.Workspace -ErrorAction SilentlyContinue
if (-not $law) {
    $law = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $names.Workspace `
        -Location $Location -Sku PerGB2018 -RetentionInDays 30
}

Step "Application Insights $($names.AppInsights)"
$appi = Get-AzApplicationInsights -ResourceGroupName $ResourceGroupName -Name $names.AppInsights -ErrorAction SilentlyContinue
if (-not $appi) {
    $appi = New-AzApplicationInsights -ResourceGroupName $ResourceGroupName -Name $names.AppInsights `
        -Location $Location -Kind web -WorkspaceResourceId $law.ResourceId
}

# --- Event Hubs -------------------------------------------------------------
Step "Event Hubs $($names.Namespace)/$HubName"
$ns = Get-AzEventHubNamespace -ResourceGroupName $ResourceGroupName -Name $names.Namespace -ErrorAction SilentlyContinue
if (-not $ns) {
    $ns = New-AzEventHubNamespace -ResourceGroupName $ResourceGroupName -Name $names.Namespace `
        -Location $Location -SkuName Standard -SkuCapacity 1
}

$hub = Get-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace -Name $HubName -ErrorAction SilentlyContinue
if (-not $hub) {
    $hub = New-AzEventHub -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace -Name $HubName `
        -PartitionCount 2 -RetentionTimeInHour 24 -CleanupPolicy Delete
}

# The pipeline reads with its own consumer group, leaving $Default free for
# watching events in the portal's Data Explorer.
if (-not (Get-AzEventHubConsumerGroup -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
            -EventHubName $HubName -Name 'pipeline' -ErrorAction SilentlyContinue)) {
    $null = New-AzEventHubConsumerGroup -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
        -EventHubName $HubName -Name 'pipeline'
}

# Send-only key for the local script (source 3).
if (-not (Get-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
            -EventHubName $HubName -Name $names.SenderRule -ErrorAction SilentlyContinue)) {
    $null = New-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
        -EventHubName $HubName -Name $names.SenderRule -Rights @('Send')
}
$senderKey = Get-AzEventHubKey -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
    -EventHubName $HubName -Name $names.SenderRule

# --- Source 1: App Insights -> Event Hubs -----------------------------------
Step 'Diagnostic setting: App Insights -> Event Hubs'
# Diagnostic settings need a namespace-level rule with Manage/Send/Listen;
# RootManageSharedAccessKey is created with every namespace.
$rootRule = Get-AzEventHubAuthorizationRule -ResourceGroupName $ResourceGroupName -NamespaceName $names.Namespace `
    -Name 'RootManageSharedAccessKey'
$logs = 'AppRequests', 'AppDependencies', 'AppExceptions' |
    ForEach-Object { New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $_ }
$null = New-AzDiagnosticSetting -Name 'to-eventhub' -ResourceId $appi.Id `
    -EventHubAuthorizationRuleId $rootRule.Id -EventHubName $HubName -Log $logs

# --- Source 2: Azure Monitor alert -> Event Hubs ----------------------------
Step "Action group $($names.ActionGroup) + alert $($names.Alert)"
$receiver = New-AzActionGroupEventHubReceiverObject -Name 'monitoring-events' -SubscriptionId $sub `
    -EventHubNameSpace $names.Namespace -EventHubName $HubName -UseCommonAlertSchema $true
$ag = New-AzActionGroup -ResourceGroupName $ResourceGroupName -Name $names.ActionGroup -Location 'Global' `
    -GroupShortName 'cas26mon' -EventHubReceiver $receiver -Enabled

$criteria = New-AzMetricAlertRuleV2Criteria -MetricName 'requests/failed' -MetricNamespace 'microsoft.insights/components' `
    -TimeAggregation Count -Operator GreaterThan -Threshold 0
$null = Add-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroupName -Name $names.Alert `
    -TargetResourceId $appi.Id -Condition $criteria -ActionGroupId $ag.Id -Severity 1 `
    -WindowSize (New-TimeSpan -Minutes 5) -Frequency (New-TimeSpan -Minutes 1) `
    -Description 'The app is returning failed requests.'

# --- Azure OpenAI -----------------------------------------------------------
Step "Azure OpenAI $($names.OpenAI) + $ModelName"
$aoai = Get-AzCognitiveServicesAccount -ResourceGroupName $ResourceGroupName -Name $names.OpenAI -ErrorAction SilentlyContinue
if (-not $aoai) {
    $aoai = New-AzCognitiveServicesAccount -ResourceGroupName $ResourceGroupName -Name $names.OpenAI `
        -Type AIServices -SkuName S0 -Location $Location -CustomSubdomainName $names.OpenAI -Force
}

# No clean cmdlet for model deployments, so one REST call. PUT is create-or-update.
$body = @{
    sku        = @{ name = 'GlobalStandard'; capacity = $ModelCapacity }
    properties = @{
        model                = @{ format = 'OpenAI'; name = $ModelName; version = $ModelVersion }
        versionUpgradeOption = 'NoAutoUpgrade'
    }
} | ConvertTo-Json -Depth 5
$response = Invoke-AzRestMethod -Method PUT -Payload $body `
    -Path "$($aoai.Id)/deployments/$($ModelName)?api-version=2025-06-01"
if ($response.StatusCode -ge 400) { throw "Model deployment failed: $($response.Content)" }

# --- Pipeline: storage + tables ---------------------------------------------
Step "Storage $($names.Storage) + RawEvents/Events/Incidents tables"
$st = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $names.Storage -ErrorAction SilentlyContinue
if (-not $st) {
    $st = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $names.Storage -Location $Location `
        -SkuName Standard_LRS -Kind StorageV2 -MinimumTlsVersion TLS1_2 -AllowBlobPublicAccess $false
}
# The correlation memory, in the order the pipeline narrows it down:
#   RawEvents  every failure exactly as it arrived, nothing merged
#   Events     one row per distinct symptom, with a count
#   Incidents  one row per group of symptoms
foreach ($table in 'RawEvents', 'Events', 'Incidents') {
    if (-not (Get-AzStorageTable -Name $table -Context $st.Context -ErrorAction SilentlyContinue)) {
        $null = New-AzStorageTable -Name $table -Context $st.Context
    }
}

# --- Pipeline: the Function's own logs --------------------------------------
# A separate App Insights on purpose. If the Function logged into the one that
# streams to Event Hubs, its own telemetry would land in the hub, trigger the
# Function, produce more telemetry... forever.
Step "Application Insights $($names.PipelineLogs) (Function logs)"
$pipelineLogs = Get-AzApplicationInsights -ResourceGroupName $ResourceGroupName -Name $names.PipelineLogs -ErrorAction SilentlyContinue
if (-not $pipelineLogs) {
    $pipelineLogs = New-AzApplicationInsights -ResourceGroupName $ResourceGroupName -Name $names.PipelineLogs `
        -Location $Location -Kind web -WorkspaceResourceId $law.ResourceId
}

# --- Pipeline: Function App -------------------------------------------------
Step "Function App $($names.FunctionApp) (Flex Consumption, PowerShell 7.4)"
if (-not (Get-Command New-AzFunctionApp).Parameters.ContainsKey('FlexConsumptionLocation')) {
    throw 'Your Az.Functions module is too old for Flex Consumption. Run: Update-Module Az.Functions'
}

# No keys: the __fullyQualifiedNamespace suffix tells the Event Hubs trigger to
# connect with the Function's managed identity. Tables and Azure OpenAI are
# called with that identity's token from the code.
$settings = @{
    'EVENTHUB_CONNECTION__fullyQualifiedNamespace' = "$($names.Namespace).servicebus.windows.net"
    'APPLICATIONINSIGHTS_CONNECTION_STRING'        = $pipelineLogs.ConnectionString
    'TABLE_ENDPOINT'                               = "https://$($names.Storage).table.core.windows.net"
    'AZURE_OPENAI_ENDPOINT'                        = "https://$($names.OpenAI).openai.azure.com/"
    'AZURE_OPENAI_DEPLOYMENT'                      = $ModelName
}

$func = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $names.FunctionApp -ErrorAction SilentlyContinue
if (-not $func) {
    $null = New-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $names.FunctionApp `
        -FlexConsumptionLocation $Location -StorageAccountName $names.Storage `
        -Runtime PowerShell -RuntimeVersion 7.4 -EnableSystemAssignedIdentity -DisableApplicationInsights `
        -AlwaysReady @(@{ name = 'function:IngestEvents'; instanceCount = 1 }) -AppSetting $settings
    $func = Get-AzFunctionApp -ResourceGroupName $ResourceGroupName -Name $names.FunctionApp
}
$null = Update-AzFunctionAppSetting -ResourceGroupName $ResourceGroupName -Name $names.FunctionApp `
    -AppSetting $settings -Force

# The Workbook fetches /api/incidents from the browser, so the portal's origin has
# to be allowed. Without this the workbook shows no data and no error worth reading.
Step 'CORS for the Azure portal'
$webConfig = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Web/sites/config' `
    -ResourceName "$($names.FunctionApp)/web" -ApiVersion '2023-12-01'
$origins = @('https://portal.azure.com', 'https://ms.portal.azure.com')
$current = @($webConfig.Properties.cors.allowedOrigins)
if (@($origins | Where-Object { $current -notcontains $_ }).Count) {
    $webConfig.Properties.cors = @{
        allowedOrigins     = @($current + $origins | Where-Object { $_ } | Select-Object -Unique)
        supportCredentials = $false
    }
    $null = Set-AzResource -ResourceId $webConfig.ResourceId -Properties $webConfig.Properties `
        -ApiVersion '2023-12-01' -Force
}
Write-Host "    $($origins -join ', ')"

# --- Pipeline: role assignments for the Function's identity -----------------
Step 'Role assignments (managed identity)'
$principalId = (Get-AzResource -ResourceId $func.Id).Identity.PrincipalId

function Grant-Role([string]$Role, [string]$Scope) {
    # A brand-new identity can take a minute to appear in Entra ID, so retry.
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            $null = New-AzRoleAssignment -ObjectId $principalId -ObjectType ServicePrincipal `
                -RoleDefinitionName $Role -Scope $Scope
            Write-Host "    $Role"
            return
        }
        catch {
            if ($_.Exception.Message -match 'already exists') { Write-Host "    $Role (already assigned)"; return }
            if ($attempt -eq 8) { throw }
            Start-Sleep -Seconds 10
        }
    }
}
Grant-Role 'Azure Event Hubs Data Receiver' $hub.Id      # read the hub
Grant-Role 'Storage Table Data Contributor' $st.Id       # Events/Incidents tables
Grant-Role 'Cognitive Services OpenAI User' $aoai.Id     # the AI step, later

# --- Pipeline: code ---------------------------------------------------------
if (-not $SkipPublish) {
    Step 'Publishing the Function code'
    & (Join-Path $PSScriptRoot 'Publish-Function.ps1') -ResourceGroupName $ResourceGroupName -FunctionAppName $names.FunctionApp
}

# --- Summary ----------------------------------------------------------------
$result = [PSCustomObject]@{
    ResourceGroup               = $ResourceGroupName
    AppInsightsConnectionString = $appi.ConnectionString          # laptop app (source 1)
    EventHubSenderConnection    = $senderKey.PrimaryConnectionString  # local script (source 3)
    EventHubNamespace           = "$($names.Namespace).servicebus.windows.net"
    EventHub                    = $HubName
    OpenAIEndpoint              = "https://$($names.OpenAI).openai.azure.com/"
    OpenAIDeployment            = $ModelName
    FunctionApp                 = $names.FunctionApp
    FunctionLogs                = $names.PipelineLogs
}

Write-Host "`nDone." -ForegroundColor Green
$result
