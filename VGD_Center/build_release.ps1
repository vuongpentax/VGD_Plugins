param(
  [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version phải là số stable dạng x.y.z.' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$catalogPath = Join-Path $repoRoot 'shared\vgd-center\catalog.json'
$rootLoader = Join-Path $repoRoot 'VGD_Center.rb'
$supportFiles = @(
  @{ Source = (Join-Path $PSScriptRoot 'main.rb'); Entry = 'VGD_Center/main.rb' },
  @{ Source = (Join-Path $PSScriptRoot 'dialog.html'); Entry = 'VGD_Center/dialog.html' },
  @{ Source = (Join-Path $PSScriptRoot 'icon.svg'); Entry = 'VGD_Center/icon.svg' },
  @{ Source = $catalogPath; Entry = 'VGD_Center/catalog.json' }
)
$outputDir = Join-Path $PSScriptRoot 'outputs'
$rbzPath = Join-Path $outputDir "VGD_Center_v$Version.rbz"
$sourcePath = Join-Path $outputDir "VGD_Center_v$Version`_source.zip"
$hashPath = Join-Path $outputDir "VGD_Center_v$Version.rbz.sha256"

if (-not (Test-Path -LiteralPath $catalogPath)) { throw "Thiếu catalog: $catalogPath" }
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($catalog.schema_version -ne 1 -or $catalog.channel -ne 'stable') { throw 'Catalog không đúng schema stable.' }
if (Test-Path -LiteralPath $rbzPath) { throw "Đã tồn tại, không ghi đè: $rbzPath" }
if (Test-Path -LiteralPath $sourcePath) { throw "Đã tồn tại, không ghi đè: $sourcePath" }
if (Test-Path -LiteralPath $hashPath) { throw "Đã tồn tại, không ghi đè: $hashPath" }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "RELEASE_NOTES_v$Version.md"))) { throw "Thiếu release notes cho $Version." }

foreach ($product in $catalog.products) {
  if ($product.version -notmatch '^\d+\.\d+\.\d+$') { throw "Catalog chứa bản prerelease: $($product.id)" }
  if ($product.download.url -match '^https://raw\.githubusercontent\.com/vuongpentax/VGD_Plugins/[0-9a-f]{40}/(.+)$') {
    $relativePackage = $Matches[1] -replace '/', '\'
    $packagePath = Join-Path $repoRoot $relativePackage
    if (-not (Test-Path -LiteralPath $packagePath)) { throw "Thiếu gói catalog: $packagePath" }
    $packageInfo = Get-Item -LiteralPath $packagePath
    $packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($packageInfo.Length -ne [int64]$product.download.size -or $packageHash -ne $product.download.sha256.ToLowerInvariant()) {
      throw "Dung lượng hoặc SHA-256 không khớp catalog cho $($product.id)."
    }
  }
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$zip = [System.IO.Compression.ZipFile]::Open($rbzPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $rootLoader, 'VGD_Center.rb') | Out-Null
  foreach ($file in $supportFiles) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.Source, $file.Entry) | Out-Null
  }
}
finally {
  $zip.Dispose()
}

$zip = [System.IO.Compression.ZipFile]::Open($sourcePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $rootLoader, 'VGD_Center.rb') | Out-Null
  foreach ($file in $supportFiles) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.Source, $file.Entry) | Out-Null
  }
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $PSScriptRoot 'README.md'), 'README.md') | Out-Null
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $PSScriptRoot "RELEASE_NOTES_v$Version.md"), "RELEASE_NOTES_v$Version.md") | Out-Null
}
finally {
  $zip.Dispose()
}

$digest = (Get-FileHash -LiteralPath $rbzPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $hashPath -Value "$digest  VGD_Center_v$Version.rbz" -Encoding ASCII
Write-Output "Created: $rbzPath"
Write-Output "Created: $sourcePath"
Write-Output "SHA-256: $digest"
