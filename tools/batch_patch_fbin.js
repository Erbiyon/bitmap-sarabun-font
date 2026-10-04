const fs = require('fs');
const path = require('path');

if (!fs.existsSync('mod_staging/fontbin')) {
  fs.mkdirSync('mod_staging/fontbin', { recursive: true });
}

const configs = JSON.parse(fs.readFileSync('font_configs.json', 'utf8').replace(/^\uFEFF/, ''));

console.log(`=== Patching ${configs.length} font .fbin files ===`);

for (const cfg of configs) {
  const fontId = cfg.id;
  const capHeight = cfg.capHeight;
  
  const origFbinPath = `mod_extracted/fontbin/${fontId}.fbin`;
  const origPngPath = `mod_extracted/fontbin/${fontId}.png`;
  const packedMetaPath = `mod_work/${fontId}_packed_meta.json`;
  
  if (!fs.existsSync(origFbinPath) || !fs.existsSync(packedMetaPath)) {
    console.warn(`Skipping ${fontId} - missing .fbin or packed meta`);
    continue;
  }
  
  // 1. Read original PNG dimensions
  const origPngBuf = fs.readFileSync(origPngPath);
  const origW = origPngBuf.readUInt32BE(16);
  const origH = origPngBuf.readUInt32BE(20);
  const targetW = (origW > 300) ? 1024 : 512;
  const targetH = origH;
  
  // 2. Read packed metadata
  const packedMeta = JSON.parse(fs.readFileSync(packedMetaPath, 'utf8').replace(/^\uFEFF/, ''));
  
  // 3. Read original .fbin
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
  
  // 4. Add Thai records with precise typography offsets
  const avgW = capHeight * 0.85;
  const vowelGap = Math.round(capHeight * 0.16);
  const tone1Gap = Math.round(capHeight * 0.16);
  const tone2Gap = Math.round(capHeight * 0.72);
  const tallShift = Math.round(avgW * 0.25);
  
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
          adv = 0;
          ox = -w - 2;
          oy = -capHeight - tone2Gap - h;
          break;
          
        case 'tone_shifted':
          adv = 0;
          ox = -w - Math.round(avgW * 0.28);
          oy = -capHeight - tone1Gap - h;
          break;

        case 'tone_high_shifted':
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
    recBuf.writeUInt16LE(code, 0);
    recBuf.writeUInt16LE(code, 2);
    recBuf.writeUInt16LE(0, 4);
    recBuf.writeUInt16LE(w, 6);
    recBuf.writeUInt16LE(h, 8);
    recBuf.writeFloatLE(w, 10);
    recBuf.writeFloatLE(h, 14);
    recBuf.writeFloatLE(oy, 18);
    recBuf.writeFloatLE(ox, 22);
    recBuf.writeFloatLE(adv, 26);
    recBuf.writeFloatLE(u0, 30);
    recBuf.writeFloatLE(v0, 34);
    recBuf.writeFloatLE(u1, 38);
    recBuf.writeFloatLE(v1, 42);
    recBuf.writeFloatLE(u0, 46);
    recBuf.writeFloatLE(v0, 50);
    recBuf.writeFloatLE(u1, 54);
    recBuf.writeFloatLE(v1, 58);
    recBuf.writeUInt32LE(1, 62);
    
    const existingIdx = allRecords.findIndex(r => r.charCode === code);
    if (existingIdx !== -1) {
      allRecords[existingIdx].buf = recBuf;
    } else {
      allRecords.push({ charCode: code, buf: recBuf });
    }
  }
  
  // 5. Sort all records by charCode
  allRecords.sort((a, b) => a.charCode - b.charCode);
  
  // 6. Construct new .fbin
  const newHeader = Buffer.from(origFbin.subarray(0, headerLen));
  newHeader.writeUInt32LE(allRecords.length, headerLen - 4);
  
  const recordBuffers = allRecords.map(r => r.buf);
  const padding = Buffer.alloc(4, 0);
  const newFbin = Buffer.concat([newHeader, ...recordBuffers, padding]);
  
  fs.writeFileSync(`mod_staging/fontbin/${fontId}.fbin`, newFbin);
  console.log(`Patched ${fontId.padEnd(25)} -> ${allRecords.length} glyphs (${newFbin.length} bytes)`);
}

console.log('\n=== All font .fbin files successfully patched into mod_staging/fontbin/! ===');
