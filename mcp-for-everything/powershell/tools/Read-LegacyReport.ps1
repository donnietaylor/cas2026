#requires -Version 7.0

<#
.SYNOPSIS
    Parses the fixed-width nightly order report that the mainframe has been
    dropping on a file share since before some of this audience was born, and
    hands it back as structured objects. Each order carries a ProductId and
    Quantity; ProductId is the same key Get-SqlInventory returns, so stock on hand
    can be compared against held or open orders.

.DESCRIPTION
    This is the demo that earns the word "Everything" in the session title.

    There is no API. There is no vendor. There is no support contract. There is a
    93-column fixed-width text file, a scheduled task, and a person who retired in
    2019. And in about twenty lines of PowerShell it becomes something an AI agent
    can reason about - with zero changes to the system that produces it.

    Every organisation has three of these. That is the point.

.PARAMETER Path
    Path to the fixed-width report file.

.PARAMETER Status
    Only return rows with this status.

.PARAMETER MinAmount
    Only return rows at or above this amount.

.PARAMETER ProductId
    Only return orders for this product (the ProductId from Get-SqlInventory).
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Path to the fixed-width report file')]
    [string]$Path = (Join-Path $PSScriptRoot '..' '..' 'data' 'legacy-orders.txt'),

    [Parameter(HelpMessage = 'Filter to one status')]
    [ValidateSet('OPEN', 'HELD', 'SHIPPED', 'CANCELLED', 'All')]
    [string]$Status = 'All',

    [Parameter(HelpMessage = 'Minimum order amount')]
    [double]$MinAmount = 0,

    [Parameter(HelpMessage = 'Only orders for this ProductId (0 = all)')]
    [ValidateRange(0, 99999)]
    [int]$ProductId = 0
)

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Legacy report not found at $Path"
}

# The column map. In real life this lives in a Word document from 2004 and the
# only copy is on a share nobody can find. Write it down in the script instead.
$columns = @(
    @{ Name = 'OrderId'; Start = 0;  Length = 10 }
    @{ Name = 'Customer'; Start = 10; Length = 28 }
    @{ Name = 'OrderDate'; Start = 38; Length = 10 }
    @{ Name = 'Status'; Start = 48; Length = 10 }
    @{ Name = 'Amount'; Start = 58; Length = 12 }
    @{ Name = 'Region'; Start = 70; Length = 10 }
    @{ Name = 'ProductId'; Start = 80; Length = 6 }
    @{ Name = 'Quantity'; Start = 86; Length = 7 }
)

$rows = foreach ($line in (Get-Content -LiteralPath $Path)) {
    # Skip headers, rulers, footers, page breaks and blanks - the file has all of them.
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -match '^(ORDER ID|-{5,}|=|REPORT|TOTAL|PAGE|CONTINUED|\*{3})') { continue }
    if ($line.Length -lt 70) { continue }

    $record = [ordered]@{}
    foreach ($col in $columns) {
        $len = [Math]::Min($col.Length, $line.Length - $col.Start)
        $record[$col.Name] = if ($len -gt 0) { $line.Substring($col.Start, $len).Trim() } else { '' }
    }

    [PSCustomObject]@{
        OrderId   = $record.OrderId
        Customer  = $record.Customer
        OrderDate = $record.OrderDate
        Status    = $record.Status
        Amount    = [double]($record.Amount -replace '[^\d.\-]', '')
        Region    = $record.Region
        ProductId = [int]$record.ProductId
        Quantity  = [int]$record.Quantity
    }
}

$rows |
    Where-Object { $Status -eq 'All' -or $_.Status -eq $Status } |
    Where-Object { $_.Amount -ge $MinAmount } |
    Where-Object { $ProductId -eq 0 -or $_.ProductId -eq $ProductId } |
    Sort-Object Amount -Descending
