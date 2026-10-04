param(
    [string]$FontFile,
    [float]$FontSize = 32.0,
    [int]$IsBold = 0,
    [string]$CharsetJson = "tables_and_configs/full_charset_table.json",
    [int]$AtlasWidth = 512,
    [int]$AtlasHeight = 512,
    [string]$OutputBase
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

[StructLayout(LayoutKind.Sequential)]
public struct TEXTMETRIC {
    public int tmHeight;
    public int tmAscent;
    public int tmDescent;
    public int tmInternalLeading;
    public int tmExternalLeading;
    public int tmAveCharWidth;
    public int tmMaxCharWidth;
    public int tmWeight;
    public int tmOverhang;
    public int tmDigitizedAspectX;
    public int tmDigitizedAspectY;
    public char tmFirstChar;
    public char tmLastChar;
    public char tmDefaultChar;
    public char tmBreakChar;
    public byte tmItalic;
    public byte tmUnderlined;
    public byte tmStruckOut;
    public byte tmPitchAndFamily;
    public byte tmCharSet;
}

public class FullCharsetRenderer {
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

    [DllImport("gdi32.dll", EntryPoint = "GetGlyphIndicesW", CharSet = CharSet.Unicode)]
    public static extern uint GetGlyphIndices(IntPtr hdc, string lpstr, int c, [Out] ushort[] pgi, uint fl);

    [DllImport("gdi32.dll", EntryPoint = "GetCharWidth32W", CharSet = CharSet.Unicode)]
    public static extern bool GetCharWidth32(IntPtr hdc, uint iFirstChar, uint iLastChar, [Out] int[] lpBuffer);

    [DllImport("gdi32.dll", EntryPoint = "GetTextMetricsW", CharSet = CharSet.Unicode)]
    public static extern bool GetTextMetrics(IntPtr hdc, out TEXTMETRIC lptm);

    public const uint ETO_GLYPH_INDEX = 0x0010;
    public const int TRANSPARENT = 1;
}
"@ -ReferencedAssemblies System.Drawing

if (-not (Test-Path $FontFile)) {
    Write-Error "Font file not found: $FontFile"
    exit 1
}

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile((Resolve-Path $FontFile).Path)
$ff = $pfc.Families[0]
$style = if ($IsBold -eq 1) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
$font = New-Object System.Drawing.Font($ff, $FontSize, $style, [System.Drawing.GraphicsUnit]::Pixel)
$hFont = $font.ToHfont()

$tableJson = [System.IO.File]::ReadAllText((Resolve-Path $CharsetJson).Path)
$charset = ConvertFrom-Json $tableJson

# Scratch surface to draw individual glyphs
$scratchSize = [int][Math]::Max(160, $FontSize * 3.0)
$scratchBmp = New-Object System.Drawing.Bitmap $scratchSize, $scratchSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$scratchG = [System.Drawing.Graphics]::FromImage($scratchBmp)
$scratchHdc = $scratchG.GetHdc()

$oldFont = [FullCharsetRenderer]::SelectObject($scratchHdc, $hFont)
[FullCharsetRenderer]::SetBkMode($scratchHdc, [FullCharsetRenderer]::TRANSPARENT)
[FullCharsetRenderer]::SetTextColor($scratchHdc, 0x00FFFFFF)

$tm = New-Object TEXTMETRIC
[FullCharsetRenderer]::GetTextMetrics($scratchHdc, [ref]$tm) | Out-Null
$lineHeight = $tm.tmHeight
$base = $tm.tmAscent

$drawOriginX = 40
$drawOriginY = 40

$processedGlyphs = @()
$renderedByGid = @{}
$packedCoordsByGid = @{}
$widthBuf = New-Object Int32[] 1
$gidBuf = New-Object UInt16[] 1

foreach ($item in $charset) {
    $code = [int]$item.code
    $charStr = [string]$item.char
    $name = if ($item.name) { [string]$item.name } else { $charStr }
    $type = [string]$item.type

    # Determine GID
    $gid = 0
    if ($item.gid) {
        $gid = [UInt16]$item.gid
    } else {
        [FullCharsetRenderer]::GetGlyphIndices($scratchHdc, $charStr, 1, $gidBuf, 0) | Out-Null
        $gid = $gidBuf[0]
    }

    # Determine Advance Width
    $advance = 0
    if ($code -eq 0xF710) {
        # Tho Than Cut Tail (0xF710) has the exact same advance width as Tho Than (0x0E10)
        if ([FullCharsetRenderer]::GetCharWidth32($scratchHdc, 0x0E10, 0x0E10, $widthBuf)) {
            $advance = $widthBuf[0]
        }
    } elseif ($code -eq 0xF70F) {
        # Yo Ying Cut Tail (0xF70F) has the exact same advance width as Yo Ying (0x0E0D)
        if ([FullCharsetRenderer]::GetCharWidth32($scratchHdc, 0x0E0D, 0x0E0D, $widthBuf)) {
            $advance = $widthBuf[0]
        }
    } elseif ($code -ge 0 -and $code -le 0xFFFF) {
        if ([FullCharsetRenderer]::GetCharWidth32($scratchHdc, [uint32]$code, [uint32]$code, $widthBuf)) {
            $advance = $widthBuf[0]
        }
    }

    $isCombining = ($type -like "*tone*" -or $type -like "*vowel*" -or $type -like "*mark*") -and ($type -notlike "*consonant*") -and ($type -ne "normal")
    if ($isCombining) {
        $advance = 0
    } elseif ($advance -le 0) {
        $advance = [int]($FontSize * 0.5)
    }

    # Handle whitespace characters (Space, No-break space)
    if ($type -eq "space" -or $code -eq 32 -or $code -eq 160) {
        $processedGlyphs += @{
            code = $code
            char = " "
            name = $name
            type = $type
            gid = $gid
            w = 0
            h = 0
            xoffset = 0
            yoffset = 0
            xadvance = $advance
            bitmap = $null
            reuseGid = 0
        }
        continue
    }

    # Check if this GID has already been extracted
    if ($gid -gt 0 -and $renderedByGid.ContainsKey($gid)) {
        $prev = $renderedByGid[$gid]
        $processedGlyphs += @{
            code = $code
            char = $charStr
            name = $name
            type = $type
            gid = $gid
            w = $prev.w
            h = $prev.h
            xoffset = $prev.xoffset
            yoffset = $prev.yoffset
            xadvance = $advance
            bitmap = $null
            reuseGid = $gid
        }
        continue
    }

    # Clear scratch surface
    [FullCharsetRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
    $scratchG.ReleaseHdc($scratchHdc)
    $scratchG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $scratchHdc = $scratchG.GetHdc()
    [FullCharsetRenderer]::SetBkMode($scratchHdc, [FullCharsetRenderer]::TRANSPARENT) | Out-Null
    [FullCharsetRenderer]::SetTextColor($scratchHdc, 0x00FFFFFF) | Out-Null
    $oldFont = [FullCharsetRenderer]::SelectObject($scratchHdc, $hFont)

    # Draw glyph using GID
    $arr = [UInt16[]]@($gid)
    [FullCharsetRenderer]::ExtTextOutW($scratchHdc, $drawOriginX, $drawOriginY, [FullCharsetRenderer]::ETO_GLYPH_INDEX, [IntPtr]::Zero, $arr, 1, [IntPtr]::Zero) | Out-Null

    # Release HDC to read pixels with GDI+
    [FullCharsetRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
    $scratchG.ReleaseHdc($scratchHdc)

    # Find tight bounding box
    $minX = $scratchSize; $maxX = -1; $minY = $scratchSize; $maxY = -1
    for ($y = 0; $y -lt $scratchSize; $y++) {
        for ($x = 0; $x -lt $scratchSize; $x++) {
            $p = $scratchBmp.GetPixel($x, $y)
            if ($p.R -gt 15 -or $p.G -gt 15 -or $p.B -gt 15) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    $scratchHdc = $scratchG.GetHdc()
    $oldFont = [FullCharsetRenderer]::SelectObject($scratchHdc, $hFont)

    if ($maxX -ge $minX -and $maxY -ge $minY) {
        $w = $maxX - $minX + 1
        $h = $maxY - $minY + 1
        $xoff = $minX - $drawOriginX
        $yoff = $minY - $drawOriginY

        # PUA Tone Marks GPOS anchor adjustment for static bitmap fonts
        # In TrueType OpenType, GIDs 347-356 rely on dynamic GPOS anchors.
        # For standalone bitmap fonts (BMFont / Texture Atlas), apply the design offsets:
        if ($code -ge 0xF705 -and $code -le 0xF709) {
            # Shifted tones (Level 2 on tall consonant without upper vowel: ป่า, ปุ๊, ฟุ้ง)
            $yoff -= [int][Math]::Round($FontSize * 0.22)
            $xoff -= [int][Math]::Round($FontSize * 0.08)
        } elseif ($code -ge 0xF70A -and $code -le 0xF70E) {
            # High Shifted tones (Level 3 on tall consonant with upper vowel: ปี่, ปิ่, ปี้, ฟื้น)
            $yoff -= [int][Math]::Round($FontSize * 0.18)
            # Center over shifted upper vowel (around -12 to -14px)
            if ($code -eq 0xF70A) { $xoff -= [int][Math]::Round($FontSize * 0.24) }
            elseif ($code -eq 0xF70B) { $xoff -= [int][Math]::Round($FontSize * 0.14) }
            elseif ($code -eq 0xF70C) { $xoff -= [int][Math]::Round($FontSize * 0.08) }
            elseif ($code -eq 0xF70D) { $xoff -= [int][Math]::Round($FontSize * 0.20) }
            elseif ($code -eq 0xF70E) { $xoff -= [int][Math]::Round($FontSize * 0.18) }
        }

        $gBmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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

        $renderedByGid[$gid] = @{
            w = $w
            h = $h
            xoffset = $xoff
            yoffset = $yoff
        }

        $processedGlyphs += @{
            code = $code
            char = $charStr
            name = $name
            type = $type
            gid = $gid
            w = $w
            h = $h
            xoffset = $xoff
            yoffset = $yoff
            xadvance = $advance
            bitmap = $gBmp
            reuseGid = 0
        }
    } else {
        # Character produced no pixels (fallback)
        $processedGlyphs += @{
            code = $code
            char = $charStr
            name = $name
            type = $type
            gid = $gid
            w = 0
            h = 0
            xoffset = 0
            yoffset = 0
            xadvance = $advance
            bitmap = $null
            reuseGid = 0
        }
    }
}

[FullCharsetRenderer]::SelectObject($scratchHdc, $oldFont) | Out-Null
$scratchG.ReleaseHdc($scratchHdc)
$scratchG.Dispose()
$scratchBmp.Dispose()
[FullCharsetRenderer]::DeleteObject($hFont) | Out-Null
$font.Dispose()
$pfc.Dispose()

Write-Host "Processed $($processedGlyphs.Count) characters. Packing into atlas ${AtlasWidth}x${AtlasHeight}..."

# Pack into sheet
$atlasBmp = New-Object System.Drawing.Bitmap $AtlasWidth, $AtlasHeight, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$atlasG = [System.Drawing.Graphics]::FromImage($atlasBmp)
$atlasG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

$curX = 4; $curY = 4; $rowH = 0
$finalGlyphs = @()

foreach ($g in $processedGlyphs) {
    if ($g.reuseGid -and $packedCoordsByGid.ContainsKey($g.reuseGid)) {
        $atlasX = $packedCoordsByGid[$g.reuseGid].x
        $atlasY = $packedCoordsByGid[$g.reuseGid].y
    } elseif ($g.w -gt 0 -and $g.h -gt 0 -and $g.bitmap -ne $null) {
        if ($curX + $g.w + 2 -gt $AtlasWidth) {
            $curX = 4
            $curY += $rowH + 2
            $rowH = 0
        }

        if ($curY + $g.h -gt $AtlasHeight) {
            Write-Warning "Atlas height exceeded! Some glyphs may be clipped. Consider increasing AtlasHeight."
        }

        $atlasG.DrawImage($g.bitmap, $curX, $curY)
        $atlasX = $curX
        $atlasY = $curY

        $packedCoordsByGid[$g.gid] = @{ x = $atlasX; y = $atlasY }

        $curX += $g.w + 2
        if ($g.h -gt $rowH) { $rowH = $g.h }
        $g.bitmap.Dispose()
    } else {
        $atlasX = 0
        $atlasY = 0
    }

    $finalGlyphs += @{
        code = $g.code
        char = $g.char
        name = $g.name
        type = $g.type
        gid = $g.gid
        x = $atlasX
        y = $atlasY
        width = $g.w
        height = $g.h
        xoffset = $g.xoffset
        yoffset = $g.yoffset
        xadvance = $g.xadvance
    }
}

$atlasG.Dispose()

# Ensure destination directory exists
$outDir = [System.IO.Path]::GetDirectoryName($OutputBase)
if ($outDir -and !(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$pngFile = "$OutputBase.png"
$jsonFile = "$OutputBase.json"
$fntFile = "$OutputBase.fnt"

$atlasBmp.Save($pngFile, [System.Drawing.Imaging.ImageFormat]::Png)
$atlasBmp.Dispose()

$metaJson = ConvertTo-Json -InputObject $finalGlyphs -Depth 3
[System.IO.File]::WriteAllText($jsonFile, $metaJson, [System.Text.Encoding]::UTF8)

# Generate AngelCode BMFont text file (.fnt)
$fontFace = if ($IsBold -eq 1) { "TH Sarabun New Bold" } else { "TH Sarabun New" }
$pngFileName = [System.IO.Path]::GetFileName($pngFile)

$fntLines = [System.Collections.Generic.List[string]]::new()
$fntLines.Add("info face=`"$fontFace`" size=$([int]$FontSize) bold=$IsBold italic=0 charset=`"`" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=2,2 outline=0")
$fntLines.Add("common lineHeight=$lineHeight base=$base scaleW=$AtlasWidth scaleH=$AtlasHeight pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0")
$fntLines.Add("page id=0 file=`"$pngFileName`"")
$fntLines.Add("chars count=$($finalGlyphs.Count)")

foreach ($fg in $finalGlyphs) {
    $fntLines.Add("char id=$($fg.code)   x=$($fg.x)     y=$($fg.y)     width=$($fg.width)     height=$($fg.height)     xoffset=$($fg.xoffset)     yoffset=$($fg.yoffset)     xadvance=$($fg.xadvance)     page=0  chnl=15")
}

[System.IO.File]::WriteAllLines($fntFile, $fntLines, [System.Text.Encoding]::UTF8)

Write-Host "SUCCESS: Generated complete bitmap font package at $OutputBase (.png, .fnt, .json)"
