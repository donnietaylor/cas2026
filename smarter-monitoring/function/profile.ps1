# Runs once per PowerShell worker cold start.

# Managed identity is the intended auth path in Azure; there are no keys here.
if ($env:MSI_SECRET) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null
}

# Import the shared pipeline modules once per worker rather than per invocation.
$moduleRoot = Join-Path $PSScriptRoot 'modules'
foreach ($module in @('EventNormalizer', 'Grounding', 'AiEnrichment', 'IncidentSink')) {
    Import-Module (Join-Path $moduleRoot "$module.psm1") -Force -Global
}

$ProgressPreference = 'SilentlyContinue'
