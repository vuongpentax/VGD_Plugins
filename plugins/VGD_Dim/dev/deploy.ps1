[CmdletBinding()]
param([switch]$VerifyOnly)
$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $taskRoot 'runtime'
$pluginRoot = Join-Path $env:APPDATA 'SketchUp\SketchUp 2022\SketchUp\Plugins'
$ownedFiles = @(
    'vgd_dim.rb',
    'VGD_Dim\main.rb',
    'VGD_Dim\defaults.rb',
    'VGD_Dim\reload.rb',
    'VGD_Dim\engine.rb',
    'VGD_Dim\native_style.rb',
    'VGD_Dim\store.rb',
    'VGD_Dim\managed.rb',
    'VGD_Dim\core.rb',
    'VGD_Dim\presets.rb',
    'VGD_Dim\autostyle.rb',
    'VGD_Dim\animation.rb',
    'VGD_Dim\smartdim.rb',
    'VGD_Dim\regions.rb',
    'VGD_Dim\manual_dim.rb',
    'VGD_Dim\probe.rb',
    'VGD_Dim\dialog.rb',
    'VGD_Dim\dialog.html',
    'VGD_Dim\dialog.css',
    'VGD_Dim\dialog.js',
    'VGD_Dim\dim.svg',
    'VGD_Dim\smart_dim.svg',
    'VGD_Dim\version.rb',
    'VGD_Dim\update_core\manifest.rb',
    'VGD_Dim\update_core\bootstrap.rb',
    'VGD_Dim\update_core\client.rb',
    'VGD_Dim\update_core\installer.rb',
    'VGD_Dim\update_core\updater.rb',
    'VGD_Dim\update_core\update_installer.ps1'
)
function Assert-TaskPath([string]$Path,[string]$Root) {
    $full = [IO.Path]::GetFullPath($Path)
    $allowed = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($full -ne $allowed -and -not $full.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)) { throw "Ngoài phạm vi: $full" }
    $cursor = $full
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Junction/symlink không được phép: $cursor" }
        }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }; $cursor = $parent
    }
}
Assert-TaskPath $pluginRoot $pluginRoot
if (-not (Test-Path -LiteralPath $pluginRoot -PathType Container)) { throw 'Không tìm thấy Plugins SU 2022.' }
$loader = Join-Path $pluginRoot 'vgd_dim.rb'
Assert-TaskPath $loader $pluginRoot
if (Test-Path -LiteralPath $loader) {
    $text = Get-Content -LiteralPath $loader -Raw
    if ($text -notmatch 'VGD_Dim/main' -or $text -notmatch 'module VGD') { throw 'Loader hiện tại không thuộc VGD Dim; từ chối ghi đè.' }
}
# Explicit predecessor only. Keep its runtime files inert for recovery; never scan other extensions.
$legacy = Join-Path $pluginRoot 'tplus_dim.rb'
Assert-TaskPath $legacy $pluginRoot
$legacyHash = $null
if (Test-Path -LiteralPath $legacy) {
    $text = Get-Content -LiteralPath $legacy -Raw
    if ($text -notmatch 'TPlus_Dim/main' -or $text -notmatch 'module TPlus' -or $text -notmatch 'module Dim') { throw 'Bộ nạp cũ không thuộc T+ Dim; từ chối di chuyển.' }
    $legacyHash = (Get-FileHash -LiteralPath $legacy -Algorithm SHA256).Hash
}
$plan = @(foreach ($relative in $ownedFiles) {
    $src = Join-Path $sourceRoot $relative; $dst = Join-Path $pluginRoot $relative
    Assert-TaskPath $src $sourceRoot; Assert-TaskPath $dst $pluginRoot
    $hash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $exists = Test-Path -LiteralPath $dst -PathType Leaf
    $before = if ($exists) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { $null }
    [PSCustomObject]@{File=$relative;Source=$src;Destination=$dst;SourceSHA256=$hash;BeforeSHA256=$before;Existed=$exists;Changed=$before -ne $hash}
})
if ($VerifyOnly) {
    $plan | Select-Object File,Existed,Changed | Format-Table -AutoSize
    Write-Output ("T+ Dim loader còn bật: " + [bool]$legacyHash)
    return
}
$backupRoot = Join-Path $taskRoot ('outputs\install_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
Assert-TaskPath $backupRoot $taskRoot
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($entry in $plan | Where-Object Changed) {
    if ($entry.Existed) {
        $backup = Join-Path $backupRoot $entry.File
        Assert-TaskPath $backup $backupRoot
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backup)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Destination -Destination $backup
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $entry.BeforeSHA256) { throw 'Sao lưu không khớp.' }
    }
}
$legacyBackup = Join-Path $backupRoot 'legacy\tplus_dim.rb'
Assert-TaskPath $legacyBackup $backupRoot
if ($legacyHash) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($legacyBackup)) -Force | Out-Null
    Copy-Item -LiteralPath $legacy -Destination $legacyBackup
    if ((Get-FileHash -LiteralPath $legacyBackup -Algorithm SHA256).Hash -ne $legacyHash) { throw 'Sao lưu bộ nạp cũ không khớp.' }
}
$written = @()
$legacyDisabled = $false
try {
    foreach ($entry in $plan | Where-Object Changed) {
        $written += $entry
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($entry.Destination)) -Force | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $entry.Destination -Force
    }
    foreach ($entry in $plan) {
        if ((Get-FileHash -LiteralPath $entry.Destination -Algorithm SHA256).Hash -ne $entry.SourceSHA256) { throw "Sai SHA256: $($entry.File)" }
    }
    if ($legacyHash) {
        if ((Get-FileHash -LiteralPath $legacy -Algorithm SHA256).Hash -ne $legacyHash) { throw 'Bộ nạp T+ Dim đã đổi trong lúc cài.' }
        Assert-TaskPath $legacy $pluginRoot
        Remove-Item -LiteralPath $legacy
        $legacyDisabled = $true
    }
    [PSCustomObject]@{Target=$pluginRoot;Status='VERIFIED';LegacyLoaderDisabled=$legacyDisabled;LegacyBackup=$legacyBackup;Files=$plan} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'INSTALL_REPORT.json') -Encoding UTF8
} catch {
    if ($legacyDisabled) { Copy-Item -LiteralPath $legacyBackup -Destination $legacy }
    foreach ($entry in $written) {
        Assert-TaskPath $entry.Destination $pluginRoot
        if ($entry.Existed) {
            Copy-Item -LiteralPath (Join-Path $backupRoot $entry.File) -Destination $entry.Destination -Force
        } elseif (Test-Path -LiteralPath $entry.Destination -PathType Leaf) {
            Remove-Item -LiteralPath $entry.Destination
        }
    }
    throw
}
Write-Output ("Đã cài VGD Dim vào SketchUp 2022; {0}/{0} file khớp SHA256. T+ Dim loader đã tắt: {1}. Backup: {2}" -f $plan.Count,$legacyDisabled,$backupRoot)
