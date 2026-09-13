<#
    Turns the three event shapes into one.

        App Insights (diagnostic setting)  { "records": [ { "Type": "AppRequests", ... } ] }
        Azure Monitor alert                { "data": { "essentials": { ... } } }   common alert schema
        Send-Event.ps1                     { "tool": ..., "title": ..., "host": ... }

    Every event comes out with the same fields. The correlation keys are TraceId
    and ParentSpanId (from OpenTelemetry, via App Insights), ResourceId and Host.
#>

$script:SeenShapes = @{}

function Get-Field {
    # First non-empty value among a few candidate property names. Exports differ
    # in casing and naming (OperationId vs operation_Id), so be forgiving.
    param($Object, [string[]]$Name)
    foreach ($n in $Name) {
        $value = $Object.$n
        if ($null -ne $value -and "$value" -ne '') { return $value }
    }
}

function Format-Time {
    # ConvertFrom-Json turns ISO timestamps into [datetime]; put them back as ISO
    # UTC so every event's Time sorts and compares the same way.
    param($Value)
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o') }
    return "$Value"
}

function Get-PayloadShape {
    param($Payload)
    if ($Payload.records) { return 'appinsights' }
    if ($Payload.data.essentials) { return 'alert' }
    if ($Payload.tool) { return 'script' }
    return 'unknown'
}

function New-PipelineEvent {
    param([hashtable]$Fields)
    $defaults = [ordered]@{
        Source = ''; Kind = ''; Time = ''; Severity = 'info'; Title = ''; Message = ''
        TraceId = ''; SpanId = ''; ParentSpanId = ''; ResourceId = ''; Host = ''; Service = ''
        Status = ''; Success = $false
    }
    foreach ($key in $Fields.Keys) { $defaults[$key] = $Fields[$key] }
    [PSCustomObject]$defaults
}

function Get-ExceptionMessage {
    <#
    .SYNOPSIS
        The useful line out of an exception record.

        Flask puts its own generic text in OuterMessage/InnermostMessage
        ("Exception on /payments [POST]"). The real message - the one worth
        handing a model - is the last line of the raw stack.
    #>
    param($Record)

    $details = $Record.Details
    if ($details -is [string]) { try { $details = $details | ConvertFrom-Json } catch { $details = $null } }
    $stack = @($details)[0].rawStack
    if ($stack) {
        $lastLine = @("$stack" -split "`n" | Where-Object { $_.Trim() })[-1]
        if ($lastLine) { return $lastLine.Trim() }
    }
    return "$(Get-Field $Record 'InnermostMessage', 'OuterMessage')"
}

function Get-HostFromTarget {
    <#
    .SYNOPSIS
        A correlatable host name out of a dependency's Target, or nothing.

        This is where OpenTelemetry earns its keep. A dependency span carrying
        server.address = sql-prod-03 arrives here as Target 'sql-prod-03', and
        the app's failure then shares a key with everything else failing on that
        box - grouped with no model involved.

        AppRoleInstance is deliberately not used as a host anywhere: Application
        Insights reports it as a GUID, so it correlates with nothing and only
        makes the incident list look like it has hosts when it does not.
    #>
    param([string]$Target)

    if (-not $Target) { return '' }
    $name = (("$Target" -split '\|')[0]).Trim()   # "sql-prod-03 | payments"
    $name = ($name -split '/')[0]
    $name = ($name -split ':')[0]                  # drop any port
    if (-not $name) { return '' }
    # Loopback and bare addresses are not names anyone correlates on.
    if ($name -in 'localhost', '127.0.0.1', '::1') { return '' }
    if ($name -match '^\d{1,3}(\.\d{1,3}){3}$') { return '' }
    return $name
}

function ConvertFrom-AppInsightsRecord {
    param($Record)

    $kind = switch (Get-Field $Record 'Type', 'category') {
        'AppRequests' { 'request' }
        'AppDependencies' { 'dependency' }
        'AppExceptions' { 'exception' }
        default { return }
    }

    # Exceptions are always failures. Requests and dependencies carry Success.
    $success = $kind -ne 'exception' -and "$(Get-Field $Record 'Success')" -eq 'True'
    $name = Get-Field $Record 'Name', 'OperationName'
    $code = Get-Field $Record 'ResultCode'

    $exceptionMessage = if ($kind -eq 'exception') { Get-ExceptionMessage $Record } else { '' }

    $title = switch ($kind) {
        'request' { "$name returned $code" }
        'dependency' { "Call to $(Get-Field $Record 'Target', 'Name') failed ($code)" }
        'exception' { "$(Get-Field $Record 'ExceptionType') in $(Get-Field $Record 'OperationName', 'ProblemId')" }
    }

    New-PipelineEvent @{
        Source       = 'appinsights'
        Kind         = $kind
        Time         = Format-Time (Get-Field $Record 'TimeGenerated', 'time', 'timestamp')
        Severity     = 'error'
        Title        = $title
        Message      = $(if ($kind -eq 'exception') { $exceptionMessage } else { "$(Get-Field $Record 'Data', 'Url')" })
        TraceId      = "$(Get-Field $Record 'OperationId', 'operation_Id')"
        SpanId       = "$(Get-Field $Record 'Id', 'id')"
        ParentSpanId = "$(Get-Field $Record 'ParentId', 'operation_ParentId')"
        ResourceId   = "$(Get-Field $Record '_ResourceId', 'ResourceId', 'resourceId')".ToLowerInvariant()
        Host         = $(if ($kind -eq 'dependency') { Get-HostFromTarget "$(Get-Field $Record 'Target')" } else { '' })
        Service      = "$(Get-Field $Record 'AppRoleName', 'cloud_RoleName')"
        Success      = $success
    }
}

function ConvertFrom-AzureMonitorAlert {
    param($Payload)
    $e = $Payload.data.essentials

    $severity = switch ($e.severity) {
        { $_ -in 'Sev0', 'Sev1' } { 'critical' }
        'Sev2' { 'error' }
        'Sev3' { 'warning' }
        default { 'info' }
    }

    New-PipelineEvent @{
        Source     = 'alert'
        Kind       = 'alert'
        Time       = Format-Time (Get-Field $e 'firedDateTime', 'resolvedDateTime')
        Severity   = $severity
        Title      = "$($e.alertRule)"
        Message    = "$($e.description)"
        ResourceId = "$(@($e.alertTargetIDs)[0])".ToLowerInvariant()
        Status     = "$($e.monitorCondition)"      # Fired / Resolved
    }
}

function ConvertFrom-ScriptEvent {
    param($Payload)
    New-PipelineEvent @{
        Source   = 'script'
        Kind     = 'event'
        Time     = Format-Time $Payload.timestamp
        Severity = (Get-Field $Payload 'severity') ?? 'info'
        Title    = "$($Payload.title)"
        Message  = "$($Payload.message)"
        Host     = "$($Payload.host)"
        Service  = "$($Payload.tool)"
    }
}

function ConvertTo-PipelineEvent {
    <#
    .SYNOPSIS
        One Event Hubs message in, zero or more pipeline events out.
    #>
    param([Parameter(Mandatory)]$Payload)

    switch (Get-PayloadShape $Payload) {
        'appinsights' { foreach ($record in $Payload.records) { ConvertFrom-AppInsightsRecord $record } }
        'alert' { ConvertFrom-AzureMonitorAlert $Payload }
        'script' { ConvertFrom-ScriptEvent $Payload }
        default {
            $json = $Payload | ConvertTo-Json -Depth 5 -Compress
            Write-Warning "Unrecognised payload: $($json.Substring(0, [Math]::Min(300, $json.Length)))"
        }
    }
}

function Write-RawLine {
    param([string]$Key, $Sample)
    $json = $Sample | ConvertTo-Json -Depth 10 -Compress
    if ($json.Length -gt 4000) { $json = $json.Substring(0, 4000) + '...' }
    Write-Host "RAW $Key $json"
}

function Write-RawSample {
    <#
    .SYNOPSIS
        Logs one raw message per shape this worker sees, so the real field names
        are visible in the logs. App Insights records are logged once per record
        type (AppRequests, AppDependencies, AppExceptions), because each type
        carries different fields.
    #>
    param($Payload)

    $shape = Get-PayloadShape $Payload
    if ($shape -eq 'appinsights') {
        foreach ($record in @($Payload.records)) {
            $key = "appinsights:$(Get-Field $record 'Type', 'category')"
            if ($script:SeenShapes.ContainsKey($key)) { continue }
            $script:SeenShapes[$key] = $true
            Write-RawLine $key $record
        }
        return
    }

    if ($script:SeenShapes.ContainsKey($shape)) { return }
    $script:SeenShapes[$shape] = $true
    Write-RawLine $shape $Payload
}

Export-ModuleMember -Function ConvertTo-PipelineEvent, Write-RawSample
