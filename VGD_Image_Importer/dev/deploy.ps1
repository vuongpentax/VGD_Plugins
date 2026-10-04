param(
  [switch]$VerifyOnly,
  [string]$PluginRoot = (Join-Path $env:APPDATA 'SketchUp\SketchUp 2022\SketchUp\Plugins')
)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtime = Join-Path $project 'runtime'
$pluginRoot = [IO.Path]::GetFullPath($PluginRoot).TrimEnd('\')
$owned = @('vgd_image_importer.rb','vgd_image_importer\engine.rb','vgd_image_importer\main.rb','vgd_image_importer\file_picker.rb','vgd_image_importer\conversion.rb','vgd_image_importer\convert_image.ps1','vgd_image_importer\dialog.html','vgd_image_importer\dialog.css','vgd_image_importer\dialog.js','vgd_image_importer\icon.svg','vgd_image_importer\vgd_icon.png')
function Assert-Target([string]$path) {
  $absolute = [IO.Path]::GetFullPath($path)
  if (-not $absolute.StartsWith($pluginRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Target outside Plugins: $absolute" }
  $cursor = $absolute
  while ($cursor.Length -ge $pluginRoot.Length) {
    if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refuse reparse point: $cursor" }
    $cursor = [IO.Path]::GetDirectoryName($cursor)
  }
  return $absolute
}
if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) { throw 'SketchUp Plugins directory not found.' }
$loader = Assert-Target (Join-Path $pluginRoot 'vgd_image_importer.rb')
if (Test-Path -LiteralPath $loader) {
  $existing = Get-Content -LiteralPath $loader -Raw
  if ($existing -notmatch 'module VGD_ImageImporter' -or $existing -notmatch "SketchupExtension.new\('VGD Image Importer'") { throw 'Existing loader has unverified ownership.' }
} elseif (Test-Path -LiteralPath (Join-Path $pluginRoot 'vgd_image_importer')) { throw 'Existing plugin folder has no verified loader.' }
foreach ($relative in $owned) {
  $null = Assert-Target (Join-Path $pluginRoot $relative)
  if (-not (Test-Path -LiteralPath (Join-Path $runtime $relative) -PathType Leaf)) { throw "Missing source: $relative" }
}
if ($VerifyOnly) { Write-Output "Verified VGD Image Importer ownership and $($owned.Count) exact file targets."; exit 0 }
$backup = Join-Path $project ('outputs\install_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$null = New-Item -ItemType Directory -Path $backup
$previous = @{}
$originalHashes = @{}
$writesStarted = $false
try {
  # Finish the complete backup before modifying any installed file.
  foreach ($relative in $owned) {
    $target = Assert-Target (Join-Path $pluginRoot $relative)
    $previous[$relative] = Test-Path -LiteralPath $target
    if ($previous[$relative]) {
      $saved = Join-Path $backup $relative
      $null = New-Item -ItemType Directory -Path (Split-Path $saved) -Force
      Copy-Item -LiteralPath $target -Destination $saved
      $originalHashes[$relative] = (Get-FileHash -LiteralPath $target).Hash
      if ((Get-FileHash -LiteralPath $saved).Hash -ne $originalHashes[$relative]) { throw "Backup mismatch: $relative" }
    }
  }
  $writesStarted = $true
  $null = New-Item -ItemType Directory -Path (Assert-Target (Join-Path $pluginRoot 'vgd_image_importer')) -Force
  foreach ($relative in $owned) {
    $source = Join-Path $runtime $relative
    $target = Assert-Target (Join-Path $pluginRoot $relative)
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw "Install mismatch: $relative" }
  }
  $report = [ordered]@{ plugin_root=$pluginRoot; installed_at=(Get-Date -Format o); version='1.1.0-beta.2'; files=$owned; existed_before=$previous; original_hashes=$originalHashes; backup=$backup; verified=$true }
  $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'install_report.json') -Encoding utf8
  Write-Output ($report | ConvertTo-Json -Depth 5)
} catch {
  if ($writesStarted) {
    foreach ($relative in $previous.Keys) {
      $target = Assert-Target (Join-Path $pluginRoot $relative)
      $saved = Join-Path $backup $relative
      if ($previous[$relative] -and (Test-Path -LiteralPath $saved)) { Copy-Item -LiteralPath $saved -Destination $target -Force }
      elseif (-not $previous[$relative] -and (Test-Path -LiteralPath $target)) { Remove-Item -LiteralPath $target }
    }
  }
  throw
}
