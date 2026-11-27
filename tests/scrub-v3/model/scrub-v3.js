'use strict';
/**
 * 가림 함수 v3 — 참조 모델(제품 코드 아님 · TICKET=scrub-redesign-1116 · 3회차: codex 설계 2R 반영 — 핵심 알고리즘은 2회차 그대로 · 바뀐 곳 = 0단계 정리의 순서).
 *
 * 한 문장: 「가릴 자리」를 원문(정리한 글 T)의 글자 위치 집합으로 계산한다. 이름은 원문에서 한 번만 찾고(모든 이름의 모든 자리 ·
 * 겹침 포함 · Aho–Corasick 선형), 결과 글에서 이름을 다시 찾지 않는다. 구조 규칙은 원문에서 찾은 뒤, 결과 글에 다시 걸리는 것이
 * 없어질 때까지만 넓힌다(그 재확인에는 이름이 끼지 않는다). 재확인이 상한을 넘거나 한도를 벗어나면 던지지 않고 칸 통째 가림.
 *
 * 돌려주는 것: { text, marks, runs, full, reason, rescans, work }
 *   text   = 가린 글(짝 잃은 서러게이트가 없다 — UTF-8 로 적었다 읽어도 그대로)
 *   marks  = 우리가 쓴 표식의 자리(가린 글 좌표 · [시작, 끝, 순위])
 *   runs   = 가린 원문 구간(T 좌표 · [시작, 끝, 순위]) — 서로 겹치지도 맞닿지도 않는다
 *   full   = 칸 통째 가림(닫힌 실패)이면 true · reason = 'names'(이름 한도) | 'rescans'(재확인 상한) | 'error'(예외) | null
 *   work   = 합치기·자리 옮김의 걸음 수(선형임을 재는 계기)
 *
 * 모든 좌표 = UTF-16 코드 단위. 비교 = 서수(코드 단위 값).
 */

const MARK = {
  EMAIL: '<이메일 지움>',
  BEARER: 'Bearer <토큰 지움>',
  KEY: '<키 지움>',
  HOME: '~',
  NAME: '~user',
  FULL: '<전부 지움>', // 닫힌 실패(칸 통째 가림) — v3 에서 새로 생기는 유일한 표식 글자(master 확정)
};

// 순위(작을수록 이김) — 한 덩이의 표식 = 그 덩이에 든 구간 중 가장 작은 순위의 표식
const RANK = { EMAIL: 0, BEARER: 1, KEY: 2, WINHOME: 3, UNIXHOME: 4, NAME: 5, FULL: 6 };
const MARK_OF_RANK = [MARK.EMAIL, MARK.BEARER, MARK.KEY, MARK.HOME, MARK.HOME, MARK.NAME, MARK.FULL];

/** 한도 — 벗어나면 던지지 않고 칸 통째 가림(조용히 일부만 가리지 않는다). */
const LIMITS = {
  NAMES_MAX: 256, // 서로 다른 이름 수(호출처 합치기 상한과 같음)
  NAME_UNITS_MAX: 262144, // 이름 글자 합(코드 단위) — 자동기계 크기의 상한. 이름 하나의 길이에는 따로 한도가 없다(긴 집 경로도 이름이다 · codex 1R Q7)
  RESCANS_MAX: 8, // 구조 재확인에서 「바뀐」 횟수 상한
};

/**
 * 0단계 정리 — 순서가 명세다(3회차 · codex 2R 발견 1):  ① 글자열로 바꿈 → ② NUL 제거 → ③ **그 결과에** 짝 잃은 서러게이트를 U+FFFD 로.
 * ②가 먼저여야 NUL 을 사이에 둔 서러게이트 반쪽 둘(\uD83D \u0000 \uDE00)이 한 글자로 붙는다. 글과 이름에 같은 순서.
 * (2회차는 한 번의 훑기 안에서 「다음 코드 단위」를 NUL 을 빼기 전의 글에서 봐서 ③이 ②보다 먼저인 꼴이었다 → 이름 일치가 사라졌다.)
 * tidyOrder = 'surrogates-first' 는 그 2회차 꼴을 되살린 뮤턴트(M15) 전용이다.
 */
function replaceLoneSurrogates(text) {
  let clean = true;
  for (let i = 0; i < text.length; i += 1) {
    const unit = text.charCodeAt(i);
    if (unit >= 0xd800 && unit <= 0xdfff) { clean = false; break; }
  }
  if (clean) return text;
  const out = [];
  for (let i = 0; i < text.length; i += 1) {
    const unit = text.charCodeAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      const next = i + 1 < text.length ? text.charCodeAt(i + 1) : 0;
      if (next >= 0xdc00 && next <= 0xdfff) { out.push(text[i], text[i + 1]); i += 1; } else out.push('�');
    } else if (unit >= 0xdc00 && unit <= 0xdfff) out.push('�');
    else out.push(text[i]);
  }
  return out.join('');
}
const removeNul = (text) => (text.indexOf('\u0000') < 0 ? text : text.split('\u0000').join(''));
function normalize(input, tidyOrder) {
  const text = String(input);
  if (tidyOrder === 'surrogates-first') return removeNul(replaceLoneSurrogates(text)); // M15 — 틀린 순서
  return replaceLoneSurrogates(removeNul(text));
}

// ── 구조 규칙 — 엔진 중립 문법만: \b · \s · \w · i 플래그 없음. 글자 모둠은 전부 코드 값으로 적는다 ──
const NB = '(?<![A-Za-z0-9_])';
const WS_WIDE = '\\t\\n\\v\\f\\r \\u0085\\u00a0\\u1680\\u180e\\u2000-\\u200a\\u2028\\u2029\\u202f\\u205f\\u3000\\ufeff';
const WS_ASCII = '\\t\\n\\v\\f\\r ';
const UNIX_STOP = '/' + WS_ASCII + '"\'<>';

const RULE_SOURCES = [
  ['[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\\.[A-Za-z0-9-]{1,63})*\\.[A-Za-z]{2,63}', RANK.EMAIL],
  [NB + '[Bb][Ee][Aa][Rr][Ee][Rr][' + WS_WIDE + ']+[A-Za-z0-9._~+/=-]+', RANK.BEARER],
  [NB + 'sk-[A-Za-z0-9_-]{8,}', RANK.KEY],
  [NB + '[A-Za-z]:(?:\\\\{1,2}|/)[Uu][Ss][Ee][Rr][Ss](?:\\\\{1,2}|/)[^\\\\/\\r\\n"\'<>|:*?]+', RANK.WINHOME],
  // (/Users/)+ — 겹겹이 든 /Users/ 를 한 번에. (?<!/Users/) — 사슬은 그 머리에서만 시작한다(뜻 불변 · 이름 없이 끝난 긴 사슬의 제곱 비용 제거).
  ['(?<!/Users/)(?:/Users/)+[^' + UNIX_STOP + ']+', RANK.UNIXHOME],
];
const RULES = RULE_SOURCES.map(([source, rank]) => [new RegExp(source, 'g'), rank]);

/** 규칙마다의 일치 구간 — 규칙 하나의 목록은 왼쪽부터·겹치지 않게(= 시작 자리 순). */
function structStreams(text, rules = RULES, tick) {
  return rules.map(([re, rank]) => {
    const spans = [];
    re.lastIndex = 0;
    for (let m = re.exec(text); m !== null; m = re.exec(text)) spans.push([m.index, m.index + m[0].length, rank]);
    if (tick) tick(); // 예산 확인 자리(split · codex 3R 발견 6) — 규칙 하나가 끝날 때마다
    return spans;
  });
}
const structSpans = (text, rules) => [].concat(...structStreams(text, rules));

/**
 * 뒤보기가 없는 엔진(옛 macOS 의 JavaScriptCore)용 같은 뜻의 규칙 실행 — 낱말 경계 = \b · /Users/ 사슬 = 손 반복.
 * structStreams 와 구간이 같아야 한다(test.js I 절 · engine-diff.js 가 견준다).
 */
const PORTABLE_RULES = RULE_SOURCES.slice(0, 4).map(([source, rank]) => [new RegExp(source.indexOf(NB) === 0 ? '\\b' + source.slice(NB.length) : source, 'g'), rank]);
const UNIX_STOP_SET = { 47: 1, 9: 1, 10: 1, 11: 1, 12: 1, 13: 1, 32: 1, 34: 1, 39: 1, 60: 1, 62: 1 };
function structStreamsPortable(text) {
  const streams = structStreams(text, PORTABLE_RULES);
  const unix = [];
  const anchor = '/Users/';
  for (let at = text.indexOf(anchor); at >= 0; ) {
    let chainEnd = at;
    while (text.startsWith(anchor, chainEnd)) chainEnd += anchor.length;
    let end = chainEnd;
    while (end < text.length && UNIX_STOP_SET[text.charCodeAt(end)] !== 1) end += 1;
    if (end > chainEnd) unix.push([at, end, RANK.UNIXHOME]);
    at = text.indexOf(anchor, end > chainEnd ? end : chainEnd);
  }
  streams.push(unix);
  return streams;
}

// ── 이름 — Aho–Corasick: 모든 이름의 모든 자리(겹침 포함)의 합집합을 O(|T| + Σ|이름|) 로 ──
function buildAutomaton(names) {
  const go = new Map(); // 열쇠 = 상태 × 65536 + 코드 단위
  const fail = [0];
  const longest = [0]; // 이 상태의 글자열을 접미사로 하는 이름 중 가장 긴 것의 길이
  const kids = [[]];
  for (const name of names) {
    let state = 0;
    for (let i = 0; i < name.length; i += 1) {
      const unit = name.charCodeAt(i);
      let to = go.get(state * 65536 + unit);
      if (to === undefined) {
        to = fail.length;
        fail.push(0);
        longest.push(0);
        kids.push([]);
        go.set(state * 65536 + unit, to);
        kids[state].push(unit);
      }
      state = to;
    }
    if (name.length > longest[state]) longest[state] = name.length;
  }
  const queue = kids[0].map((unit) => go.get(unit));
  for (let head = 0; head < queue.length; head += 1) {
    const state = queue[head];
    for (const unit of kids[state]) {
      const to = go.get(state * 65536 + unit);
      let f = fail[state];
      while (f !== 0 && !go.has(f * 65536 + unit)) f = fail[f];
      const via = go.get(f * 65536 + unit);
      fail[to] = via !== undefined && via !== to ? via : 0;
      if (longest[fail[to]] > longest[to]) longest[to] = longest[fail[to]];
      queue.push(to);
    }
  }
  return { go, fail, longest };
}

/** 이름이 덮는 원문 구간들(겹친 것·맞닿은 것은 한 구간으로 · 왼쪽부터). */
function nameSpans(text, names, tick) {
  if (names.length === 0) return [];
  const { go, fail, longest } = buildAutomaton(names);
  const spans = []; // 끝 자리가 늘어나는 순서로 쌓인다 — 새 구간이 앞 구간에 닿으면 합친다(되돌아가는 걸음의 합 ≤ 쌓은 수)
  let state = 0;
  for (let i = 0; i < text.length; i += 1) {
    if (tick && (i & 65535) === 65535) tick(); // 예산 확인 자리(split · 발견 6) — 65,536 글자마다
    const unit = text.charCodeAt(i);
    while (state !== 0 && !go.has(state * 65536 + unit)) state = fail[state];
    const to = go.get(state * 65536 + unit);
    state = to === undefined ? 0 : to;
    const len = longest[state];
    if (len === 0) continue;
    let start = i + 1 - len; // 여기서 끝나는 가장 긴 이름 하나면 충분하다 — 같은 끝의 더 짧은 이름은 그 안에 든다
    while (spans.length > 0 && spans[spans.length - 1][1] >= start) {
      const prev = spans.pop();
      if (prev[0] < start) start = prev[0];
    }
    spans.push([start, i + 1, RANK.NAME]);
  }
  return spans;
}

/**
 * 시작 자리 순으로 놓인 목록 여러 개(개수는 상수: 이름 1 + 규칙 5 + 앞 덩이 1)를 한 번 훑어 덩이로 합친다 — 정렬 없음 · 선형.
 * 겹치거나 맞닿으면 한 덩이 · 덩이의 순위 = 가장 작은 순위. counter.work = 걸음 수.
 */
function mergeStreams(streams, counter) {
  const heads = streams.map(() => 0);
  const runs = [];
  let start = -1;
  let end = -1;
  let rank = 0;
  for (;;) {
    let pick = -1;
    for (let k = 0; k < streams.length; k += 1) {
      if (heads[k] < streams[k].length && (pick < 0 || streams[k][heads[k]][0] < streams[pick][heads[pick]][0])) pick = k;
    }
    if (pick < 0) break;
    const [s, e, r] = streams[pick][heads[pick]];
    heads[pick] += 1;
    if (counter) counter.work += 1;
    if (start >= 0 && s <= end) {
      if (e > end) end = e;
      if (r < rank) rank = r;
    } else {
      if (start >= 0) runs.push([start, end, rank]);
      start = s;
      end = e;
      rank = r;
    }
  }
  if (start >= 0) runs.push([start, end, rank]);
  return runs;
}
/** 시험·바깥용: 순서 없는 구간 목록을 덩이로(정렬 사용 — 모델 본문은 쓰지 않는다). */
const mergeSpans = (spans) => mergeStreams([spans.slice().sort((a, b) => a[0] - b[0])]);

/** 덩이마다 표식 하나로 바꾼 글 + 표식 자리(가린 글 좌표). */
function render(text, runs) {
  const pieces = [];
  let length = 0;
  let cursor = 0;
  const marks = [];
  for (const [start, end, rank] of runs) {
    pieces.push(text.slice(cursor, start));
    length += start - cursor;
    const mark = MARK_OF_RANK[rank];
    marks.push([length, length + mark.length, rank]);
    pieces.push(mark);
    length += mark.length;
    cursor = end;
  }
  pieces.push(text.slice(cursor));
  return { text: pieces.join(''), marks };
}

/**
 * 가린 글의 구간들(한 규칙의 목록 = 왼쪽부터)을 원문 구간으로 — 표식에 닿은 쪽은 그 덩이 끝까지.
 * 목록이 왼쪽부터이므로 표식 목록을 가리키는 손가락 둘(시작용·끝용)은 앞으로만 간다 → 선형(이분 탐색 없음 · codex 1R Q3).
 */
function toOriginalStream(found, runs, marks, counter, quadratic) {
  const out = [];
  let a = -1; // marks[a] = 자리 pos 이하에서 시작하는 마지막 표식
  let b = -1;
  const locate = (pos, from) => {
    let k = quadratic ? -1 : from;
    while (k + 1 < marks.length && marks[k + 1][0] <= pos) { k += 1; if (counter) counter.work += 1; }
    return k;
  };
  for (const [from, to, rank] of found) {
    if (counter) counter.work += 1;
    a = locate(from, a);
    b = locate(to - 1, b > a ? b : a);
    const start = a < 0 ? from : from < marks[a][1] ? runs[a][0] : runs[a][1] + (from - marks[a][1]);
    const last = to - 1;
    const end = b < 0 ? last + 1 : last < marks[b][1] ? runs[b][1] : runs[b][1] + (last - marks[b][1]) + 1;
    out.push([start, end, rank]);
  }
  return out;
}

function fullMask(text, reason, rescans, work) {
  if (text.length === 0) return { text: '', marks: [], runs: [], full: false, reason: null, rescans: 0, work: 0 };
  return { text: MARK.FULL, marks: [[0, MARK.FULL.length, RANK.FULL]], runs: [[0, text.length, RANK.FULL]], full: true, reason, rescans: rescans || 0, work: work || 0 };
}

function cleanNames(names, keepRaw, tidyOrder) {
  const seen = new Set();
  for (const raw of names) {
    const name = keepRaw ? String(raw).split('\u0000').join('') : normalize(raw, tidyOrder);
    if (name.length > 0) seen.add(name);
  }
  return [...seen];
}

/**
 * 가림 — 던지지 않는다.
 * opts(시험·뮤턴트용): rules(구조 규칙 바꿔 끼우기) · limits · variant(뮤턴트 이름)
 */
function scrubV3(input, names, opts = {}) {
  const limits = opts.limits || LIMITS;
  const rules = opts.rules || RULES;
  const variant = opts.variant || '';
  const raw = variant === 'M13-no-wellform';
  const tidyOrder = variant === 'M15-tidy-order' ? 'surrogates-first' : undefined;
  const text = raw ? String(input).split('\u0000').join('') : normalize(input, tidyOrder);
  const counter = { work: 0 };
  let rescans = 0;
  // 예산 확인 자리(split · codex 3R 발견 6): 호출처(pipeline.js)가 넘긴 함수 — 예산을 넘었거나 시계가 고장이면 던진다(까닭을 실어서).
  //   결과 글은 이 함수와 무관하다(확인만 한다 · 없으면 아무 일도 없다). 자리 = 정리 뒤 · 이름 훑기 65,536 글자마다 · 규칙 하나가 끝날 때마다 · 재확인 한 바퀴마다.
  const tick = typeof opts.checkpoint === 'function' ? opts.checkpoint : undefined;
  try {
    if (tick) tick();
    const list = cleanNames(names || [], raw, tidyOrder);
    if (text.length === 0) return fullMask(text);
    if (variant === 'M10-always-full') return fullMask(text, 'error');
    let units = 0;
    for (const name of list) units += name.length;
    if ((list.length > limits.NAMES_MAX || units > limits.NAME_UNITS_MAX) && variant !== 'M8-ignore-limits') return fullMask(text, 'names');

    let found0 = nameSpans(text, list, tick);
    if (variant === 'M1-nonoverlap') found0 = nameSpansNonOverlapping(text, list);
    if (variant === 'M2-keep-marker') found0 = mergeSpans(dropTouchingMarkers(text, splitNameSpans(text, list)));
    if (variant === 'M21-ac-no-stack') found0 = nameSpansNoStack(text, list); // 부록 E — 자동기계가 낸 구간을 쌓아 합치지 않고 그대로 합치기에 넘김
    if (variant === 'M11-overhide') found0 = mergeSpans(found0.map(([s, e, r]) => [s, Math.min(text.length, e + 1), r]));
    let runs = mergeStreams(variant === 'M3-names-first' ? [found0] : [found0, ...structStreams(text, rules, tick)], counter);
    for (; ; rescans += 1) {
      const rendered = render(text, runs);
      if (variant === 'M7-marks-off') rendered.marks.forEach((mark) => { mark[1] += 1; });
      if (tick) tick();
      const found = variant === 'M4-no-rescan' ? [] : structStreams(rendered.text, rules, tick);
      if (found.every((stream) => stream.length === 0)) return { text: rendered.text, marks: rendered.marks, runs, full: false, reason: null, rescans, work: counter.work };
      if (rescans === limits.RESCANS_MAX && variant !== 'M6-unbounded') {
        if (variant === 'M5-throw') throw new RangeError('scrub: no fixpoint');
        return fullMask(text, 'rescans', rescans, counter.work);
      }
      const widened = found.map((stream) => toOriginalStream(stream, runs, rendered.marks, counter, variant === 'M12-quadratic-map'));
      runs = mergeStreams([runs, ...widened], counter);
    }
  } catch (error) {
    if (variant === 'M5-throw') throw error;
    return fullMask(text, error && typeof error.scrubReason === 'string' ? error.scrubReason : 'error', rescans, counter.work);
  }
}

// ── 아래는 뮤턴트(성질을 일부러 어기는 변종) 전용 — 설계가 아니다 ──
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
/** M1: 겹쳐 찾지 않음(왼쪽·긴 것 먼저) — 37cb989 의 결함 ⑧ 을 되살린 꼴. */
function nameSpansNonOverlapping(text, names) {
  if (names.length === 0) return [];
  const re = new RegExp(names.slice().sort((a, b) => b.length - a.length).map(escapeRegExp).join('|'), 'g');
  const spans = [];
  for (let m = re.exec(text); m !== null; m = re.exec(text)) spans.push([m.index, m.index + m[0].length, RANK.NAME]);
  return spans;
}
/**
 * M21: 자동기계가 「여기서 끝나는 가장 긴 이름」을 낸 그대로(쌓아 합치지 않음) — 시작 자리가 차례대로가 아니다.
 * 이것을 정렬 없이 합치기(mergeStreams)에 넘기면 긴 이름의 원문 자리가 남는다(codex 2R 포팅 주의 · 측정 스크립트의 옛 꼴).
 */
function nameSpansNoStack(text, names) {
  if (names.length === 0) return [];
  const { go, fail, longest } = buildAutomaton(names);
  const spans = [];
  let state = 0;
  for (let i = 0; i < text.length; i += 1) {
    const unit = text.charCodeAt(i);
    while (state !== 0 && !go.has(state * 65536 + unit)) state = fail[state];
    const to = go.get(state * 65536 + unit);
    state = to === undefined ? 0 : to;
    if (longest[state] > 0) spans.push([i + 1 - longest[state], i + 1, RANK.NAME]);
  }
  return spans;
}
/** 이름 자리 하나하나(합치지 않음 · 느려도 되는 시험용). */
function splitNameSpans(text, names) {
  const spans = [];
  for (const name of names) for (let at = text.indexOf(name); at >= 0; at = text.indexOf(name, at + 1)) spans.push([at, at + name.length, RANK.NAME]);
  return spans;
}
/** M2: 원문에 있던 표식 글자에 닿는 이름 자리는 이름이 아님 — 37cb989 의 「의도한 바뀜 ⓐ」(C3) 를 되살린 꼴. */
function dropTouchingMarkers(text, spans) {
  const keep = [];
  for (const literal of [MARK.BEARER, MARK.EMAIL, MARK.KEY, MARK.NAME]) {
    for (let at = text.indexOf(literal); at >= 0; at = text.indexOf(literal, at + 1)) keep.push([at, at + literal.length]);
  }
  return spans.filter(([start, end]) => !keep.some(([a, b]) => a < end && start < b));
}

module.exports = {
  MARK, RANK, MARK_OF_RANK, LIMITS, RULE_SOURCES, RULES,
  scrubV3, normalize, removeNul, replaceLoneSurrogates, structStreams, structSpans, structStreamsPortable, nameSpans, mergeStreams, mergeSpans, render, toOriginalStream, cleanNames, fullMask, buildAutomaton,
};
