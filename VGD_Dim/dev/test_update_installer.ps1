$ErrorActionPreference = 'Stop'
$pluginRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputRoot = [IO.Path]::GetFullPath((Join-Path $pluginRoot 'outputs'))
$caseRoot = [IO.Path]::GetFullPath((Join-Path $outputRoot ('update_fixture_' + [guid]::NewGuid().ToString('N'))))
$prefix = $outputRoot.TrimEnd('\') + '\'
if (-not $caseRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped plugin outputs.' }
$manifest = Get-Content -LiteralPath (Join-Path $pluginRoot 'VGD_UPDATE_MANIFEST.json') -Raw | ConvertFrom-Json
$archive = Join-Path $outputRoot $manifest.filename
if (-not (Test-Path -LiteralPath $archive)) { throw "Missing RBZ: $archive" }
$plugins = Join-Path $caseRoot 'Plugins'
$oldPlugin = Join-Path $plugins 'VGD_Dim'
New-Item -ItemType Directory -Path (Join-Path $oldPlugin 'custom') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $oldPlugin 'main.rb') -Value 'old runtime' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $oldPlugin 'custom\keep.txt') -Value 'preserve this unmanaged file' -Encoding UTF8
$loader = Join-Path $plugins 'vgd_dim.rb'
Set-Content -LiteralPath $loader -Value "module VGD; end; require 'VGD_Dim/main'" -Encoding UTF8
$helper = Join-Path $pluginRoot 'runtime\VGD_Dim\update_core\update_installer.ps1'
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $helper -Archive $archive -Plugins $plugins -ExpectedSha256 $manifest.sha256 -ExpectedBytes $manifest.bytes -Version $manifest.version
  if ($LASTEXITCODE -ne 0) { throw "Installer helper exited with code $LASTEXITCODE." }
  $newVersion = Get-Content -LiteralPath (Join-Path $oldPlugin 'version.rb') -Raw
  if ($newVersion -notmatch [regex]::Escape($manifest.version)) { throw 'New runtime version was not installed.' }
  if ((Get-Content -LiteralPath (Join-Path $oldPlugin 'custom\keep.txt') -Raw).Trim() -ne 'preserve this unmanaged file') { throw 'Unmanaged plugin file was not preserved.' }
  $backups = @(Get-ChildItem -LiteralPath $plugins -Directory -Filter 'VGD_Dim.backup_*')
  if ($backups.Count -ne 1 -or (Get-Content -LiteralPath (Join-Path $backups[0].FullName 'main.rb') -Raw).Trim() -ne 'old runtime') { throw 'Old plugin backup was not preserved.' }
  if (Test-Path -LiteralPath (Join-Path $plugins 'vgd_dim_update.json')) { throw 'Transaction journal remained after successful install.' }
  if (Get-ChildItem -LiteralPath $plugins -Directory -Filter '.VGD_Dim.stage_*') { throw 'Staging directory remained after successful install.' }
  Write-Output 'PASS: helper validates package, swaps the plugin directory, preserves unmanaged content, retains backup, and closes journal.'
} finally {
  if (Test-Path -LiteralPath $caseRoot) {
    $resolved = [IO.Path]::GetFullPath($caseRoot)
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to remove a path outside outputs.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
}
