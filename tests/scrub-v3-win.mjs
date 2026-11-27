// scrub-v3-win.mjs — 윈 설치기(bootstrap.ps1 · 순수 PowerShell)의 가림 v3 포팅을 참조 모델과 견준다(TICKET=scrub-v3-port-1116 · ROLE=win).
//
//   node tests/scrub-v3-win.mjs [--dir install-master] [--n 6000] [--jsonl <파일>] [--server-jsonl <파일>] [--pwsh pwsh] [--keep <폴더>]
//
// 관문 1   공용 벡터 161(tests/scrub-v3/model/vectors-v3.json 84 · vectors-split.json 77 — split/model 의 바이트 사본 · sha256 을 매번 잰다)
//          — 글은 코드 단위로 대조(구동기가 UTF-16 코드 단위 16진으로 돌려준다 · UTF-8 해시 금지) · expected.names = 집합 · 설치기 답 null = 보내지 않음.
//          설치기 첨부 18건은 두 길로: 바이트 함수(ConvertTo-RemoteHelpAttachment) + 실제 파일 길(Get-ScrubbedTextBytes · 임시 파일).
//          서버 첨부 22건 = 이 구현의 부품(수확·칸 처리)을 모델 serverAttachment 순서로 조합(시험 안에서만 · 구동기 Invoke-ServerViaPort).
// 관문 1-1 잣대(모델 test.js G 절 serverBad · installerBad · ledgerBad 를 옮김): ㉠ 실제로 보낸 바이트를 UTF-8 로 읽은 글 ㉡ 알려진 이름 **원본**을
//          구현과 따로 들고 그 모든 원문 자리가 가려졌는가 ㉢ 구현이 돌려준 장부(runs·marks)로 — 모델을 다시 돌리지 않는다.
// 관문 2   씨앗 고정 무작위(모델 test.js 의 genGeneral·genPrivate · 서버 좌석과 같은 씨앗 11160301~04) — 모델과 글·통째·까닭·장부 차이 0 +
//          결과마다 violations()(느린 독립 오라클 P13 포함) · core 두 갈래를 서버 좌석과 같은 줄 꼴의 JSONL 로 남기고 서버 JSONL 과 직접 맞댄다.
// 종료 코드 0 = 전부 맞음. 구현 경로 = --dir(뮤턴트 실행기가 사본 폴더를 넘긴다).
import { createRequire } from "node:module";
import { readFileSync, writeFileSync, mkdtempSync, rmSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import os from "node:os";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const MD = path.join(here, "scrub-v3", "model");
const MODEL = { ...require(path.join(MD, "scrub-v3.js")), ...require(path.join(MD, "harvest.js")), ...require(path.join(MD, "pipeline.js")), ...require(path.join(MD, "attach-strict.js")) };
const T = require(path.join(MD, "attach-table.js"));

const args = process.argv.slice(2);
const argOf = (flag, fallback) => { const at = args.indexOf(flag); return at >= 0 ? args[at + 1] : fallback; };
const DIR = path.resolve(argOf("--dir", path.join(here, "..", "install-master")));
const N = Number(argOf("--n", "6000"));
const JSONL = argOf("--jsonl", null);
const SERVER_JSONL = argOf("--server-jsonl", null);
const PWSH = argOf("--pwsh", "pwsh");
const QUIET = args.includes("--quiet");
const KEEP = argOf("--keep", null);

let failed = 0;
const fails = [];
const say = (line) => { if (!QUIET) console.log(line); };
const ok = (cond, label, detail) => { if (!cond) { failed += 1; if (fails.length < 40) fails.push("  ✗ " + label + (detail ? " — " + detail : "")); } return cond; };
const show = (text) => { const s = JSON.stringify(text); return s.length > 90 ? s.slice(0, 60) + "…(" + String(text).length + "자)" : s; };
const { MARK, MARK_OF_RANK, LIMITS, RULE_SOURCES, RANK } = MODEL;
const enc = (text) => new TextEncoder().encode(text);
const hexBytes = (hex) => Uint8Array.from(hex.match(/../g) ?? [], (h) => parseInt(h, 16));
const hex = (bytes) => Buffer.from(bytes).toString("hex");
const sameSet = (a, b) => a.length === b.length && new Set(a).size === new Set([...a, ...b]).size;
// 글 ↔ UTF-16 코드 단위 16진(구동기와 주고받는 꼴)
const U = (text) => { let out = ""; for (let i = 0; i < text.length; i += 1) out += text.charCodeAt(i).toString(16).padStart(4, "0"); return out; };
const D = (h) => { if (h === null || h === undefined) return h; let out = ""; for (let i = 0; i < h.length; i += 4) out += String.fromCharCode(parseInt(h.slice(i, i + 4), 16)); return out; };
const nameArg = (known) => {
  if (Array.isArray(known)) return { t: "list", v: known.map((x) => (typeof x === "string" ? U(x) : x)) };
  if (known !== null && typeof known === "object" && Array.isArray(known.names)) return { t: "set", names: known.names.map((x) => (typeof x === "string" ? U(x) : x)), overflow: known.overflow };
  return { t: "raw", v: known };
};

// ── 벡터 사본의 sha256(split/model 원본 = f539528d…2908a5 · 3095e97c…eb1ab1) ──
const sha = (file) => createHash("sha256").update(readFileSync(file)).digest("hex");
const SHA_V3 = "f539528d57aba26b621be9b228c7263324375806e3bf05f1f2b9e7bbfb2908a5";
const SHA_SPLIT = "3095e97c0c6d5a87bb4db7af8f8cec36e3c15ad75fa52d0e2c0cc7b7baeb1ab1";
ok(sha(path.join(MD, "vectors-v3.json")) === SHA_V3, "벡터 사본 vectors-v3.json sha256", sha(path.join(MD, "vectors-v3.json")));
ok(sha(path.join(MD, "vectors-split.json")) === SHA_SPLIT, "벡터 사본 vectors-split.json sha256", sha(path.join(MD, "vectors-split.json")));
for (const line of readFileSync(path.join(MD, "SHA256SUMS"), "utf8").trim().split("\n")) {
  const [want, file] = line.split(/\s+/);
  ok(sha(path.join(MD, file)) === want, "모델 사본 " + file + " sha256");
}

// ── 잣대(모델 test.js G 절 · 서버 좌석 test-node/scrub-port.mjs 와 같은 옮김 — 이 구현과 공유하는 것은 규칙 원문과 표식 글자뿐) ──
const ORACLE_RULES = RULE_SOURCES.map(([source, rank]) => [new RegExp(source, "g"), rank]);
const tidy = (value) => String(value).split("\u0000").join("").toWellFormed();
const tidyNames = (names) => [...new Set([...names].map(tidy).filter((name) => name.length > 0))];
const structSpansOracle = (text) => {
  const found = [];
  for (const [re, r] of ORACLE_RULES) { re.lastIndex = 0; for (let m = re.exec(text); m !== null; m = re.exec(text)) found.push([m.index, m.index + m[0].length, r]); }
  return found;
};
function nameOccurrences(text, names) {
  const spans = [];
  for (const name of tidyNames(names)) for (let at = text.indexOf(name); at >= 0; at = text.indexOf(name, at + 1)) spans.push([at, at + name.length]);
  return spans;
}
function covered(runs, start, end) {
  let lo = 0;
  let hi = runs.length - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    if (runs[mid][1] <= start) lo = mid + 1;
    else if (runs[mid][0] > start) hi = mid - 1;
    else return end <= runs[mid][1];
  }
  return false;
}
function oracle(input, names) {
  const text = tidy(input);
  const list = tidyNames(names);
  if (text.length === 0) return { text: "", full: false };
  if (list.length > LIMITS.NAMES_MAX || list.reduce((sum, name) => sum + name.length, 0) > LIMITS.NAME_UNITS_MAX) return { text: MARK.FULL, full: true };
  const VISIBLE = 9;
  const rank = new Int8Array(text.length).fill(VISIBLE);
  const hide = (start, end, r) => { for (let k = start; k < end; k += 1) if (r < rank[k]) rank[k] = r; };
  for (const name of list) for (let at = text.indexOf(name); at >= 0; at = text.indexOf(name, at + 1)) hide(at, at + name.length, RANK.NAME);
  for (const [start, end, r] of structSpansOracle(text)) hide(start, end, r);
  for (let changed = 0; ; changed += 1) {
    const out = [];
    const back = [];
    for (let i = 0; i < text.length; ) {
      if (rank[i] === VISIBLE) { out.push(text[i]); back.push([i, i + 1]); i += 1; continue; }
      let j = i;
      let r = VISIBLE;
      while (j < text.length && rank[j] !== VISIBLE) { if (rank[j] < r) r = rank[j]; j += 1; }
      for (const ch of MARK_OF_RANK[r].split("")) { out.push(ch); back.push([i, j]); }
      i = j;
    }
    const rendered = out.join("");
    const found = structSpansOracle(rendered);
    if (found.length === 0) return { text: rendered, full: false, rescans: changed };
    if (changed === LIMITS.RESCANS_MAX) return { text: MARK.FULL, full: true };
    for (const [a, b, r] of found) hide(back[a][0], back[b - 1][1], r);
  }
}
/** test.js violations() — 단, 이 구현이 돌려준 결과로(㉢ · 모델을 다시 돌리지 않는다). 돌려주는 것 = 어긴 성질들. */
function violationsOf(input, names, result) {
  const bad = new Set();
  const text = tidy(input);
  const clean = tidyNames(names);
  const overLimit = clean.length > LIMITS.NAMES_MAX || clean.reduce((sum, name) => sum + name.length, 0) > LIMITS.NAME_UNITS_MAX;
  if (overLimit && text.length > 0 && !result.full) bad.add("P9");
  if (result.rescans > LIMITS.RESCANS_MAX) bad.add("P6");
  if (result.work > 8 * (text.length + 16) * (result.rescans + 2)) bad.add("P6");
  const plain = !overLimit && nameOccurrences(text, names).length === 0 && structSpansOracle(text).length === 0;
  if (plain && result.text !== text) bad.add("P10");
  if (!result.text.isWellFormed()) bad.add("P12");
  const want = oracle(input, names);
  if (want.text !== result.text || want.full !== result.full) bad.add("P13");
  let rebuilt = "";
  let cursor = 0;
  let sound = true;
  const marks = [];
  for (const [start, end, rank] of result.runs) {
    if (!(start >= cursor && end > start && end <= text.length) || (cursor > 0 && start === cursor)) sound = false;
    rebuilt += text.slice(cursor, start);
    marks.push([rebuilt.length, rebuilt.length + MARK_OF_RANK[rank].length, rank]);
    rebuilt += MARK_OF_RANK[rank];
    cursor = end;
  }
  rebuilt += text.slice(cursor);
  if (!sound || rebuilt !== result.text || JSON.stringify(marks) !== JSON.stringify(result.marks)) bad.add("P4");
  if (result.full) { if (result.text !== MARK.FULL) bad.add("P4"); return bad; }
  for (const [start, end] of nameOccurrences(text, names)) if (!covered(result.runs, start, end)) { bad.add("P1"); break; }
  for (const [start, end] of structSpansOracle(text)) if (!covered(result.runs, start, end)) { bad.add("P2"); break; }
  if (structSpansOracle(result.text).length > 0) bad.add("P3");
  return bad;
}
// 손으로 짠 엄격한 UTF-8 검사(Unicode 표 3-7) — 이 구현이 쓰는 .NET 디코더와 다른 수단
const strictUtf8 = (bytes) => {
  let i = 0;
  const n = bytes.length;
  const cont = (k, lo, hi) => k < n && bytes[k] >= lo && bytes[k] <= hi;
  while (i < n) {
    const b = bytes[i];
    if (b <= 0x7f) i += 1;
    else if (b >= 0xc2 && b <= 0xdf) { if (!cont(i + 1, 0x80, 0xbf)) return false; i += 2; }
    else if (b === 0xe0) { if (!cont(i + 1, 0xa0, 0xbf) || !cont(i + 2, 0x80, 0xbf)) return false; i += 3; }
    else if ((b >= 0xe1 && b <= 0xec) || b === 0xee || b === 0xef) { if (!cont(i + 1, 0x80, 0xbf) || !cont(i + 2, 0x80, 0xbf)) return false; i += 3; }
    else if (b === 0xed) { if (!cont(i + 1, 0x80, 0x9f) || !cont(i + 2, 0x80, 0xbf)) return false; i += 3; }
    else if (b === 0xf0) { if (!cont(i + 1, 0x90, 0xbf) || !cont(i + 2, 0x80, 0xbf) || !cont(i + 3, 0x80, 0xbf)) return false; i += 4; }
    else if (b >= 0xf1 && b <= 0xf3) { if (!cont(i + 1, 0x80, 0xbf) || !cont(i + 2, 0x80, 0xbf) || !cont(i + 3, 0x80, 0xbf)) return false; i += 4; }
    else if (b === 0xf4) { if (!cont(i + 1, 0x80, 0x8f) || !cont(i + 2, 0x80, 0xbf) || !cont(i + 3, 0x80, 0xbf)) return false; i += 4; }
    else return false;
  }
  return true;
};
const stripBoms = (text) => { let at = 0; while (text.charCodeAt(at) === 0xfeff) at += 1; return text.slice(at); };
const slowTail = (text, max) => {
  if (Buffer.byteLength(text, "utf8") <= max) return text;
  let lo = 0;
  let hi = text.length;
  while (lo < hi) { const mid = (lo + hi) >> 1; if (Buffer.byteLength(text.slice(mid), "utf8") <= max) hi = mid; else lo = mid + 1; }
  if (lo < text.length && text.charCodeAt(lo) >= 0xdc00 && text.charCodeAt(lo) <= 0xdfff) lo += 1;
  return text.slice(lo);
};
const BLANK_CODES = [9, 10, 11, 12, 13, 32, 0x85, 0xa0, 0x1680, 0x180e, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff];
for (let unit = 0x2000; unit <= 0x200a; unit += 1) BLANK_CODES.push(unit);
const blankOnly = (name) => { for (let i = 0; i < name.length; i += 1) if (BLANK_CODES.indexOf(name.charCodeAt(i)) < 0) return false; return true; };
const listOf = (known) => (Array.isArray(known) ? known : known.names);
const rawKnown = (known) => tidyNames(listOf(known).filter((name) => typeof name === "string")).filter((name) => !blankOnly(name));
const knownOverflow = (known) => !Array.isArray(known) && known.overflow === true;
const ledgerBad = (text, names, runs, gotText, cut) => {
  if (!Array.isArray(runs)) return ["장부(runs) 없음"];
  const bad = [];
  let rebuilt = "";
  let cursor = 0;
  let sound = true;
  for (const [start, end, rank] of runs) { if (!(start >= cursor && end > start && end <= text.length)) sound = false; rebuilt += text.slice(cursor, start) + MARK_OF_RANK[rank]; cursor = end; }
  rebuilt += text.slice(cursor);
  if (!sound) bad.push("장부가 어긋남");
  if ((cut === null ? rebuilt : slowTail(rebuilt, cut)) !== gotText) bad.push("장부로 다시 만든 글 ≠ 받은 글");
  for (const [start, end] of nameOccurrences(text, names)) if (!covered(runs, start, end)) { bad.push("알려진 이름의 원문 자리가 장부 밖"); break; }
  return bad;
};
const expected = (text, known) => {
  const found = MODEL.harvest(text, known);
  const names = [...new Set([...rawKnown(known), ...found.names])];
  const over = knownOverflow(known) || found.overflow;
  const whole = text.length === 0 ? { text: "", full: false } : over ? { text: MARK.FULL, full: true } : oracle(text, names);
  return { names, over, whole };
};
/** 서버 길 잣대 — 저장할 것(돌려준 글의 UTF-8)을 되읽은 글로(㉠). */
const serverBad = (bytes, known, out) => {
  const bad = [];
  const stored = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(enc(out.text));
  if (stored !== out.text) bad.push("저장 바이트를 읽은 글 ≠ 돌려준 글");
  if (out.path === "full" && stored !== MARK.FULL) bad.push("통째 가림이 상수가 아님");
  if (bytes.length === 0) return bad;
  if (!strictUtf8(bytes) || bytes.indexOf(0) >= 0) { if (out.path !== "full") bad.push("UTF-8 이 아니거나 0 바이트가 있는데 저장함"); return bad; }
  const text = stripBoms(Buffer.from(bytes).toString("utf8"));
  const want = expected(text, known);
  if (want.whole.full !== (out.path === "full") || (!want.whole.full && want.whole.text !== stored)) bad.push("저장 글 ≠ 독립 구현(" + show(want.whole.text) + " ↔ " + show(stored) + ")");
  if (out.overflow !== want.over) bad.push("넘침 표시가 다름");
  if (out.path === "text") {
    if (!stored.isWellFormed() || stored.indexOf("\u0000") >= 0) bad.push("저장 글에 짝 잃은 서러게이트·NUL");
    bad.push(...ledgerBad(text, want.names, out.runs, stored, null));
  }
  return bad;
};
/** 설치기 잣대 — 실제로 보낸 바이트로(㉠). sent = { bytes, text, full, overflow, runs } 또는 null. */
const installerBad = (file, known, sent, maxBytes) => {
  const bad = [];
  if (file.length === 0) { if (sent !== null) bad.push("빈 파일을 보냄"); return bad; }
  const readable = strictUtf8(file) && file.indexOf(0) < 0;
  const text = readable ? stripBoms(Buffer.from(file).toString("utf8")) : null;
  if (sent === null) { if (!(readable && text.length === 0)) bad.push("보내지 않음 — 머리표뿐인 온전한 UTF-8 파일이 아닌데"); return bad; }
  if (!strictUtf8(sent.bytes) || sent.bytes.indexOf(0) >= 0) { bad.push("보낸 바이트가 온전한 UTF-8·무 NUL 이 아님"); return bad; }
  const wire = Buffer.from(sent.bytes).toString("utf8");
  if (wire !== sent.text) bad.push("보낸 바이트를 읽은 글 ≠ 돌려준 글");
  if (sent.bytes.length > Math.max(maxBytes, 15)) bad.push("보낸 바이트가 상한을 넘음");
  if (text === null) { if (wire !== MARK.FULL) bad.push("엄격히 읽히지 않는 파일인데 통째 가림이 아님"); return bad; }
  if (text.length === 0) { bad.push("머리표뿐인 파일을 보냄"); return bad; }
  const want = expected(text, known);
  const wantText = want.whole.full ? MARK.FULL : slowTail(want.whole.text, maxBytes);
  if (wire !== wantText) bad.push("보낸 글 ≠ 독립 구현이 전체를 가린 뒤 자른 글");
  if (sent.overflow !== want.over) bad.push("넘침 표시가 다름");
  if (!want.whole.full && !sent.full) bad.push(...ledgerBad(text, want.names, sent.runs, wire, maxBytes));
  return bad;
};

// ── 무작위 생성기(모델 test.js 그대로 — 같은 조각 · 같은 뽑기 차례 · 서버 좌석 scrub-port.mjs 와 같은 씨앗) ──
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const pick = (r, list) => list[Math.floor(r() * list.length)];
const int = (r, lo, hi) => lo + Math.floor(r() * (hi - lo + 1));
const PIECES = ["/Users/", "/Users/", "C:\\Users\\", "c:/users/", "C:\\\\Users\\\\", "Bearer ", "bearer\t", "BEARER\u00a0", "sk-", "@", ".com", ".co.kr", ".", "~user", "~user", "~", "~",
  MARK.EMAIL, MARK.KEY, MARK.BEARER, MARK.FULL, " ", " ", " ", "\n", "\r\n", "/", "\\", "\"", "'", "<", ">", "a", "b", "r", "s", "x", "u", "e", "k", "rx", "rs", "user", "kim", "hong",
  "Hong", "Gil", "Dong", "abcdefgh12345678", "abcDEF1234567890", "0", "1", "7", "홍", "길", "동", "서연", "님", "\ufeff", "\u3000", "\u0085", "%", "=", ":", "-", "_", "+", "USER=", "HOME=", "\u0000", "\ud83d\ude00", "\ud83d", "\ude00", "\ufffd"];
const SPECIAL_NAMES = ["~user", "user", "r x", "rx", "rs", "~", "Bearer", "sk", "Users", "er", "지움", "토큰", "<", ">", "r~u", "/Users/", "C:", "@", ".", " ", "M0", "1", "a\u0000b", "\u0000", "", "\ud83d", "\ufffd", "\ude00x"];
function genGeneral(r) {
  let text = "";
  const count = int(r, 1, 28);
  for (let i = 0; i < count; i += 1) text += pick(r, PIECES);
  const names = [];
  const nameCount = int(r, 0, 5);
  const flat = text.split("\u0000").join("");
  for (let i = 0; i < nameCount; i += 1) {
    if (r() < 0.25 || flat.length === 0) names.push(pick(r, SPECIAL_NAMES));
    else { const start = int(r, 0, flat.length - 1); names.push(flat.slice(start, start + int(r, 1, 10))); }
  }
  return { text, names };
}
const PRIVATE = "QXZJ홍길동서연";
const PRIVATE_RE = /[QXZJ홍길동서연]/g;
const FILLER = ["log", "ok", "x", "r", "s", "user", "~user", "~", "er", " ", " ", " ", "\n", "/", ":", "=", ".", MARK.KEY, MARK.BEARER, MARK.EMAIL, "/Users/", "C:\\Users\\", "@", "a.co", "path", "님", " 입니다"];
function privateName(r) {
  let name = "";
  const len = int(r, 2, 6);
  for (let i = 0; i < len; i += 1) name += r() < 0.12 && i > 0 && i < len - 1 ? pick(r, [" ", ".", "~"]) : PRIVATE[Math.floor(r() * PRIVATE.length)];
  return name;
}
function genPrivate(r) {
  const names = [];
  const nameCount = int(r, 1, 4);
  for (let i = 0; i < nameCount; i += 1) names.push(privateName(r));
  const composites = [];
  if (r() < 0.7) {
    const a = pick(r, names);
    const k = int(r, 1, a.length - 1);
    const b = a.slice(a.length - k) + privateName(r);
    names.push(b);
    composites.push(a + b.slice(k));
    if (r() < 0.5) {
      const k2 = int(r, 1, b.length - 1);
      const c = b.slice(b.length - k2) + privateName(r);
      names.push(c);
      composites.push(a + b.slice(k) + c.slice(k2));
    }
  }
  if (r() < 0.3) names.push(pick(r, ["rx", "user", "r x", "er", "sk", "Bearer"]));
  const digits = () => { let d = ""; for (let i = 0; i < 10; i += 1) d += String(int(r, 0, 9)); return d; };
  let text = "";
  const count = int(r, 2, 24);
  for (let i = 0; i < count; i += 1) {
    const roll = r();
    if (roll < 0.3) text += pick(r, names.filter((name) => PRIVATE_RE.test(name) || true));
    else if (roll < 0.4 && composites.length > 0) text += pick(r, composites);
    else if (roll < 0.5) text += (r() < 0.8 ? " " : "") + pick(r, ["sk-" + digits(), "Bearer " + digits(), digits() + "@" + digits() + ".QQ", "/Users/" + pick(r, names), "C:\\Users\\" + pick(r, names)]);
    else text += pick(r, FILLER);
  }
  return { text, names };
}
const genBytes = (rand) => {
  const mode = rand();
  const made = mode < 0.5 ? genGeneral(rand) : genPrivate(rand);
  const text = made.text;
  let bytes;
  if (mode < 0.6) bytes = T.enc(text.toWellFormed());
  else if (mode < 0.7) bytes = T.join([0xef, 0xbb, 0xbf], T.enc(text.toWellFormed()));
  else if (mode < 0.8) bytes = T.u16(text, rand() < 0.5, rand() < 0.5);
  else { const raw = [...T.enc(text.toWellFormed())]; const edits = int(rand, 1, 3); for (let k = 0; k < edits && raw.length > 0; k += 1) { const at = int(rand, 0, raw.length - 1); if (rand() < 0.5) raw.splice(at, 1); else raw.splice(at, 0, pick(rand, [0x00, 0x80, 0xbf, 0xc0, 0xe3, 0xed, 0xff, 0xfe])); } bytes = Uint8Array.from(raw); }
  return { bytes, names: made.names };
};
const LABEL_BITS = ["USER=", "USERNAME: ", "HOME=/Users/", "USERPROFILE=C:\\Users\\", "whoami: ", "whoami> ", "LOGNAME=", "\nDESK-1\\", "\nZZ\\", "\r\n", "\n", "'", "\"", " ", "\t"];
function genLabelled(r) {
  const base = r() < 0.5 ? genGeneral(r) : genPrivate(r);
  let text = base.text;
  const lines = int(r, 0, 6);
  for (let i = 0; i < lines; i += 1) text += pick(r, LABEL_BITS) + pick(r, ["acct" + int(r, 0, 99), "q", "O'Brien", "Hong Gildong", "kim.dev", "  sp  ", "\"quoted\"", ...base.names.filter((name) => typeof name === "string")]) + pick(r, ["\n", "\r\n", "", " ok\n"]);
  const known = r() < 0.2 ? { names: base.names, overflow: r() < 0.2 } : base.names;
  return { text, known };
}

// ════ 일 만들기 ════
const v3 = JSON.parse(readFileSync(path.join(MD, "vectors-v3.json"), "utf8"));
const split = JSON.parse(readFileSync(path.join(MD, "vectors-split.json"), "utf8"));
const jobs = [];
const meta = new Map();
const job = (id, body, info) => { jobs.push({ id, ...body }); meta.set(id, info); };
for (const v of v3.vectors) job("v3:" + v.id, { op: "scrub", input: U(v.input), names: nameArg(v.names) }, { kind: "v3", v });
for (const v of split.harvest) job("h:" + v.id, { op: "harvest", input: U(v.input), known: nameArg(v.known) }, { kind: "harvest", v });
const FIELD_HARVEST = "(이 글에서 수확)";
const FIELD_KNOWN = "(이 글에서 수확 · 알려진 이름 ";
for (const v of split.field) {
  const body = { op: "field", input: U(v.text), opts: v.opts };
  if (v.names === FIELD_HARVEST) body.harvest = nameArg([]);
  else if (typeof v.names === "string" && v.names.startsWith(FIELD_KNOWN)) body.harvest = nameArg([JSON.parse(v.names.slice(FIELD_KNOWN.length, -1))]); // 이름 하나의 JSON(배열 아님 · 서버 인계 7절 함정)
  else if (typeof v.names === "string") { ok(false, "field " + v.id + " 이름 꼴을 모름", v.names); continue; }
  else body.names = nameArg(v.names);
  job("f:" + v.id, body, { kind: "field", v });
}
for (const v of split.server_attachment) job("s:" + v.id, { op: "server", hex: v.bytes_hex, known: nameArg(v.known) }, { kind: "server", v });
for (const v of split.installer_attachment) job("i:" + v.id, { op: "attach", hex: v.file_hex, known: nameArg(v.known), max: v.max_bytes, file: true }, { kind: "installer", v });
// 1R 발견 1 — 알려진 이름 원본(q · acct'77)을 본문 칸·첨부 둘 다에서(잣대가 원본을 따로 든다)
for (const [account, text] of [["q", "USERNAME=q\nstatus q ok\n"], ["acct'77", "USERNAME=acct'77\nstatus acct'77 ok\n"]]) {
  job("k1:field:" + account, { op: "field", input: U(text), harvest: nameArg([account]), opts: {} }, { kind: "known1", account, text });
  job("k1:attach:" + account, { op: "attach", hex: hex(enc(text)), known: nameArg([account]), max: 921600, file: true }, { kind: "known1a", account, text });
}
// 관문 2 무작위
const randomJobs = { core: [], field: [], attach: [] };
for (const [gen, seed] of [[genGeneral, 11160301], [genPrivate, 11160302]]) {
  const r = rng(seed);
  for (let i = 0; i < N; i += 1) { const { text, names } = gen(r); const id = "rc:" + gen.name + ":" + i; job(id, { op: "scrub", input: U(text), names: nameArg(names) }, { kind: "rcore", lane: "core-" + gen.name, i, text, names }); randomJobs.core.push(id); }
}
{
  const r = rng(11160303);
  for (let i = 0; i < N; i += 1) {
    const { text, known } = genLabelled(r);
    const cut = r() < 0.5 ? undefined : int(r, 0, 200);
    const keep = r() < 0.5 ? "tail" : "head";
    const opts = { keep }; if (cut !== undefined) opts.maxBytes = cut;
    const id = "rf:" + i;
    job(id, { op: "field", input: U(text), harvest: nameArg(known), opts }, { kind: "rfield", i, text, known, cut, keep });
  }
}
{
  const r = rng(11160304);
  for (let i = 0; i < N; i += 1) {
    const { bytes, names } = genBytes(r);
    const cap = int(r, 16, 400);
    job("ra:i:" + i, { op: "attach", hex: hex(bytes), known: nameArg(names), max: cap, file: false }, { kind: "rattach", i, bytes, names, cap });
    job("ra:s:" + i, { op: "server", hex: hex(bytes), known: nameArg(names) }, { kind: "rserver", i, bytes, names });
  }
}

// ════ 구동기 실행(pwsh 하나) ════
const work = KEEP ? KEEP : mkdtempSync(path.join(os.tmpdir(), "scrub-v3-win-"));
const jobsFile = path.join(work, "jobs.jsonl");
const outFile = path.join(work, "out.jsonl");
writeFileSync(jobsFile, jobs.map((j) => JSON.stringify(j)).join("\n") + "\n");
const started = Date.now();
const run = spawnSync(PWSH, ["-NoProfile", ...(process.platform === "win32" ? ["-ExecutionPolicy", "Bypass"] : []), "-File", path.join(here, "scrub-v3-win-driver.ps1"), "-Dir", DIR, "-Jobs", jobsFile, "-Out", outFile], { encoding: "utf8", maxBuffer: 1 << 26 });
const seconds = ((Date.now() - started) / 1000).toFixed(1);
if (run.status !== 0 || !existsSync(outFile)) { console.log(run.stdout); console.log(run.stderr); console.log("RESULT: FAIL — 구동기 rc " + run.status); process.exit(2); }
const outs = new Map();
for (const line of readFileSync(outFile, "utf8").split("\n")) { if (line.trim()) { const o = JSON.parse(line); outs.set(o.id, o); } }
say("구동기(" + PWSH + " · " + DIR + "): 일 " + jobs.length + " · 답 " + outs.size + " · " + seconds + "초");
const runsOf = (list) => (list === null || list === undefined ? list : list.map((x) => [x[0], x[1], x[2]]));
const scrubOut = (o) => ({ text: D(o.text), full: o.full, reason: o.reason, runs: runsOf(o.runs), marks: runsOf(o.marks), rescans: o.rescans, work: o.work });
const sentOut = (o) => (o === null ? null : { bytes: hexBytes(o.hex), hex: o.hex, text: D(o.text), full: o.full, reason: o.reason, names: o.names.map((x) => (typeof x === "string" ? D(x) : x)), overflow: o.overflow, runs: runsOf(o.runs) });
const answer = (id) => { const o = outs.get(id); if (!o) { ok(false, id + " 답 없음"); return null; } if (o.error) { ok(false, id + " 구동기 오류", o.error); return null; } return o; };

// ════ 관문 1 ════
const gate1 = { v3: [0, 0], harvest: [0, 0], field: [0, 0], server: [0, 0], installer: [0, 0], file: [0, 0] };
const tally = (key, cond) => { gate1[key][1] += 1; if (cond) gate1[key][0] += 1; return cond; };
const clockOf = (values) => { let k = 0; return () => { const value = values[Math.min(k, values.length - 1)]; k += 1; return value; }; };
for (const [id, info] of meta) {
  if (!["v3", "harvest", "field", "server", "installer", "known1", "known1a"].includes(info.kind)) continue;
  const o = answer(id);
  if (o === null) { if (info.kind !== "known1" && info.kind !== "known1a") tally(info.kind, false); continue; }
  const v = info.v;
  if (info.kind === "v3") {
    const got = scrubOut(o.out);
    const bad = violationsOf(v.input, v.names, got);
    tally("v3", ok(got.text === v.expected && JSON.stringify(got.marks) === JSON.stringify(v.marks) && bad.size === 0, "v3 " + v.id, show(got.text) + " ↔ " + show(v.expected) + " " + [...bad].join(",")));
  } else if (info.kind === "harvest") {
    const names = o.out.names.map(D);
    tally("harvest", ok(sameSet(names, v.names) && o.out.overflow === v.overflow, "harvest " + v.id, JSON.stringify(names) + " " + o.out.overflow));
  } else if (info.kind === "field") {
    const e = v.expected;
    const got = o.out;
    tally("field", ok(D(got.text) === e.text && got.full === e.full && got.reason === e.reason && got.truncated === e.truncated, "field " + v.id, JSON.stringify([show(D(got.text)), got.full, got.reason, got.truncated])));
  } else if (info.kind === "server") {
    const e = v.expected;
    const got = { path: o.out.path, text: D(o.out.text), reason: o.out.reason, names: o.out.names.map((x) => (typeof x === "string" ? D(x) : x)), overflow: o.out.overflow, runs: runsOf(o.out.runs) };
    const bytes = hexBytes(v.bytes_hex);
    const bad = serverBad(bytes, v.known, got);
    tally("server", ok(got.path === e.path && got.reason === e.reason && got.text === e.text && sameSet(got.names, e.names) && got.overflow === e.overflow && bad.length === 0, "server " + v.id, JSON.stringify([got.path, got.reason, show(got.text)]) + " " + bad.join(" · ")));
  } else if (info.kind === "installer") {
    const e = v.expected;
    const file = hexBytes(v.file_hex);
    const got = sentOut(o.out);
    const bad = installerBad(file, v.known, got, v.max_bytes);
    const same = e === null ? got === null : got !== null && got.full === e.full && got.reason === e.reason && got.text === e.sent_text && got.hex === e.sent_hex && sameSet(got.names, e.names) && got.overflow === e.overflow;
    tally("installer", ok(same && bad.length === 0, "installer " + v.id, JSON.stringify(got === null ? null : [got.full, got.reason, show(got.text)]) + " " + bad.join(" · ")));
    // 실제 파일 길(Get-ScrubbedTextBytes) — 보낸 바이트 = 기대 바이트(null = 보내지 않음)
    tally("file", ok(e === null ? o.file === null : o.file === e.sent_hex, "installer 파일 길 " + v.id, String(o.file).slice(0, 80) + " ↔ " + (e === null ? "null" : e.sent_hex.slice(0, 80))));
  } else if (info.kind === "known1") {
    ok(D(o.out.text) === "USERNAME=~user\nstatus ~user ok\n", "1R 발견 1 본문 칸 원본 이름 " + info.account, show(D(o.out.text)));
  } else if (info.kind === "known1a") {
    const got = sentOut(o.out);
    const wire = got === null ? null : Buffer.from(got.bytes).toString("utf8");
    const fileWire = o.file === null ? null : Buffer.from(hexBytes(o.file)).toString("utf8");
    ok(wire === "USERNAME=~user\nstatus ~user ok\n" && fileWire === wire && installerBad(enc(info.text), [info.account], got, 921600).length === 0, "1R 발견 1 첨부(바이트·파일 길) 원본 이름 " + info.account, show(wire) + " / " + show(fileWire));
  }
}
const g1 = ["v3", "harvest", "field", "server", "installer"].reduce((a, k) => [a[0] + gate1[k][0], a[1] + gate1[k][1]], [0, 0]);
say("관문 1 — 공용 벡터 " + g1[0] + "/" + g1[1] + " (가림 " + gate1.v3.join("/") + " · 수확 " + gate1.harvest.join("/") + " · 칸 처리 " + gate1.field.join("/") + " · 서버 첨부(이 구현 부품 조합) " + gate1.server.join("/") + " · 설치기 첨부 " + gate1.installer.join("/") + ") · 설치기 파일 길 " + gate1.file.join("/"));

// ════ 관문 2 ════
const gate2 = { core: [0, 0, 0], field: [0, 0, 0], attach: [0, 0, 0] };
const jsonl = [];
for (const [id, info] of meta) {
  if (info.kind === "rcore") {
    const o = answer(id); gate2.core[1] += 1; if (o === null) continue;
    const mine = scrubOut(o.out);
    const model = MODEL.scrubV3(info.text, info.names);
    const same = mine.text === model.text && mine.full === model.full && mine.reason === model.reason && JSON.stringify(mine.runs) === JSON.stringify(model.runs) && JSON.stringify(mine.marks) === JSON.stringify(model.marks);
    if (ok(same, "무작위 core " + info.lane + " #" + info.i, show(info.text) + " " + JSON.stringify(info.names) + " → " + show(mine.text) + " ↔ " + show(model.text))) gate2.core[0] += 1;
    const bad = violationsOf(info.text, info.names, mine);
    if (bad.size > 0) { gate2.core[2] += 1; ok(false, "무작위 core 성질 " + info.lane + " #" + info.i, [...bad].join(",") + " " + show(info.text)); }
    jsonl.push(JSON.stringify({ lane: info.lane, i: info.i, input: info.text, names: info.names, text: mine.text, full: mine.full, reason: mine.reason }));
  } else if (info.kind === "rfield") {
    const o = answer(id); gate2.field[1] += 1; if (o === null) continue;
    const mineSet = { names: o.set.names.map(D), overflow: o.set.overflow };
    const modelSet = MODEL.harvest(info.text, info.known);
    const mine = { text: D(o.out.text), full: o.out.full, reason: o.out.reason, truncated: o.out.truncated, runs: runsOf(o.out.runs) };
    const model = MODEL.scrubField(info.text, modelSet, { maxBytes: info.cut, keep: info.keep });
    const same = JSON.stringify(mineSet) === JSON.stringify(modelSet) && mine.text === model.text && mine.full === model.full && mine.reason === model.reason && mine.truncated === model.truncated && JSON.stringify(mine.runs) === JSON.stringify(model.runs);
    if (ok(same, "무작위 field #" + info.i, show(info.text) + " → " + show(mine.text) + " ↔ " + show(model.text))) gate2.field[0] += 1;
    // 칸의 성질: 자르기 전 전체 가림이 violations() 를 지키는가(이 구현의 장부로) · 원본 이름의 모든 자리가 장부 안인가(㉡)
    if (!mine.full && Array.isArray(mine.runs)) {
      const t = tidy(info.text);
      const whole = { text: "", full: false, runs: mine.runs, marks: [], rescans: 0, work: 0 };
      let rebuilt = ""; let cursor = 0;
      for (const [s, e, rk] of mine.runs) { rebuilt += t.slice(cursor, s); whole.marks.push([rebuilt.length, rebuilt.length + MARK_OF_RANK[rk].length, rk]); rebuilt += MARK_OF_RANK[rk]; cursor = e; }
      whole.text = rebuilt + t.slice(cursor);
      const bad = violationsOf(info.text, mineSet.names, whole);
      bad.delete("P6"); // 걸음 수는 칸 결과에 실리지 않는다(core 갈래가 잰다)
      const cutOk = info.cut === undefined ? whole.text === mine.text : (info.keep === "head" ? whole.text.startsWith(mine.text) : whole.text.endsWith(mine.text)) && Buffer.byteLength(mine.text, "utf8") <= info.cut;
      if (bad.size > 0 || !cutOk) { gate2.field[2] += 1; ok(false, "무작위 field 성질 #" + info.i, [...bad].join(",") + " cut=" + cutOk); }
      for (const [start, end] of nameOccurrences(t, rawKnown(info.known))) if (!covered(mine.runs, start, end)) { gate2.field[2] += 1; ok(false, "무작위 field 원본 이름 #" + info.i, show(info.text)); break; }
    }
  } else if (info.kind === "rattach") {
    const o = answer(id); const os2 = answer("ra:s:" + info.i); gate2.attach[1] += 1; if (o === null || os2 === null) continue;
    const sentMine = sentOut(o.out);
    const sentModel = MODEL.installerAttachment(info.bytes, info.names, { maxBytes: info.cap });
    const sameSent = sentModel === null ? sentMine === null : sentMine !== null && sentMine.text === sentModel.text && sentMine.hex === hex(sentModel.bytes) && sentMine.reason === sentModel.reason && JSON.stringify(sentMine.names) === JSON.stringify(sentModel.names) && sentMine.overflow === sentModel.overflow;
    const mineS = { path: os2.out.path, text: D(os2.out.text), reason: os2.out.reason, names: os2.out.names.map((x) => (typeof x === "string" ? D(x) : x)), overflow: os2.out.overflow, runs: runsOf(os2.out.runs) };
    const modelS = MODEL.serverAttachment(info.bytes, info.names);
    const sameS = mineS.path === modelS.path && mineS.text === modelS.text && mineS.reason === modelS.reason && JSON.stringify(mineS.names) === JSON.stringify(modelS.names) && mineS.overflow === modelS.overflow;
    if (ok(sameSent && sameS, "무작위 attach #" + info.i, hex(info.bytes).slice(0, 60) + " → " + show(sentMine && sentMine.text) + " ↔ " + show(sentModel && sentModel.text) + " | " + show(mineS.text) + " ↔ " + show(modelS.text))) gate2.attach[0] += 1;
    const bad = [...installerBad(info.bytes, info.names, sentMine, info.cap), ...serverBad(info.bytes, info.names, mineS)];
    if (bad.length > 0) { gate2.attach[2] += 1; ok(false, "무작위 attach 잣대 #" + info.i, bad.join(" · ")); }
  }
}
say("관문 2 — 무작위(씨앗 11160301~04): core " + gate2.core[0] + "/" + gate2.core[1] + " 같음 · 성질 위반 " + gate2.core[2]
  + " | field " + gate2.field[0] + "/" + gate2.field[1] + " · 위반 " + gate2.field[2]
  + " | attach " + gate2.attach[0] + "/" + gate2.attach[1] + " · 잣대 위반 " + gate2.attach[2]);
if (JSONL) { writeFileSync(JSONL, jsonl.join("\n") + "\n"); say("JSONL " + jsonl.length + "줄 → " + JSONL); }
// 세 구현 맞대기 — 서버 좌석의 JSONL 과 줄마다(같은 입력인가 · 같은 답인가)
if (SERVER_JSONL) {
  const theirs = readFileSync(SERVER_JSONL, "utf8").split("\n").filter((x) => x.trim()).map((x) => JSON.parse(x));
  let sameInput = 0; let sameOut = 0; let differ = 0;
  const mine = jsonl.map((x) => JSON.parse(x));
  for (let k = 0; k < Math.max(mine.length, theirs.length); k += 1) {
    const a = mine[k]; const b = theirs[k];
    if (!a || !b) { differ += 1; continue; }
    if (a.lane === b.lane && a.i === b.i && a.input === b.input && JSON.stringify(a.names) === JSON.stringify(b.names)) sameInput += 1;
    if (a.text === b.text && a.full === b.full && a.reason === b.reason) sameOut += 1; else { differ += 1; ok(false, "서버 JSONL 맞대기 " + a.lane + " #" + a.i, show(a.text) + " ↔ " + show(b.text)); }
  }
  say("서버 JSONL 맞대기 — 줄 " + mine.length + " ↔ " + theirs.length + " · 같은 입력 " + sameInput + " · 같은 답 " + sameOut + " · 차이 " + differ);
}
if (!KEEP) rmSync(work, { recursive: true, force: true });
for (const line of fails) say(line);
say(failed === 0 ? "RESULT: PASS — 실패 0" : "RESULT: FAIL — 실패 " + failed);
process.exitCode = failed === 0 ? 0 : 1;
