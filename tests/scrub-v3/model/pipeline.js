'use strict';
/**
 * 칸 하나의 처리 순서 — 참조 모델(split 판 · codex 설계 2R 발견 4 + 3R 발견 3·6).
 *
 * 순서가 명세다(까닭도 이 차례로 붙는다 — 둘 이상 걸리면 앞의 것):
 *   빈 글이면 빈 글을 돌려준다(가릴 것도 지킬 것도 없다 — 문지기·시계를 보지 않는 유일한 예외)
 *   ⓪ 문지기(가리기 전): ㉠ 넘친 수확의 이름 묶음이면 통째 가림(harvest) → ㉡ 글이 크기 상한을 넘으면 통째 가림(size)
 *      그 뒤에 시계를 처음 읽는다(고장이면 clock) — 문지기는 시계에 기대지 않는다(split 1R 발견 4)
 *   ① 받은 글 **전체**를 가린다(가림 앞에서는 한 글자도 줄이지 않는다 · 2R 발견 4)
 *   ② 그 뒤에 자른다(UTF-8 바이트 상한 · 서러게이트 짝을 가르지 않음)
 *   예산(벽시계)은 ①② 를 하는 **도중**에 확인한다 — 끝난 뒤 한 번이 아니다(3R 발견 6).
 *
 * 닫힌 실패(전부 `<전부 지움>` 한 낱말 + 까닭):
 *   harvest  이름 묶음이 넘친 수확에서 왔다(불완전한 이름으로 가리지 않는다 · 3R 발견 3)
 *   size     글이 FIELD_UNITS_MAX 코드 단위를 넘는다 — **가리기 전에** 판정한다(실행 시간·메모리의 진짜 뚜껑은 이것이다.
 *            벽시계 예산은 정규식 한 번·디코딩 한 번 같은 「끊을 수 없는 한 단계」 안에서는 확인하지 못한다)
 *   budget   벽시계 예산을 넘었다(확인 자리 = 가림 모델의 checkpoint 자리들 + 자른 뒤)
 *   clock    예산을 재는 시계가 고장이다 — 값이 유한한 수가 아니거나, 뒤로 가거나, 읽다가 던지거나, 예산 값 자체가 유한한 0 이상의 수가 아니다.
 *            확인하는 것은 이 넷뿐이다: **멈춘 시계·느린 시계는 알아채지 못한다**(늘 같은 값을 내는 시계는 통과하고 예산은 영영 닫히지 않는다) — 그때의 뚜껑은 크기 문지기다
 *   names · rescans · error  가림 함수의 까닭 그대로
 * 통째 표식은 자르지 않는다(상수 15바이트) — maxBytes 가 그보다 작아도 `<전부 지움>` 그대로다(제품의 상한은 전부 120바이트 이상이다 · 명시된 예외).
 *
 * scrubField(text, names, opts) → { text, full, reason, truncated, runs }   (runs = 가린 구간의 원문 좌표 — 자르기 전 · 통째 가림이면 null)
 *   names           이름 배열, 또는 harvest() 가 돌려준 { names, overflow }
 *   opts.maxBytes   자른 뒤 UTF-8 바이트 상한(없으면 자르지 않음)      opts.keep  'tail'(기본 · 기록은 끝이 중요) | 'head'
 *   opts.budgetMs · opts.clock()  벽시계 예산(없으면 재지 않음)       opts.unitsMax  크기 상한을 바꿔 끼우기(시험용)
 *   opts.variant    'M16-cut-first'(2회차 처분) · 'M26-clock-unchecked'(3회차 꼴 = 시계 값을 믿고 끝에서 한 번만 잰다)
 *                   · 'M27-no-size-cap'(크기 문지기 없음) · 'M28-ignore-overflow'(넘친 수확을 그대로 씀) · 'M36-clock-first'(시계 초기화가 문지기보다 먼저)
 */
const { scrubV3, MARK } = require('./scrub-v3.js');

/** 칸 하나가 받는 글의 크기 상한(코드 단위). 파일을 읽는 호출처는 **읽기 전에** 파일 바이트 수를 이 값과 견준다(UTF-8 은 바이트 수 ≥ 코드 단위 수). */
const FIELD_UNITS_MAX = 4194304;

const utf8Size = (point) => (point < 0x80 ? 1 : point < 0x800 ? 2 : point < 0x10000 ? 3 : 4);

/** 끝에서부터 maxBytes(UTF-8) 이하 — 서러게이트 짝을 가르지 않는다. 표식 가운데서 잘려도 된다(표식 글자는 비밀이 아니다). 선형. */
function cutTail(text, maxBytes) {
  let size = 0;
  let at = text.length;
  while (at > 0) {
    const low = text.charCodeAt(at - 1);
    const pair = low >= 0xdc00 && low <= 0xdfff && at >= 2 && text.charCodeAt(at - 2) >= 0xd800 && text.charCodeAt(at - 2) <= 0xdbff;
    const step = pair ? 2 : 1;
    const bytes = pair ? 4 : utf8Size(low >= 0xd800 && low <= 0xdfff ? 0xfffd : low);
    if (size + bytes > maxBytes) break;
    size += bytes;
    at -= step;
  }
  return text.slice(at);
}
function cutHead(text, maxBytes) {
  let size = 0;
  let at = 0;
  while (at < text.length) {
    const point = text.codePointAt(at);
    const bytes = utf8Size(point >= 0xd800 && point <= 0xdfff ? 0xfffd : point);
    if (size + bytes > maxBytes) break;
    size += bytes;
    at += point > 0xffff ? 2 : 1;
  }
  return text.slice(0, at);
}

const stop = (reason) => { const error = new Error('scrub stop: ' + reason); error.scrubReason = reason; return error; };

/**
 * 예산 계기 — 시계 값을 믿지 않는다. 읽을 때마다: 유한한 수인가 · 앞에 읽은 값보다 작지 않은가. 어긋나면 'clock' 으로 던진다.
 * check() = 시계를 한 번 읽어 (지금 − 처음) > 예산이면 'budget' 으로 던진다.
 */
function makeBudget(opts) {
  if (opts.budgetMs === undefined) return { check: undefined };
  if (typeof opts.budgetMs !== 'number' || !Number.isFinite(opts.budgetMs) || opts.budgetMs < 0) throw stop('clock');
  let last = null;
  const read = () => {
    let now;
    try { now = opts.clock(); } catch (error) { throw stop('clock'); }
    if (typeof now !== 'number' || !Number.isFinite(now) || (last !== null && now < last)) throw stop('clock');
    last = now;
    return now;
  };
  const started = read();
  return { check: () => { if (read() - started > opts.budgetMs) throw stop('budget'); } };
}

function scrubField(text, names, opts = {}) {
  let source = '';
  const full = (reason) => ({ text: source.length === 0 ? '' : MARK.FULL, full: source.length > 0, reason: source.length === 0 ? null : reason, truncated: false, runs: source.length === 0 ? [] : null });
  try {
    source = String(text);
    if (source.length === 0) return full(null); // 빈 글 예외 — 문지기·시계보다 먼저
    const variant = opts.variant || '';
    const nameList = Array.isArray(names) ? names : (names && names.names) || [];
    const overflow = !Array.isArray(names) && names !== null && names !== undefined && names.overflow === true;
    // ⓪ 문지기 — 가리기 전 · 시계보다 먼저(variant 'M36-clock-first' = split 1R 발견 4 의 꼴: 시계 초기화가 문지기보다 먼저)
    if (variant === 'M36-clock-first') makeBudget(opts);
    if (overflow && variant !== 'M28-ignore-overflow') return full('harvest');
    const unitsMax = opts.unitsMax === undefined ? FIELD_UNITS_MAX : opts.unitsMax;
    if (source.length > unitsMax && variant !== 'M27-no-size-cap') return full('size');
    if (variant === 'M26-clock-unchecked') {
      // 3회차 꼴: 시계 값을 검증하지 않고, 다 끝난 뒤 한 번만 잰다(NaN·뒤로 가는 시계가 통과한다 · 예산은 뚜껑이 아니다)
      const started = opts.budgetMs === undefined ? 0 : opts.clock();
      const result = scrubV3(source, nameList);
      if (opts.budgetMs !== undefined && opts.clock() - started > opts.budgetMs) return full('budget');
      if (result.full) return full(result.reason);
      if (opts.maxBytes === undefined) return { text: result.text, full: false, reason: null, truncated: false, runs: result.runs };
      const kept = opts.keep === 'head' ? cutHead(result.text, opts.maxBytes) : cutTail(result.text, opts.maxBytes);
      return { text: kept, full: false, reason: null, truncated: kept.length < result.text.length, runs: result.runs };
    }
    const budget = makeBudget(opts); // 시계를 처음 읽는다 — 고장이면 여기서 'clock'
    if (variant === 'M16-cut-first' && opts.maxBytes !== undefined) {
      // 2회차 처분: 끝에서 (상한 + 4096) 글자를 줄 경계로 뗀다 → 가림 → 첫 줄 버림 → 상한으로 자름
      const window = opts.maxBytes + 4096;
      if (source.length > window) {
        const from = source.indexOf('\n', source.length - window);
        const part = from >= 0 ? source.slice(from + 1) : source.slice(source.length - window);
        const result = scrubV3(part, nameList);
        if (result.full) return full(result.reason);
        const firstLine = result.text.indexOf('\n');
        return { text: cutTail(firstLine >= 0 ? result.text.slice(firstLine + 1) : '', opts.maxBytes), full: false, reason: null, truncated: true, runs: null };
      }
    }
    const result = scrubV3(source, nameList, { checkpoint: budget.check }); // ① 전체를 가린다(도중에 예산 확인)
    if (result.full) return full(result.reason);
    if (opts.maxBytes === undefined) { if (budget.check) budget.check(); return { text: result.text, full: false, reason: null, truncated: false, runs: result.runs }; }
    const kept = opts.keep === 'head' ? cutHead(result.text, opts.maxBytes) : cutTail(result.text, opts.maxBytes); // ② 그 뒤에 자른다
    if (budget.check) budget.check(); // 자르기까지가 예산 안이다
    return { text: kept, full: false, reason: null, truncated: kept.length < result.text.length, runs: result.runs };
  } catch (error) {
    return full(error && typeof error.scrubReason === 'string' ? error.scrubReason : 'error');
  }
}

module.exports = { scrubField, cutTail, cutHead, FIELD_UNITS_MAX };
