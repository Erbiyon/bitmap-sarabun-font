param(
    [string]$FontJson = "sarabun_bitmap_fonts/standalone_full_fonts/sarabun_bold_32px.json",
    [string]$FontPng = "sarabun_bitmap_fonts/standalone_full_fonts/sarabun_bold_32px.png",
    [string]$TextJson = "sarabun_bitmap_fonts/docs/showcase_text.json",
    [string]$OutputPng = "sarabun_bitmap_fonts/docs/images/standalone_showcase.png"
)

Add-Type -AssemblyName System.Drawing

$glyphs = ConvertFrom-Json ([System.IO.File]::ReadAllText((Resolve-Path $FontJson).Path, [System.Text.Encoding]::UTF8))
$atlasBmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $FontPng).Path)
$textData = ConvertFrom-Json ([System.IO.File]::ReadAllText((Resolve-Path $TextJson).Path, [System.Text.Encoding]::UTF8))

# Build glyph lookup map by char / code
$map = @{}
foreach ($g in $glyphs) {
    $map[$g.code] = $g
}

function Shape-Thai {
    param([string]$inputStr)
    if ([string]::IsNullOrEmpty($inputStr)) { return "" }

    $s = $inputStr

    # 1. Base removal for ญ (U+0E0D) and ฐ (U+0E10, U+0E20) before lower vowels (ุ, ู, ฺ)
    $cutYoYing = "$([char]0xF70F)"
    $cutThoThan = "$([char]0xF710)"
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "[\u0E0D](?=[\u0E38\u0E39\u0E3A])", $cutYoYing)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "[\u0E10\u0E20](?=[\u0E38\u0E39\u0E3A])", $cutThoThan)

    # Dictionaries
    $highToneMap = @{ [char]0x0E48 = [char]0xF700; [char]0x0E49 = [char]0xF701; [char]0x0E4A = [char]0xF702; [char]0x0E4B = [char]0xF703; [char]0x0E4C = [char]0xF704 }
    $highShiftedToneMap = @{ [char]0x0E48 = [char]0xF70A; [char]0x0E49 = [char]0xF70B; [char]0x0E4A = [char]0xF70C; [char]0x0E4B = [char]0xF70D; [char]0x0E4C = [char]0xF70E }
    $shiftedToneMap = @{ [char]0x0E48 = [char]0xF705; [char]0x0E49 = [char]0xF706; [char]0x0E4A = [char]0xF707; [char]0x0E4B = [char]0xF708; [char]0x0E4C = [char]0xF709 }
    $shiftedVowelMap = @{
        [char]0x0E31 = [char]0xF714; [char]0x0E34 = [char]0xF715; [char]0x0E35 = [char]0xF716
        [char]0x0E36 = [char]0xF717; [char]0x0E37 = [char]0xF718; [char]0x0E47 = [char]0xF719; [char]0x0E4D = [char]0xF71A
    }

    # 2. SARA AM (ำ U+0E33) and Tone Marks (่, ้, ๊, ๋, ์ U+0E48 - U+0E4C)
    # Normalize decomposed Sara Am (ํ U+0E4D + า U+0E32) if present
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "\u0E4D\u0E32", "$([char]0x0E33)")
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E48-\u0E4C])\u0E4D\u0E32", { param($m) $m.Groups[1].Value + [char]0x0E33 })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "\u0E4D([\u0E48-\u0E4C])\u0E32", { param($m) $m.Groups[1].Value + [char]0x0E33 })

    # Tall consonants (ป, ฝ, ฟ, ฬ, ผ) -> High Shifted Tone (0xF70A - 0xF70E)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])\u0E33", {
        param($m) $m.Groups[1].Value + $highShiftedToneMap[$m.Groups[2].Value[0]] + [char]0x0E33
    })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])\u0E33([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $highShiftedToneMap[$m.Groups[2].Value[0]] + [char]0x0E33
    })

    # Normal consonants (ก-ฮ and cut-base variants) -> Upper-level High Tone (0xF700 - 0xF704)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E01-\u0E2E\uF70F\uF710])([\u0E48-\u0E4C])\u0E33", {
        param($m) $m.Groups[1].Value + $highToneMap[$m.Groups[2].Value[0]] + [char]0x0E33
    })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E01-\u0E2E\uF70F\uF710])\u0E33([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $highToneMap[$m.Groups[2].Value[0]] + [char]0x0E33
    })

    # Fallback tone mark adjacent to Sara Am
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E48-\u0E4C])\u0E33", {
        param($m) $highToneMap[$m.Groups[1].Value[0]] + [char]0x0E33
    })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "\u0E33([\u0E48-\u0E4C])", {
        param($m) $highToneMap[$m.Groups[1].Value[0]] + [char]0x0E33
    })

    # 3. Long-tail consonants (ป, ฝ, ฟ, ฬ, ผ)
    # Case 3A: Tall + Upper Vowel + Tone (e.g. ปี่, ปิ่, ปี้, ฟื้น)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $shiftedVowelMap[$m.Groups[2].Value[0]] + $highShiftedToneMap[$m.Groups[3].Value[0]]
    })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])", {
        param($m) $m.Groups[1].Value + $shiftedVowelMap[$m.Groups[3].Value[0]] + $highShiftedToneMap[$m.Groups[2].Value[0]]
    })

    # Case 3B: Tall + Upper Vowel alone (e.g. ปี, ปิ, ฟิ, ฝี, ป็)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])", {
        param($m) $m.Groups[1].Value + $shiftedVowelMap[$m.Groups[2].Value[0]]
    })

    # Case 3C: Tall + Lower Vowel + Tone (e.g. ปุ๊, ปู่, ฟุ้ง)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E38\u0E39\u0E3A])([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $m.Groups[2].Value + $shiftedToneMap[$m.Groups[3].Value[0]]
    })

    # Case 3D: Tall + Tone mark alone (e.g. ป่, ป่า, ป้า, ป๊, ฝ่)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $shiftedToneMap[$m.Groups[2].Value[0]]
    })

    # 4. Normal consonant + Upper Vowel + Tone (e.g. ที่, ขึ้น, นั่ง)
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])", {
        param($m) $m.Groups[1].Value + $highToneMap[$m.Groups[2].Value[0]]
    })
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])", {
        param($m) $m.Groups[2].Value + $highToneMap[$m.Groups[1].Value[0]]
    })

    # 5. Lowered vowels for ฎ, ฏ
    $lowerShortMap = @{ [char]0x0E38 = [char]0xF711; [char]0x0E39 = [char]0xF712; [char]0x0E3A = [char]0xF713 }
    $s = [System.Text.RegularExpressions.Regex]::Replace($s, "([\u0E0E\u0E0F])([\u0E38\u0E39\u0E3A])", {
        param($m) $m.Groups[1].Value + $lowerShortMap[$m.Groups[2].Value[0]]
    })

    return $s
}

$canvasW = 950
$canvasH = 390
$banner = New-Object System.Drawing.Bitmap $canvasW, $canvasH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($banner)
$g.Clear([System.Drawing.Color]::FromArgb(255, 18, 22, 31)) # Modern dark slate background

function Draw-BitmapText {
    param(
        [System.Drawing.Graphics]$gfx,
        [string]$text,
        [int]$startX,
        [int]$startY
    )

    $shaped = Shape-Thai $text
    $curX = $startX
    $lastBaseX = $startX
    $lastBaseW = 14

    for ($i = 0; $i -lt $shaped.Length; $i++) {
        $c = [int][char]$shaped[$i]
        if ($map.ContainsKey($c)) {
            $glyph = $map[$c]
            $isCombining = ($glyph.type -like "*tone*" -or $glyph.type -like "*vowel*" -or $glyph.type -like "*mark*") -and ($glyph.type -ne "normal")

            $xoff = $glyph.xoffset
            $yoff = $glyph.yoffset
            if ($c -ge 0xF700 -and $c -le 0xF704) {
                $isNextAm = ($i + 1 -lt $shaped.Length -and [int][char]$shaped[$i + 1] -eq 0x0E33)
                $isPrevAm = ($i - 1 -ge 0 -and [int][char]$shaped[$i - 1] -eq 0x0E33)
                if ($isNextAm -or $isPrevAm) {
                    $xoff += 3
                    $yoff -= 3
                }
            }

            if ($glyph.width -gt 0 -and $glyph.height -gt 0) {
                $srcRect = New-Object System.Drawing.Rectangle $glyph.x, $glyph.y, $glyph.width, $glyph.height
                $dstRect = New-Object System.Drawing.Rectangle ($curX + $xoff), ($startY + $yoff), $glyph.width, $glyph.height
                $gfx.DrawImage($atlasBmp, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
            }

            if (-not $isCombining) {
                $curX += $glyph.xadvance
            }
        } else {
            $curX += 14
        }
    }
}

$curY = 24
foreach ($line in $textData.lines) {
    Draw-BitmapText $g $line 30 $curY
    $curY += 56
}

$g.Dispose()
$atlasBmp.Dispose()

$outDir = [System.IO.Path]::GetDirectoryName($OutputPng)
if ($outDir -and !(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$banner.Save($OutputPng, [System.Drawing.Imaging.ImageFormat]::Png)
$banner.Dispose()

Write-Host "Saved standalone showcase image to $OutputPng"
