#requires -Version 7.0

<#
.SYNOPSIS
    Greets someone by name. The "hello world" of the session - proof that a
    plain PowerShell script becomes an AI-callable tool with zero glue code.

.PARAMETER Name
    Who to greet.

.PARAMETER Style
    How enthusiastic to be about it.

.PARAMETER Times
    How many times to repeat the greeting.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = 'Who to greet')]
    [string]$Name,

    [ValidateSet('Formal', 'Casual', 'Texan', 'Pirate')]
    [string]$Style = 'Casual',

    [ValidateRange(1, 5)]
    [int]$Times = 1
)

$greeting = switch ($Style) {
    'Formal' { "Good day, $Name." }
    'Texan' { "Howdy, $Name! Welcome to the Cloud and AI Summit." }
    'Pirate' { "Ahoy, $Name! Welcome to the Cloud and AI Summit." }
    default { "Hey $Name - welcome to MCP for Everything." }
}

[PSCustomObject]@{
    Greeting    = (1..$Times | ForEach-Object { $greeting }) -join ' '
    Style       = $Style
    GeneratedOn = (Get-Date).ToString('u')
    RunningOn   = [System.Environment]::MachineName
    PSVersion   = $PSVersionTable.PSVersion.ToString()
}
