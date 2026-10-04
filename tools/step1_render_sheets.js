const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Ensure output dirs exist
if (!fs.existsSync('mod_staging/fontbin')) {
  fs.mkdirSync('mod_staging/fontbin', { recursive: true });
}
if (!fs.existsSync('mod_work')) {
  fs.mkdirSync('mod_work', { recursive: true });
}

console.log('=== Building Exact Thai Glyph Sheets with TH Sarabun New ===');

const boldFontPath = "C:\\Users\\mkanl\\AppData\\Local\\Microsoft\\Windows\\Fonts\\THSarabunNew Bold.ttf";
const regFontPath = "C:\\Users\\mkanl\\AppData\\Local\\Microsoft\\Windows\\Fonts\\THSarabunNew.ttf";

// Target font configurations
const fontConfigs = [
  { id: 'FONT_ID_PD_16', fontFile: boldFontPath, fontSize: 38.0, isBold: 1 },
  { id: 'FONT_ID_PD_20', fontFile: boldFontPath, fontSize: 48.0, isBold: 1 },
  { id: 'FONT_ID_PD_23', fontFile: boldFontPath, fontSize: 55.0, isBold: 1 },
  { id: 'FONT_ID_PD_32', fontFile: boldFontPath, fontSize: 76.0, isBold: 1 },
  { id: 'FONT_ID_NOTO_15', fontFile: regFontPath, fontSize: 33.0, isBold: 0 },
  { id: 'FONT_ID_NOTO_17', fontFile: regFontPath, fontSize: 37.0, isBold: 0 },
  { id: 'FONT_ID_NOTO_20', fontFile: regFontPath, fontSize: 44.0, isBold: 0 }
];

for (const cfg of fontConfigs) {
  const outPng = `mod_work/thai_${cfg.id.toLowerCase()}.png`;
  const outJson = `mod_work/thai_${cfg.id.toLowerCase()}_meta.json`;
  console.log(`Rendering exact glyphs for ${cfg.id} (size ${cfg.fontSize}px)...`);
  const cmd = `powershell -ExecutionPolicy Bypass -File render_exact_glyphs.ps1 -FontFile "${cfg.fontFile}" -FontSize ${cfg.fontSize} -IsBold ${cfg.isBold} -GlyphTableJson "exact_thai_table.json" -OutputPng "${outPng}" -OutputJson "${outJson}"`;
  execSync(cmd, { stdio: 'inherit' });
}

console.log('All Thai glyph sheets successfully generated with verified GIDs!');
