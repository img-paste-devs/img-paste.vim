Param(
  [string]$directory
)

Add-Type -Assembly PresentationCore
$image = [Windows.Clipboard]::GetImage()
if ($image -eq $null) {
    return 1
}
#Write-Host ("Screenshot:  {0}x{1} Pixel." -f $image.PixelWidth,$image.PixelHeight)
$fcb = new-object Windows.Media.Imaging.FormatConvertedBitmap($image, [Windows.Media.PixelFormats]::Rgb24, $null, 0)
$file_name = ("{0}\clipboard-{1}.png" -f $directory,((Get-Date -f s) -replace '[-T:]',''))
$stream = [IO.File]::Open($file_name, "OpenOrCreate")
$encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($fcb))
$encoder.Save($stream)
#$stream.Dispose()
return $file_name
