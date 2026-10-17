param(
  [Parameter(Mandatory = $true)][string]$Pdf,
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Page = 0,
  [int]$Dpi = 200
)
# Renders one page of a PDF to PNG with the Windows 10 PDF engine (no extra software needed).
# Prints one JSON line: { "width_mm", "height_mm", "pages", "png" } or { "error" }.
$ErrorActionPreference = 'Stop'
try {
  if ($Dpi -lt 50 -or $Dpi -gt 600) { throw 'DPI must be between 50 and 600.' }
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
  $null = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
  $null = [Windows.Storage.Streams.InMemoryRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]

  $operationTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
      $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]
  function Wait-Operation($operation, [Type]$resultType) {
    $task = $operationTask.MakeGenericMethod($resultType).Invoke($null, @($operation))
    $null = $task.Wait(-1)
    $task.Result
  }

  $actionTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
      $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
    })[0]
  function Wait-Action($action) {
    $task = $actionTask.Invoke($null, @($action))
    $null = $task.Wait(-1)
  }

  $file = Wait-Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path -LiteralPath $Pdf).Path)) ([Windows.Storage.StorageFile])
  $document = Wait-Operation ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
  if ($Page -lt 0 -or $Page -ge $document.PageCount) { throw "The PDF has $($document.PageCount) page(s); page $Page does not exist." }
  $pdfPage = $document.GetPage($Page)
  $factor = $Dpi / 96.0   # PDF page sizes are reported in 1/96 inch units
  $options = New-Object Windows.Data.Pdf.PdfPageRenderOptions
  $options.DestinationWidth = [uint32][Math]::Round($pdfPage.Size.Width * $factor)
  $options.DestinationHeight = [uint32][Math]::Round($pdfPage.Size.Height * $factor)
  $stream = New-Object Windows.Storage.Streams.InMemoryRandomAccessStream
  $null = (Wait-Action ($pdfPage.RenderToStreamAsync($stream, $options)))
  $reader = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($stream)
  $reader.Position = 0
  $target = [System.IO.File]::Create($Out)
  try { $reader.CopyTo($target) } finally { $target.Dispose(); $reader.Dispose() }
  [pscustomobject]@{
    width_mm = [Math]::Round($pdfPage.Size.Width / 96.0 * 25.4, 2)
    height_mm = [Math]::Round($pdfPage.Size.Height / 96.0 * 25.4, 2)
    pages = [int]$document.PageCount
    png = $Out
  } | ConvertTo-Json -Compress
} catch {
  [pscustomobject]@{ error = $_.Exception.Message } | ConvertTo-Json -Compress
  exit 1
}
