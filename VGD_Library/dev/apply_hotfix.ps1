$ErrorActionPreference = 'Stop'
$vgdProject = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vgdRuntime = Join-Path $vgdProject 'runtime'
$vgdPlugins = Join-Path $env:APPDATA 'SketchUp\SketchUp 2022\SketchUp\Plugins'
$vgdResolvedPlugins = (Resolve-Path -LiteralPath $vgdPlugins).Path
if ($vgdResolvedPlugins -ne [IO.Path]::GetFullPath($vgdPlugins)) { throw 'Unexpected plugin directory resolution.' }
if (-not (Test-Path -LiteralPath (Join-Path $vgdResolvedPlugins 'vgd_library\catalog.rb') -PathType Leaf)) { throw 'VGD_Library is not installed in SketchUp 2022.' }
$vgdFiles = @('vgd_library.rb', 'vgd_library\catalog.rb', 'vgd_library\main.rb', 'vgd_library\online.rb', 'vgd_library\seamless.rb', 'vgd_library\shell_sync.rb')
$vgdBackup = Join-Path $vgdProject ('outputs\installed-backup-1.1.1-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path (Join-Path $vgdBackup 'vgd_library') -Force | Out-Null
foreach ($vgdRelative in $vgdFiles) {
    $vgdSource = Join-Path $vgdRuntime $vgdRelative
    $vgdDestination = [IO.Path]::GetFullPath((Join-Path $vgdResolvedPlugins $vgdRelative))
    if (-not $vgdDestination.StartsWith($vgdResolvedPlugins + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escaped the SketchUp Plugins directory.' }
    if (-not (Test-Path -LiteralPath $vgdSource -PathType Leaf)) { throw "Missing source: $vgdRelative" }
    if (-not (Test-Path -LiteralPath $vgdDestination -PathType Leaf)) { throw "Missing installed file: $vgdRelative" }
    Copy-Item -LiteralPath $vgdDestination -Destination (Join-Path $vgdBackup $vgdRelative)
}
foreach ($vgdRelative in $vgdFiles) {
    $vgdSource = Join-Path $vgdRuntime $vgdRelative
    $vgdDestination = Join-Path $vgdResolvedPlugins $vgdRelative
    Copy-Item -LiteralPath $vgdSource -Destination $vgdDestination -Force
    if ((Get-FileHash -LiteralPath $vgdSource -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $vgdDestination -Algorithm SHA256).Hash) { throw "Verification failed: $vgdRelative" }
}
Write-Output "Updated and verified $($vgdFiles.Count) VGD_Library files for SketchUp 2022."
Write-Output "Backup: $vgdBackup"
Write-Output 'Save drawings, close every SketchUp window, then restart to load 1.1.1-beta.1.'
