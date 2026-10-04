param(
    [string]$FontName = "TH Sarabun New",
    [string]$FontFile = "C:\Users\mkanl\AppData\Local\Microsoft\Windows\Fonts\THSarabunNew Bold.ttf",
    [float]$TargetFontSize = 24.0,
    [float]$BaselineY = -21.0,
    [string]$OutputFile = "thai_glyphs.png",
    [string]$MetaFile = "thai_glyphs_meta.json"
)

Add-Type -AssemblyName System.Drawing

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($FontFile)
$ff = $pfc.Families[0]
$font = New-Object System.Drawing.Font($ff, $TargetFontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

Write-Host "Rendering Thai glyphs with font: $($ff.Name) size: $TargetFontSize px"

# Build character list
$charList = @()

# 1. Consonants: 0x0E01 - 0x0E2E
for ($code = 0x0E01; $code -le 0x0E2E; $code++) {
    $charList += @{ Code = $code; Char = [char]$code; Type = "consonant" }
}

# 2. Vowels & signs: 0x0E2F - 0x0E3A
for ($code = 0x0E2F; $code -le 0x0E3A; $code++) {
    $ch = [char]$code
    $type = "normal"
    if ($code -ge 0x0E34 -and $code -le 0x0E37) { $type = "upper_vowel" }
    elseif ($code -eq 0x0E31) { $type = "upper_vowel" }
    elseif ($code -eq 0x0E38 -or $code -eq 0x0E39 -or $code -eq 0x0E3A) { $type = "lower_vowel" }
    $charList += @{ Code = $code; Char = $ch; Type = $type }
}

# 3. Currency & More Vowels: 0x0E3F - 0x0E4E
for ($code = 0x0E3F; $code -le 0x0E4E; $code++) {
    $ch = [char]$code
    $type = "normal"
    if ($code -ge 0x0E48 -and $code -le 0x0E4C) { $type = "tone_mark" }
    elseif ($code -eq 0x0E47 -or $code -eq 0x0E4D -or $code -eq 0x0E4E) { $type = "upper_vowel" }
    $charList += @{ Code = $code; Char = $ch; Type = $type }
}

# 4. Numerals: 0x0E50 - 0x0E59
for ($code = 0x0E50; $code -le 0x0E59; $code++) {
    $charList += @{ Code = $code; Char = [char]$code; Type = "normal" }
}

# 5. PUA High tone marks (above upper vowels): 0xF700 - 0xF704
$puaHighTones = @(0xF700, 0xF701, 0xF702, 0xF703, 0xF704)
$srcTones = @([char]0x0E48, [char]0x0E49, [char]0x0E4A, [char]0x0E4B, [char]0x0E4C)
for ($i = 0; $i -lt 5; $i++) {
    $charList += @{ Code = $puaHighTones[$i]; Char = $srcTones[$i]; Type = "high_tone" }
}

# 6. PUA Shifted tone marks (for tall consonants ป ผ ฝ ฟ): 0xF705 - 0xF709
$puaShiftTones = @(0xF705, 0xF706, 0xF707, 0xF708, 0xF709)
for ($i = 0; $i -lt 5; $i++) {
    $charList += @{ Code = $puaShiftTones[$i]; Char = $srcTones[$i]; Type = "shift_tone" }
}

# 7. PUA Shifted upper vowels: 0xF710 - 0xF714
$puaShiftVowels = @(0xF710, 0xF711, 0xF712, 0xF713, 0xF714)
$srcVowels = @([char]0x0E31, [char]0x0E34, [char]0x0E35, [char]0x0E36, [char]0x0E37)
for ($i = 0; $i -lt 5; $i++) {
    $charList += @{ Code = $puaShiftVowels[$i]; Char = $srcVowels[$i]; Type = "shift_upper_vowel" }
}

Write-Host "Total characters to render: $($charList.Count)"

# Render each character to a scratch bitmap to find exact bounding box
$scratchBmp = New-Object System.Drawing.Bitmap 120, 120
$scratchG = [System.Drawing.Graphics]::FromImage($scratchBmp)
$scratchG.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

$glyphData = @()

foreach ($item in $charList) {
    $scratchG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $str = $item.Char.ToString()
    
    # Measure string
    $sf = [System.Drawing.StringFormat]::GenericTypographic
    $sf.FormatFlags = $sf.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
    
    # Draw character with margin (x=30, y=30)
    $drawX = 30.0
    $drawY = 30.0
    $scratchG.DrawString($str, $font, [System.Drawing.Brushes]::White, $drawX, $drawY, $sf)
    
    # Find bounding box of non-zero pixels
    $minX = 120; $maxX = -1; $minY = 120; $maxY = -1
    for ($y = 0; $y -lt 120; $y++) {
        for ($x = 0; $x -lt 120; $x++) {
            $p = $scratchBmp.GetPixel($x, $y)
            if ($p.A -gt 15) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    
    if ($maxX -ge $minX -and $maxY -ge $minY) {
        $w = $maxX - $minX + 1
        $h = $maxY - $minY + 1
        
        # Calculate advance and offsets
        $rawSize = $scratchG.MeasureString($str, $font, 1000, $sf)
        $advance = [Math]::Max($w + 1, [Math]::Ceiling($rawSize.Width))
        $ox = 0.0
        # Baseline relative to drawY + font.Height * ascender/lineSpacing
        $cellHeight = $font.Height
        $oy = [float]($minY - ($drawY + $cellHeight * 0.75))
        
        # Adjust for special types
        if ($item.Type -eq "upper_vowel") {
            $advance = 0.0
            $ox = -[Math]::Round($w * 0.8)
        } elseif ($item.Type -eq "lower_vowel") {
            $advance = 0.0
            $ox = -[Math]::Round($w * 0.8)
        } elseif ($item.Type -eq "tone_mark") {
            $advance = 0.0
            $ox = -[Math]::Round($w * 0.8)
        } elseif ($item.Type -eq "high_tone") {
            $advance = 0.0
            $ox = -[Math]::Round($w * 0.8)
            $oy -= 6.0 # Shift up above upper vowel
        } elseif ($item.Type -eq "shift_tone" -or $item.Type -eq "shift_upper_vowel") {
            $advance = 0.0
            $ox = -[Math]::Round($w * 1.2) # Shift left to avoid tall consonant tail
        }
        
        # Extract glyph sub-bitmap
        $glyphBmp = New-Object System.Drawing.Bitmap $w, $h
        $gg = [System.Drawing.Graphics]::FromImage($glyphBmp)
        $gg.DrawImage($scratchBmp, 0, 0, (New-Object System.Drawing.Rectangle $minX, $minY, $w, $h), [System.Drawing.GraphicsUnit]::Pixel)
        $gg.Dispose()
        
        $glyphData += @{
            Code = $item.Code
            Char = $str
            Type = $item.Type
            W = $w
            H = $h
            OX = $ox
            OY = $oy
            Advance = $advance
            Bitmap = $glyphBmp
        }
    }
}

$scratchG.Dispose()
$scratchBmp.Dispose()

Write-Host "Successfully processed $($glyphData.Count) glyphs."

# Pack glyphs into a sheet
$sheetW = 300
$sheetH = 1000
$sheetBmp = New-Object System.Drawing.Bitmap $sheetW, $sheetH
$sheetG = [System.Drawing.Graphics]::FromImage($sheetBmp)
$sheetG.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

$curX = 4
$curY = 4
$rowH = 0

$metaList = @()

foreach ($g in $glyphData) {
    if ($curX + $g.W + 2 -gt $sheetW) {
        $curX = 4
        $curY += $rowH + 2
        $rowH = 0
    }
    
    $sheetG.DrawImage($g.Bitmap, $curX, $curY)
    
    $metaList += @{
        code = $g.Code
        char = $g.Char
        w = $g.W
        h = $g.H
        ox = $g.OX
        oy = $g.OY
        advance = $g.Advance
        atlasX = $curX
        atlasY = $curY
    }
    
    $curX += $g.W + 2
    if ($g.H -gt $rowH) { $rowH = $g.H }
    $g.Bitmap.Dispose()
}

$sheetG.Dispose()
$sheetBmp.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
$sheetBmp.Dispose()
$font.Dispose()
$pfc.Dispose()

# Export meta as JSON
$json = ConvertTo-Json -InputObject $metaList -Depth 3
[System.IO.File]::WriteAllText($MetaFile, $json, [System.Text.Encoding]::UTF8)

Write-Host "Saved atlas to $OutputFile and metadata to $MetaFile"
