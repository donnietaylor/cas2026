#requires -Version 7.0
<#
.SYNOPSIS
    Runs one PowerShell tool with arguments supplied as JSON on stdin.

.DESCRIPTION
    The bridge between the Python MCP host and your PowerShell.

    Why stdin instead of building a command line: quoting. Passing model-supplied
    strings through a shell command line is how you get an injection bug and a
    bad afternoon. JSON in, splat into the param block, let PowerShell's own
    parameter binder do the validation. Nothing is ever string-concatenated
    into a command.

    Everything the tool emits on the success stream becomes "result".
    Warnings are captured. Errors become a structured failure, not a stack trace.
    Only one thing is ever written to stdout: the JSON envelope.

.PARAMETER ToolPath
    Full path to the tool script to run.

.PARAMETER TimeoutSeconds
    Advisory only; the host enforces the real timeout by killing the process.

.EXAMPLE
    '{"Category":"Widgets"}' | ./_invoke.ps1 -ToolPath ./tools/Get-Inventory.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ToolPath,

    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # progress bars corrupt piped output

$started = [DateTime]::UtcNow
$warnings = [System.Collections.Generic.List[string]]::new()

function Write-Envelope {
    param([hashtable]$Envelope)
    $Envelope['durationMs'] = [int]([DateTime]::UtcNow - $started).TotalMilliseconds
    # Console::Out, not Write-Output: nothing else may touch stdout.
    [Console]::Out.Write(($Envelope | ConvertTo-Json -Depth 20 -Compress))
}

try {
    $raw = [Console]::In.ReadToEnd()

    $params = @{}
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        # -AsHashtable is PS 7+, and is what makes splatting work cleanly.
        $params = $raw | ConvertFrom-Json -AsHashtable
    }
    if ($null -eq $params) { $params = @{} }

    if (-not (Test-Path -LiteralPath $ToolPath)) {
        throw "Tool script not found: $ToolPath"
    }

    # Both redirections are load-bearing, and this cost an afternoon to find:
    #
    #   3> $null  warnings. -WarningVariable CAPTURES them but does not stop them
    #             being written out, and depending on how the host is launched
    #             they can land on stdout, directly ahead of the JSON envelope.
    #             A tool falling back to demo data emits a warning - so this
    #             breaks precisely when the wifi has already died.
    #   6> $null  information stream, which is where Write-Host goes in PS 7.
    #
    # Warnings are not lost: they travel inside the envelope's "warnings" array.
    $result = & $ToolPath @params -WarningVariable +toolWarnings 3> $null 6> $null

    foreach ($w in $toolWarnings) { $warnings.Add([string]$w) }

    # Always an array, even for a single object or no results at all.
    #
    # This matters more than it looks. PowerShell unrolls the pipeline, so a
    # search that finds one match returns an object and a search that finds three
    # returns an array. If we pass that straight through, the model has to branch
    # on the shape of its own tool output, and sooner or later it gets it wrong.
    # One rule instead: result is a list. Same as every REST collection endpoint.
    $items = @($result)

    Write-Envelope @{
        ok       = $true
        tool     = [IO.Path]::GetFileNameWithoutExtension($ToolPath)
        count    = $items.Count
        result   = $items
        warnings = $warnings
    }
}
catch {
    $err = $_
    Write-Envelope @{
        ok       = $false
        tool     = [IO.Path]::GetFileNameWithoutExtension($ToolPath)
        error    = @{
            message   = $err.Exception.Message
            type      = $err.Exception.GetType().FullName
            category  = [string]$err.CategoryInfo.Category
            target    = [string]$err.CategoryInfo.TargetName
            # Deliberately not the full stack trace: it goes to the model, and
            # internal paths are not the model's business.
            scriptLine = [string]$err.InvocationInfo.Line.Trim()
        }
        warnings = $warnings
    }
    exit 1
}
