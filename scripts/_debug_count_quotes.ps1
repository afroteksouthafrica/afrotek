$path = 'c:\Users\afrot\projects\afrotek\scripts\deploy-product.ps1'
$s = Get-Content -Raw $path
$count = ($s.ToCharArray() | Where-Object { $_ -eq '"' }).Count
Write-Host "Double-quote count: $count"
# Also print a few lines around the end for inspection
$lines = Get-Content $path -Encoding UTF8
$start = [Math]::Max(0, $lines.Count - 30)
$lines[$start..($lines.Count-1)] | ForEach-Object { "$($_ -replace '\t','    ')" }
