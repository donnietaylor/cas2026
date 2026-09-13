#requires -Version 7.4
#requires -Modules Az.Accounts

<#
.SYNOPSIS
    Zips the function/ folder and pushes it to the Flex Consumption Function App.

.DESCRIPTION
    Deploy-Azure.ps1 calls this at the end. Run it on its own after any code change.

    Flex Consumption takes code through its OneDeploy endpoint (/api/publish).
    We authenticate with your Azure sign-in token - no publishing credentials.

.EXAMPLE
    ./Publish-Function.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-cas2026-monitoring',
    [string]$FunctionAppName
)

$ErrorActionPreference = 'Stop'
$sub = (Get-AzContext).Subscription.Id
if (-not $sub) { throw 'Run Connect-AzAccount first.' }
if (-not $FunctionAppName) { $FunctionAppName = "func-cas26-$($sub.Substring(0, 6))" }

# --- Zip function/ ----------------------------------------------------------
# Entries are written with forward slashes: the host runs on Linux, and a
# Windows-style 'IngestEvents\run.ps1' entry would unpack as one flat file.
$source = Join-Path $PSScriptRoot 'function'
$zipPath = Join-Path ([IO.Path]::GetTempPath()) "$FunctionAppName.zip"
Remove-Item $zipPath -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
        $entry = [IO.Path]::GetRelativePath($source, $file.FullName).Replace('\', '/')
        $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry)
    }
}
finally { $zip.Dispose() }

# --- Push it ----------------------------------------------------------------
$site = (Invoke-AzRestMethod -Method GET `
        -Path "/subscriptions/$sub/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$($FunctionAppName)?api-version=2024-04-01").Content |
    ConvertFrom-Json
$scmHost = ($site.properties.hostNameSslStates | Where-Object hostType -eq 'Repository').name
if (-not $scmHost) { throw "Function App '$FunctionAppName' not found in '$ResourceGroupName'." }

# Az.Accounts 5+ returns the token as a SecureString; older versions as a string.
$token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com/').Token
if ($token -is [securestring]) { $token = ConvertFrom-SecureString $token -AsPlainText }
$headers = @{ Authorization = "Bearer $token" }

Write-Host "Publishing to $FunctionAppName..."
$response = Invoke-WebRequest -Method Post -Uri "https://$scmHost/api/publish?RemoteBuild=false" `
    -InFile $zipPath -ContentType 'application/zip' -Headers $headers -SkipHttpErrorCheck
if ($response.StatusCode -notin 200, 202) { throw "Publish failed ($($response.StatusCode)): $($response.Content)" }

# Kudu deployment status: 4 = succeeded, 3 = failed.
$deadline = (Get-Date).AddMinutes(5)
do {
    Start-Sleep -Seconds 5
    $status = (Invoke-RestMethod -Uri "https://$scmHost/api/deployments/latest" -Headers $headers).status
    if ($status -eq 3) { throw "Deployment failed. Details: https://$scmHost/api/deployments/latest" }
} until ($status -eq 4 -or (Get-Date) -gt $deadline)
if ($status -ne 4) { throw "Timed out waiting for the deployment. Check https://$scmHost/api/deployments/latest" }

Remove-Item $zipPath
Write-Host 'Published.' -ForegroundColor Green
