
param(
    [string]$FontFile,
    [float]$FontSize,
    [int]$IsBold,
    [string]$GlyphTableJson = "thai_glyph_table.json",
    [string]$OutputPng,
    [string]$OutputJson
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class NativeFontRenderer {
    [DllImport("gdi32.dll", EntryPoint = "CreateCompatibleDC")]
    public static extern IntPtr CreateCompatibleDC(IntPtr hdc);

    [DllImport("gdi32.dll", EntryPoint = "DeleteDC")]
    public static extern bool DeleteDC(IntPtr hdc);

    [DllImport("gdi32.dll", EntryPoint = "SelectObject")]
    public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);

    [DllImport("gdi32.dll", EntryPoint = "DeleteObject")]
    public static extern bool DeleteObject(IntPtr hObject);

    [DllImport("gdi32.dll", EntryPoint = "SetTextColor")]
    public static extern uint SetTextColor(IntPtr hdc, int crColor);

    [DllImport("gdi32.dll", EntryPoint = "SetBkMode")]
    public static extern int SetBkMode(IntPtr hdc, int iBkMode);

    [DllImport("gdi32.dll", EntryPoint = "ExtTextOutW")]
    public static extern bool ExtTextOutW(IntPtr hdc, int X, int Y, uint fuOptions, IntPtr lprc, ushort[] lpString, uint cbCount, IntPtr lpDx);

    public const uint ETO_GLYPH_INDEX = 0x0010;
    public const int TRANSPARENT = 1;
}
"@ -ReferencedAssemblies System.Drawing

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($FontFile)
$ff = $pfc.Families[0]
$style = if ($IsBold -eq 1) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
$font = New-Object System.Drawing.Font($ff, $FontSize, $style, [System.Drawing.GraphicsUnit]::Pixel)
$hFont = $font.ToHfont()

$tableJson = [System.IO.File]::ReadAllText((Resolve-Path $GlyphTableJson).Path)
$glyphTable = ConvertFrom-Json $tableJson

# Scratch surface to draw individual glyphs
$scratchSize = 120
$scratchBmp = New-Object System.Drawing.Bitmap $scratchSize, $scratchSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$scratchG = [System.Drawing.Graphics]::FromImage($scratchBmp)
$scratchHdc = $scratchG.GetHdc()

[NativeFontRenderer]::SetBkMode($scratchHdc, [NativeFontRenderer]::TRANSPARENT)
[NativeFontRenderer]::SetTextColor($scratchHdc, 0x00FFFFFF)
$oldFont = [NativeFontRenderer]::SelectObject($scratchHdc, $hFont)

$processedGlyphs = @()

foreach ($item in $glyphTable) {
    $gid = [UInt16]$item.gid
    $code = [int]$item.code
    $type = [string]$item.type
    
    # Clear scratch HDC / bitmap
    # Note: drawing black rect
    $arr = [UInt16[]]@($gid)
    
    # We release HDC temporarily to clear with GDI+
    [NativeFontRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
    $scratchG.ReleaseHdc($scratchHdc)
    $scratchG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $scratchHdc = $scratchG.GetHdc()
    [NativeFontRenderer]::SetBkMode($scratchHdc, [NativeFontRenderer]::TRANSPARENT) | Out-Null
    [NativeFontRenderer]::SetTextColor($scratchHdc, 0x00FFFFFF) | Out-Null
    $oldFont = [NativeFontRenderer]::SelectObject($scratchHdc, $hFont)
    
    # Draw glyph at (30, 30)
    $drawX = 30
    $drawY = 30
    [NativeFontRenderer]::ExtTextOutW($scratchHdc, $drawX, $drawY, [NativeFontRenderer]::ETO_GLYPH_INDEX, [IntPtr]::Zero, $arr, 1, [IntPtr]::Zero) | Out-Null
    
    # Release HDC to read pixels with GDI+
    [NativeFontRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
    $scratchG.ReleaseHdc($scratchHdc)
    
    # Find bounding box
    $minX = $scratchSize; $maxX = -1; $minY = $scratchSize; $maxY = -1
    for ($y = 0; $y -lt $scratchSize; $y++) {
        for ($x = 0; $x -lt $scratchSize; $x++) {
            $p = $scratchBmp.GetPixel($x, $y)
            # In GDI ExtTextOut with white text on transparent, RGB is white
            if ($p.R -gt 20 -or $p.G -gt 20 -or $p.B -gt 20) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    
    $scratchHdc = $scratchG.GetHdc()
    $oldFont = [NativeFontRenderer]::SelectObject($scratchHdc, $hFont)
    
    if ($maxX -ge $minX -and $maxY -ge $minY) {
        $w = $maxX - $minX + 1
        $h = $maxY - $minY + 1
        
        $gBmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        # Copy pixels into gBmp with proper alpha
        for ($y = 0; $y -lt $h; $y++) {
            for ($x = 0; $x -lt $w; $x++) {
                $p = $scratchBmp.GetPixel($minX + $x, $minY + $y)
                $brightness = [int][Math]::Max($p.R, [Math]::Max($p.G, $p.B))
                if ($brightness -gt 0) {
                    $color = [System.Drawing.Color]::FromArgb($brightness, 255, 255, 255)
                    $gBmp.SetPixel($x, $y, $color)
                }
            }
        }
        
        $processedGlyphs += @{
            code = $code
            gid = $gid
            name = $item.name
            type = $type
            w = $w
            h = $h
            bitmap = $gBmp
        }
    }
}

[NativeFontRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
$scratchG.ReleaseHdc($scratchHdc)
$scratchG.Dispose()
$scratchBmp.Dispose()
[NativeFontRenderer]::DeleteObject($hFont) | Out-Null
$font.Dispose()
$pfc.Dispose()

Write-Host "Extracted $($processedGlyphs.Count) glyphs successfully."

# Pack into sheet
$sheetW = 300
$sheetH = 1000
$sheetBmp = New-Object System.Drawing.Bitmap $sheetW, $sheetH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sheetG = [System.Drawing.Graphics]::FromImage($sheetBmp)
$sheetG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

$curX = 4; $curY = 4; $rowH = 0
$metaList = @()

foreach ($g in $processedGlyphs) {
    if ($curX + $g.w + 2 -gt $sheetW) {
        $curX = 4
        $curY += $rowH + 2
        $rowH = 0
    }
    
    $sheetG.DrawImage($g.bitmap, $curX, $curY)
    
    $metaList += @{
        code = $g.code
        gid = $g.gid
        name = $g.name
        type = $g.type
        w = $g.w
        h = $g.h
        sheetX = $curX
        sheetY = $curY
    }
    
    $curX += $g.w + 2
    if ($g.h -gt $rowH) { $rowH = $g.h }
    $g.bitmap.Dispose()
}

$sheetG.Dispose()
$sheetBmp.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)
$sheetBmp.Dispose()

$metaJson = ConvertTo-Json -InputObject $metaList -Depth 3
[System.IO.File]::WriteAllText($OutputJson, $metaJson, [System.Text.Encoding]::UTF8)
Write-Host "Saved atlas to $OutputPng ($($metaList.Count) glyphs)"
