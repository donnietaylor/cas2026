#requires -Version 7.0
<#
.SYNOPSIS
    Turns a folder of ordinary PowerShell scripts into an MCP tool manifest.

.DESCRIPTION
    This is the whole trick behind the session.

    PowerShell already has everything MCP needs to describe a tool:
      * comment-based help (.SYNOPSIS)  -> tool description
      * [Parameter(Mandatory)]          -> JSON Schema "required"
      * the parameter's [type]          -> JSON Schema "type"
      * [ValidateSet] / [ValidateRange] -> "enum" / "minimum" / "maximum"
      * HelpMessage / .PARAMETER help   -> per-property description
      * the approved verb + ShouldProcess -> read-only vs. destructive hints

    So we do not hand-write JSON Schema anywhere. We read it out of the
    scripts you already know how to write.

    Emits a single JSON document on stdout. The Python host calls this once at
    startup and again whenever a file in the tools folder changes.

.PARAMETER ToolPath
    Folder containing *.ps1 tool scripts. Defaults to ./tools.

.EXAMPLE
    ./Get-ToolManifest.ps1 | ConvertFrom-Json | Select-Object -Expand tools | Format-Table name, readOnly
#>
[CmdletBinding()]
param(
    [string]$ToolPath = (Join-Path $PSScriptRoot 'tools')
)

$ErrorActionPreference = 'Stop'

# Parameters PowerShell adds for free. The model does not need to see them.
$script:CommonParameters = @(
    'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ProgressAction',
    'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer',
    'PipelineVariable', 'WhatIf', 'Confirm'
)

# The approved-verb list has been a permission model this whole time.
$script:ReadOnlyVerbs = @(
    'Get', 'Read', 'Search', 'Find', 'Test', 'Measure', 'Select',
    'Show', 'Compare', 'Resolve', 'Trace', 'Convert', 'ConvertTo', 'ConvertFrom'
)

function ConvertTo-SchemaType {
    <# Map a .NET type onto a JSON Schema fragment. #>
    param([Type]$Type)

    if ($null -eq $Type) { return @{ type = 'string' } }

    # Unwrap Nullable<T>
    $inner = [Nullable]::GetUnderlyingType($Type)
    if ($inner) { $Type = $inner }

    if ($Type.IsArray) {
        return @{
            type  = 'array'
            items = (ConvertTo-SchemaType -Type $Type.GetElementType())
        }
    }

    if ($Type.IsEnum) {
        return @{
            type = 'string'
            enum = [string[]][Enum]::GetNames($Type)
        }
    }

    switch ($Type.FullName) {
        'System.String' { return @{ type = 'string' } }
        'System.Char' { return @{ type = 'string' } }
        'System.Boolean' { return @{ type = 'boolean' } }
        'System.Management.Automation.SwitchParameter' { return @{ type = 'boolean' } }
        'System.Int16' { return @{ type = 'integer' } }
        'System.Int32' { return @{ type = 'integer' } }
        'System.Int64' { return @{ type = 'integer' } }
        'System.UInt32' { return @{ type = 'integer'; minimum = 0 } }
        'System.UInt64' { return @{ type = 'integer'; minimum = 0 } }
        'System.Single' { return @{ type = 'number' } }
        'System.Double' { return @{ type = 'number' } }
        'System.Decimal' { return @{ type = 'number' } }
        'System.DateTime' { return @{ type = 'string'; format = 'date-time' } }
        'System.Guid' { return @{ type = 'string'; format = 'uuid' } }
        'System.Collections.Hashtable' { return @{ type = 'object' } }
        default { return @{ type = 'string' } }
    }
}

function Get-ParameterDefault {
    <#
        Pull literal default values straight out of the AST. Get-Command gives us
        types and attributes but not defaults, so we read the param block itself.
    #>
    param([string]$Path)

    $defaults = @{}
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    if (-not $ast.ParamBlock) { return $defaults }

    foreach ($p in $ast.ParamBlock.Parameters) {
        if ($null -eq $p.DefaultValue) { continue }
        $name = $p.Name.VariablePath.UserPath
        try {
            # SafeGetValue only evaluates constant expressions - it will not run code.
            $defaults[$name] = $p.DefaultValue.SafeGetValue()
        }
        catch {
            # Non-constant default (e.g. (Get-Date)); skip it rather than executing anything.
        }
    }
    return $defaults
}

function Get-ToolAccess {
    <#
        Read-only or state-changing? PowerShell already told us, twice:
        the approved verb, and whether the author opted into ShouldProcess.
    #>
    param([string]$Path, [System.Management.Automation.CommandInfo]$Command)

    $leaf = [IO.Path]::GetFileNameWithoutExtension($Path)
    $verb = ($leaf -split '-')[0]

    $supportsShouldProcess = $false
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    if ($ast.ParamBlock -and $ast.ParamBlock.Attributes) {
        foreach ($attr in $ast.ParamBlock.Attributes) {
            if ($attr.TypeName.Name -ne 'CmdletBinding') { continue }
            foreach ($named in $attr.NamedArguments) {
                if ($named.ArgumentName -eq 'SupportsShouldProcess') { $supportsShouldProcess = $true }
            }
        }
    }

    $readOnly = ($verb -in $script:ReadOnlyVerbs) -and -not $supportsShouldProcess

    return @{
        readOnly              = $readOnly
        destructive           = $supportsShouldProcess
        supportsShouldProcess = $supportsShouldProcess
        verb                  = $verb
    }
}

# ---------------------------------------------------------------------------
# Walk the tools folder
# ---------------------------------------------------------------------------

$tools = [System.Collections.Generic.List[object]]::new()
$problems = [System.Collections.Generic.List[object]]::new()

$files = Get-ChildItem -Path $ToolPath -Filter '*.ps1' -File |
    Where-Object { -not $_.Name.StartsWith('_') } |
    Sort-Object Name

foreach ($file in $files) {
    try {
        $command = Get-Command -Name $file.FullName -CommandType ExternalScript
        $help = Get-Help -Name $file.FullName -ErrorAction SilentlyContinue
        $defaults = Get-ParameterDefault -Path $file.FullName
        $access = Get-ToolAccess -Path $file.FullName -Command $command

        $properties = [ordered]@{}
        $required = [System.Collections.Generic.List[string]]::new()

        foreach ($key in $command.Parameters.Keys) {
            if ($key -in $script:CommonParameters) { continue }
            $meta = $command.Parameters[$key]

            $schema = ConvertTo-SchemaType -Type $meta.ParameterType
            $isMandatory = $false
            $description = $null

            foreach ($attr in $meta.Attributes) {
                switch ($attr.GetType().Name) {
                    'ParameterAttribute' {
                        if ($attr.Mandatory) { $isMandatory = $true }
                        if ($attr.HelpMessage) { $description = $attr.HelpMessage }
                    }
                    'ValidateSetAttribute' {
                        $schema.Remove('format')
                        $schema['enum'] = [string[]]$attr.ValidValues
                        $schema['type'] = 'string'
                    }
                    'ValidateRangeAttribute' {
                        if ($null -ne $attr.MinRange) { $schema['minimum'] = $attr.MinRange }
                        if ($null -ne $attr.MaxRange) { $schema['maximum'] = $attr.MaxRange }
                    }
                    'ValidatePatternAttribute' {
                        $schema['pattern'] = $attr.RegexPattern
                    }
                    'ValidateLengthAttribute' {
                        $schema['minLength'] = $attr.MinLength
                        $schema['maxLength'] = $attr.MaxLength
                    }
                    'ValidateCountAttribute' {
                        $schema['minItems'] = $attr.MinLength
                        $schema['maxItems'] = $attr.MaxLength
                    }
                }
            }

            # .PARAMETER help beats HelpMessage when both are present - it is
            # usually the more descriptive of the two.
            $helpParam = $help.parameters.parameter | Where-Object { $_.name -eq $key } | Select-Object -First 1
            if ($helpParam -and $helpParam.description) {
                $text = ($helpParam.description | ForEach-Object { $_.Text }) -join ' '
                if ($text.Trim()) { $description = $text.Trim() }
            }

            if ($description) { $schema['description'] = $description }
            if ($defaults.ContainsKey($key)) { $schema['default'] = $defaults[$key] }

            $properties[$key] = $schema
            if ($isMandatory) { $required.Add($key) }
        }

        $synopsis = if ($help -and $help.Synopsis) { $help.Synopsis.Trim() } else { '' }

        # Gotcha worth knowing: if a #requires statement sits directly against the
        # <# .SYNOPSIS #> block with no blank line between them, PowerShell silently
        # stops parsing comment-based help and Get-Help hands back the syntax string
        # instead. The tool still works - it just shows up to the model with a
        # useless description, which is worse. Catch it here and say so out loud.
        if ($synopsis.StartsWith($file.Name)) {
            $problems.Add([ordered]@{
                    file  = $file.Name
                    error = 'Comment-based help did not parse (Get-Help returned the syntax string). Check for a #requires statement directly above <# .SYNOPSIS #> with no blank line between them.'
                })
            $synopsis = ''
        }

        if (-not $synopsis) { $synopsis = "PowerShell tool: $($file.BaseName)" }

        $inputSchema = [ordered]@{
            type                 = 'object'
            properties           = $properties
            additionalProperties = $false
        }
        if ($required.Count -gt 0) { $inputSchema['required'] = [string[]]$required }

        $tools.Add([ordered]@{
                name         = $file.BaseName
                description  = $synopsis
                scriptPath   = $file.FullName
                inputSchema  = $inputSchema
                readOnly     = $access.readOnly
                destructive  = $access.destructive
                verb         = $access.verb
                lastModified = $file.LastWriteTimeUtc.ToString('o')
            })
    }
    catch {
        # One bad script must not take the whole manifest down mid-demo.
        $problems.Add([ordered]@{
                file  = $file.Name
                error = $_.Exception.Message
            })
    }
}

[ordered]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    toolRoot    = (Resolve-Path $ToolPath).Path
    psVersion   = $PSVersionTable.PSVersion.ToString()
    tools       = $tools
    problems    = $problems
} | ConvertTo-Json -Depth 20 -Compress
