$path = 'c:\Users\afrot\projects\afrotek\scripts\deploy-product.ps1'
$code = Get-Content -Raw $path
$errors = $null
[System.Management.Automation.Language.Parser]::ParseInput($code,[ref]$errors,[ref]$null) | Out-Null
if ($errors) { $errors | ForEach-Object { $_.ToString() } } else { Write-Host 'No parse errors' }