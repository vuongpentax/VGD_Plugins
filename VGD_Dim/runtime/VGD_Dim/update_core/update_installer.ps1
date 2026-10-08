param(
 [Parameter(Mandatory=$true)][string]$Archive,
 [Parameter(Mandatory=$true)][string]$Plugins,
 [Parameter(Mandatory=$true)][string]$ExpectedSha256,
 [Parameter(Mandatory=$true)][long]$ExpectedBytes,
 [Parameter(Mandatory=$true)][string]$Version
)
$ErrorActionPreference='Stop'
$preserveStage=$false
$owned=@(
 'vgd_dim.rb','VGD_Dim/main.rb','VGD_Dim/defaults.rb','VGD_Dim/reload.rb','VGD_Dim/engine.rb',
 'VGD_Dim/native_style.rb','VGD_Dim/store.rb','VGD_Dim/managed.rb','VGD_Dim/core.rb','VGD_Dim/presets.rb',
 'VGD_Dim/autostyle.rb','VGD_Dim/animation.rb','VGD_Dim/smartdim.rb','VGD_Dim/probe.rb','VGD_Dim/dialog.rb',
 'VGD_Dim/dialog.html','VGD_Dim/dialog.css','VGD_Dim/dialog.js','VGD_Dim/dim.svg','VGD_Dim/smart_dim.svg',
 'VGD_Dim/version.rb','VGD_Dim/update_core/manifest.rb','VGD_Dim/update_core/bootstrap.rb',
 'VGD_Dim/update_core/client.rb','VGD_Dim/update_core/installer.rb','VGD_Dim/update_core/updater.rb',
 'VGD_Dim/update_core/update_installer.ps1'
)
$root=[IO.Path]::GetFullPath($Plugins)
$plugin=Join-Path $root 'VGD_Dim'
$stage=Join-Path $root ('.VGD_Dim.stage_'+[guid]::NewGuid().ToString('N'))
$stagePlugin=Join-Path $stage 'VGD_Dim'
$backup=Join-Path $root ('VGD_Dim.backup_'+[guid]::NewGuid().ToString('N'))
$loader=Join-Path $root 'vgd_dim.rb'
$loaderBackup=Join-Path $root ('vgd_dim.backup_'+[guid]::NewGuid().ToString('N')+'.rb')
$journal=Join-Path $root 'vgd_dim_update.json'
$work=Join-Path ([IO.Path]::GetTempPath()) ('vgd_dim_extract_'+[guid]::NewGuid().ToString('N'))
function Assert-Within([string]$path,[string]$base) {
 $full=[IO.Path]::GetFullPath($path); $prefix=[IO.Path]::GetFullPath($base).TrimEnd('\')+'\'
 if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Path outside allowed root: $full" }
}
try {
 if ($Version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') { throw 'Invalid version.' }
 if ((Get-Item -LiteralPath $Archive).Length -ne $ExpectedBytes) { throw 'Archive size mismatch.' }
 if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $ExpectedSha256.ToLowerInvariant()) { throw 'Archive SHA-256 mismatch.' }
 if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'SketchUp Plugins folder is missing.' }
 New-Item -ItemType Directory -Path $work | Out-Null
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try {
   $names=@($zip.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
   if ($names.Count -ne $owned.Count -or @($names | Select-Object -Unique).Count -ne $names.Count -or
       @($names | Where-Object { $_ -notin $owned }).Count -gt 0 -or @($owned | Where-Object { $_ -notin $names }).Count -gt 0) {
     throw 'RBZ entries differ from updater whitelist.'
   }
 } finally { $zip.Dispose() }
 [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $work)
 New-Item -ItemType Directory -Path $stagePlugin | Out-Null
 if (Test-Path -LiteralPath $plugin) {
   if ((Get-Item -LiteralPath $plugin -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Plugin folder is a reparse point.' }
   $nestedLinks=@(Get-ChildItem -LiteralPath $plugin -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
   if ($nestedLinks.Count -gt 0) { throw "Plugin tree contains a reparse point; refusing to stage it." }
   Get-ChildItem -LiteralPath $plugin -Force | Copy-Item -Destination $stagePlugin -Recurse -Force
 }
 foreach ($rel in $owned) {
   $source=Join-Path $work $rel
   if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing archive member: $rel" }
   if ($rel -eq 'vgd_dim.rb') { Copy-Item -LiteralPath $source -Destination (Join-Path $stage 'vgd_dim.rb') }
   else {
     $inside=$rel.Substring('VGD_Dim/'.Length)
     $dest=Join-Path $stagePlugin $inside
     Assert-Within $dest $stagePlugin
     New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force | Out-Null
     Copy-Item -LiteralPath $source -Destination $dest -Force
   }
 }
 $expected=@{}
 foreach ($rel in $owned | Where-Object { $_ -ne 'vgd_dim.rb' }) {
   $inside=$rel.Substring('VGD_Dim/'.Length)
   $expected[$inside]=(Get-FileHash -LiteralPath (Join-Path $work $rel) -Algorithm SHA256).Hash
 }
 $expectedLoader=(Get-FileHash -LiteralPath (Join-Path $work 'vgd_dim.rb') -Algorithm SHA256).Hash
 $isInstalledSketchUpRoot = $root -like '*\SketchUp\SketchUp ????\SketchUp\Plugins'
 if ($isInstalledSketchUpRoot) {
   $deadline=(Get-Date).AddHours(8)
   while ((Get-Process -Name SketchUp -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
   if (Get-Process -Name SketchUp -ErrorAction SilentlyContinue) { throw 'SketchUp remained open; installation cancelled.' }
 }
 if (Test-Path -LiteralPath $loader) {
   if ((Get-Item -LiteralPath $loader -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Loader is a reparse point." }
   $loaderText=Get-Content -LiteralPath $loader -Raw
   if ($loaderText -notmatch 'VGD_Dim/main' -or $loaderText -notmatch 'module VGD') { throw 'Existing VGD Dim loader guard failed.' }
   Copy-Item -LiteralPath $loader -Destination $loaderBackup
 }
 $state=[ordered]@{phase='prepared';backup=$backup;loader_backup=$loaderBackup;expected=$expected;expected_loader=$expectedLoader}
 $journalTmp=$journal+'.tmp'
 $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journalTmp -Encoding UTF8
 Move-Item -LiteralPath $journalTmp -Destination $journal -Force
 $preserveStage=$true
 if (Test-Path -LiteralPath $plugin) { Move-Item -LiteralPath $plugin -Destination $backup }
 $state.phase='old_moved'; $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journalTmp -Encoding UTF8; Move-Item $journalTmp $journal -Force
 Move-Item -LiteralPath $stagePlugin -Destination $plugin
 Copy-Item -LiteralPath (Join-Path $stage 'vgd_dim.rb') -Destination $loader -Force
 $state.phase='new_moved'; $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journalTmp -Encoding UTF8; Move-Item $journalTmp $journal -Force
 foreach ($rel in $expected.Keys) {
   if ((Get-FileHash -LiteralPath (Join-Path $plugin $rel) -Algorithm SHA256).Hash -ne $expected[$rel]) { throw "Install verification failed: $rel" }
 }
 if ((Get-FileHash -LiteralPath $loader -Algorithm SHA256).Hash -ne $expectedLoader) { throw 'Loader verification failed.' }
 Remove-Item -LiteralPath $journal -Force
 Remove-Item -LiteralPath $stage -Recurse -Force
 $preserveStage=$false
} catch {
 if (Test-Path -LiteralPath $backup) {
   if (Test-Path -LiteralPath $plugin) { Move-Item -LiteralPath $plugin -Destination ($plugin+'.failed_'+[guid]::NewGuid().ToString('N')) }
   Move-Item -LiteralPath $backup -Destination $plugin
 }
 if (Test-Path -LiteralPath $loaderBackup) { Copy-Item -LiteralPath $loaderBackup -Destination $loader -Force }
 if (Test-Path -LiteralPath $journal) { Remove-Item -LiteralPath $journal -Force }
 throw
} finally {
 if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
 if (-not $preserveStage -and (Test-Path -LiteralPath $stage)) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
