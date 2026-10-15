$ErrorActionPreference = 'Stop'

$pluginRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = Join-Path $pluginRoot 'VGD_Package.rb'
$pluginFolder = Join-Path $pluginRoot 'VGD_Package'
$outputFolder = Join-Path $pluginFolder 'outputs'
$packagePath = Join-Path $outputFolder 'VGD_Package_v0.1.3.rbz'
$zipBuildPath = Join-Path $outputFolder 'VGD_Package_v0.1.3_build.zip'
$stagingRoot = Join-Path $outputFolder ('.staging-' + [guid]::NewGuid().ToString('N'))
$outputRootResolved = [System.IO.Path]::GetFullPath($outputFolder).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$stagingRootResolved = [System.IO.Path]::GetFullPath($stagingRoot)
if (-not $stagingRootResolved.StartsWith($outputRootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw 'Staging path escaped the plugin outputs directory.'
}

if (-not (Test-Path -LiteralPath $sourceFile) -or -not (Test-Path -LiteralPath $pluginFolder)) {
  throw 'VGD_Package.rb or the VGD_Package runtime folder is missing.'
}

New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null
New-Item -ItemType Directory -Path $stagingRoot | Out-Null
try {
  Copy-Item -LiteralPath $sourceFile -Destination $stagingRoot
  $stagedPlugin = Join-Path $stagingRoot 'VGD_Package'
  New-Item -ItemType Directory -Path $stagedPlugin | Out-Null
  Get-ChildItem -LiteralPath $pluginFolder -Force | Where-Object { $_.Name -ne 'outputs' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stagedPlugin -Recurse
  }
  if (Test-Path -LiteralPath $zipBuildPath) { Remove-Item -LiteralPath $zipBuildPath -Force }
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::Open($zipBuildPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Get-ChildItem -LiteralPath $stagingRoot -File -Recurse | ForEach-Object {
      $entryName = $_.FullName.Substring($stagingRootResolved.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace('\', '/')
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive, $_.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  } finally {
    $archive.Dispose()
  }
  if (Test-Path -LiteralPath $packagePath) { Remove-Item -LiteralPath $packagePath -Force }
  Move-Item -LiteralPath $zipBuildPath -Destination $packagePath
} finally {
  if (Test-Path -LiteralPath $zipBuildPath) { Remove-Item -LiteralPath $zipBuildPath -Force -ErrorAction SilentlyContinue }
  if ((Test-Path -LiteralPath $stagingRootResolved) -and $stagingRootResolved.StartsWith($outputRootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $stagingRootResolved -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Get-FileHash -LiteralPath $packagePath -Algorithm SHA256 | ForEach-Object {
  "$($_.Hash.ToLowerInvariant())  $([System.IO.Path]::GetFileName($packagePath))"
} | Set-Content -LiteralPath "$packagePath.sha256" -Encoding ascii
Write-Output "Created $packagePath"
