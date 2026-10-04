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

    # Step 1: Normalize Sara Am (0x0E33)
    # Decompose into Nikhahit (0x0E4D) + Tone + Sara Aa (0x0E32)
    $toneClass = "[\u0E48\u0E49\u0E4A\u0E4B\u0E4C]"
    $saraAm = [char]0x0E33
    $nikhahit = [char]0x0E4D
    $saraAa = [char]0x0E32

    $normalized = [System.Text.RegularExpressions.Regex]::Replace($inputStr, "($toneClass)$saraAm", "$nikhahit`$1$saraAa")
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, "$saraAm($toneClass)", "$nikhahit`$1$saraAa")
    $normalized = [System.Text.RegularExpressions.Regex]::Replace($normalized, "$saraAm", "$nikhahit$saraAa")

    $upperVowelShiftMap = @{
        0x0E31 = 0xF714 # Mai Han-Akat (ั)
        0x0E34 = 0xF715 # Sara I (ิ)
        0x0E35 = 0xF716 # Sara Ii (ี)
        0x0E36 = 0xF717 # Sara Ue (ึ)
        0x0E37 = 0xF718 # Sara Uee (ื)
        0x0E47 = 0xF719 # Maitaikhu (็)
        0x0E4D = 0xF71A # Nikhahit (ํ)
    }

    $sb = New-Object System.Text.StringBuilder
    $len = $normalized.Length

    for ($i = 0; $i -lt $len; $i++) {
        $ch = [int][char]$normalized[$i]

        # Lookahead: Check if next char is lower vowel (0x0E38, 0x0E39, 0x0E3A)
        $next = if ($i + 1 -lt $len) { [int][char]$normalized[$i + 1] } else { 0 }
        $hasLowerVowelNext = ($next -eq 0x0E38 -or $next -eq 0x0E39 -or $next -eq 0x0E3A)

        # 1. Base removal for ญ (0x0E0D) and ฐ (0x0E10) before lower vowels
        if ($ch -eq 0x0E0D -and $hasLowerVowelNext) {
            $sb.Append([char]0xF70F) | Out-Null
            continue
        }
        if ($ch -eq 0x0E10 -and $hasLowerVowelNext) {
            $sb.Append([char]0xF710) | Out-Null
            continue
        }

        # Lookbehind: Scan backwards to find immediate vowel and base consonant
        $immediatePrev = if ($i -gt 0) { [int][char]$normalized[$i - 1] } else { 0 }

        # Check if immediate previous is an upper vowel
        $hasUpperVowelPrev = (
            $immediatePrev -eq 0x0E31 -or
            ($immediatePrev -ge 0x0E34 -and $immediatePrev -le 0x0E37) -or
            $immediatePrev -eq 0x0E47 -or
            $immediatePrev -eq 0x0E4D -or
            ($immediatePrev -ge 0xF714 -and $immediatePrev -le 0xF71A)
        )

        # Find the base consonant by scanning back past vowels/marks
        $baseConsonant = 0
        for ($k = $i - 1; $k -ge 0; $k--) {
            $prevCode = [int][char]$normalized[$k]
            # Thai consonants range: 0x0E01 - 0x0E2E, plus PUA base consonants 0xF70F, 0xF710
            if (($prevCode -ge 0x0E01 -and $prevCode -le 0x0E2E) -or $prevCode -eq 0xF70F -or $prevCode -eq 0xF710) {
                $baseConsonant = $prevCode
                break
            }
            # Stop if we hit whitespace or non-Thai
            if ($prevCode -lt 0x0E01 -or $prevCode -gt 0x0E5B) {
                break
            }
        }

        $isTallBase = ($baseConsonant -eq 0x0E1B -or $baseConsonant -eq 0x0E1D -or $baseConsonant -eq 0x0E1F -or $baseConsonant -eq 0x0E2C) # ป, ฝ, ฟ, ฬ
        $isDescenderBase = ($baseConsonant -eq 0x0E0E -or $baseConsonant -eq 0x0E0F) # ฎ, ฏ

        # 2. Lower vowels after ฎ, ฏ
        if (($ch -ge 0x0E38 -and $ch -le 0x0E3A) -and $isDescenderBase) {
            if ($ch -eq 0x0E38) { $sb.Append([char]0xF711) | Out-Null }
            elseif ($ch -eq 0x0E39) { $sb.Append([char]0xF712) | Out-Null }
            elseif ($ch -eq 0x0E3A) { $sb.Append([char]0xF713) | Out-Null }
            continue
        }

        # 3. Tone marks and Thanthakhat: 0x0E48 - 0x0E4C (่ ้ ๊ ๋ ์)
        if ($ch -ge 0x0E48 -and $ch -le 0x0E4C) {
            $offset = $ch - 0x0E48
            if ($isTallBase -and $hasUpperVowelPrev) {
                # High + Shifted Tone (e.g. ปี่, ปี้, ฟื้น)
                $sb.Append([char](0xF70A + $offset)) | Out-Null
            } elseif ($hasUpperVowelPrev) {
                # High Tone (e.g. ที่, ขึ้น, น้ำ)
                $sb.Append([char](0xF700 + $offset)) | Out-Null
            } elseif ($isTallBase) {
                # Shifted Tone directly on tall base or over lower vowel (e.g. ป่า, ปุ๊, ฟุ้ง)
                $sb.Append([char](0xF705 + $offset)) | Out-Null
            } else {
                # Normal Tone
                $sb.Append([char]$ch) | Out-Null
            }
            continue
        }

        # 4. Upper vowels & symbols (ั ิ ี ึ ื ็ ํ) on tall consonants
        if ($upperVowelShiftMap.ContainsKey($ch)) {
            if ($isTallBase) {
                $sb.Append([char]$upperVowelShiftMap[$ch]) | Out-Null
            } else {
                $sb.Append([char]$ch) | Out-Null
            }
            continue
        }

        # 5. All other characters unchanged
        $sb.Append([char]$ch) | Out-Null
    }

    return $sb.ToString()
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

            if ($glyph.width -gt 0 -and $glyph.height -gt 0) {
                $srcRect = New-Object System.Drawing.Rectangle $glyph.x, $glyph.y, $glyph.width, $glyph.height
                $dstRect = New-Object System.Drawing.Rectangle ($curX + $glyph.xoffset), ($startY + $glyph.yoffset), $glyph.width, $glyph.height
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
$secondOutput = [System.IO.Path]::Combine($outDir, "standalone_showcase_2.png")
$banner.Save($secondOutput, [System.Drawing.Imaging.ImageFormat]::Png)
$banner.Dispose()

Write-Host "Saved standalone showcase image to $OutputPng and $secondOutput"
