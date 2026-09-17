#requires -Version 7.0

<#
.SYNOPSIS
    Gets an official-sounding excuse for an outage from the BOFH Excuse Server's
    master list, for use when the real cause is not something you want to say
    out loud.

.DESCRIPTION
    The Bastard Operator From Hell excuse server has been hosted at the
    University of Wisconsin since 1995. It has never had an API. Its entire
    dataset is one plain-text file, one excuse per line, and this tool
    downloads it and picks from it at random.

    If the file is unreachable (it is a thirty-year-old web page on a
    university host) the tool falls back to a short built-in list and says so.

.PARAMETER Count
    How many excuses to return.

.PARAMETER Audience
    Who the excuse is for. Only changes the suggested delivery.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'How many excuses to return')]
    [ValidateRange(1, 10)]
    [int]$Count = 1,

    [Parameter(HelpMessage = 'Who needs to hear it')]
    [ValidateSet('Users', 'Management', 'Auditors', 'Vendor')]
    [string]$Audience = 'Users'
)

$url = 'https://pages.cs.wisc.edu/~ballard/bofh/excuses'

# For when the 1995 web page is having its own outage.
$fallback = @(
    'Solar flares.',
    'The router thinks it is a printer.',
    'Someone was calculating pi on the server.',
    'Static from nylon underwear.',
    'Interference from the microwave in the break room.',
    'The vendor changed the API. There was no API.',
    'A firewall rule that was definitely not there yesterday.',
    'DNS. It is always DNS.',
    'The certificate expired at the exact moment nobody was looking.',
    'An unscheduled reboot, which we are now calling a scheduled reboot.'
)

$delivery = switch ($Audience) {
    'Management' { 'Say it slowly, with a slide.' }
    'Auditors'   { 'Say it once, then refer all further questions to the change record.' }
    'Vendor'     { 'Say it in the ticket, then ask them to escalate.' }
    default      { 'Say it with confidence. Do not elaborate.' }
}

$source = 'pages.cs.wisc.edu/~ballard/bofh/excuses'
try {
    $raw = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Content
    # The file has no extension, so it may come back as bytes rather than a string.
    if ($raw -is [byte[]]) { $raw = [System.Text.Encoding]::UTF8.GetString($raw) }

    # One excuse per line. Skip blanks and the odd comment.
    $excuses = @($raw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^#' })
    if ($excuses.Count -lt 10) { throw "Downloaded the file but only found $($excuses.Count) lines in it." }
}
catch {
    Write-Warning "BOFH excuse list unavailable ($($_.Exception.Message)). Using the built-in list."
    $excuses = $fallback
    $source = 'built-in'
}

$excuses | Get-Random -Count ([Math]::Min($Count, $excuses.Count)) | ForEach-Object {
    [PSCustomObject]@{
        Excuse   = $_
        Audience = $Audience
        Delivery = $delivery
        Source   = $source
    }
}
