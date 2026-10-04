const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Ensure staging directory
if (!fs.existsSync('mod_staging/fontbin')) {
  fs.mkdirSync('mod_staging/fontbin', { recursive: true });
}

/**
 * Patch a font with exact Thai glyphs
 * @param {string} fontId e.g. "FONT_ID_PD_20"
 * @param {string} thaiPngPath e.g. "mod_work/thai_font_id_pd_20.png"
 * @param {string} thaiMetaPath e.g. "mod_work/thai_font_id_pd_20_meta.json"
 * @param {number} capHeight Nominal capital height
 */
function patchFont(fontId, thaiPngPath, thaiMetaPath, capHeight) {
  console.log(`\n=== Patching ${fontId} ===`);
  
  const origFbinPath = `mod_extracted/fontbin/${fontId}.fbin`;
  const origPngPath = `mod_extracted/fontbin/${fontId}.png`;
  
  if (!fs.existsSync(origFbinPath) || !fs.existsSync(origPngPath)) {
    throw new Error(`Original files for ${fontId} not found in mod_extracted/fontbin/`);
  }
  
  // 1. Read original PNG dimensions
  const origPngBuf = fs.readFileSync(origPngPath);
  const origW = origPngBuf.readUInt32BE(16);
  const origH = origPngBuf.readUInt32BE(20);
  const targetW = 512;
  const targetH = origH;
  
  console.log(`Original size: ${origW} x ${origH} -> Target size: ${targetW} x ${targetH}`);
  
  // 2. Read Thai glyph metadata
  const thaiMeta = JSON.parse(fs.readFileSync(thaiMetaPath, 'utf8').replace(/^\uFEFF/, ''));
  console.log(`Loaded ${thaiMeta.length} Thai glyph metadata entries.`);
  
  // 3. Composite PNG using PowerShell System.Drawing
  const compScript = `
Add-Type -AssemblyName System.Drawing

$origBmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path "${origPngPath}").Path)
$thaiSheet = [System.Drawing.Bitmap]::FromFile((Resolve-Path "${thaiPngPath}").Path)

$newBmp = New-Object System.Drawing.Bitmap ${targetW}, ${targetH}, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($newBmp)
$g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

# Copy original into left side
$g.DrawImage($origBmp, 0, 0, ${origW}, ${origH})

# Pack Thai glyphs in region [${origW + 6} .. ${targetW - 6}]
$startX = ${origW + 6}
$maxX = ${targetW - 6}
$curX = $startX
$curY = 4
$rowH = 0

$outMeta = @()
$metaJson = [System.IO.File]::ReadAllText((Resolve-Path "${thaiMetaPath}").Path)
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
    
    # Draw from thai sheet
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
$newBmp.Save("mod_staging/fontbin/${fontId}.png", [System.Drawing.Imaging.ImageFormat]::Png)
$newBmp.Dispose()
$origBmp.Dispose()
$thaiSheet.Dispose()

$resJson = ConvertTo-Json -InputObject $outMeta -Depth 3
[System.IO.File]::WriteAllText("mod_work/${fontId}_packed_meta.json", $resJson, [System.Text.Encoding]::UTF8)
Write-Host "Composited PNG saved to mod_staging/fontbin/${fontId}.png"
`;

  fs.writeFileSync('temp_comp.ps1', '\uFEFF' + compScript, 'utf8');
  execSync('powershell -ExecutionPolicy Bypass -File temp_comp.ps1', { stdio: 'inherit' });
  
  // 4. Read packed metadata
  const packedMeta = JSON.parse(fs.readFileSync(`mod_work/${fontId}_packed_meta.json`, 'utf8').replace(/^\uFEFF/, ''));
  
  // 5. Read original .fbin
  const origFbin = fs.readFileSync(origFbinPath);
  let strEnd = 8;
  while (origFbin[strEnd] !== 0 && strEnd < origFbin.length) strEnd++;
  const fontName = origFbin.subarray(8, strEnd).toString('ascii');
  const headerLen = strEnd + 1 + 44;
  const origCount = origFbin.readUInt32LE(headerLen - 4);
  
  // Read existing records
  const allRecords = [];
  const uScale = origW / targetW;
  
  for (let i = 0; i < origCount; i++) {
    const offset = headerLen + i * 66;
    const recBuf = Buffer.from(origFbin.subarray(offset, offset + 66));
    
    const u0 = recBuf.readFloatLE(30) * uScale;
    const u1 = recBuf.readFloatLE(38) * uScale;
    const u0_alt = recBuf.readFloatLE(46) * uScale;
    const u1_alt = recBuf.readFloatLE(54) * uScale;
    
    recBuf.writeFloatLE(u0, 30);
    recBuf.writeFloatLE(u1, 38);
    recBuf.writeFloatLE(u0_alt, 46);
    recBuf.writeFloatLE(u1_alt, 54);
    
    const charCode = recBuf.readUInt16LE(0);
    allRecords.push({ charCode, buf: recBuf });
  }
  
  // 6. Add Thai records with precise typography offsets
  const avgW = capHeight * 0.85; // e.g. 19 * 0.85 = 16.15px
  
  for (const item of packedMeta) {
    const code = item.code;
    const type = item.type;
    const w = item.w;
    const h = item.h;
    const atlasX = item.atlasX;
    const atlasY = item.atlasY;
    
    let ox = 0;
    let oy = -h;
    let adv = w + 1;
    
    const u0 = atlasX / targetW;
    const v0 = atlasY / targetH;
    const u1 = (atlasX + w) / targetW;
    const v1 = (atlasY + h) / targetH;
    
    // Proportional typography gaps and shifts
    const vowelGap = Math.round(capHeight * 0.16); // Clean vertical gap above consonant (~3px in PD_20)
    const tone1Gap = Math.round(capHeight * 0.16); // Clean vertical gap above consonant (~3px in PD_20)
    const tone2Gap = Math.round(capHeight * 0.72); // Leaves clean gap above upper vowel (~14px in PD_20)
    const tallShift = Math.round(avgW * 0.25);     // Shift for tall consonants to place full uncut vowel over body (~4px in PD_20)
    
    // Descender consonants check by code as well as type
    if ([0x0E0D, 0x0E10, 0x0E0E, 0x0E0F, 0x0E24, 0x0E26].includes(code) || type === 'consonant_descender') {
      oy = -capHeight;
      ox = 0;
      adv = w + 1;
    } else {
      switch (type) {
        case 'consonant':
        case 'consonant_tall':
        case 'consonant_cut_tail':
          oy = -h;
          ox = 0;
          adv = w + 1;
          break;

        case 'normal':
          if (code === 0x0E33) {
            // Fallback for 0x0E33 if ever called directly
            oy = -capHeight;
            ox = -Math.round(avgW * 0.35);
            adv = w - Math.round(avgW * 0.35) + 1;
          } else {
            oy = -h;
            ox = 0;
            adv = w + 1;
          }
          break;
          
        case 'upper_vowel':
          adv = 0;
          ox = -w - 1;
          oy = -capHeight - vowelGap - h;
          break;
          
        case 'upper_vowel_shifted':
          adv = 0;
          ox = -w - tallShift;
          oy = -capHeight - vowelGap - h;
          break;
          
        case 'lower_vowel':
          adv = 0;
          ox = -Math.round(w * 0.85) - 4;
          oy = 2;
          break;
          
        case 'lower_vowel_short':
          adv = 0;
          ox = -Math.round(w * 0.85) - 4;
          oy = Math.round(capHeight * 0.40) + 1;
          break;
          
        case 'tone_mark':
        case 'tone_normal':
          adv = 0;
          ox = -w - 2;
          oy = -capHeight - tone1Gap - h;
          break;
        
        case 'tone_high':
          // Level 2 tone mark above upper vowel with clean gap
          adv = 0;
          ox = -w - 2;
          oy = -capHeight - tone2Gap - h;
          break;
          
        case 'tone_shifted':
          // Level 1 tone mark shifted left for tall consonants
          adv = 0;
          ox = -w - Math.round(avgW * 0.28);
          oy = -capHeight - tone1Gap - h;
          break;

        case 'tone_high_shifted':
          // Level 2 tone mark shifted left for tall consonants
          adv = 0;
          ox = -w - Math.round(avgW * 0.28);
          oy = -capHeight - tone2Gap - h;
          break;
          
        default:
          oy = -h;
          ox = 0;
          adv = w + 1;
          break;
      }
    }
    
    const recBuf = Buffer.alloc(66);
    recBuf.writeUInt16LE(code, 0);     // charCode
    recBuf.writeUInt16LE(code, 2);     // charCode2
    recBuf.writeUInt16LE(0, 4);        // 0
    recBuf.writeUInt16LE(w, 6);        // w (int)
    recBuf.writeUInt16LE(h, 8);        // h (int)
    recBuf.writeFloatLE(w, 10);        // w (flt)
    recBuf.writeFloatLE(h, 14);        // h (flt)
    recBuf.writeFloatLE(oy, 18);       // offsetY
    recBuf.writeFloatLE(ox, 22);       // offsetX
    recBuf.writeFloatLE(adv, 26);      // advanceX
    recBuf.writeFloatLE(u0, 30);       // u0
    recBuf.writeFloatLE(v0, 34);       // v0
    recBuf.writeFloatLE(u1, 38);       // u1
    recBuf.writeFloatLE(v1, 42);       // v1
    recBuf.writeFloatLE(u0, 46);       // u0_alt
    recBuf.writeFloatLE(v0, 50);       // v0_alt
    recBuf.writeFloatLE(u1, 54);       // u1_alt
    recBuf.writeFloatLE(v1, 58);       // v1_alt
    recBuf.writeUInt32LE(1, 62);       // flag = 1
    
    const existingIdx = allRecords.findIndex(r => r.charCode === code);
    if (existingIdx !== -1) {
      allRecords[existingIdx].buf = recBuf;
    } else {
      allRecords.push({ charCode: code, buf: recBuf });
    }
  }
  
  // 7. Sort all records by charCode
  allRecords.sort((a, b) => a.charCode - b.charCode);
  console.log(`Total sorted records after merge: ${allRecords.length}`);
  
  // 8. Construct new .fbin
  const newHeader = Buffer.from(origFbin.subarray(0, headerLen));
  newHeader.writeUInt32LE(allRecords.length, headerLen - 4);
  
  const recordBuffers = allRecords.map(r => r.buf);
  const padding = Buffer.alloc(4, 0);
  const newFbin = Buffer.concat([newHeader, ...recordBuffers, padding]);
  
  fs.writeFileSync(`mod_staging/fontbin/${fontId}.fbin`, newFbin);
  console.log(`Saved new .fbin: mod_staging/fontbin/${fontId}.fbin (${newFbin.length} bytes)`);
}

// Target font configurations
const fontConfigs = [
  { id: 'FONT_ID_PD_16', capHeight: 15.0 },
  { id: 'FONT_ID_PD_20', capHeight: 19.0 },
  { id: 'FONT_ID_PD_23', capHeight: 22.0 },
  { id: 'FONT_ID_PD_32', capHeight: 30.0 },
  { id: 'FONT_ID_NOTO_15', capHeight: 14.0 },
  { id: 'FONT_ID_NOTO_17', capHeight: 16.0 },
  { id: 'FONT_ID_NOTO_20', capHeight: 19.0 }
];

for (const cfg of fontConfigs) {
  const pngPath = `mod_work/thai_${cfg.id.toLowerCase()}.png`;
  const metaPath = `mod_work/thai_${cfg.id.toLowerCase()}_meta.json`;
  patchFont(cfg.id, pngPath, metaPath, cfg.capHeight);
}

console.log('\n=== All 7 UI fonts successfully patched into mod_staging/fontbin/! ===');
