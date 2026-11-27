'use strict';
/**
 * 글자 첨부 — 참조 모델(split 판 · 추정 없음 · codex split 1R 반영).
 *
 * 3회차까지의 첨부(attach.js — 추정 가지 일곱 · 후보 둘 · 세 인코딩으로 적어 네 읽기 = 12칸 검사 · 표식 바이트 구간 면제 · 두 벌의 이름)는 **쓰지 않는다.**
 * 새 길은 읽기 하나(엄격한 UTF-8) · 판정 둘뿐이다. UTF-16 은 머리표가 있어도 읽지 않는다(쓰는 코드가 없는 가지를 세 구현에 옮기지 않는다 — master 결정 11-16).
 *
 *   서버  serverAttachment(bytes, known)
 *     ⓪ 받은 바이트 수 > FIELD_UNITS_MAX        → 통째 가림(size) — 다른 일보다 먼저(제품에서는 그 앞의 요청 상한 921,600 이 먼저 막는다)
 *     ① 0 바이트가 하나라도 있으면              → 통째 가림(nul)
 *     ② 엄격한 UTF-8 디코더(치명 모드)가 던지면   → 통째 가림(not_utf8)
 *     ③ 맨 앞의 U+FEFF 를 전부 뗀다(디코더가 하나 · 남은 것을 손으로) → 이름 묶음 = harvest(그 글, known) → 칸 처리(pipeline.scrubField = 본문과 같은 가림 함수)
 *     저장 = 가린 글의 UTF-8.
 *
 *   설치기  installerAttachment(fileBytes, known, { maxBytes })
 *     ⓪ 빈 파일은 보내지 않는다 · 파일 바이트 수 > FIELD_UNITS_MAX → 읽지 않고 통째 가림(size)
 *     ① 엄격한 UTF-8 로 읽는다(머리표 EF BB BF 는 디코더가 뗀다). 던지면 통째 가림(decode) · 읽은 글에 NUL 글자가 있으면 통째 가림(nul)
 *     ② 맨 앞 U+FEFF 를 전부 뗌 → **뗀 뒤 글이 비면 보내지 않는다**(머리표뿐인 파일 = 빈 파일과 같다) → 이름 묶음 → **전체를 가린다 → 끝에서 maxBytes 로 자른다**(글자 단위)
 *     ③ 보내는 것 = 그 글의 UTF-8 바이트(온전한 UTF-8 · NUL 없음). 닫힌 실패면 `<전부 지움>` 한 낱말을 보낸다.
 *
 *   ★이름(known) = 배열 **또는 이름 묶음 { names, overflow }**. 묶음을 넘기면 앞 보고의 넘침이 보존된다(넘친 묶음으로 가리는 칸은 통째 가림 — 까닭 harvest).
 *     배열만 넘기는 옛 꼴 = 「넘침 아님」 으로 읽는다(옛 저장 행 = 배열 그대로). 알려진 이름은 수확이 **원본 그대로** 합친다(harvest.js).
 *     두 함수는 이 첨부까지 합친 이름 묶음을 돌려준다(names · overflow) — 다음 칸·다음 첨부는 그 묶음을 그대로 받아야 넘침을 잃지 않는다.
 *
 *   옛 설치기(0.3.45 이하)  oldInstallerAttachment(fileBytes, maxBytes) = 원래 바이트 그대로 · 넘으면 끝에서 **바이트로** 자름(글자 경계를 보지 않는다).
 *
 * 변종(뮤턴트 전용): 'M29-lenient-decode'(서버가 느슨히 읽음) · 'M30-allow-nul'(서버가 0 바이트를 받아들임) · 'M31-installer-lenient'(설치기가 느슨히 읽음)
 *   · 'M32-mac-tail-window'(지금 맥 설치기 = 끝 2×상한 바이트를 떼고 첫 줄을 버린 뒤 가림) · 'M33-groom-known'(알려진 이름을 손질한 것만 씀 = split 1R 발견 1)
 *   · 'M34-send-raw-bytes'(글은 가렸는데 보내는 바이트는 원문 = split 1R 발견 3 의 시험 변종) · 'M37-drop-overflow'(받은 묶음의 넘침을 버리고 이름만 씀 = split 1R 발견 2)
 */
const { MARK } = require('./scrub-v3.js');
const { harvest } = require('./harvest.js');
const { scrubField, FIELD_UNITS_MAX } = require('./pipeline.js');

const ATTACH_MAX_BYTES = 900 * 1024; // 서버 계약(첨부 한 건) = 설치기가 자르는 상한

function stripLeadingBoms(text) {
  let at = 0;
  while (at < text.length && text.charCodeAt(at) === 0xfeff) at += 1;
  return at === 0 ? text : text.slice(at);
}
/** 받은 이름(배열 또는 묶음)을 던지지 않고 푼다. */
function openNames(known) {
  if (Array.isArray(known)) return { names: known, overflow: false };
  if (known !== null && typeof known === 'object' && Array.isArray(known.names)) return { names: known.names, overflow: known.overflow === true };
  return { names: [], overflow: false };
}

function serverAttachment(bytes, known = [], opts = {}) {
  const variant = opts.variant || '';
  const given = openNames(known);
  const incoming = variant === 'M37-drop-overflow' ? given.names : given;
  const full = (reason, set) => ({ path: 'full', text: MARK.FULL, reason, names: set ? set.names : given.names.slice(), overflow: set ? set.overflow : given.overflow, runs: null });
  try {
    if (bytes.length === 0) return { path: 'empty', text: '', reason: null, names: given.names.slice(), overflow: given.overflow, runs: [] }; // 서버는 빈 첨부를 그 앞에서 400 으로 돌려보낸다
    if (bytes.length > FIELD_UNITS_MAX) return full('size');
    if (variant !== 'M30-allow-nul' && bytes.includes(0)) return full('nul');
    let text;
    try { text = new TextDecoder('utf-8', { fatal: variant !== 'M29-lenient-decode' }).decode(bytes); } catch (error) { return full('not_utf8'); }
    text = stripLeadingBoms(text);
    const found = harvest(text, incoming, { variant: variant.indexOf('M33') >= 0 || variant.indexOf('M35') >= 0 ? variant : '' });
    const result = scrubField(text, found, { budgetMs: opts.budgetMs, clock: opts.clock });
    if (result.full) return full(result.reason, found);
    return { path: 'text', text: result.text, reason: null, names: found.names, overflow: found.overflow, runs: result.runs };
  } catch (error) {
    return full('error');
  }
}

function installerAttachment(fileBytes, known = [], opts = {}) {
  const variant = opts.variant || '';
  const maxBytes = opts.maxBytes === undefined ? ATTACH_MAX_BYTES : opts.maxBytes;
  const given = openNames(known);
  const incoming = variant === 'M37-drop-overflow' ? given.names : given;
  const send = (text, fullReason, set, runs) => ({ bytes: new TextEncoder().encode(text), text, full: fullReason !== null, reason: fullReason, names: set ? set.names : given.names.slice(), overflow: set ? set.overflow : given.overflow, runs: runs === undefined ? null : runs });
  try {
    if (fileBytes.length === 0) return null; // 빈 파일은 보내지 않는다(지금과 같음)
    if (variant === 'M32-mac-tail-window') {
      // 지금 맥 설치기(help_scrubbed_tail): 파일이 상한의 두 배를 넘으면 끝 2×상한 바이트를 떼고 첫 줄을 버린다 → 틀린 바이트를 버리고(iconv -c) 읽는다 → 가림 → 자름
      let part = fileBytes;
      if (fileBytes.length > maxBytes * 2) {
        part = fileBytes.subarray(fileBytes.length - maxBytes * 2);
        const nl = part.indexOf(10);
        part = nl >= 0 ? part.subarray(nl + 1) : part.subarray(part.length);
      }
      const loose = new TextDecoder('utf-8').decode(part).split(String.fromCharCode(0xfffd)).join('');
      const set = harvest(loose, incoming);
      const got = scrubField(loose, set, { maxBytes, keep: 'tail' });
      return send(got.text, got.full ? got.reason : null, set, got.runs);
    }
    const unitsMax = opts.unitsMax === undefined ? FIELD_UNITS_MAX : opts.unitsMax;
    if (fileBytes.length > unitsMax) return send(MARK.FULL, 'size'); // 읽기 전에 — 파일 크기만 보고
    let text;
    try { text = new TextDecoder('utf-8', { fatal: variant !== 'M31-installer-lenient' }).decode(fileBytes); } catch (error) { return send(MARK.FULL, 'decode'); }
    if (text.indexOf('\u0000') >= 0) return send(MARK.FULL, 'nul');
    text = stripLeadingBoms(text);
    if (text.length === 0) return null; // 머리표뿐인 파일 = 빈 파일과 같다(보내지 않는다)
    const found = harvest(text, incoming, { variant: variant.indexOf('M33') >= 0 || variant.indexOf('M35') >= 0 ? variant : '' });
    const result = scrubField(text, found, { maxBytes, keep: 'tail', budgetMs: opts.budgetMs, clock: opts.clock, unitsMax });
    const out = send(result.text, result.full ? result.reason : null, found, result.runs);
    if (variant === 'M34-send-raw-bytes') out.bytes = fileBytes; // 글(text)은 가렸지만 실제로 보내는 바이트는 원문
    return out;
  } catch (error) {
    return send(MARK.FULL, 'error');
  }
}

function oldInstallerAttachment(fileBytes, maxBytes = ATTACH_MAX_BYTES) {
  if (fileBytes.length === 0) return null;
  return { bytes: fileBytes.length <= maxBytes ? fileBytes : fileBytes.subarray(fileBytes.length - maxBytes), full: false, reason: null };
}

module.exports = { serverAttachment, installerAttachment, oldInstallerAttachment, stripLeadingBoms, openNames, ATTACH_MAX_BYTES };
