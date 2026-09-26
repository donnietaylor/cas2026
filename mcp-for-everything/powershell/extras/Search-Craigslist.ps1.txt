#requires -Version 7.0

<#
.SYNOPSIS
    Searches Craigslist for-sale listings in a metro area and returns title,
    price, location and link for each result. Craigslist has no API.

.DESCRIPTION
    A public website with no API, no feed (RSS was removed in 2021) and no
    intention of ever offering one. The search page is still plain HTML, so the
    tool is Invoke-WebRequest plus one regex per listing.

    This is the pattern for any website: fetch the page, find the repeating
    element, pull the fields out of it, emit objects. Same shape as netstat.

.PARAMETER Query
    What to search for, e.g. 'tractor', 'zero turn mower', 'server rack'.

.PARAMETER Area
    Craigslist metro slug - the subdomain part of the site, e.g. dallas, austin,
    houston, sanantonio, oklahomacity, denver, seattle, sfbay, newyork.

.PARAMETER Category
    Listing category. ForSale searches everything.

.PARAMETER MinPrice
    Only listings priced at or above this amount.

.PARAMETER MaxPrice
    Only listings priced at or below this amount.

.PARAMETER PostedToday
    Only listings posted in the last 24 hours.

.PARAMETER TitleOnly
    Match the query against titles only, not body text.

.PARAMETER Sort
    Sort order: Newest, PriceLowToHigh, PriceHighToLow.

.PARAMETER MaxResults
    Maximum number of listings to return.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = 'What to search for')]
    [ValidateLength(1, 100)]
    [string]$Query,

    [Parameter(HelpMessage = 'Craigslist metro slug, e.g. dallas, austin, houston')]
    [ValidatePattern('^[a-z]{2,20}$')]
    [string]$Area = 'dallas',

    [Parameter(HelpMessage = 'Listing category')]
    [ValidateSet('ForSale', 'FarmGarden', 'Tools', 'HeavyEquipment', 'CarsTrucks', 'Electronics',
                 'Computers', 'Furniture', 'Appliances', 'Materials', 'Boats', 'Bikes', 'Free')]
    [string]$Category = 'ForSale',

    [Parameter(HelpMessage = 'Minimum price')]
    [ValidateRange(0, 10000000)]
    [int]$MinPrice,

    [Parameter(HelpMessage = 'Maximum price')]
    [ValidateRange(0, 10000000)]
    [int]$MaxPrice,

    [Parameter(HelpMessage = 'Only listings from the last 24 hours')]
    [switch]$PostedToday,

    [Parameter(HelpMessage = 'Match titles only')]
    [switch]$TitleOnly,

    [Parameter(HelpMessage = 'Sort order')]
    [ValidateSet('Newest', 'PriceLowToHigh', 'PriceHighToLow')]
    [string]$Sort = 'Newest',

    [Parameter(HelpMessage = 'Maximum listings to return')]
    [ValidateRange(1, 120)]
    [int]$MaxResults = 25
)

# Craigslist's own category codes. The friendly names are for the model; these are for the URL.
$categoryCode = @{
    ForSale = 'sss'; FarmGarden = 'gra'; Tools = 'tla'; HeavyEquipment = 'hva'; CarsTrucks = 'cta'
    Electronics = 'ela'; Computers = 'sya'; Furniture = 'fua'; Appliances = 'ppa'; Materials = 'maa'
    Boats = 'boo'; Bikes = 'bia'; Free = 'zip'
}
$sortCode = @{ Newest = 'date'; PriceLowToHigh = 'priceasc'; PriceHighToLow = 'pricedsc' }

# Build the query string the same way the site's own search form does.
$qs = [System.Collections.Generic.List[string]]::new()
$qs.Add("query=$([uri]::EscapeDataString($Query))")
$qs.Add("sort=$($sortCode[$Sort])")
if ($MinPrice)    { $qs.Add("min_price=$MinPrice") }
if ($MaxPrice)    { $qs.Add("max_price=$MaxPrice") }
if ($PostedToday) { $qs.Add('postedToday=1') }
if ($TitleOnly)   { $qs.Add('srchType=T') }

$url = "https://$Area.craigslist.org/search/$($categoryCode[$Category])?$($qs -join '&')"

$response = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 5 `
    -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36' `
    -ErrorAction Stop
$html = $response.Content

# Each result is one <li class="cl-static-search-result" title="..."> with an <a href>,
# a div.title, a div.price and a div.location inside it. Everything else on the page
# is ignored.
$listing = '(?s)<li[^>]+class="cl-static-search-result"[^>]*title="(?<Title>[^"]*)"[^>]*>(?<Body>.*?)</li>'

$results = [regex]::Matches($html, $listing) | ForEach-Object {
    $body = $_.Groups['Body'].Value
    $href = if ($body -match 'href="(?<Href>[^"]+)"')                          { $Matches.Href } else { $null }
    $price = if ($body -match '<div class="price">\s*(?<Price>[^<]*)</div>')    { $Matches.Price.Trim() } else { '' }
    $where = if ($body -match '<div class="location">\s*(?<Loc>[^<]*)</div>')   { $Matches.Loc.Trim() } else { '' }

    [PSCustomObject]@{
        Title    = [System.Net.WebUtility]::HtmlDecode($_.Groups['Title'].Value)
        Price    = if ($price -match '[\d,]+') { [int]($Matches[0] -replace ',', '') } else { $null }
        Location = [System.Net.WebUtility]::HtmlDecode($where)
        PostId   = if ($href -match '/(?<Id>\d{9,})\.html') { $Matches.Id } else { $null }
        Url      = $href
    }
}

if (-not $results -and $html -notmatch 'cl-static-search-result' -and $html -match 'craigslist') {
    # Page came back but not in the shape we parse. Say so instead of returning nothing.
    Write-Warning "Craigslist returned a page with no static results for $url - the markup may have changed, or this area/category combination has no listings."
}

$results | Select-Object -First $MaxResults
