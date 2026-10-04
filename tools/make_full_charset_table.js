const fs = require('fs');

// 1. ASCII 32 - 126
const ascii = [];
for (let c = 32; c <= 126; c++) {
  const ch = String.fromCharCode(c);
  let type = 'symbol';
  if (c >= 48 && c <= 57) type = 'digit';
  else if (c >= 65 && c <= 90) type = 'latin_upper';
  else if (c >= 97 && c <= 122) type = 'latin_lower';
  else if (c === 32) type = 'space';
  
  ascii.push({
    code: c,
    char: ch,
    name: c === 32 ? 'Space' : ch,
    type: type
  });
}

// 2. Extra Typographic Symbols
const extraSymbols = [
  { code: 0x00A0, char: '\u00A0', name: 'No-Break Space', type: 'space' },
  { code: 0x00A9, char: '©', name: 'Copyright', type: 'symbol' },
  { code: 0x00AE, char: '®', name: 'Registered', type: 'symbol' },
  { code: 0x2122, char: '™', name: 'Trademark', type: 'symbol' },
  { code: 0x00B0, char: '°', name: 'Degree', type: 'symbol' },
  { code: 0x00B1, char: '±', name: 'Plus-Minus', type: 'symbol' },
  { code: 0x00D7, char: '×', name: 'Multiply', type: 'symbol' },
  { code: 0x00F7, char: '÷', name: 'Divide', type: 'symbol' },
  { code: 0x00AB, char: '«', name: 'Left Guillemet', type: 'punctuation' },
  { code: 0x00BB, char: '»', name: 'Right Guillemet', type: 'punctuation' },
  { code: 0x2013, char: '–', name: 'En Dash', type: 'punctuation' },
  { code: 0x2014, char: '—', name: 'Em Dash', type: 'punctuation' },
  { code: 0x2018, char: '‘', name: 'Left Single Quote', type: 'punctuation' },
  { code: 0x2019, char: '’', name: 'Right Single Quote', type: 'punctuation' },
  { code: 0x201C, char: '“', name: 'Left Double Quote', type: 'punctuation' },
  { code: 0x201D, char: '”', name: 'Right Double Quote', type: 'punctuation' },
  { code: 0x2022, char: '•', name: 'Bullet', type: 'symbol' },
  { code: 0x2026, char: '…', name: 'Ellipsis', type: 'punctuation' }
];

// 3. Thai glyph table from exact_thai_table.json
const thaiTable = JSON.parse(fs.readFileSync('sarabun_bitmap_fonts/tables_and_configs/exact_thai_table.json', 'utf8'));

// 4. Standard Unicode PUA (0xF700 - 0xF71A) mapping to the same GIDs for universal game engine support
const puaMap = [
  // 0xF700 - 0xF704: High tone marks
  { pua: 0xF700, targetCode: 3680, name: 'Mai Ek High' },
  { pua: 0xF701, targetCode: 3681, name: 'Mai Tho High' },
  { pua: 0xF702, targetCode: 3682, name: 'Mai Tri High' },
  { pua: 0xF703, targetCode: 3683, name: 'Mai Chattawa High' },
  { pua: 0xF704, targetCode: 3684, name: 'Thanthakhat High' },

  // 0xF705 - 0xF709: Shifted tone marks
  { pua: 0xF705, targetCode: 3685, name: 'Mai Ek Shifted' },
  { pua: 0xF706, targetCode: 3686, name: 'Mai Tho Shifted' },
  { pua: 0xF707, targetCode: 3687, name: 'Mai Tri Shifted' },
  { pua: 0xF708, targetCode: 3688, name: 'Mai Chattawa Shifted' },
  { pua: 0xF709, targetCode: 3689, name: 'Thanthakhat Shifted' },

  // 0xF70A - 0xF70E: High shifted tone marks
  { pua: 0xF70A, targetCode: 3702, name: 'Mai Ek High Shifted' },
  { pua: 0xF70B, targetCode: 3703, name: 'Mai Tho High Shifted' },
  { pua: 0xF70C, targetCode: 3704, name: 'Mai Tri High Shifted' },
  { pua: 0xF70D, targetCode: 3705, name: 'Mai Chattawa High Shifted' },
  { pua: 0xF70E, targetCode: 3706, name: 'Thanthakhat High Shifted' },

  // 0xF70F - 0xF710: Cut descender
  { pua: 0xF70F, targetCode: 3698, name: 'Yo Ying Cut Tail' },
  { pua: 0xF710, targetCode: 3697, name: 'Tho Than Cut Tail' },

  // 0xF711 - 0xF713: Lowered vowels
  { pua: 0xF711, targetCode: 3699, name: 'Sara U Short' },
  { pua: 0xF712, targetCode: 3700, name: 'Sara Uu Short' },
  { pua: 0xF713, targetCode: 3701, name: 'Phinthu Short' },

  // 0xF714 - 0xF71A: Shifted upper vowels
  { pua: 0xF714, targetCode: 3690, name: 'Mai Han-Akat Shifted' },
  { pua: 0xF715, targetCode: 3691, name: 'Sara I Shifted' },
  { pua: 0xF716, targetCode: 3692, name: 'Sara Ii Shifted' },
  { pua: 0xF717, targetCode: 3693, name: 'Sara Ue Shifted' },
  { pua: 0xF718, targetCode: 3694, name: 'Sara Uee Shifted' },
  { pua: 0xF719, targetCode: 3695, name: 'Maitaikhu Shifted' },
  { pua: 0xF71A, targetCode: 3696, name: 'Nikhahit Shifted' }
];

const puaEntries = [];
for (const p of puaMap) {
  const target = thaiTable.find(x => x.code === p.targetCode);
  if (target) {
    puaEntries.push({
      code: p.pua,
      gid: target.gid,
      char: String.fromCharCode(p.pua),
      name: p.name,
      type: target.type
    });
  }
}

// Combine all
const fullCharset = [...ascii, ...extraSymbols, ...thaiTable, ...puaEntries];
console.log('Total characters in full charset (with standard PUA):', fullCharset.length);

const outPath1 = 'sarabun_bitmap_fonts/tables_and_configs/full_charset_table.json';
const outPath2 = 'D:/mod/sarabun-bitmap-fonts/tables_and_configs/full_charset_table.json';

fs.writeFileSync(outPath1, JSON.stringify(fullCharset, null, 2), 'utf8');
fs.writeFileSync(outPath2, JSON.stringify(fullCharset, null, 2), 'utf8');
console.log('Saved full_charset_table.json successfully.');
