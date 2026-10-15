param([Parameter(Mandatory=$true)][string]$Source, [Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationCore
$stream = [IO.File]::OpenRead($Source)
try {
  $decoder = [Windows.Media.Imaging.BitmapDecoder]::Create($stream, [Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
  $frame = $decoder.Frames[0]
  if ([long]$frame.PixelWidth * [long]$frame.PixelHeight -gt 32000000) { throw 'Ảnh vượt giới hạn 32 triệu pixel.' }
  $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
  $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($frame))
  $output = [IO.File]::Create($Destination)
  try { $encoder.Save($output) } finally { $output.Dispose() }
} finally { $stream.Dispose() }
