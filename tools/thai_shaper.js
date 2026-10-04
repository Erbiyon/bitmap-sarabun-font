/**
 * Thai Text Shaper for Bitmap Fonts & Game Engines
 * Automatically shapes Thai Unicode into Private Use Area (PUA) 0xF700 - 0xF71A
 *
 * Rules:
 *  1. Base removal for ญ (U+0E0D) and ฐ (U+0E10, U+0E20) when followed by lower vowels (ุ U+0E38, ู U+0E39, ฺ U+0E3A) -> PUA 0xF70F, 0xF710
 *  2. Tone marks with SARA AM (ำ U+0E33) -> mapped to upper-level PUA variants (0xF700 - 0xF704 / 0xF70A - 0xF70E)
 *  3. Long-tail consonants (ป U+0E1B, ฝ U+0E1D, ฟ U+0E1F, ฬ U+0E2C, ผ U+0E1C):
 *     - Upper vowels (ั, ิ, ี, ึ, ื, ็, ํ) -> Left-shifted PUA (0xF714 - 0xF71A)
 *     - Tone marks (่, ้, ๊, ๋, ์) with upper vowel -> High left-shifted PUA (0xF70A - 0xF70E)
 *     - Tone marks (่, ้, ๊, ๋, ์) without upper vowel (e.g. ป่, ป่า, ปุ๊, ฝ่) -> Left-shifted PUA (0xF705 - 0xF709)
 *  4. Normal consonants + upper vowel + tone -> High PUA (0xF700 - 0xF704)
 *  5. Lower vowels after ฎ, ฏ -> Lowered PUA (0xF711 - 0xF713)
 */

function shapeThaiText(str) {
  if (!str) return '';

  let s = str;

  // 1. Base removal for ญ (U+0E0D) and ฐ (U+0E10, U+0E20) before lower vowels (ุ U+0E38, ู U+0E39, ฺ U+0E3A)
  s = s.replace(/[\u0E0D](?=[\u0E38\u0E39\u0E3A])/g, '\uF70F');
  s = s.replace(/[\u0E10\u0E20](?=[\u0E38\u0E39\u0E3A])/g, '\uF710');

  // Mappings
  const highToneMap = {
    '\u0E48': '\uF700', // Mai Ek High
    '\u0E49': '\uF701', // Mai Tho High
    '\u0E4A': '\uF702', // Mai Tri High
    '\u0E4B': '\uF703', // Mai Chattawa High
    '\u0E4C': '\uF704'  // Thanthakhat High
  };
  const highShiftedToneMap = {
    '\u0E48': '\uF70A', // Mai Ek High Shifted
    '\u0E49': '\uF70B', // Mai Tho High Shifted
    '\u0E4A': '\uF70C', // Mai Tri High Shifted
    '\u0E4B': '\uF70D', // Mai Chattawa High Shifted
    '\u0E4C': '\uF70E'  // Thanthakhat High Shifted
  };
  const shiftedToneMap = {
    '\u0E48': '\uF705', // Mai Ek Shifted
    '\u0E49': '\uF706', // Mai Tho Shifted
    '\u0E4A': '\uF707', // Mai Tri Shifted
    '\u0E4B': '\uF708', // Mai Chattawa Shifted
    '\u0E4C': '\uF709'  // Thanthakhat Shifted
  };
  const shiftedVowelMap = {
    '\u0E31': '\uF714', // Mai Han-Akat Shifted
    '\u0E34': '\uF715', // Sara I Shifted
    '\u0E35': '\uF716', // Sara Ii Shifted
    '\u0E36': '\uF717', // Sara Ue Shifted
    '\u0E37': '\uF718', // Sara Uee Shifted
    '\u0E47': '\uF719', // Maitaikhu Shifted
    '\u0E4D': '\uF71A'  // Nikhahit Shifted
  };

  // 2. SARA AM (ำ) and Tone Marks
  // Tall consonants with Sara Am and Tone (e.g. ปล้ำ, ป้ำ)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])\u0E33/g, (m, c, t) => c + highShiftedToneMap[t] + '\u0E33');
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])\u0E33([\u0E48-\u0E4C])/g, (m, c, t) => c + highShiftedToneMap[t] + '\u0E33');

  // Normal consonants with Sara Am and Tone (e.g. น้ำ, ค่ำ, ถ้ำ)
  s = s.replace(/([\u0E48-\u0E4C])\u0E33/g, (m, t) => highToneMap[t] + '\u0E33');
  s = s.replace(/\u0E33([\u0E48-\u0E4C])/g, (m, t) => highToneMap[t] + '\u0E33');

  // 3. Long-tail consonants (ป U+0E1B, ฝ U+0E1D, ฟ U+0E1F, ฬ U+0E2C, ผ U+0E1C)
  // Case 3A: Tall + Upper Vowel + Tone (e.g. ปี่, ปิ่, ปี้, ฟื้น)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])/g,
    (m, c, v, t) => c + shiftedVowelMap[v] + highShiftedToneMap[t]);
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, c, t, v) => c + shiftedVowelMap[v] + highShiftedToneMap[t]);

  // Case 3B: Tall + Upper Vowel alone (e.g. ปี, ปิ, ฟิ, ฝี, ป็)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, c, v) => c + shiftedVowelMap[v]);

  // Case 3C: Tall + Lower Vowel + Tone (e.g. ปุ๊, ปู่, ฟุ้ง)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E38\u0E39\u0E3A])([\u0E48-\u0E4C])/g,
    (m, c, v, t) => c + v + shiftedToneMap[t]);

  // Case 3D: Tall + Tone mark alone (e.g. ป่, ป่า, ป้า, ป๊, ฝ่)
  s = s.replace(/([\u0E1B\u0E1D\u0E1F\u0E2C\u0E1C])([\u0E48-\u0E4C])/g,
    (m, c, t) => c + shiftedToneMap[t]);

  // 4. Normal consonant + Upper Vowel + Tone (e.g. ที่, ขึ้น, นั่ง)
  s = s.replace(/([\u0E31\u0E34-\u0E37\u0E47\u0E4D])([\u0E48-\u0E4C])/g,
    (m, v, t) => v + highToneMap[t]);
  s = s.replace(/([\u0E48-\u0E4C])([\u0E31\u0E34-\u0E37\u0E47\u0E4D])/g,
    (m, t, v) => v + highToneMap[t]);

  // 5. Lowered vowels for ฎ, ฏ
  const lowerShortMap = { '\u0E38': '\uF711', '\u0E39': '\uF712', '\u0E3A': '\uF713' };
  s = s.replace(/([\u0E0E\u0E0F])([\u0E38\u0E39\u0E3A])/g,
    (m, c, v) => c + lowerShortMap[v]);

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
