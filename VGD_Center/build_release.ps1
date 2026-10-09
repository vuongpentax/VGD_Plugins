param(
  [string]$Version = '1.0.9'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version phải là số stable dạng x.y.z.' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$catalogPath = Join-Path $repoRoot 'shared\vgd-center\catalog.json'
$centerManifestPath = Join-Path $repoRoot 'shared\vgd-center\center-update.json'
$rootLoader = Join-Path $repoRoot 'VGD_Center.rb'
$supportFiles = @(
  @{ Source = (Join-Path $PSScriptRoot 'main.rb'); Entry = 'VGD_Center/main.rb' },
  @{ Source = (Join-Path $PSScriptRoot 'dialog.html'); Entry = 'VGD_Center/dialog.html' },
  @{ Source = (Join-Path $PSScriptRoot 'icon.svg'); Entry = 'VGD_Center/icon.svg' },
  @{ Source = $catalogPath; Entry = 'VGD_Center/catalog.json' },
  @{ Source = $centerManifestPath; Entry = 'VGD_Center/center-update.json' }
)
$guideFiles = @(
  @{ Source = (Join-Path $PSScriptRoot 'guides\center.html'); Entry = 'VGD_Center/guides/center.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\dim.html'); Entry = 'VGD_Center/guides/dim.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\cabinet.html'); Entry = 'VGD_Center/guides/cabinet.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\library.html'); Entry = 'VGD_Center/guides/library.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\image_importer.html'); Entry = 'VGD_Center/guides/image_importer.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\scenes.html'); Entry = 'VGD_Center/guides/scenes.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\bim_lite.html'); Entry = 'VGD_Center/guides/bim_lite.html' },
  @{ Source = (Join-Path $PSScriptRoot 'guides\reference.html'); Entry = 'VGD_Center/guides/reference.html' }
)
$outputDir = Join-Path $PSScriptRoot 'outputs'
$rbzPath = Join-Path $outputDir "VGD_Center_v$Version.rbz"
$sourcePath = Join-Path $outputDir "VGD_Center_v$Version`_source.zip"
$hashPath = Join-Path $outputDir "VGD_Center_v$Version.rbz.sha256"

if (-not (Test-Path -LiteralPath $catalogPath)) { throw "Thiếu catalog: $catalogPath" }
if (-not (Test-Path -LiteralPath $centerManifestPath)) { throw "Thiếu manifest cập nhật Center: $centerManifestPath" }
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($catalog.schema_version -ne 1 -or $catalog.channel -ne 'latest') { throw 'Catalog không đúng schema latest.' }
$centerManifest = Get-Content -LiteralPath $centerManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($centerManifest.schema_version -ne 1 -or $centerManifest.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Manifest Center không đúng schema stable.' }
if ($centerManifest.download.filename -ne "VGD_Center_v$($centerManifest.version).rbz") { throw 'Tên RBZ trong manifest Center không khớp phiên bản.' }
$centerUrl = [string]$centerManifest.download.url
$centerUrlAllowed = $centerUrl.StartsWith('https://github.com/vuongpentax/VGD_Plugins/releases/download/') -or $centerUrl.StartsWith('https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/shared/vgd-center/packages/')
if (-not $centerUrlAllowed -or -not $centerUrl.EndsWith("/$($centerManifest.download.filename)")) { throw 'URL RBZ trong manifest Center không hợp lệ.' }
if ($centerManifest.version -ne $Version) {
$centerPackagePath = Join-Path $PSScriptRoot ("outputs\" + $centerManifest.download.filename)
if (-not (Test-Path -LiteralPath $centerPackagePath)) { throw "Thiếu RBZ stable được khai báo trong manifest Center: $centerPackagePath" }
$centerPackageInfo = Get-Item -LiteralPath $centerPackagePath
$centerPackageHash = (Get-FileHash -LiteralPath $centerPackagePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($centerPackageInfo.Length -ne [int64]$centerManifest.download.size -or $centerPackageHash -ne $centerManifest.download.sha256.ToLowerInvariant()) { throw 'Dung lượng hoặc SHA-256 của RBZ stable VGD Center không khớp manifest.' }
}
if (Test-Path -LiteralPath $rbzPath) { throw "Đã tồn tại, không ghi đè: $rbzPath" }
if (Test-Path -LiteralPath $sourcePath) { throw "Đã tồn tại, không ghi đè: $sourcePath" }
if (Test-Path -LiteralPath $hashPath) { throw "Đã tồn tại, không ghi đè: $hashPath" }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "RELEASE_NOTES_v$Version.md"))) { throw "Thiếu release notes cho $Version." }

$localPackages = @{
  dim = 'VGD_Dim/outputs/VGD_Dim_v3.3.0-beta.5.rbz'
  cabinet = 'VGD_Cabinet/outputs/vgd_cabinet_modeling/VGD_Cabinet_v4.5.0-beta.4.rbz'
  library = 'VGD_Library/VGD_Library_v1.1.2-beta.4.rbz'
  image_importer = 'VGD_Image_Importer/VGD_Image_Importer_v1.1.0-beta.5.rbz'
  scenes = 'VGD_Scenes/VGD_Scenes_v1.5.3-beta.3.rbz'
  bim_lite = 'VGD_BIM/VGD_BIM_Lite_v0.1.4-alpha.rbz'
  reference = 'VGD_Reference/VGD_Reference_v1.0.0-beta.6.rbz'
}
foreach ($product in $catalog.products) {
  if ($product.version -notmatch '^\d+\.\d+\.\d+(?:-(?:alpha|beta)(?:\.\d+)?)?$') { throw "Catalog chứa phiên bản không hỗ trợ: $($product.id)" }
  $expectedChannel = if ($product.version -match '-(alpha|beta)') { $Matches[1] } else { 'stable' }
  if ($product.release_channel -ne $expectedChannel) { throw "Kênh phát hành không khớp phiên bản: $($product.id)" }
  if (-not $localPackages.ContainsKey($product.id)) { throw "Không có đường dẫn kiểm tra gói cho $($product.id)." }
  $packagePath = Join-Path $repoRoot ($localPackages[$product.id] -replace '/', '\')
  if (-not (Test-Path -LiteralPath $packagePath)) { throw "Thiếu gói catalog: $packagePath" }
  $packageInfo = Get-Item -LiteralPath $packagePath
  $packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($packageInfo.Length -ne [int64]$product.download.size -or $packageHash -ne $product.download.sha256.ToLowerInvariant()) {
    throw "Dung lượng hoặc SHA-256 không khớp catalog cho $($product.id)."
  }
}
foreach ($guide in $guideFiles) {
  if (-not (Test-Path -LiteralPath $guide.Source)) { throw "Thiếu hướng dẫn: $($guide.Source)" }
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$zip = [System.IO.Compression.ZipFile]::Open($rbzPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $rootLoader, 'VGD_Center.rb') | Out-Null
  foreach ($file in $supportFiles) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.Source, $file.Entry) | Out-Null
  }
  foreach ($guide in $guideFiles) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $guide.Source, $guide.Entry) | Out-Null
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
  foreach ($guide in $guideFiles) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $guide.Source, $guide.Entry) | Out-Null
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
