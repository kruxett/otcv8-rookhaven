Add-Type -AssemblyName System.Drawing

$src = "C:\RookhavenServerandClientCode\otcv8-rookhaven\data\images\clienticon.png"
$dst = "C:\RookhavenServerandClientCode\otcv8-rookhaven\src\otcicon.ico"

$png = [System.Drawing.Image]::FromFile($src)
$sizes = @(256, 128, 64, 48, 32, 16)

$imageDataList = @()
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($png, 0, 0, $size, $size)
    $g.Dispose()
    $imgMs = New-Object System.IO.MemoryStream
    $bmp.Save($imgMs, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $imageDataList += , $imgMs.ToArray()
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)

# ICO header
$bw.Write([uint16]0)          # reserved
$bw.Write([uint16]1)          # type: icon
$bw.Write([uint16]$sizes.Count)

# Directory entries - offset starts after header (6) + directory entries (16 each)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $sz = $sizes[$i]
    $dim = if ($sz -eq 256) { 0 } else { $sz }
    $imgBytes = $imageDataList[$i]
    $bw.Write([byte]$dim)
    $bw.Write([byte]$dim)
    $bw.Write([byte]0)         # color count
    $bw.Write([byte]0)         # reserved
    $bw.Write([uint16]1)       # planes
    $bw.Write([uint16]32)      # bit count
    $bw.Write([uint32]$imgBytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $imgBytes.Length
}

# Image data
foreach ($imgBytes in $imageDataList) {
    $bw.Write($imgBytes)
}

$bw.Flush()
[System.IO.File]::WriteAllBytes($dst, $ms.ToArray())
Write-Host "Done. ICO written to $dst ($($ms.Length) bytes)"
