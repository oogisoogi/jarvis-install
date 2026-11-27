'use strict';
/**
 * 첨부 경로의 상태 표 — 보내는 쪽 판 × 파일 꼴 × 크기 × 이름 묶음 → 서버 판정(split 판).
 *   node model/attach-table.js            실제 상한(921,600 바이트)으로 돌려 표를 찍는다(결과 = attach-table.txt 에 붙여 둔다 · 약 1분)
 *   test.js 의 G 절은 buildTable() 을 작은 상한으로 불러 「빈칸이 없다 · 기대와 같다」 를 잰다.
 *
 * 보내는 쪽: old = 0.3.45 이하(원래 바이트 그대로 · 상한을 넘으면 끝에서 바이트로 자름) · new = split 설계의 설치기(엄격한 UTF-8 로 읽기 → 전체 가림 → 글자 단위로 자름 → UTF-8 · UTF-16 은 머리표가 있어도 읽지 않는다)
 * 판정 낱말: text(가린 글 저장) · full:<까닭>(서버가 통째 가림) · full(설치기):<까닭>(설치기가 `<전부 지움>` 한 낱말을 보냄 → 서버는 그대로 저장) · none(보내지 않음 = 빈 파일)
 * 「평범한 첨부」 = 설치기가 실제로 쓰는 꼴(ENCODING-FACTS.md ㉮ 표): UTF-8 한글 LF · UTF-8 한글 CRLF · UTF-8 머리표 CRLF · ASCII LF · ASCII CRLF.
 */
const A = require('./attach-strict.js');

const enc = (text) => new Uint8Array(Buffer.from(text, 'utf8'));
const u16 = (text, be, bom) => {
  const body = Buffer.from(text, 'utf16le');
  if (be) body.swap16();
  return new Uint8Array(bom ? Buffer.concat([Buffer.from(be ? [0xfe, 0xff] : [0xff, 0xfe]), body]) : body);
};
const join = (...parts) => new Uint8Array(Buffer.concat(parts.map((part) => Buffer.from(part))));
// CP949(한국어 ANSI) 바이트 — node 에는 그 인코더가 없다. 여기 쓰는 낱말만 손으로 적은 표(설치 = BC B3 C4 A1 · 완료 = BF CF B7 E1 · 기록 = B1 E2 B7 CF · 가 = B0 A1).
const CP949 = { 설: [0xbc, 0xb3], 치: [0xc4, 0xa1], 완: [0xbf, 0xcf], 료: [0xb7, 0xe1], 기: [0xb1, 0xe2], 록: [0xb7, 0xcf], 가: [0xb0, 0xa1] };
const cp949 = (text) => {
  const out = [];
  for (const ch of text) { if (CP949[ch]) out.push(...CP949[ch]); else if (ch.charCodeAt(0) < 0x80) out.push(ch.charCodeAt(0)); else throw new Error('cp949 표에 없는 글자 ' + ch); }
  return new Uint8Array(out);
};

/** 평범한 기록 글 — 한 줄 약 70바이트. 계정 이름(지어낸 값)이 표시 줄과 맨 글 양쪽에 나온다. */
function logText(account, eol, lines, korean) {
  const out = [];
  for (let i = 0; i < lines; i += 1) {
    if (i % 40 === 0) out.push('USERNAME=' + account);
    else if (i % 40 === 1) out.push((korean ? '설치 기록 ' : 'install log ') + 'C:\\Users\\' + account + '\\.jarvis\\bootstrap.log');
    else if (i % 40 === 2) out.push((korean ? '완료 ' : 'done ') + account + ' ok step ' + i);
    else out.push('2026-11-16T10:' + String(i % 60).padStart(2, '0') + ':00+0900 ' + (korean ? '[3/10] 설치 기록 가 ' : '[3/10] install step ') + i);
  }
  return out.join(eol) + eol;
}
const linesFor = (bytes) => Math.max(3, Math.round(bytes / 62));

const KINDS = [
  // [이름, 평범한가, 만드는 함수(글) → 바이트]
  ['UTF-8 한글 LF(맥 기록·환경 보고)', true, (acct, n) => enc(logText(acct, '\n', n, true))],
  ['UTF-8 한글 CRLF(윈 기록·환경 보고)', true, (acct, n) => enc(logText(acct, '\r\n', n, true))],
  ['UTF-8 머리표 + CRLF(윈 5.1 설치 창 글자)', true, (acct, n) => join([0xef, 0xbb, 0xbf], enc(logText(acct, '\r\n', n, true)))],
  ['ASCII LF', true, (acct, n) => enc(logText(acct, '\n', n, false))],
  ['ASCII CRLF', true, (acct, n) => enc(logText(acct, '\r\n', n, false))],
  ['UTF-16LE 머리표(쓰는 코드 없음)', false, (acct, n) => u16(logText(acct, '\r\n', n, true), false, true)],
  ['UTF-16LE 머리표 없음(쓰는 코드 없음)', false, (acct, n) => u16(logText(acct, '\r\n', n, true), false, false)],
  ['UTF-16BE 머리표(쓰는 코드 없음)', false, (acct, n) => u16(logText(acct, '\r\n', n, true), true, true)],
  ['UTF-16BE 머리표 없음(쓰는 코드 없음)', false, (acct, n) => u16(logText(acct, '\r\n', n, true), true, false)],
  ['CP949 한글(v0.3.17 의 5.1 설치 기록)', false, (acct, n) => cp949(logText(acct, '\r\n', n, true))],
  ['UTF-8 기록에 CP949 줄이 섞임(v0.3.17 흔적)', false, (acct, n) => join(cp949(logText(acct, '\r\n', 3, true)), enc(logText(acct, '\r\n', n, true)))],
  ['UTF-8 + NUL 바이트 하나', false, (acct, n) => join(enc(logText(acct, '\r\n', n, true)), [0x00], enc('tail ' + acct + '\r\n'))],
  ['빈 파일', false, () => new Uint8Array(0)],
];
const ACCOUNTS = ['acct77', 'ra', 'kim.dev', '서연', '홍길동']; // 지어낸 값(짧은 영문 · 점 든 영문 · 한글)

const verdict = (out) => (out.path === 'full' ? 'full:' + out.reason : out.path);

/**
 * buildTable({ maxBytes, sizes }) → 줄 목록 [{ kind, ordinary, size, sender, counts: { 판정 낱말: 건수 }, n }]
 *   sizes = 파일 바이트 크기의 목표값들(상한보다 큰 값을 하나 넣으면 「잘리는」 칸이 나온다)
 *   CP949 표에 없는 계정(한글)은 CP949 꼴에서 건너뛴다.
 */
function buildTable(opts = {}) {
  const maxBytes = opts.maxBytes === undefined ? A.ATTACH_MAX_BYTES : opts.maxBytes;
  const sizes = opts.sizes || [2000, 60000, 600000, Math.round(maxBytes * 1.4)];
  const rows = [];
  const cells = [];
  for (const [kind, ordinary, make] of KINDS) {
    for (const size of sizes) {
      for (const sender of ['old', 'new']) {
        const counts = {};
        let n = 0;
        for (const account of ACCOUNTS) {
          let file;
          try { file = make(account, linesFor(size)); } catch (error) { continue; } // CP949 표에 없는 한글 계정
          const reportNames = [account]; // 보고를 열 때 설치기·서버가 이미 아는 이름
          const sent = sender === 'old' ? A.oldInstallerAttachment(file, maxBytes) : A.installerAttachment(file, reportNames, { maxBytes });
          let word;
          let out = null;
          if (sent === null) word = 'none';
          else if (sent.bytes.length > maxBytes) word = 'rejected(413)'; // 서버 계약: 한 건 상한 초과 — 생기면 안 된다
          else {
            out = A.serverAttachment(sent.bytes, reportNames);
            // 새 설치기가 스스로 통째 가림을 보냈으면(`<전부 지움>` 한 낱말) 서버는 그것을 평범한 글로 받는다 — 표에는 「어디서 · 왜」 를 적는다
            word = sent.full ? 'full(설치기):' + sent.reason : verdict(out);
            if (sent.full && !(out.path === 'text' && out.text === '<전부 지움>')) word = '불일치(설치기 통째 ↔ 서버 ' + verdict(out) + ')';
          }
          counts[word] = (counts[word] || 0) + 1;
          n += 1;
          cells.push({ kind, ordinary, size, sender, account, file, sent, out, word });
        }
        rows.push({ kind, ordinary, size, sender, counts, n });
      }
    }
  }
  return { rows, cells, maxBytes, sizes };
}

function printTable(table, say) {
  const fmt = (counts) => Object.keys(counts).sort().map((word) => word + ' ' + counts[word]).join(' · ');
  say('| 파일 꼴 | 크기(바이트 목표) | 옛 설치기(0.3.45 이하 · 원래 바이트) → 서버 | 새 설치기 → 서버 |');
  say('|---|---|---|---|');
  for (let i = 0; i < table.rows.length; i += 2) {
    const a = table.rows[i];
    const b = table.rows[i + 1];
    say('| ' + a.kind + ' | ' + a.size + ' | ' + fmt(a.counts) + ' | ' + fmt(b.counts) + ' |');
  }
  const ordinary = table.cells.filter((cell) => cell.ordinary);
  for (const sender of ['old', 'new']) {
    const mine = ordinary.filter((cell) => cell.sender === sender);
    const full = mine.filter((cell) => cell.word.indexOf('full') === 0);
    say('평범한 첨부(설치기가 실제로 쓰는 다섯 꼴) · ' + (sender === 'old' ? '옛 설치기' : '새 설치기') + ': ' + mine.length + '건 중 통째 가림 ' + full.length
      + (full.length > 0 ? ' — ' + [...new Set(full.map((cell) => cell.kind + ' @' + cell.size + ' ' + cell.word))].join(' / ') : ''));
  }
}

module.exports = { buildTable, printTable, KINDS, ACCOUNTS, enc, u16, join, cp949, logText };

if (require.main === module) {
  const started = Date.now();
  const table = buildTable();
  const out = [];
  const say = (line) => { out.push(line); console.log(line); };
  say('첨부 상태 표 — 상한 ' + table.maxBytes + ' 바이트 · 이름 묶음 ' + ACCOUNTS.length + '(지어낸 계정 값) · node ' + process.version);
  printTable(table, say);
  say('걸린 시간 ' + (Date.now() - started) + 'ms');
}
