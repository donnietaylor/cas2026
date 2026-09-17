#requires -Version 7.0

<#
.SYNOPSIS
    Lists TCP ports a machine is listening on, with the owning process, by
    running netstat.exe and parsing its text output.

.DESCRIPTION
    The pattern for any command-line tool that only prints text:
    run it, split the lines, regex the columns, emit objects. netstat has been
    printing the same columns since Windows NT and will never grow an API.
    Joining the PID to a process name is the part people actually want and
    the part netstat never did for them.

.PARAMETER Port
    Only return this port. Default is every listening port.

.PARAMETER ProcessName
    Only return ports owned by processes whose name matches this wildcard.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Only return this port number')]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter(HelpMessage = 'Filter by owning process name, wildcards allowed')]
    [string]$ProcessName = '*'
)

if (-not $IsWindows) {
    throw 'Get-ListeningPort wraps netstat.exe and needs Windows.'
}

# One lookup table so we are not calling Get-Process once per line.
$procs = @{}
Get-Process | ForEach-Object { $procs[$_.Id] = $_.ProcessName }

# netstat -ano prints:  TCP    0.0.0.0:135    0.0.0.0:0    LISTENING    1234
# Everything else in the output (headers, UDP, established) is ignored.
$pattern = '^\s*TCP\s+(?<Local>\S+):(?<Port>\d+)\s+\S+\s+LISTENING\s+(?<Pid>\d+)\s*$'

netstat.exe -ano |
    ForEach-Object {
        if ($_ -match $pattern) {
            $procId = [int]$Matches.Pid
            [PSCustomObject]@{
                Port        = [int]$Matches.Port
                Address     = $Matches.Local
                ProcessId   = $procId
                ProcessName = $procs[$procId] ?? 'unknown'
            }
        }
    } |
    Where-Object { -not $Port -or $_.Port -eq $Port } |
    Where-Object { $_.ProcessName -like $ProcessName } |
    Sort-Object Port -Unique
