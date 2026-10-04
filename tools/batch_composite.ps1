Add-Type -AssemblyName System.Drawing

if (-not (Test-Path "mod_staging/fontbin")) {
    New-Item -ItemType Directory -Path "mod_staging/fontbin" -Force | Out-Null
}

$cfgJson = [System.IO.File]::ReadAllText((Resolve-Path "font_configs.json").Path)
$configs = ConvertFrom-Json $cfgJson

foreach ($cfg in $configs) {
    $fontId = $cfg.id
    Write-Host "Compositing $fontId..."
    
    $origPngPath = "mod_extracted/fontbin/$fontId.png"
    $thaiPngPath = "mod_work/thai_$($fontId.ToLower()).png"
    $thaiMetaPath = "mod_work/thai_$($fontId.ToLower())_meta.json"
    
    if (-not (Test-Path $origPngPath) -or -not (Test-Path $thaiPngPath) -or -not (Test-Path $thaiMetaPath)) {
        Write-Warning "Skipping $fontId - missing input files"
        continue
    }
    
    $origBmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $origPngPath).Path)
    $origW = $origBmp.Width
    $origH = $origBmp.Height
    
    $targetW = if ($origW -gt 300) { 1024 } else { 512 }
    $targetH = $origH
    
    $thaiSheet = [System.Drawing.Bitmap]::FromFile((Resolve-Path $thaiPngPath).Path)
    $newBmp = New-Object System.Drawing.Bitmap $targetW, $targetH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($newBmp)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    
    # Copy original into left side
    $g.DrawImage($origBmp, 0, 0, $origW, $origH)
    
    # Pack Thai glyphs
    $startX = $origW + 6
    $maxX = $targetW - 6
    $curX = $startX
    $curY = 4
    $rowH = 0
    
    $outMeta = @()
    $metaJson = [System.IO.File]::ReadAllText((Resolve-Path $thaiMetaPath).Path)
    $items = ConvertFrom-Json $metaJson
    
    foreach ($item in $items) {
        $w = [int]$item.w
        $h = [int]$item.h
        $sx = [int]$item.sheetX
        $sy = [int]$item.sheetY
        
        if ($curX + $w + 2 -gt $maxX) {
            $curX = $startX
            $curY += $rowH + 2
            $rowH = 0
        }
        
        $srcRect = New-Object System.Drawing.Rectangle $sx, $sy, $w, $h
        $g.DrawImage($thaiSheet, $curX, $curY, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        
        $outMeta += @{
            code = $item.code
            gid = $item.gid
            name = $item.name
            type = $item.type
            w = $w
            h = $h
            atlasX = $curX
            atlasY = $curY
        }
        
        $curX += $w + 2
        if ($h -gt $rowH) { $rowH = $h }
    }
    
    $g.Dispose()
    $newBmp.Save("mod_staging/fontbin/$fontId.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $newBmp.Dispose()
    $origBmp.Dispose()
    $thaiSheet.Dispose()
    
    $resJson = ConvertTo-Json -InputObject $outMeta -Depth 3
    [System.IO.File]::WriteAllText("mod_work/$($fontId)_packed_meta.json", $resJson, [System.Text.Encoding]::UTF8)
    Write-Host "  -> Saved mod_staging/fontbin/$fontId.png ($targetW x $targetH)"
}

Write-Host "All font atlases composited successfully!"
