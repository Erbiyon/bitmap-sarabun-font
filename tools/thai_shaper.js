/**
 * Thai Text Shaper for Bitmap Fonts & Game Engines
 * Shapes Thai Unicode into Game-Safe Thai Block (0x0E60 - 0x0E7A)
 * Safe from YuGiOh.exe gamepad/controller icon filtering (< 0xE000).
 *
 * Rules:
 *  1. SARA AM (ำ U+0E33) decomposition:
 *     - Always decomposes into Nikhahit (ํ U+0E4D) + Sara Aa (า U+0E32)
 *     - If tone mark present: Consonant + Nikhahit + High Tone + Sara Aa
 *  2. Base removal for ญ (U+0E0D) and ฐ (U+0E10) when followed by lower vowels -> 0x0E72, 0x0E71
 *  3. Short lower vowels (ุ, ู, ฺ) after descenders (ฎ, ฏ, ฤ, ฦ) -> 0x0E73 - 0x0E75
 *  4. Long-tail consonants (ป U+0E1B, ฝ U+0E1D, ฟ U+0E1F, ฬ U+0E2C):
 *     - Upper vowels (ั, ิ, ี, ึ, ื, ็, ํ) -> Left-shifted (0x0E6A - 0x0E70)
 *     - Tone marks with upper vowel -> High left-shifted (0x0E76 - 0x0E7A)
 *     - Tone marks alone or with lower vowel -> Left-shifted (0x0E65 - 0x0E69)
 *  5. Normal consonants:
 *     - Tone marks with upper vowel -> High level-2 (0x0E60 - 0x0E64)
 */

function shapeThaiText(str) {
  if (!str) return '';

  let s = str;

  // Mappings (< 0xE000, safe from YuGiOh.exe gamepad button icons)
  const highToneMap = {
    '\u0E48': '\u0E60', // Mai Ek High
    '\u0E49': '\u0E61', // Mai Tho High
    '\u0E4A': '\u0E62', // Mai Tri High
    '\u0E4B': '\u0E63', // Mai Chattawa High
    '\u0E4C': '\u0E64'  // Thanthakhat High
  };
  const shiftedToneMap = {
    '\u0E48': '\u0E65', // Mai Ek Shifted (Level 1)
    '\u0E49': '\u0E66', // Mai Tho Shifted (Level 1)
    '\u0E4A': '\u0E67', // Mai Tri Shifted (Level 1)
    '\u0E4B': '\u0E68', // Mai Chattawa Shifted (Level 1)
    '\u0E4C': '\u0E69'  // Thanthakhat Shifted (Level 1)
  };
  const shiftedVowelMap = {
    '\u0E31': '\u0E6A', // Mai Han-Akat Shifted
    '\u0E34': '\u0E6B', // Sara I Shifted
    '\u0E35': '\u0E6C', // Sara Ii Shifted
    '\u0E36': '\u0E6D', // Sara Ue Shifted
    '\u0E37': '\u0E6E', // Sara Uee Shifted
    '\u0E47': '\u0E6F', // Maitaikhu Shifted
    '\u0E4D': '\u0E70'  // Nikhahit Shifted
  };
  const cutTailConsonants = {
    '\u0E10': '\u0E71', // ฐ cut-tail
    '\u0E0D': '\u0E72'  // ญ cut-tail
  };
  const shortLowerVowelMap = {
    '\u0E38': '\u0E73', // ุ short
    '\u0E39': '\u0E74', // ู short
    '\u0E3A': '\u0E75'  // ฺ short
  };
  const highShiftedToneMap = {
    '\u0E48': '\u0E76', // Mai Ek High Shifted (Level 2)
    '\u0E49': '\u0E77', // Mai Tho High Shifted (Level 2)
    '\u0E4A': '\u0E78', // Mai Tri High Shifted (Level 2)
    '\u0E4B': '\u0E79', // Mai Chattawa High Shifted (Level 2)
    '\u0E4C': '\u0E7A'  // Thanthakhat High Shifted (Level 2)
  };

  // 1. SARA AM (ำ U+0E33) decomposition
  // Decompose ำ into Nikhahit (ํ U+0E4D) + Sara Aa (า U+0E32)
  // Normalization for existing decomposed forms
  s = s.replace(/([\u0E48-\u0E4C])\u0E4D\u0E32/g, '\u0E4D$1\u0E32');
  
  // Tall consonants with SARA AM and Tone
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E48-\u0E4C])\u0E33/g, (m, c, t) => c + '\u0E70' + highShiftedToneMap[t] + '\u0E32');
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])\u0E33([\u0E48-\u0E4C])/g, (m, c, t) => c + '\u0E70' + highShiftedToneMap[t] + '\u0E32');
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])\u0E33/g, '$1\u0E70\u0E32');

  // Normal consonants with SARA AM and Tone
  s = s.replace(/([\u0E01-\u0E2E])([\u0E48-\u0E4C])\u0E33/g, (m, c, t) => c + '\u0E4D' + highToneMap[t] + '\u0E32');
  s = s.replace(/([\u0E01-\u0E2E])\u0E33([\u0E48-\u0E4C])/g, (m, c, t) => c + '\u0E4D' + highToneMap[t] + '\u0E32');
  s = s.replace(/([\u0E01-\u0E2E])\u0E33/g, '$1\u0E4D\u0E32');

  // Standalone tone adjacent to Sara Am
  s = s.replace(/([\u0E48-\u0E4C])\u0E33/g, (m, t) => '\u0E4D' + highToneMap[t] + '\u0E32');
  s = s.replace(/\u0E33([\u0E48-\u0E4C])/g, (m, t) => '\u0E4D' + highToneMap[t] + '\u0E32');
  s = s.replace(/\u0E33/g, '\u0E4D\u0E32');

  // 2. Base removal for ญ (U+0E0D) and ฐ (U+0E10) before lower vowels (ุ U+0E38, ู U+0E39, ฺ U+0E3A)
  s = s.replace(/\u0E0D(?=[\u0E38\u0E39\u0E3A])/g, cutTailConsonants['\u0E0D']);
  s = s.replace(/[\u0E10\u0E20](?=[\u0E38\u0E39\u0E3A])/g, cutTailConsonants['\u0E10']);

  // 3. Short lower vowels after descender consonants (ฎ U+0E0E, ฏ U+0E0F, ฤ U+0E24, ฦ U+0E26)
  s = s.replace(/([\u0E0E\u0E0F\u0E24\u0E26])([\u0E38\u0E39\u0E3A])/g, (m, c, v) => c + shortLowerVowelMap[v]);

  // 4. Long-tail consonants (ป U+0E1B, ฝ U+0E1D, ฟ U+0E1F, ฬ U+0E2C)
  // Case 4A: Tall + Upper Vowel + Tone (e.g. ปี่, ปิ่, ปี้, ฟื้น)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])/g,
    (m, c, v, t) => c + shiftedVowelMap[v] + highShiftedToneMap[t]);
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, c, t, v) => c + shiftedVowelMap[v] + highShiftedToneMap[t]);

  // Case 4B: Tall + Upper Vowel alone (e.g. ปี, ปิ, ฟิ, ฝี, ป็)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, c, v) => c + shiftedVowelMap[v]);

  // Case 4C: Tall + Lower Vowel + Tone (e.g. ปุ๊, ปู่, ฟุ้ง)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E38\u0E39\u0E3A])([\u0E48-\u0E4C])/g,
    (m, c, v, t) => c + v + shiftedToneMap[t]);

  // Case 4D: Tall + Tone mark alone (e.g. ป่, ป่า, ป้า, ป๊, ฝ่)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C])([\u0E48-\u0E4C])/g,
    (m, c, t) => c + shiftedToneMap[t]);

  // 5. Normal consonant + Upper Vowel + Tone (e.g. ที่, ขึ้น, นั่ง, น้ำ)
  s = s.replace(/([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])/g,
    (m, v, t) => v + highToneMap[t]);
  s = s.replace(/([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, t, v) => v + highToneMap[t]);

  return s;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { shapeThaiText };
}

if (typeof require !== 'undefined' && require.main === module) {
  const args = process.argv.slice(2);
  if (args.length > 0) {
    const input = args.join(' ');
    const shaped = shapeThaiText(input);
    console.log(shaped);
  } else {
    console.log('Usage: node thai_shaper.js "<text>"');
  }
}
