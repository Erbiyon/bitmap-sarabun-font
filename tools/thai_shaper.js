/**
 * Thai Text Shaper for Bitmap Fonts & Game Engines
 * Automatically shapes Thai Unicode into Private Use Area (PUA) 0xF700 - 0xF71A
 * Handles:
 *  1. SARA AM (ำ) decomposition and tone elevation (e.g. น้ำใจ)
 *  2. Long-tail consonants (ป, ฝ, ฟ, ฬ) collision avoidance (e.g. ปี่, ปิ่, ปี้, ปุ๊, ฟื้น)
 *  3. Base removal for ญ and ฐ with lower vowels (e.g. ญุ, ฐู)
 *  4. Lowered lower vowels for ฎ and ฏ (e.g. ฎุ)
 */

function shapeThaiText(inputStr) {
  if (!inputStr) return '';

  // Step 1: Normalize Sara Am (0x0E33)
  // Decompose into Nikhahit (0x0E4D) + Tone + Sara Aa (0x0E32)
  const toneRegex = /([\u0E48\u0E49\u0E4A\u0E4B\u0E4C])/g;
  let normalized = inputStr
    .replace(/([\u0E48\u0E49\u0E4A\u0E4B\u0E4C])\u0E33/g, '\u0E4D$1\u0E32')
    .replace(/\u0E33([\u0E48\u0E49\u0E4A\u0E4B\u0E4C])/g, '\u0E4D$1\u0E32')
    .replace(/\u0E33/g, '\u0E4D\u0E32');

  const upperVowelShiftMap = {
    0x0E31: 0xF714, // Mai Han-Akat (ั)
    0x0E34: 0xF715, // Sara I (ิ)
    0x0E35: 0xF716, // Sara Ii (ี)
    0x0E36: 0xF717, // Sara Ue (ึ)
    0x0E37: 0xF718, // Sara Uee (ื)
    0x0E47: 0xF719, // Maitaikhu (็)
    0x0E4D: 0xF71A  // Nikhahit (ํ)
  };

  const chars = Array.from(normalized);
  const result = [];
  const len = chars.length;

  for (let i = 0; i < len; i++) {
    const ch = chars[i].charCodeAt(0);

    // Lookahead: Next character
    const next = i + 1 < len ? chars[i + 1].charCodeAt(0) : 0;
    const hasLowerVowelNext = (next === 0x0E38 || next === 0x0E39 || next === 0x0E3A);

    // 1. Base removal for ญ (0x0E0D) and ฐ (0x0E10) before lower vowels
    if (ch === 0x0E0D && hasLowerVowelNext) {
      result.push(String.fromCharCode(0xF70F));
      continue;
    }
    if (ch === 0x0E10 && hasLowerVowelNext) {
      result.push(String.fromCharCode(0xF710));
      continue;
    }

    // Lookbehind: Immediate previous character
    const immediatePrev = i > 0 ? chars[i - 1].charCodeAt(0) : 0;
    const hasUpperVowelPrev = (
      immediatePrev === 0x0E31 ||
      (immediatePrev >= 0x0E34 && immediatePrev <= 0x0E37) ||
      immediatePrev === 0x0E47 ||
      immediatePrev === 0x0E4D ||
      (immediatePrev >= 0xF714 && immediatePrev <= 0xF71A)
    );

    // Find base consonant by scanning backwards past marks
    let baseConsonant = 0;
    for (let k = i - 1; k >= 0; k--) {
      const prevCode = chars[k].charCodeAt(0);
      if ((prevCode >= 0x0E01 && prevCode <= 0x0E2E) || prevCode === 0xF70F || prevCode === 0xF710) {
        baseConsonant = prevCode;
        break;
      }
      if (prevCode < 0x0E01 || prevCode > 0x0E5B) {
        break;
      }
    }

    const isTallBase = (
      baseConsonant === 0x0E1B || // ป
      baseConsonant === 0x0E1D || // ฝ
      baseConsonant === 0x0E1F || // ฟ
      baseConsonant === 0x0E2C    // ฬ
    );
    const isDescenderBase = (baseConsonant === 0x0E0E || baseConsonant === 0x0E0F); // ฎ, ฏ

    // 2. Lower vowels after ฎ, ฏ
    if (ch >= 0x0E38 && ch <= 0x0E3A && isDescenderBase) {
      if (ch === 0x0E38) result.push(String.fromCharCode(0xF711));
      else if (ch === 0x0E39) result.push(String.fromCharCode(0xF712));
      else if (ch === 0x0E3A) result.push(String.fromCharCode(0xF713));
      continue;
    }

    // 3. Tone marks and Thanthakhat: 0x0E48 - 0x0E4C (่ ้ ๊ ๋ ์)
    if (ch >= 0x0E48 && ch <= 0x0E4C) {
      const offset = ch - 0x0E48;
      if (isTallBase && hasUpperVowelPrev) {
        // High + Shifted Tone (e.g. ปี่, ปิ่, ปี้, ฟื้น)
        result.push(String.fromCharCode(0xF70A + offset));
      } else if (hasUpperVowelPrev) {
        // High Tone (e.g. ที่, ขึ้น, น้ำ)
        result.push(String.fromCharCode(0xF700 + offset));
      } else if (isTallBase) {
        // Shifted Tone (e.g. ป่า, ปุ๊, ฟุ้ง)
        result.push(String.fromCharCode(0xF705 + offset));
      } else {
        // Normal Tone
        result.push(chars[i]);
      }
      continue;
    }

    // 4. Upper vowels & symbols (ั ิ ี ึ ื ็ ํ) on tall consonants
    if (upperVowelShiftMap[ch]) {
      if (isTallBase) {
        result.push(String.fromCharCode(upperVowelShiftMap[ch]));
      } else {
        result.push(chars[i]);
      }
      continue;
    }

    // 5. Default
    result.push(chars[i]);
  }

  return result.join('');
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
