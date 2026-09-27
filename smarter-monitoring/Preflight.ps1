<#
.SYNOPSIS
    Pre-flight check for the Smarter Monitoring demo laptop.

.DESCRIPTION
    Read-only. Checks local tooling, the store-api venv, Azure sign-in, and that the
    pieces in the resource group exist and are running. It sends nothing to Event Hubs
    and changes nothing in Azure. Azure resource names are discovered by type, so a
    redeploy with a new suffix doesn't break it.

    Exit code = number of FAIL results (0 = ready).

.EXAMPLE
    .\Preflight.ps1
.EXAMPLE
    .\Preflight.ps1 -SkipGit      # no network call to the git remote
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-cas2026-monitoring',
    [string]$HubName       = 'monitoring-events',
    [switch]$SkipGit
)

# Az cmdlets ignore the script's $ErrorActionPreference, so force it per-cmdlet.
$PSDefaultParameterValues = $PSDefaultParameterValues.Clone()
$PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
$ErrorActionPreference = 'Stop'

$root     = $PSScriptRoot
$storeDir = Join-Path $root 'store-api'
$results  = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Area,
        [string]$Check,
        [ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [string]$Detail = ''
    )
    $results.Add([pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail })
    $color = @{ PASS = 'Green'; WARN = 'Yellow'; FAIL = 'Red' }[$Status]
    Write-Host ("[{0}] " -f $Status) -ForegroundColor $color -NoNewline
    Write-Host ("{0,-7} {1}" -f $Area, $Check) -NoNewline
    if ($Detail) { Write-Host "  $Detail" -ForegroundColor DarkGray } else { Write-Host '' }
}

function Test-Tcp {
    param([string]$HostName, [int]$Port = 443, [int]$TimeoutMs = 3000)
    $client = [System.Net.Sockets.TcpClient]::new()
    try   { return $client.ConnectAsync($HostName, $Port).Wait($TimeoutMs) }
    catch { return $false }
    finally { $client.Dispose() }
}

function Get-StorePort {
    param([string]$AppPath)
    if (Test-Path $AppPath) {
        $m = Select-String -Path $AppPath -Pattern 'port\s*=\s*(\d{2,5})' | Select-Object -First 1
        if ($m) { return [int]$m.Matches[0].Groups[1].Value }
    }
    return 5000   # Flask default
}

function Invoke-ArmGet {
    param([string]$Path)
    $r = Invoke-AzRestMethod -Method GET -Path $Path
    if ($r.StatusCode -ne 200) { return $null }
    return $r.Content | ConvertFrom-Json
}

Write-Host "`nSmarter Monitoring pre-flight  ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))  on $env:COMPUTERNAME`n" -ForegroundColor Cyan

# ---------------------------------------------------------------- Local
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Add-Result Local 'PowerShell 7' PASS $PSVersionTable.PSVersion.ToString()
} else {
    Add-Result Local 'PowerShell 7' FAIL "Running $($PSVersionTable.PSVersion) - use pwsh"
}

foreach ($mod in 'Az.Accounts', 'Az.Resources', 'Az.Storage') {
    $m = Get-Module -ListAvailable -Name $mod | Sort-Object Version -Descending | Select-Object -First 1
    if ($m) { Add-Result Local "Module $mod" PASS $m.Version.ToString() }
    else    { Add-Result Local "Module $mod" FAIL 'Install-Module Az -Scope CurrentUser' }
}

foreach ($script in 'Send-Event.ps1', 'Break-Everything.ps1', 'Reset-Pipeline.ps1', 'Show-Incidents.ps1', 'store-api\Start-Traffic.ps1') {
    $p = Join-Path $root $script
    if (Test-Path $p) { Add-Result Local $script PASS }
    else              { Add-Result Local $script FAIL "Missing: $p" }
}

if (-not $SkipGit -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try {
        git -C $root fetch --quiet 2>$null
        $dirty  = @(git -C $root status --porcelain 2>$null).Count
        $behind = git -C $root rev-list --count 'HEAD..@{u}' 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $behind) {
            Add-Result Local 'Repo up to date' WARN 'No upstream branch to compare against'
        } elseif ([int]$behind -gt 0) {
            Add-Result Local 'Repo up to date' FAIL "$behind commit(s) behind - git pull"
        } else {
            Add-Result Local 'Repo up to date' PASS "0 behind, $dirty local change(s)"
        }
    } catch {
        Add-Result Local 'Repo up to date' WARN $_.Exception.Message
    }
}

# ---------------------------------------------------------------- store-api
$py      = Join-Path $storeDir '.venv\Scripts\python.exe'
$appPath = Join-Path $storeDir 'store_api.py'
$reqPath = Join-Path $storeDir 'requirements.txt'
$port    = Get-StorePort $appPath

if (Test-Path $appPath) { Add-Result Store 'store_api.py' PASS "port $port" }
else                    { Add-Result Store 'store_api.py' FAIL "Missing: $appPath" }

if (Test-Path $py) {
    Add-Result Store 'Python venv' PASS (& $py --version 2>&1)

    $probe = Join-Path ([IO.Path]::GetTempPath()) "sm-preflight-$PID.py"
    @'
import importlib.metadata as m
for p in ("flask", "azure-monitor-opentelemetry"):
    try:
        print(p + "=" + m.version(p))
    except m.PackageNotFoundError:
        print(p + "=MISSING")
'@ | Set-Content -Path $probe -Encoding utf8
    $installed = @{}
    & $py $probe | ForEach-Object { $k, $v = $_ -split '=', 2; $installed[$k] = $v }
    Remove-Item $probe -ErrorAction SilentlyContinue

    $pin = $null
    if (Test-Path $reqPath) {
        $pm = Select-String -Path $reqPath -Pattern '^\s*azure-monitor-opentelemetry\s*==\s*(\S+)' | Select-Object -First 1
        if ($pm) { $pin = $pm.Matches[0].Groups[1].Value }
    }

    foreach ($pkg in 'flask', 'azure-monitor-opentelemetry') {
        $v = $installed[$pkg]
        if (-not $v -or $v -eq 'MISSING') {
            Add-Result Store "pkg $pkg" FAIL 'pip install -r requirements.txt inside the venv'
        } elseif ($pkg -eq 'azure-monitor-opentelemetry' -and $pin -and $v -ne $pin) {
            Add-Result Store "pkg $pkg" WARN "$v installed, requirements pins $pin"
        } else {
            Add-Result Store "pkg $pkg" PASS $v
        }
    }
} else {
    Add-Result Store 'Python venv' FAIL "No venv at $py - Start-Store.ps1 will create it"
}

$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listener) {
    $owner = (Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    Add-Result Store "Port $port" WARN "In use by $owner (PID $($listener.OwningProcess)) - store already running?"
} else {
    Add-Result Store "Port $port" PASS 'free'
}

# ---------------------------------------------------------------- Azure
$ctx = Get-AzContext -ErrorAction SilentlyContinue
if (-not $ctx -or -not $ctx.Account) {
    Add-Result Azure 'Signed in' FAIL 'Run Connect-AzAccount, then re-run'
} else {
    $tokenOk = $true
    try { $null = Get-AzAccessToken -WarningAction SilentlyContinue } catch { $tokenOk = $false }
    if ($tokenOk) { Add-Result Azure 'Signed in' PASS "$($ctx.Account.Id) / $($ctx.Subscription.Name)" }
    else          { Add-Result Azure 'Signed in' FAIL 'Token expired - Connect-AzAccount' }

    $rg = if ($tokenOk) { Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue }
    if (-not $rg) {
        if ($tokenOk) { Add-Result Azure "RG $ResourceGroup" FAIL 'Not found in this subscription (wrong subscription?)' }
    } else {
        Add-Result Azure "RG $ResourceGroup" PASS $rg.Location
        $res = Get-AzResource -ResourceGroupName $ResourceGroup

        # Event Hubs
        $ns = $res | Where-Object ResourceType -eq 'Microsoft.EventHub/namespaces' | Select-Object -First 1
        if (-not $ns) {
            Add-Result Azure 'Event Hubs namespace' FAIL 'None in RG'
        } else {
            $hub = Invoke-ArmGet "$($ns.ResourceId)/eventhubs/$HubName`?api-version=2024-01-01"
            if ($hub) { Add-Result Azure "Hub $HubName" PASS "$($ns.Name), $($hub.properties.status)" }
            else      { Add-Result Azure "Hub $HubName" FAIL "Not found in $($ns.Name)" }

            # Send-Event.ps1 has the send-only connection string built in - make sure it
            # still points at this namespace and matches a current key on its rule.
            $sePath = Join-Path $root 'Send-Event.ps1'
            $sm = if (Test-Path $sePath) {
                Select-String -Path $sePath -Pattern 'Endpoint=sb://([^./]+)\.servicebus\.windows\.net/?;SharedAccessKeyName=([^;]+);SharedAccessKey=([^;"'']+)' |
                    Select-Object -First 1
            }
            if (-not $sm) {
                Add-Result Azure 'Send-Event.ps1 key' FAIL 'No connection string found in Send-Event.ps1'
            } else {
                $g = $sm.Matches[0].Groups
                $seNs, $seRule, $seKey = $g[1].Value, $g[2].Value, $g[3].Value
                $rulePath = $null
                foreach ($p in "$($ns.ResourceId)/eventhubs/$HubName/authorizationRules/$seRule", "$($ns.ResourceId)/authorizationRules/$seRule") {
                    if (Invoke-ArmGet "$p`?api-version=2024-01-01") { $rulePath = $p; break }
                }
                if ($seNs -ne $ns.Name) {
                    Add-Result Azure 'Send-Event.ps1 key' FAIL "Points at $seNs, deployed namespace is $($ns.Name) - paste the new EventHubSenderConnection"
                } elseif (-not $rulePath) {
                    Add-Result Azure 'Send-Event.ps1 key' FAIL "Rule '$seRule' not found on $($ns.Name)"
                } else {
                    $keys = Invoke-AzRestMethod -Method POST -Path "$rulePath/listKeys?api-version=2024-01-01"
                    $k = if ($keys.StatusCode -eq 200) { $keys.Content | ConvertFrom-Json }
                    if (-not $k)                                           { Add-Result Azure 'Send-Event.ps1 key' WARN "Could not read keys for '$seRule'" }
                    elseif ($seKey -in @($k.primaryKey, $k.secondaryKey)) { Add-Result Azure 'Send-Event.ps1 key' PASS "$seRule on $seNs matches" }
                    else                                                    { Add-Result Azure 'Send-Event.ps1 key' FAIL "Key for '$seRule' was regenerated - update Send-Event.ps1" }
                }
            }

            $fqdn = "$($ns.Name).servicebus.windows.net"
            if (Test-Tcp $fqdn 443) { Add-Result Net "$fqdn :443" PASS }
            else                    { Add-Result Net "$fqdn :443" FAIL 'Blocked - check venue network/VPN' }
        }

        # App Insights - store_api.py has its connection string built in; find the
        # resource whose instrumentation key matches it.
        $ikey = $null
        if (Test-Path $appPath) {
            $km = Select-String -Path $appPath -Pattern 'InstrumentationKey=([0-9a-fA-F-]{36})' | Select-Object -First 1
            if ($km) { $ikey = $km.Matches[0].Groups[1].Value }
        }
        $appi = $res | Where-Object ResourceType -eq 'Microsoft.Insights/components' |
            ForEach-Object { Get-AzResource -ResourceId $_.ResourceId -ExpandProperties } |
            Where-Object { $ikey -and $_.Properties.InstrumentationKey -eq $ikey } |
            Select-Object -First 1

        if (-not $ikey) {
            Add-Result Azure 'store_api.py -> App Insights' FAIL 'No InstrumentationKey found in store_api.py'
        } elseif (-not $appi) {
            Add-Result Azure 'store_api.py -> App Insights' FAIL "Key $ikey matches nothing in $ResourceGroup (redeployed?) - update CONNECTION_STRING"
        } else {
            Add-Result Azure 'store_api.py -> App Insights' PASS $appi.Name
        }
        if ($env:APPLICATIONINSIGHTS_CONNECTION_STRING) {
            Add-Result Azure 'Connection string override' WARN 'APPLICATIONINSIGHTS_CONNECTION_STRING is set here and overrides store_api.py'
        }

        if ($appi) {
            $diag = Invoke-ArmGet "$($appi.ResourceId)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
            $toHub = @($diag.value | Where-Object { $_.properties.eventHubAuthorizationRuleId })
            if ($toHub.Count) { Add-Result Azure 'Diag setting -> Event Hubs' PASS ($toHub.name -join ',') }
            else              { Add-Result Azure 'Diag setting -> Event Hubs' FAIL 'App telemetry will not reach the hub' }

            if ($appi.Properties.ConnectionString -match 'IngestionEndpoint=https://([^/;]+)') {
                $ing = $Matches[1]
                if (Test-Tcp $ing 443) { Add-Result Net "$ing :443" PASS }
                else                   { Add-Result Net "$ing :443" FAIL 'Telemetry export blocked' }
            }
        }

        # Alert + action group
        $alert = $res | Where-Object ResourceType -eq 'Microsoft.Insights/metricAlerts' | Select-Object -First 1
        if ($alert) {
            $a = Invoke-ArmGet "$($alert.ResourceId)?api-version=2018-03-01"
            if ($a.properties.enabled) { Add-Result Azure 'Metric alert' PASS $alert.Name }
            else                       { Add-Result Azure 'Metric alert' FAIL "$($alert.Name) is disabled" }
        } else {
            Add-Result Azure 'Metric alert' FAIL 'None in RG'
        }
        if ($res | Where-Object ResourceType -eq 'Microsoft.Insights/actionGroups') { Add-Result Azure 'Action group' PASS }
        else                                                                          { Add-Result Azure 'Action group' FAIL 'None in RG' }

        # Function app
        $func = $res | Where-Object { $_.ResourceType -eq 'Microsoft.Web/sites' -and $_.Kind -like '*functionapp*' } | Select-Object -First 1
        if (-not $func) {
            Add-Result Azure 'Function app' FAIL 'None in RG'
        } else {
            $site = Invoke-ArmGet "$($func.ResourceId)?api-version=2023-12-01"
            if ($site.properties.state -eq 'Running') { Add-Result Azure 'Function app' PASS "$($func.Name) Running" }
            else                                      { Add-Result Azure 'Function app' FAIL "$($func.Name) state: $($site.properties.state)" }

            $fns = Invoke-ArmGet "$($func.ResourceId)/functions?api-version=2023-12-01"
            $names = @($fns.value | ForEach-Object { ($_.name -split '/')[-1] })
            if ($names -contains 'IngestEvents') { Add-Result Azure 'IngestEvents deployed' PASS }
            elseif ($fns)                        { Add-Result Azure 'IngestEvents deployed' FAIL "Found: $($names -join ', ')" }
            else                                 { Add-Result Azure 'IngestEvents deployed' WARN 'Could not list functions' }
        }

        # Table Storage (correlation memory)
        $found = $null
        foreach ($sa in $res | Where-Object ResourceType -eq 'Microsoft.Storage/storageAccounts') {
            $tbl    = Invoke-ArmGet "$($sa.ResourceId)/tableServices/default/tables?api-version=2023-05-01"
            $tables = @($tbl.value | ForEach-Object name)
            if ($tables -contains 'Events' -and $tables -contains 'Incidents') { $found = $sa.Name; break }
        }
        if ($found) { Add-Result Azure 'Tables Events/Incidents' PASS $found }
        else        { Add-Result Azure 'Tables Events/Incidents' FAIL 'Not found in any storage account in RG' }

        # Azure OpenAI
        $ai = $res | Where-Object ResourceType -eq 'Microsoft.CognitiveServices/accounts' | Select-Object -First 1
        if (-not $ai) {
            Add-Result Azure 'Azure OpenAI' FAIL 'None in RG'
        } else {
            $deps = Invoke-ArmGet "$($ai.ResourceId)/deployments?api-version=2024-10-01"
            $ok = @($deps.value | Where-Object { $_.properties.provisioningState -eq 'Succeeded' })
            if ($ok.Count) { Add-Result Azure 'Azure OpenAI' PASS "$($ai.Name): $($ok.name -join ', ')" }
            else           { Add-Result Azure 'Azure OpenAI' FAIL "$($ai.Name) has no ready deployment" }
        }
    }
}

# ---------------------------------------------------------------- Summary
$fail = @($results | Where-Object Status -eq 'FAIL').Count
$warn = @($results | Where-Object Status -eq 'WARN').Count
Write-Host ''
if ($fail -eq 0) {
    Write-Host "READY  ($warn warning(s))" -ForegroundColor Green
    Write-Host "Launch the store with: .\Start-Store.ps1 -Traffic" -ForegroundColor DarkGray
} else {
    Write-Host "NOT READY  - $fail failure(s), $warn warning(s)" -ForegroundColor Red
}
exit $fail
