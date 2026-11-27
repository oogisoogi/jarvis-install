'use strict';
/**
 * 이름 수확 — 참조 모델(split 판 · codex 설계 3R 발견 3·4 고침).
 * 규칙의 뜻은 지금 서버 src/scrub.ts harvestNames 와 같고 문법만 엔진 중립이다(\b · i 플래그 · trim() 을 쓰지 않는다).
 *
 * split 에서 바뀐 것 둘:
 *  ① 발견 4 — 셋째 가지(`DOMAIN\계정` 이 한 줄을 다 차지하는 꼴)가 줄 끝 개행을 「먹지」 않는다(앞보기로만 본다).
 *     먹으면 바로 다음 줄이 시작 닻(줄 처음 = 앞 개행)을 잃어 연속한 둘째 줄이 통째로 빠졌다(`ZZ\acct01␤ZZ\acct02␤` → 둘째 줄 미수확).
 *  ② 발견 3 — 상한(64)에 닿아도 훑기를 멈추지 않는다. 65번째 「새 이름」 이 나오면 넘침(overflow)을 돌려준다.
 *     넘친 수확의 이름 목록은 **불완전**하다 → 그 목록으로 가리는 칸은 전부 통째 가림이다(pipeline.js 가 강제 · 조용히 버리지 않는다 = P9 의 뜻).
 *
 * 정리 순서(명세 — 설계 문서 「정리 단계의 순서」 표의 수확 줄):
 *   입력 전체를 0-2(NUL 제거) → 0-3(짝 잃은 서러게이트 → U+FFFD) 로 정리한 뒤 정규식을 돌린다(값만 정리하는 것이 아니다).
 *   값마다: 0-2 → 0-3 → 앞뒤 빈칸 뗌 → 따옴표(" ') 전부 제거 → 2자 이상이면 이름 · 그 값의 마지막 경로 조각(`\` `/` 뒤)을 **다시 앞뒤 빈칸을 떼어** 2자 이상이면 이름.
 *   같은 이름은 하나(코드 단위 비교) · 돌려주는 순서 = 긴 것 먼저(가림 결과는 순서와 무관하다).
 *  ③ split 1R 발견 1 — 알려진 이름은 원본 그대로 합친다(손질은 「더 얻는 이름」 만 만든다) · 표시 값도 따옴표를 떼기 전의 꼴을 함께 둔다(아래 harvest 주석).
 * 그대로인 것: 표시 줄에서 얻는 이름은 2자 이상 · 값 전체 + 마지막 경로 조각 · 따옴표 뗀 꼴 · 상한 64 · 값의 길이 상한 없음(codex 1R Q7) · 수확 문법(어느 줄이 표시 줄인가).
 */
const { normalize } = require('./scrub-v3.js');

const MAX_NAMES = 64;
const NB = '(?<![A-Za-z0-9_])';
const ci = (word) => word.split('').map((ch) => (/[A-Za-z]/.test(ch) ? '[' + ch.toUpperCase() + ch.toLowerCase() + ']' : ch)).join('');
const LABELS = ['USERNAME', 'USERPROFILE', 'LOGNAME', 'USER', 'HOME'].map(ci).join('|');
const nameLines = (lineEnd) => new RegExp(
  NB + '(?:' + LABELS + ')[ \\t]*[=:][ \\t]*([^\\r\\n]+)'
  + '|' + NB + ci('whoami') + '[ \\t]*[:=>][ \\t]*([^\\r\\n]+)'
  + '|(?:^|\\n)[ \\t]*([A-Za-z][A-Za-z0-9.-]{1,63}\\\\[A-Za-z0-9._-]{2,63})[ \\t]*' + lineEnd,
  'g',
);
const NAME_LINES = nameLines('(?=\\r?\\n|$)'); // split: 줄 끝은 앞보기로만(먹지 않는다)
const NAME_LINES_CONSUMING = nameLines('(?:\\r?\\n|$)'); // 3회차까지의 꼴 — 뮤턴트 M24 전용
const WS_SET = new Set([9, 10, 11, 12, 13, 32, 0x85, 0xa0, 0x1680, 0x180e, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]);
for (let unit = 0x2000; unit <= 0x200a; unit += 1) WS_SET.add(unit);

function trimWide(value) {
  let a = 0;
  let b = value.length;
  while (a < b && WS_SET.has(value.charCodeAt(a))) a += 1;
  while (b > a && WS_SET.has(value.charCodeAt(b - 1))) b -= 1;
  return value.slice(a, b);
}

const isBlank = (value) => { for (let i = 0; i < value.length; i += 1) if (!WS_SET.has(value.charCodeAt(i))) return false; return true; };

/**
 * harvest(input, known, opts) → { names, overflow }
 *   known = 이미 아는 이름 — 배열, 또는 앞에서 만든 이름 묶음 { names, overflow }(앞 보고의 넘침을 그대로 물려받는다).
 *
 *   ★알려진 이름은 **원본 그대로** 합친다(codex split 1R 발견 1). 수확 손질(2자 이상 · 따옴표 제거 · 마지막 경로 조각)은 「더 얻는 이름」 을 만들 뿐,
 *     받은 이름을 대신하지 않는다. 손질을 받은 이름에 적용하면 한 글자 계정(`q`)이 사라지고 따옴표 든 계정(`acct'77`)이 다른 글자열로 바뀌어,
 *     가림 함수가 그 이름을 영영 모른다.
 *     원본에서 버리는 것은 둘뿐이다: 정리(0-2 · 0-3) 뒤 **빈 글자열** · **빈칸(넓은 빈칸 목록)뿐인 글자열** — 뒤의 것을 이름으로 두면 글의 모든 빈칸이 가려진다.
 *   표시 줄의 값도 같은 뜻으로: 따옴표를 떼기 **전의 값**(앞뒤 빈칸만 뗀 것)도 2자 이상이면 이름이다 — `USERNAME=O'Brien` 의 글자 그대로를 놓치지 않게.
 *   합친 뒤에 한도: 서로 다른 이름이 MAX_NAMES 를 넘으면 overflow(그때 names 는 앞의 MAX_NAMES 개뿐 = 불완전 → 그 묶음으로 가리는 칸은 통째 가림).
 *   넣는 차례(한도에 닿았을 때 무엇이 남는가만 정한다): 알려진 이름 원본 → 알려진 이름에서 손질로 얻은 것 → 글의 표시 줄에서 얻은 것.
 *
 *   opts.variant: 'M24-consume-newline'(발견 4 의 옛 꼴) · 'M25-silent-cap'(발견 3 의 옛 꼴) · 'M33-groom-known'(알려진 이름을 손질한 것만 넣음 = split 1R 발견 1 의 꼴)
 *                 · 'M35-stripped-only'(표시 값을 따옴표 뗀 꼴로만 넣음)
 */
function harvest(input, known = [], opts = {}) {
  const variant = opts.variant || '';
  const knownList = Array.isArray(known) ? known : (known && Array.isArray(known.names) ? known.names : []);
  const names = [];
  const seen = new Set();
  let overflow = !Array.isArray(known) && known !== null && known !== undefined && known.overflow === true;
  const put = (value) => {
    if (seen.has(value)) return;
    if (names.length >= MAX_NAMES) { if (variant !== 'M25-silent-cap') overflow = true; return; }
    seen.add(value);
    names.push(value);
  };
  const push = (value) => { if (value.length >= 2) put(value); };
  const add = (raw) => {
    const whole = trimWide(normalize(raw));
    const value = whole.split('"').join('').split("'").join('');
    if (variant.indexOf('M35-stripped-only') < 0) {
      // 따옴표를 떼기 전의 값과 그 마지막 경로 조각(따옴표가 없으면 아래 둘과 같은 글자열이라 하나로 센다)
      push(whole);
      const cutWhole = Math.max(whole.lastIndexOf('\\'), whole.lastIndexOf('/'));
      push(trimWide(whole.slice(cutWhole + 1)));
    }
    push(value);
    const cut = Math.max(value.lastIndexOf('\\'), value.lastIndexOf('/'));
    push(trimWide(value.slice(cut + 1)));
  };
  // ① 알려진 이름 원본 — 손질하지 않는다(빈 것 · 빈칸뿐인 것만 버린다)
  if (variant.indexOf('M33-groom-known') < 0) {
    for (const name of knownList) {
      if (typeof name !== 'string') continue; // 글자열이 아닌 것(null · undefined · 수)은 이름이 아니다 — "null"·"undefined" 라는 낱말을 이름으로 만들지 않는다
      const raw = normalize(name);
      if (raw.length > 0 && !isBlank(raw)) put(raw);
    }
  }
  // ② 알려진 이름에서 손질로 더 얻는 것(앞뒤 빈칸을 뗀 꼴 · 따옴표를 뗀 꼴 · 마지막 경로 조각)
  for (const name of knownList) if (typeof name === 'string' && name) add(name);
  // ③ 글의 표시 줄
  const text = normalize(input);
  const re = variant === 'M24-consume-newline' ? NAME_LINES_CONSUMING : NAME_LINES;
  re.lastIndex = 0;
  // 상한에 닿아도 계속 훑는다 — 멈추는 것은 넘침이 확인된 때뿐이다(옛 꼴 M25 는 상한에서 멈춘다).
  for (let m = re.exec(text); m !== null && !overflow && !(variant === 'M25-silent-cap' && names.length >= MAX_NAMES); m = re.exec(text)) {
    add(m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]);
    if (m[0].length === 0) re.lastIndex += 1; // 빈 일치로 제자리 걸음하지 않게(이 문법에서는 생기지 않는다 — 방어)
  }
  names.sort((a, b) => b.length - a.length);
  return { names, overflow };
}

/** 옛 호출 꼴(이름 배열만) — 3회차의 검사(E·F·J 절)가 그대로 돌게 남긴 얇은 껍데기다. 넘침을 잃으므로 새 코드는 쓰지 않는다(harvest() 의 묶음을 그대로 넘긴다). */
function harvestNames(input, known = []) {
  return harvest(input, known).names;
}

module.exports = { harvest, harvestNames, MAX_NAMES, trimWide, isBlank };
