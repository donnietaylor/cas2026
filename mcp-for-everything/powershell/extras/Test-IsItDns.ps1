#requires -Version 7.0

<#
.SYNOPSIS
    Determines whether the current problem is DNS. Takes no parameters because
    none are needed.

.DESCRIPTION
    A tool does not have to take input. This one takes none, and it is still a
    complete, valid MCP tool: a name, a description, an empty schema, a result.

    It does resolve one name so the timing looks plausible.
#>
[CmdletBinding()]
param()

$sw = [System.Diagnostics.Stopwatch]::StartNew()
try   { $null = Resolve-DnsName -Name 'example.com' -Type A -ErrorAction Stop; $resolved = $true }
catch { $resolved = $false }
$sw.Stop()

[PSCustomObject]@{
    IsItDns        = $true
    Confidence     = 'High'
    ResolverWorked = $resolved
    CheckedInMs    = $sw.ElapsedMilliseconds
    Note           = if ($resolved) { 'DNS resolved fine. It is still DNS.' } else { 'DNS did not resolve. See? DNS.' }
}
