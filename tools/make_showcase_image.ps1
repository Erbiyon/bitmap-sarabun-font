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
    param([string]$s)
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $s.Length; $i++) {
        $ch = [int][char]$s[$i]
        $prev = if ($i -gt 0) { [int][char]$s[$i - 1] } else { 0 }
        $prevPrev = if ($i -gt 1) { [int][char]$s[$i - 2] } else { 0 }

        $isTall = ($prev -eq 0x0E1B -or $prev -eq 0x0E1D -or $prev -eq 0x0E1E -or $prev -eq 0x0E1F) # ป ฝ พ ฟ
        $prevIsUpper = ($prev -ge 0x0E31 -and $prev -le 0x0E37) # สระบน
        $prevPrevIsTall = ($prevPrev -eq 0x0E1B -or $prevPrev -eq 0x0E1D -or $prevPrev -eq 0x0E1E -or $prevPrev -eq 0x0E1F)

        # Cut descender for ญ (0x0E0D), ฐ (0x0E10) with lower vowels
        $next = if ($i + 1 -lt $s.Length) { [int][char]$s[$i + 1] } else { 0 }
        $hasLowerVowel = ($next -eq 0x0E38 -or $next -eq 0x0E39 -or $next -eq 0x0E3A)

        if ($ch -eq 0x0E0D -and $hasLowerVowel) {
            $sb.Append([char]0xF70F) | Out-Null
            continue
        }
        if ($ch -eq 0x0E10 -and $hasLowerVowel) {
            $sb.Append([char]0xF710) | Out-Null
            continue
        }

        # Tone marks: 0x0E48 - 0x0E4C (่ ้ ๊ ๋ ์)
        if ($ch -ge 0x0E48 -and $ch -le 0x0E4C) {
            $offset = $ch - 0x0E48
            if ($prevIsUpper -and $prevPrevIsTall) {
                $sb.Append([char](0xF70A + $offset)) | Out-Null
            } elseif ($prevIsUpper) {
                $sb.Append([char](0xF700 + $offset)) | Out-Null
            } elseif ($isTall) {
                $sb.Append([char](0xF705 + $offset)) | Out-Null
            } else {
                $sb.Append([char]$ch) | Out-Null
            }
        } elseif ($ch -ge 0x0E31 -and $ch -le 0x0E37 -and $isTall) {
            $offset = $ch - 0x0E31
            $sb.Append([char](0xF714 + $offset)) | Out-Null
        } else {
            $sb.Append([char]$ch) | Out-Null
        }
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
$banner.Dispose()

Write-Host "Saved standalone showcase image to $OutputPng"
