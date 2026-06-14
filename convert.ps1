Add-Type -AssemblyName System.Drawing
$pngPath = "firsthit.png"
$tgaPath = "firsthit.tga"

if (-not (Test-Path $pngPath)) {
    Write-Output "PNG not found!"
    exit 1
}

$bmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $pngPath).Path)

# Minimap icons in WoW 3.3.5a are usually 32x32 or 64x64. Let's use 64x64 for better resolution.
$width = 64
$height = 64
$resized = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($resized)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($bmp, 0, 0, $width, $height)
$g.Dispose()

$fs = [System.IO.File]::Create((Join-Path (Get-Location).Path $tgaPath))
$bw = New-Object System.IO.BinaryWriter($fs)

# TGA Header for 32-bit uncompressed RGB
$bw.Write([byte]0)   # ID length
$bw.Write([byte]0)   # Color map type
$bw.Write([byte]2)   # Image type 2 = uncompressed RGB
$bw.Write([byte]0)   # Color map spec 1
$bw.Write([byte]0)
$bw.Write([byte]0)
$bw.Write([byte]0)
$bw.Write([byte]0)
$bw.Write([int16]0)  # X origin
$bw.Write([int16]0)  # Y origin
$bw.Write([int16]$width)  # Width
$bw.Write([int16]$height) # Height
$bw.Write([byte]32)  # Pixel depth (32 bpp)
$bw.Write([byte]0x28) # Image descriptor (Top-to-Bottom, 8-bit alpha)

# Pixel data (BGRA order)
for ($y = 0; $y -lt $height; $y++) {
    for ($x = 0; $x -lt $width; $x++) {
        $color = $resized.GetPixel($x, $y)
        $bw.Write([byte]$color.B)
        $bw.Write([byte]$color.G)
        $bw.Write([byte]$color.R)
        $bw.Write([byte]$color.A)
    }
}

$bw.Close()
$fs.Close()
$resized.Dispose()
$bmp.Dispose()

Write-Output "Image converted successfully to $tgaPath"
