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

// 4. Standard Unicode PUA (0xF700 - 0xF71A) mapped to exact OpenType GSUB GIDs in TH Sarabun New
const puaList = [
  // 0xF700 - 0xF704: High tone marks (่ ้ ๊ ๋ ์) - on upper vowels (ที่, ขึ้น, น้ำ)
  { code: 0xF700, gid: 361, name: 'Mai Ek High', type: 'tone_high' },
  { code: 0xF701, gid: 362, name: 'Mai Tho High', type: 'tone_high' },
  { code: 0xF702, gid: 363, name: 'Mai Tri High', type: 'tone_high' },
  { code: 0xF703, gid: 364, name: 'Mai Chattawa High', type: 'tone_high' },
  { code: 0xF704, gid: 365, name: 'Thanthakhat High', type: 'tone_high' },

  // 0xF705 - 0xF709: Shifted tone marks (่ ้ ๊ ๋ ์) - on tall consonants without upper vowel (ป่า, ปุ๊, ฟุ้ง)
  { code: 0xF705, gid: 347, name: 'Mai Ek Shifted', type: 'tone_shifted' },
  { code: 0xF706, gid: 348, name: 'Mai Tho Shifted', type: 'tone_shifted' },
  { code: 0xF707, gid: 349, name: 'Mai Tri Shifted', type: 'tone_shifted' },
  { code: 0xF708, gid: 350, name: 'Mai Chattawa Shifted', type: 'tone_shifted' },
  { code: 0xF709, gid: 351, name: 'Thanthakhat Shifted', type: 'tone_shifted' },

  // 0xF70A - 0xF70E: High shifted tone marks (่ ้ ๊ ๋ ์) - on tall consonants with upper vowel (ปี่, ปิ่, ปี้, ฟื้น)
  { code: 0xF70A, gid: 352, name: 'Mai Ek High Shifted', type: 'tone_high_shifted' },
  { code: 0xF70B, gid: 353, name: 'Mai Tho High Shifted', type: 'tone_high_shifted' },
  { code: 0xF70C, gid: 354, name: 'Mai Tri High Shifted', type: 'tone_high_shifted' },
  { code: 0xF70D, gid: 355, name: 'Mai Chattawa High Shifted', type: 'tone_high_shifted' },
  { code: 0xF70E, gid: 356, name: 'Thanthakhat High Shifted', type: 'tone_high_shifted' },

  // 0xF70F - 0xF710: Cut descender for ญ and ฐ (before lower vowels ุ, ู, ฺ)
  { code: 0xF70F, gid: 357, name: 'Yo Ying Cut Tail', type: 'consonant_cut_tail' },
  { code: 0xF710, gid: 342, name: 'Tho Than Cut Tail', type: 'consonant_cut_tail' },

  // 0xF711 - 0xF713: Lowered vowels for ฎ and ฏ
  { code: 0xF711, gid: 366, name: 'Sara U Short', type: 'lower_vowel_short' },
  { code: 0xF712, gid: 367, name: 'Sara Uu Short', type: 'lower_vowel_short' },
  { code: 0xF713, gid: 368, name: 'Phinthu Short', type: 'lower_vowel_short' },

  // 0xF714 - 0xF71A: Shifted upper vowels for ป, ฝ, ฟ (ั ิ ี ึ ื ็ ํ)
  { code: 0xF714, gid: 358, name: 'Mai Han-Akat Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF715, gid: 343, name: 'Sara I Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF716, gid: 344, name: 'Sara Ii Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF717, gid: 345, name: 'Sara Ue Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF718, gid: 346, name: 'Sara Uee Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF719, gid: 360, name: 'Maitaikhu Shifted', type: 'upper_vowel_shifted' },
  { code: 0xF71A, gid: 359, name: 'Nikhahit Shifted', type: 'upper_vowel_shifted' }
];

const puaEntries = puaList.map(p => ({
  code: p.code,
  gid: p.gid,
  char: String.fromCharCode(p.code),
  name: p.name,
  type: p.type
}));

// Standard Thai Unicode: ก to ๛ (codes 3585 - 3675)
const thaiStandard = thaiTable.filter(x => x.code <= 3675);

// Combine all (Standard ASCII + Extra Typography + Standard Thai Unicode + Standard Thai PUA)
const fullCharset = [...ascii, ...extraSymbols, ...thaiStandard, ...puaEntries];
console.log('Total characters in full charset (with standard PUA):', fullCharset.length);

const outPath1 = 'sarabun_bitmap_fonts/tables_and_configs/full_charset_table.json';
const outPath2 = 'D:/mod/sarabun-bitmap-fonts/tables_and_configs/full_charset_table.json';

fs.writeFileSync(outPath1, JSON.stringify(fullCharset, null, 2), 'utf8');
fs.writeFileSync(outPath2, JSON.stringify(fullCharset, null, 2), 'utf8');
console.log('Saved full_charset_table.json successfully.');
