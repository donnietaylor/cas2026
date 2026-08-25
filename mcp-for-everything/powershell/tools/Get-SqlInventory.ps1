#requires -Version 7.0

<#
.SYNOPSIS
    Queries the product inventory in Azure SQL. Demonstrates the single most
    common real-world ask: "let the assistant read our database" - done
    without ever letting it write SQL.

.DESCRIPTION
    Note what is NOT happening here: the model does not send us a query. It
    sends us parameters. We own the SQL, we parameterise it, and the database
    connection uses a read-only login.

    The moment you expose a run_sql(query) tool, your security model is
    "whatever the model felt like typing." Expose questions, not a query engine.

.PARAMETER Category
    Product category to filter on.

.PARAMETER MaxPrice
    Only return products at or below this price.

.PARAMETER BelowReorderPoint
    Only return products whose stock has fallen below the reorder threshold.
#>
[CmdletBinding()]
param(
    [Parameter(HelpMessage = 'Product category to filter on')]
    [ValidateSet('Widgets', 'Gadgets', 'Sprockets', 'All')]
    [string]$Category = 'All',

    [Parameter(HelpMessage = 'Maximum unit price')]
    [ValidateRange(0, 100000)]
    [double]$MaxPrice = 100000,

    [Parameter(HelpMessage = 'Only items below their reorder threshold')]
    [switch]$BelowReorderPoint
)

Import-Module (Join-Path $PSScriptRoot '..' 'CasDemo.psm1') -Force

# Parameterised. Always. The model's input is never concatenated into SQL.
$sql = @'
SELECT TOP (200)
       p.ProductId, p.Name, p.Category, p.UnitPrice,
       i.QuantityOnHand, i.ReorderPoint
FROM   dbo.Products  AS p
JOIN   dbo.Inventory AS i ON i.ProductId = p.ProductId
WHERE  (@Category = 'All' OR p.Category = @Category)
  AND  p.UnitPrice <= @MaxPrice
  AND  (@BelowReorder = 0 OR i.QuantityOnHand < i.ReorderPoint)
ORDER BY p.Name;
'@

Invoke-WithFallback -Name 'sql-inventory' -Live {
    Import-Module SqlServer -ErrorAction Stop

    if (-not $env:SQL_CONNECTION_STRING) {
        throw 'SQL_CONNECTION_STRING is not set.'
    }

    $params = @{
        Category     = $Category
        MaxPrice     = $MaxPrice
        BelowReorder = [int]$BelowReorderPoint.IsPresent
    }

    Invoke-Sqlcmd -ConnectionString $env:SQL_CONNECTION_STRING `
                  -Query $sql `
                  -SqlParameters $params `
                  -ErrorAction Stop |
        ForEach-Object {
            [PSCustomObject]@{
                ProductId      = $_.ProductId
                Name           = $_.Name
                Category       = $_.Category
                UnitPrice      = [double]$_.UnitPrice
                QuantityOnHand = [int]$_.QuantityOnHand
                ReorderPoint   = [int]$_.ReorderPoint
                NeedsReorder   = ([int]$_.QuantityOnHand -lt [int]$_.ReorderPoint)
            }
        }
}
