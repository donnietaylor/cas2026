#requires -Version 7.0

<#
.SYNOPSIS
    Posts events to the monitoring Event Hub - the "third-party tools" source.

.DESCRIPTION
    No Az modules needed. It builds a SAS token from the send-only connection string
    and POSTs JSON to the Event Hubs REST endpoint, so it runs the same on any
    machine with PowerShell 7.

    The send-only connection string is built in, so it just runs. It can only send
    to this one hub. If the hub is ever redeployed, paste the new
    EventHubSenderConnection from Deploy-Azure.ps1 below.

    THE CATALOG

    Sixteen monitoring signals from twelve fictional tools, standing in for the
    estate we are not going to deploy. They form two real stories and a pile of
    things that are wrong but irrelevant:

      sql    A backup job overran its window and is still reading sql-prod-03 at
             11 MB/s. The disk is saturated, queries are piling up on locks, the
             connection pool is exhausted, and checkout is failing in the app.
             Four tools, three hosts, one cause - and the cause is the signal with
             the LOWEST severity, on a host that shares nothing with the others.

      cert   A TLS certificate on lb-edge-02 expired. Token validation is failing
             on two API nodes and the synthetic login probe is red in three
             regions. Four hosts, no shared key between them but the cert.

      noise  Five things that are genuinely wrong and have nothing to do with
             either story. A good correlator leaves them alone.

    Signals repeat with varying numbers - 480 ms, then 512 ms, then 455 ms. The
    pipeline collapses digit runs when it fingerprints, so those land as one
    symptom with a count, not three symptoms. That is the point of the counts on
    screen.

.EXAMPLE
    ./Send-Event.ps1 -Story
    # everything, ~40 seconds, paced for the stage

.EXAMPLE
    ./Send-Event.ps1 -Story -Only sql -Fast
    # one storyline, no pauses

.EXAMPLE
    ./Send-Event.ps1 -List
#>
[CmdletBinding(DefaultParameterSetName = 'Manual')]
param(
    [Parameter(ParameterSetName = 'Story', Mandatory)]
    [switch]$Story,

    [Parameter(ParameterSetName = 'Story')]
    [ValidateSet('sql', 'cert', 'noise')]
    [string]$Only,

    [Parameter(ParameterSetName = 'Story')]
    [switch]$Fast,

    [Parameter(ParameterSetName = 'One', Mandatory)]
    [string]$Signal,

    [Parameter(ParameterSetName = 'List', Mandatory)]
    [switch]$List,

    [Parameter(ParameterSetName = 'Manual')]
    [string]$Title = 'Test event',

    [Parameter(ParameterSetName = 'Manual')]
    [ValidateSet('critical', 'error', 'warning', 'info')]
    [string]$Severity = 'warning',

    [Parameter(ParameterSetName = 'Manual')]
    [string]$Computer = [Environment]::MachineName,

    [Parameter(ParameterSetName = 'Manual')]
    [string]$Message = 'Sent by Send-Event.ps1',

    [Parameter(ParameterSetName = 'Manual')]
    [string]$Tool = 'local-script',

    [string]$ConnectionString = 'Endpoint=sb://evhns-cas26-193812.servicebus.windows.net/;SharedAccessKeyName=local-sender;SharedAccessKey=ZJHhloSsq0/uF7S9ROtkLgWDWHK5PMKQS+AEhAQuaVw=;EntityPath=monitoring-events'
)

$ErrorActionPreference = 'Stop'

# --- The catalog ------------------------------------------------------------
# Repeat = how many times this signal fires. Vary = the numbers that change
# between firings ({0} in Title/Message). Gap = seconds of quiet afterwards.
# Order is the order it goes on the wire, noise deliberately mixed in.

$catalog = @(
    # --- sql: the cause fires first, quietly, on a host nobody is watching ---
    @{
        Id = 'backup'; Story = 'sql'; Tool = 'backup-agent'; Computer = 'backup-01'
        Severity = 'warning'; Repeat = 3; Vary = @(4, 5, 6); Gap = 2
        Title   = 'Nightly backup of sql-prod-03 still running, {0} hours over window'
        Message = 'Job SQL-NIGHTLY-FULL started 22:00 and is still reading from sql-prod-03. Throughput has fallen to 11 MB/s from a normal 240 MB/s. The backup window closed at 02:00 and the job holds a read stream against the data volume for its whole run.'
    }
    @{
        Id = 'dhcp'; Story = 'noise'; Tool = 'dhcp-watch'; Computer = 'dc-02'
        Severity = 'warning'; Repeat = 2; Vary = @(86, 88); Gap = 1
        Title   = 'Scope 10.20.0.0/16 at {0} percent utilization'
        Message = 'Address pool on dc-02 is {0} percent allocated. Lease time is 8 days. Not yet exhausting, but trending up since the new floor was occupied.'
    }
    @{
        Id = 'disk-read'; Story = 'sql'; Tool = 'storage-watch'; Computer = 'sql-prod-03'
        Severity = 'error'; Repeat = 6; Vary = @(410, 455, 480, 512, 498, 466); Gap = 2
        Title   = 'Disk read latency {0} ms, sustained'
        Message = 'Volume E: on sql-prod-03 carries the database data files and has averaged {0} ms read latency for the last several minutes. Normal for this volume is under 8 ms.'
    }
    @{
        Id = 'disk-queue'; Story = 'sql'; Tool = 'storage-watch'; Computer = 'sql-prod-03'
        Severity = 'warning'; Repeat = 4; Vary = @(48, 56, 64, 61); Gap = 1
        Title   = 'Write queue depth {0}, above threshold 8'
        Message = 'Outstanding I/O on volume E: of sql-prod-03 is {0}. The volume is servicing an unusually large sequential read alongside the normal random workload.'
    }
    @{
        Id = 'esx'; Story = 'noise'; Tool = 'vsphere'; Computer = 'esx-04'
        Severity = 'warning'; Repeat = 3; Vary = @(82, 83, 83); Gap = 1
        Title   = 'Datastore DS-VOL-02 at {0} percent capacity'
        Message = 'Datastore DS-VOL-02 on esx-04 is {0} percent full. Thin-provisioned guests on this datastore have grown steadily over the quarter. Alarm threshold is 80 percent.'
    }
    @{
        Id = 'locks'; Story = 'sql'; Tool = 'sql-watch'; Computer = 'sql-prod-03'
        Severity = 'error'; Repeat = 5; Vary = @(2200, 3100, 4400, 3800, 5100); Gap = 2
        Title   = 'Lock wait time {0} ms on OrderLines'
        Message = 'Sessions are waiting an average of {0} ms for page locks on dbo.OrderLines. The blocking chain is 14 deep and the head session is waiting on PAGEIOLATCH_SH, which means it is waiting for disk, not for another query.'
    }
    @{
        Id = 'pool'; Story = 'sql'; Tool = 'sql-watch'; Computer = 'sql-prod-03'
        Severity = 'critical'; Repeat = 8; Vary = @(97, 99, 100, 100, 98, 100, 100, 99); Gap = 2
        Title   = 'Connection pool exhausted, {0} of 100 in use'
        Message = 'The application connection pool on sql-prod-03 is at {0} of 100. Average checkout wait is over 1400 ms and climbing. Connections are not leaking - they are being held open waiting on I/O.'
    }
    @{
        Id = 'wan'; Story = 'noise'; Tool = 'net-monitor'; Computer = 'fw-edge-01'
        Severity = 'warning'; Repeat = 3; Vary = @(2, 3, 2); Gap = 1
        Title   = 'Packet loss {0} percent on WAN interface'
        Message = 'Interface ge-0/0/1 on fw-edge-01 is showing {0} percent loss to the ISP gateway. The carrier has an open maintenance notice for the region until 06:00. Internal interfaces are clean.'
    }
    @{
        Id = 'checkout'; Story = 'sql'; Tool = 'apm'; Computer = 'app-web-01'
        Severity = 'critical'; Repeat = 6; Vary = @(12, 19, 27, 31, 24, 29); Gap = 2
        Title   = 'Checkout failures {0} percent of requests'
        Message = 'The checkout endpoint on app-web-01 is failing {0} percent of requests. Errors are timeouts, not exceptions in application code. Cart and catalog endpoints are healthy.'
    }
    @{
        Id = 'payments'; Story = 'sql'; Tool = 'apm'; Computer = 'app-web-01'
        Severity = 'error'; Repeat = 5; Vary = @(1500, 1500, 1500, 2000, 1500); Gap = 3
        Title   = 'Payments database connection timeout after {0} ms'
        Message = 'app-web-01 could not obtain a database connection within {0} ms while handling a payment. The pool on the far end is sql-prod-03.'
    }

    # --- cert: a second, unrelated outage running at the same time ----------
    @{
        Id = 'cert'; Story = 'cert'; Tool = 'cert-watch'; Computer = 'lb-edge-02'
        Severity = 'critical'; Repeat = 3; Vary = @(3, 11, 18); Gap = 2
        Title   = 'TLS certificate for api.contoso.com expired {0} minutes ago'
        Message = 'The certificate bound to the HTTPS listener on lb-edge-02 expired. Renewal automation last ran 38 days ago and reported success. The replacement certificate is present on disk but was never bound to the listener.'
    }
    @{
        Id = 'print'; Story = 'noise'; Tool = 'patch-agent'; Computer = 'win-print-02'
        Severity = 'warning'; Repeat = 2; Vary = @(11, 12); Gap = 1
        Title   = 'Reboot pending for {0} days'
        Message = 'win-print-02 has had a reboot pending since the September cumulative update. The maintenance window has been skipped twice because of print queue activity.'
    }
    @{
        Id = 'auth-03'; Story = 'cert'; Tool = 'auth-svc'; Computer = 'app-api-03'
        Severity = 'error'; Repeat = 7; Vary = @(526, 526, 495, 526, 526, 495, 526); Gap = 2
        Title   = 'Token validation failing, upstream returned {0}'
        Message = 'app-api-03 cannot validate bearer tokens. Calls to the identity endpoint through the edge listener are terminating at the TLS layer before any HTTP response is produced.'
    }
    @{
        Id = 'auth-04'; Story = 'cert'; Tool = 'auth-svc'; Computer = 'app-api-04'
        Severity = 'error'; Repeat = 6; Vary = @(526, 495, 526, 526, 495, 526); Gap = 2
        Title   = 'Token validation failing, upstream returned {0}'
        Message = 'app-api-04 cannot validate bearer tokens. Same failure pattern as the rest of the API tier. Direct calls that bypass the edge listener succeed.'
    }
    @{
        Id = 'av'; Story = 'noise'; Tool = 'av-console'; Computer = 'hr-ws-14'
        Severity = 'warning'; Repeat = 1; Gap = 1
        Title   = 'Quarantined EICAR test file'
        Message = 'hr-ws-14 quarantined an EICAR test string in a file downloaded from a vendor training portal. This is the standard antivirus test file, not malware.'
    }
    @{
        Id = 'synthetic'; Story = 'cert'; Tool = 'synthetic'; Computer = 'probe-dfw'
        Severity = 'critical'; Repeat = 4; Vary = @(2, 3, 4, 3); Gap = 0
        Title   = 'Login journey failing from {0} of 4 regions'
        Message = 'The scripted login journey is failing from {0} of 4 probe regions. The step that fails is the token exchange. Anonymous pages load normally from every region.'
    }
)

if ($List) {
    $catalog | ForEach-Object {
        [PSCustomObject]@{
            Id       = $_.Id
            Story    = $_.Story
            Tool     = $_.Tool
            Host     = $_.Computer
            Severity = $_.Severity
            Fires    = $_.Repeat
            Title    = ($_.Title -f '#')
        }
    } | Format-Table -AutoSize
    $total = ($catalog | Measure-Object Repeat -Sum).Sum
    Write-Host "$($catalog.Count) signals, $total events, $(($catalog.Computer | Select-Object -Unique).Count) hosts, $(($catalog.Tool | Select-Object -Unique).Count) tools." -ForegroundColor Green
    return
}

# --- Wire up ----------------------------------------------------------------
# Endpoint=sb://<ns>.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=...;EntityPath=<hub>
$parts = @{}
foreach ($segment in $ConnectionString.Split(';', [StringSplitOptions]::RemoveEmptyEntries)) {
    $name, $value = $segment.Split('=', 2)
    $parts[$name] = $value
}
$namespace = ([uri]$parts.Endpoint).Host
$hub = $parts.EntityPath
if (-not $hub) { throw 'Connection string has no EntityPath - use the hub-level send key.' }

# SAS token, valid for 30 minutes - longer than any run of the story.
$resource = [uri]::EscapeDataString("https://$namespace/$hub")
$expiry = [DateTimeOffset]::UtcNow.AddMinutes(30).ToUnixTimeSeconds()
$hmac = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($parts.SharedAccessKey))
$signature = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$resource`n$expiry")))
$token = "SharedAccessSignature sr=$resource&sig=$([uri]::EscapeDataString($signature))&se=$expiry&skn=$($parts.SharedAccessKeyName)"

$uri = "https://$namespace/$hub/messages?api-version=2014-01"
$severityColor = @{ critical = 'Red'; error = 'Magenta'; warning = 'Yellow'; info = 'Gray' }

function Send-One {
    param([string]$ToolName, [string]$HostName, [string]$Level, [string]$Text, [string]$Detail)

    $payload = [ordered]@{
        tool      = $ToolName
        severity  = $Level
        title     = $Text
        message   = $Detail
        host      = $HostName
        timestamp = [DateTime]::UtcNow.ToString('o')
    }

    # Partition by the host. Event Hubs hashes the partition key, so every event
    # about sql-prod-03 lands on the same partition and is processed in order by
    # one worker. Without this, events round-robin and two invocations correlate
    # the same host at the same instant. Partition by the thing you correlate on.
    Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' `
        -Headers @{
            Authorization    = $token
            BrokerProperties = (@{ PartitionKey = $HostName } | ConvertTo-Json -Compress)
        } `
        -Body ($payload | ConvertTo-Json -Compress) | Out-Null

    Write-Host ('  {0,-14} {1,-13} {2,-9} {3}' -f $ToolName, $HostName, $Level, $Text) `
        -ForegroundColor ($severityColor[$Level] ?? 'Gray')
}

function Send-Signal {
    param([hashtable]$Entry)

    for ($i = 0; $i -lt [int]$Entry.Repeat; $i++) {
        $text = $Entry.Title
        $detail = $Entry.Message
        if ($Entry.Vary) {
            $value = $Entry.Vary[$i % $Entry.Vary.Count]
            $text = $Entry.Title -f $value
            if ($Entry.Message -match '\{0\}') { $detail = $Entry.Message -f $value }
        }
        Send-One -ToolName $Entry.Tool -HostName $Entry.Computer -Level $Entry.Severity -Text $text -Detail $detail
        Start-Sleep -Milliseconds 120
    }
}

# --- Run --------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'One') {
    $entry = $catalog | Where-Object Id -eq $Signal
    if (-not $entry) { throw "No signal named '$Signal'. Run with -List to see them." }
    Send-Signal $entry
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Manual') {
    Send-One -ToolName $Tool -HostName $Computer -Level $Severity -Text $Title -Detail $Message
    return
}

$selected = if ($Only) { $catalog | Where-Object Story -eq $Only } else { $catalog }
$total = ($selected | Measure-Object Repeat -Sum).Sum

Write-Host ''
Write-Host "Sending $total events from $($selected.Count) signals to $namespace/$hub" -ForegroundColor Green
Write-Host ''

$sw = [Diagnostics.Stopwatch]::StartNew()
for ($s = 0; $s -lt $selected.Count; $s++) {
    Send-Signal $selected[$s]
    if (-not $Fast -and $s -lt $selected.Count - 1 -and $selected[$s].Gap) {
        Start-Sleep -Seconds $selected[$s].Gap
    }
}
$sw.Stop()

Write-Host ''
Write-Host ('{0} events from {1} tools across {2} hosts in {3:n0}s.' -f `
        $total,
    ($selected.Tool | Select-Object -Unique).Count,
    ($selected.Computer | Select-Object -Unique).Count,
    $sw.Elapsed.TotalSeconds) -ForegroundColor Green
