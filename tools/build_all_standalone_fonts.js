const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('=== Building All Standalone Full Bitmap Fonts (English + Numerals + Symbols + Thai) ===');

const regTtf = 'sarabun_bitmap_fonts/ttf_sources/THSarabunNew.ttf';
const boldTtf = 'sarabun_bitmap_fonts/ttf_sources/THSarabunNew Bold.ttf';
const charset = 'sarabun_bitmap_fonts/tables_and_configs/full_charset_table.json';
const outDir = 'sarabun_bitmap_fonts/standalone_full_fonts';

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const configs = [
  { name: 'sarabun_regular_24px', ttf: regTtf, size: 24, bold: 0, w: 512, h: 512 },
  { name: 'sarabun_regular_32px', ttf: regTtf, size: 32, bold: 0, w: 512, h: 512 },
  { name: 'sarabun_regular_48px', ttf: regTtf, size: 48, bold: 0, w: 1024, h: 1024 },
  { name: 'sarabun_bold_24px', ttf: boldTtf, size: 24, bold: 1, w: 512, h: 512 },
  { name: 'sarabun_bold_32px', ttf: boldTtf, size: 32, bold: 1, w: 512, h: 512 },
  { name: 'sarabun_bold_48px', ttf: boldTtf, size: 48, bold: 1, w: 1024, h: 1024 },
];

for (const cfg of configs) {
  const outputBase = `${outDir}/${cfg.name}`;
  console.log(`\nRendering ${cfg.name} (${cfg.size}px, Atlas ${cfg.w}x${cfg.h})...`);
  const cmd = `powershell -ExecutionPolicy Bypass -File sarabun_bitmap_fonts/tools/render_full_charset.ps1 -FontFile "${cfg.ttf}" -FontSize ${cfg.size} -IsBold ${cfg.bold} -CharsetJson "${charset}" -AtlasWidth ${cfg.w} -AtlasHeight ${cfg.h} -OutputBase "${outputBase}"`;
  execSync(cmd, { stdio: 'inherit' });
}

console.log('\nAll standalone bitmap fonts generated successfully in', outDir);
