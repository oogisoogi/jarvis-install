// TICKET=scrub-v3-port-1116 · ROLE=mac — 맥 설치기(bootstrap.sh 의 JXA REMOTE_HELP_JS) 가림 v3 포팅을 참조 모델에 맞댄다.
//
//   node tests/scrub-v3-mac.mjs [--n 6000] [--jsonl <파일>] [--decode 200000] [--quiet]      · rc 0 = 전건 통과
//   (SCRUB_SH=<bootstrap.sh 사본> 이면 그 사본을 잰다 — 뮤턴트 러너 tests/scrub-v3-mac-mutants.mjs 가 쓴다)
//
// 실물 엔진에서 잰다: bootstrap.sh 에서 REMOTE_HELP_JS 를 그대로 떼어 **/usr/bin/osascript -l JavaScript**(JavaScriptCore)로 한 번에 돌린다
//   — 시험용으로 덧붙이는 것은 끝의 run() 하나(입력 파일을 읽어 제품 함수를 부르고 결과를 파일로 적는다)뿐이다.
// 관문 1   공용 벡터(tests/scrub-v3/model/ = split/model 의 바이트 사본 · vectors-v3.json 84 + vectors-split.json 77) — 글은 코드 단위로(JS 글자열 같음 · UTF-8 해시 아님)
//          · expected.names 는 집합으로 · 설치기 답 null = 보내지 않음. 서버 첨부 22건은 맥 설치기에 그 경로가 없어 잴 대상이 아니다(서버 좌석 몫) → 맥 = 84 + 19 + 18 + 18 = 139.
// 관문 1-1 잣대(model/test.js G 절 · 서버 좌석 scrub-port.mjs 의 serverBad·installerBad·ledgerBad 를 그대로 옮김): ㉠ 설치기가 **실제로 적은 파일의 바이트**를
//          UTF-8 로 읽은 글 ㉡ 알려진 이름 원본을 구현과 따로 들고 원문의 모든 자리가 장부 안인가 ㉢ 구현이 돌려준 장부(runs·marks) — 모델을 다시 돌려 얻지 않는다.
// 관문 2   씨앗 고정 무작위(모델 test.js 의 genGeneral·genPrivate · 서버 좌석과 같은 씨앗·같은 뽑기 차례 11160301~04) — 모델과 결과 글 코드 단위 차이 0 +
//          결과마다 violations()(느린 독립 오라클 P13 포함). --jsonl = 서버 좌석과 같은 줄 꼴 {lane, i, input, names, text, full, reason}.
// 관문 4m  NSString(NSUTF8StringEncoding) 엄격 읽기 대 TextDecoder('utf-8',{fatal:true}) 차등(무작위 + 1·2바이트 전수 · 파일 읽기 표본).
import { createRequire } from "node:module";
import { readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import os from "node:os";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const MODEL = {
  ...require("./scrub-v3/model/scrub-v3.js"),
  ...require("./scrub-v3/model/harvest.js"),
  ...require("./scrub-v3/model/pipeline.js"),
  ...require("./scrub-v3/model/attach-strict.js"),
};
const T = require("./scrub-v3/model/attach-table.js");
const SH = process.env.SCRUB_SH ? path.resolve(process.env.SCRUB_SH) : path.join(here, "..", "install-master", "bootstrap.sh");

const args = process.argv.slice(2);
const argOf = (flag, fallback) => { const at = args.indexOf(flag); return at >= 0 ? args[at + 1] : fallback; };
const N = Number(argOf("--n", "6000"));
const NDEC = Number(argOf("--decode", "200000"));
const JSONL = argOf("--jsonl", null);
const QUIET = args.includes("--quiet");

let failed = 0;
const fails = [];
const say = (line) => { if (!QUIET) console.log(line); };
const ok = (cond, label, detail) => {
  if (!cond) { failed += 1; if (fails.length < 40) fails.push("  ✗ " + label + (detail ? " — " + detail : "")); }
  return cond;
};
const show = (text) => { const s = JSON.stringify(text); return s === undefined ? String(text) : s.length > 90 ? s.slice(0, 60) + "…(" + String(text).length + "자)" : s; };
const { MARK, MARK_OF_RANK, LIMITS, RULE_SOURCES, RANK } = MODEL;
const enc = (text) => new TextEncoder().encode(text);
const hexBytes = (hex) => Uint8Array.from(hex.match(/../g) ?? [], (h) => parseInt(h, 16));
const hex = (bytes) => Buffer.from(bytes).toString("hex");
const sameSet = (a, b) => a.length === b.length && new Set(a).size === new Set([...a, ...b]).size;

// ════ JXA 쪽 — 제품 글(REMOTE_HELP_JS) + 시험용 run() ════
const shText = readFileSync(SH, "utf8");
const begin = shText.indexOf("IFS= read -r -d '' REMOTE_HELP_JS <<'EOF_REMOTE_HELP_JS'");
const jsStart = shText.indexOf("\n", begin) + 1;
const jsEnd = shText.indexOf("\nEOF_REMOTE_HELP_JS\n", jsStart);
if (begin < 0 || jsEnd < 0) { console.log("REMOTE_HELP_JS 를 찾지 못함: " + SH); process.exit(2); }
const PRODUCT_JS = shText.slice(jsStart, jsEnd + 1);
const DRIVER = String.raw`
function run(argv) {
  var job = JSON.parse(readText(argv[0]));
  var out = job.cases.map(function (c) {
    try {
      if (c.op === "v3") return scrubV3(c.input, c.names);
      if (c.op === "harvest") return harvest(c.input, c.known);
      if (c.op === "field") {
        var names = c.harvest ? harvest(c.text, c.known) : c.names;
        var opts = {};
        ["maxBytes", "keep", "unitsMax", "budgetMs"].forEach(function (key) { if (c.opts[key] !== undefined) opts[key] = c.opts[key]; });
        if (c.opts.clockValues) { var k = 0; var values = c.opts.clockValues; opts.clock = function () { var v = values[Math.min(k, values.length - 1)]; k += 1; return v === "NaN" ? NaN : v; }; }
        var got = scrubField(c.text, names, opts);
        got.set = c.harvest ? names : null;
        return got;
      }
      if (c.op === "attach") {
        var sent = attachmentFromFile(c.path, c.known, c.max, c.unitsMax === undefined ? undefined : { unitsMax: c.unitsMax });
        if (sent !== null) writeText(c.out, sent.text);   // 제품 modeScrubFile 과 같은 쓰기(writeText · UTF-8)
        return sent;
      }
      if (c.op === "decode") { var bytes = base64Bytes(c.b64, c.n); return bytes === null ? { thrown: "base64" } : utf8StrictDecode(bytes); }   // 제품의 손 디코더
      if (c.op === "nsdecode") {   // 관측만(제품은 쓰지 않는다): NSString 의 UTF-8 읽기
        var s = $.NSString.alloc.initWithDataEncoding($.NSData.alloc.initWithBase64EncodedStringOptions(c.b64, 0), $.NSUTF8StringEncoding);
        return s.isNil() ? null : ObjC.unwrap(s);
      }
      if (c.op === "readfile") return readStrictUtf8File(c.path);   // 제품의 파일 읽기(NSData → base64 → 손 디코더)
      return { thrown: "op" };
    } catch (error) { return { thrown: String(error) }; }
  });
  writeText(argv[1], JSON.stringify(out));
  return "DONE " + out.length;
}
`;
const work = mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), "scrub-v3-mac-"));
const driverPath = path.join(work, "driver.js");
writeFileSync(driverPath, PRODUCT_JS + DRIVER);
let jobNo = 0;
function runJxa(cases) {
  jobNo += 1;
  const jobPath = path.join(work, "job" + jobNo + ".json");
  const outPath = path.join(work, "out" + jobNo + ".json");
  writeFileSync(jobPath, JSON.stringify({ cases }));
  const said = execFileSync("/usr/bin/osascript", ["-l", "JavaScript", driverPath, jobPath, outPath], { encoding: "utf8", maxBuffer: 1 << 26, stdio: ["ignore", "pipe", "pipe"] }).trim();
  if (said !== "DONE " + cases.length) throw new Error("JXA 답이 이상함: " + said.slice(0, 200));
  const results = JSON.parse(readFileSync(outPath, "utf8"));
  rmSync(jobPath); rmSync(outPath);
  return results;
}
const fileNo = { n: 0 };
function attachCase(fileBytes, known, max, unitsMax) {
  fileNo.n += 1;
  const dir = path.join(work, "f");
  if (!existsSync(dir)) mkdirSync(dir);
  const p = path.join(dir, "in" + fileNo.n);
  writeFileSync(p, Buffer.from(fileBytes));
  return { op: "attach", path: p, out: p + ".sent", known, max, unitsMax };
}
/** JXA 의 첨부 결과 + 실제로 적힌 바이트(㉠). null = 보내지 않음(그때 적힌 파일도 없어야 한다). */
function sentOf(c, r) {
  if (r === null) return existsSync(c.out) ? { bogus: "보내지 않는다면서 파일을 적음" } : null;
  if (!existsSync(c.out)) return { ...r, bytes: new Uint8Array(0), bogus: "보낸다면서 파일이 없음" };
  return { ...r, bytes: new Uint8Array(readFileSync(c.out)) };
}

// ── 잣대(model/test.js G 절 · 오라클과 성질 검사 — 구현과 공유하는 것은 규칙 원문과 표식뿐) ──
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
/** test.js violations() — 이 포팅이 돌려준 결과에(㉢ · 모델 재실행 없음). 어긴 성질을 돌려준다. */
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
// 손으로 짠 엄격한 UTF-8 검사(유니코드 표 3-7) — 포팅이 쓰는 NSString 과 다른 수단
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
/** 기대 = 따로 든 이름 원본 ∪ 표시 줄 이름(그 부분은 모델 수확을 쓴다 — 잣대의 한계 L13). */
const expected = (text, known) => {
  const found = MODEL.harvest(text, known);
  const names = [...new Set([...rawKnown(known), ...found.names])];
  const over = knownOverflow(known) || found.overflow;
  const whole = text.length === 0 ? { text: "", full: false } : over ? { text: MARK.FULL, full: true } : oracle(text, names);
  return { names, over, whole };
};
/** 설치기 잣대 — 실제로 적힌(보낸) 바이트로(㉠). */
const installerBad = (file, known, sent, maxBytes) => {
  const bad = [];
  if (sent !== null && sent.bogus) bad.push(sent.bogus);
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
  if (wire !== wantText) bad.push("보낸 글 ≠ 독립 구현이 전체를 가린 뒤 자른 글(" + show(wantText) + " ↔ " + show(wire) + ")");
  if (sent.overflow !== want.over) bad.push("넘침 표시가 다름");
  if (!want.whole.full && !sent.full) bad.push(...ledgerBad(text, want.names, sent.runs, wire, maxBytes));
  return bad;
};

// ════ 관문 1 — 공용 벡터 ════
const v3 = JSON.parse(readFileSync(path.join(here, "scrub-v3", "model", "vectors-v3.json"), "utf8"));
const split = JSON.parse(readFileSync(path.join(here, "scrub-v3", "model", "vectors-split.json"), "utf8"));
const g1cases = [];
for (const v of v3.vectors) g1cases.push({ op: "v3", input: v.input, names: v.names });
for (const v of split.harvest) g1cases.push({ op: "harvest", input: v.input, known: v.known });
for (const v of split.field) {
  const c = { op: "field", text: v.text, opts: v.opts };
  if (v.names === "(이 글에서 수확)") { c.harvest = true; c.known = []; }
  else if (typeof v.names === "string" && v.names.startsWith("(이 글에서 수확 · 알려진 이름 ")) { c.harvest = true; c.known = [JSON.parse(v.names.slice("(이 글에서 수확 · 알려진 이름 ".length, -1))]; } // gen-split-vectors.js 는 이름 하나를 JSON.stringify 로 적는다(배열이 아님 · 서버 좌석 함정 1)
  else if (typeof v.names === "string") { c.unknownForm = v.names; }
  else c.names = v.names;
  g1cases.push(c);
}
for (const v of split.installer_attachment) g1cases.push(attachCase(hexBytes(v.file_hex), v.known, v.max_bytes));
// 맥 고유 덧붙임(벡터 밖 · 기대 = 잣대 installerBad 와 모델): 엄격 읽기의 경계 바이트 — NSString 이 받아 주는 41 A9 꼴 · ED A0 80(서러게이트 부호값) · C0 80(넘친 꼴) · F4 90 80 80 · 잘린 꼴
const EDGE_FILES = ["41a9", "a9", "0aa90a", "41eda08042", "41edbfbf42", "41ed9fbf42", "41c08042", "41f490808042", "41f48fbfbf42", "41e0809f42", "41e0a08042", "41e2", "41f09f98", "c2", "efbbbfa9"];
for (const h of EDGE_FILES) g1cases.push(attachCase(hexBytes(h + "0a") , ["hongtester"], 921600));
// 1R 발견 1 손 재현(㉡ — 계정 q · acct'77 이 본문 칸과 첨부 둘 다에서 원문 자리 전부 가려지는가)
const F1 = [["q", "USERNAME=q\nstatus q ok\n"], ["acct'77", "USERNAME=acct'77\nstatus acct'77 ok\n"]];
for (const [account, text] of F1) { g1cases.push({ op: "field", text, opts: {}, harvest: true, known: [account] }); g1cases.push(attachCase(enc(text), [account], 921600)); }
const g1 = runJxa(g1cases);
const gate1 = { v3: [0, 0], harvest: [0, 0], field: [0, 0], installer: [0, 0] };
const tally = (key, cond) => { gate1[key][1] += 1; if (cond) gate1[key][0] += 1; return cond; };
let k1 = 0;
for (const v of v3.vectors) {
  const got = g1[k1++];
  const bad = got && !got.thrown ? violationsOf(v.input, v.names, got) : new Set(["THROW"]);
  tally("v3", ok(got && got.text === v.expected && JSON.stringify(got.marks) === JSON.stringify(v.marks) && bad.size === 0, "v3 " + v.id, show(got && got.text) + " ↔ " + show(v.expected) + " " + [...bad].join(",")));
}
for (const v of split.harvest) {
  const got = g1[k1++];
  tally("harvest", ok(got && Array.isArray(got.names) && sameSet(got.names, v.names) && got.overflow === v.overflow, "harvest " + v.id, JSON.stringify(got)));
}
for (const v of split.field) {
  const got = g1[k1++];
  const e = v.expected;
  tally("field", ok(got && got.text === e.text && got.full === e.full && got.reason === e.reason && got.truncated === e.truncated, "field " + v.id, JSON.stringify(got && [show(got.text), got.full, got.reason, got.truncated, got.thrown])));
}
for (const v of split.installer_attachment) {
  const c = g1cases[k1];
  const sent = sentOf(c, g1[k1++]);
  const file = hexBytes(v.file_hex);
  const e = v.expected;
  const bad = installerBad(file, v.known, sent, v.max_bytes);
  const same = e === null ? sent === null : sent !== null && sent.full === e.full && sent.reason === e.reason && sent.text === e.sent_text && hex(sent.bytes) === e.sent_hex && sameSet(sent.names, e.names) && sent.overflow === e.overflow;
  tally("installer", ok(same && bad.length === 0, "installer " + v.id, JSON.stringify(sent === null ? null : [sent.full, sent.reason, show(sent.text), sent.thrown]) + " " + bad.join(" · ")));
}
let edgeOk = 0;
for (const h of EDGE_FILES) {
  const c = g1cases[k1];
  const sent = sentOf(c, g1[k1++]);
  const file = hexBytes(h + "0a");
  const model = MODEL.installerAttachment(file, ["hongtester"], { maxBytes: 921600 });
  const bad = installerBad(file, ["hongtester"], sent, 921600);
  const same = model === null ? sent === null : sent !== null && sent.text === model.text && hex(sent.bytes) === hex(model.bytes) && sent.reason === model.reason;
  if (ok(same && bad.length === 0, "맥 경계 바이트 " + h, JSON.stringify(sent && [sent.reason, show(sent.text)]) + " ↔ " + JSON.stringify(model && [model.reason, show(model.text)]) + " " + bad.join(" · "))) edgeOk += 1;
}
for (const [account, text] of F1) {
  const body = g1[k1++];
  const c = g1cases[k1];
  const sent = sentOf(c, g1[k1++]);
  const wire = sent && sent.bytes ? Buffer.from(sent.bytes).toString("utf8") : null;
  ok(body.text === "USERNAME=~user\nstatus ~user ok\n" && wire === body.text && installerBad(enc(text), [account], sent, 921600).length === 0, "1R 발견 1 원본 이름 " + account, show(body.text) + " / " + show(wire));
}
const total1 = Object.values(gate1).reduce((a, [p, n]) => [a[0] + p, a[1] + n], [0, 0]);
say("관문 1 — 공용 벡터 " + total1[0] + "/" + total1[1] + " (가림 " + gate1.v3.join("/") + " · 수확 " + gate1.harvest.join("/") + " · 칸 처리 " + gate1.field.join("/") + " · 설치기 첨부 " + gate1.installer.join("/") + " · 서버 첨부 22 = 맥에 없는 경로) + 1R 발견 1 손 재현 2×2 + 맥 경계 바이트 첨부 " + edgeOk + "/" + EDGE_FILES.length);

// ════ 관문 2 — 씨앗 고정 무작위 · 모델과 차등 + violations() ════
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
// genGeneral · genPrivate — 모델 test.js 에서 그대로(같은 조각 · 같은 뽑기)
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
  if (mode < 0.6) bytes = enc(text.toWellFormed());
  else if (mode < 0.7) bytes = T.join([0xef, 0xbb, 0xbf], enc(text.toWellFormed()));
  else if (mode < 0.8) bytes = T.u16(text, rand() < 0.5, rand() < 0.5);
  else { const raw = [...enc(text.toWellFormed())]; const edits = int(rand, 1, 3); for (let k = 0; k < edits && raw.length > 0; k += 1) { const at = int(rand, 0, raw.length - 1); if (rand() < 0.5) raw.splice(at, 1); else raw.splice(at, 0, pick(rand, [0x00, 0x80, 0xbf, 0xc0, 0xe3, 0xed, 0xff, 0xfe])); } bytes = Uint8Array.from(raw); }
  return { bytes, names: made.names };
};
// 표시 줄을 섞은 글(서버 좌석 scrub-port.mjs genLabelled 와 같은 뽑기 — 수확 길이 USER=·whoami·DOMAIN 줄·따옴표·되풀이를 본다)
const LABEL_BITS = ["USER=", "USERNAME: ", "HOME=/Users/", "USERPROFILE=C:\\Users\\", "whoami: ", "whoami> ", "LOGNAME=", "\nDESK-1\\", "\nZZ\\", "\r\n", "\n", "'", "\"", " ", "\t"];
function genLabelled(r) {
  const base = r() < 0.5 ? genGeneral(r) : genPrivate(r);
  let text = base.text;
  const lines = int(r, 0, 6);
  for (let i = 0; i < lines; i += 1) text += pick(r, LABEL_BITS) + pick(r, ["acct" + int(r, 0, 99), "q", "O'Brien", "Hong Gildong", "kim.dev", "  sp  ", "\"quoted\"", ...base.names.filter((name) => typeof name === "string")]) + pick(r, ["\n", "\r\n", "", " ok\n"]);
  const known = r() < 0.2 ? { names: base.names, overflow: r() < 0.2 } : base.names;
  return { text, known };
}

const gate2 = { core: [0, 0, 0], field: [0, 0, 0], attach: [0, 0, 0] }; // [같음, 전체, 위반]
const jsonl = [];
// lane core — 가림 함수 그 자체(genGeneral 씨앗 11160301 · genPrivate 씨앗 11160302 · 각 N)
const coreInputs = [];
for (const [gen, seed] of [[genGeneral, 11160301], [genPrivate, 11160302]]) {
  const r = rng(seed);
  for (let i = 0; i < N; i += 1) { const { text, names } = gen(r); coreInputs.push({ lane: "core-" + gen.name, i, text, names }); }
}
// lane field — 수확(알려진 이름 포함) + 칸 처리 + 무작위 자르기(씨앗 11160303)
const fieldInputs = [];
{
  const r = rng(11160303);
  for (let i = 0; i < N; i += 1) {
    const { text, known } = genLabelled(r);
    const cut = r() < 0.5 ? undefined : int(r, 0, 200);
    const keep = r() < 0.5 ? "tail" : "head";
    fieldInputs.push({ i, text, known, cut, keep });
  }
}
// lane attach — 설치기 첨부(파일 바이트 · 씨앗 11160304 · 서버 좌석과 같은 뽑기 차례: genBytes 다음 cap)
const attachInputs = [];
{
  const r = rng(11160304);
  for (let i = 0; i < N; i += 1) { const { bytes, names } = genBytes(r); const cap = int(r, 16, 400); attachInputs.push({ i, bytes, names, cap }); }
}
const g2cases = [
  ...coreInputs.map((x) => ({ op: "v3", input: x.text, names: x.names })),
  ...fieldInputs.map((x) => ({ op: "field", text: x.text, harvest: true, known: x.known, opts: { maxBytes: x.cut, keep: x.keep } })),
  ...attachInputs.map((x) => attachCase(x.bytes, x.names, x.cap)),
];
const t2 = Date.now();
const g2 = runJxa(g2cases);
const jxaMs = Date.now() - t2;
let k2 = 0;
for (const x of coreInputs) {
  const mine = g2[k2++];
  const model = MODEL.scrubV3(x.text, x.names);
  const same = mine && mine.text === model.text && mine.full === model.full && mine.reason === model.reason && JSON.stringify(mine.runs) === JSON.stringify(model.runs) && JSON.stringify(mine.marks) === JSON.stringify(model.marks);
  gate2.core[1] += 1;
  if (ok(same, "무작위 core " + x.lane + " #" + x.i, show(x.text) + " " + JSON.stringify(x.names) + " → " + show(mine && mine.text) + " ↔ " + show(model.text))) gate2.core[0] += 1;
  if (mine && !mine.thrown) {
    const bad = violationsOf(x.text, x.names, mine);
    if (bad.size > 0) { gate2.core[2] += 1; ok(false, "무작위 core 성질 " + x.lane + " #" + x.i, [...bad].join(",") + " " + show(x.text)); }
    jsonl.push(JSON.stringify({ lane: x.lane, i: x.i, input: x.text, names: x.names, text: mine.text, full: mine.full, reason: mine.reason }));
  }
}
for (const x of fieldInputs) {
  const mine = g2[k2++];
  const mineSet = mine && mine.set;
  const modelSet = MODEL.harvest(x.text, x.known);
  const model = MODEL.scrubField(x.text, modelSet, { maxBytes: x.cut, keep: x.keep });
  const same = mine && JSON.stringify(mineSet) === JSON.stringify(modelSet) && mine.text === model.text && mine.full === model.full && mine.reason === model.reason && mine.truncated === model.truncated && JSON.stringify(mine.runs) === JSON.stringify(model.runs);
  gate2.field[1] += 1;
  if (ok(same, "무작위 field #" + x.i, show(x.text) + " → " + show(mine && mine.text) + " ↔ " + show(model.text))) gate2.field[0] += 1;
  if (mine && !mine.full && Array.isArray(mine.runs)) {
    // 칸의 성질: 자르기 뒤의 글 = (이 포팅의 장부로 다시 만든 전체 가림 글)의 끝/앞 · 상한 안 · 원본 이름 자리 전부 장부 안(㉡)
    const t = tidy(x.text);
    let rebuilt = ""; let cursor = 0;
    for (const [s, e, rk] of mine.runs) { rebuilt += t.slice(cursor, s) + MARK_OF_RANK[rk]; cursor = e; }
    rebuilt += t.slice(cursor);
    const want = expected(x.text, x.known);
    const cutOk = x.cut === undefined ? rebuilt === mine.text : (x.keep === "head" ? rebuilt.startsWith(mine.text) : rebuilt.endsWith(mine.text)) && Buffer.byteLength(mine.text, "utf8") <= x.cut;
    const wholeOk = !want.whole.full && want.whole.text === rebuilt;
    let namesOk = true;
    for (const [s, e] of nameOccurrences(t, rawKnown(x.known))) if (!covered(mine.runs, s, e)) { namesOk = false; break; }
    if (!cutOk || !wholeOk || !namesOk) { gate2.field[2] += 1; ok(false, "무작위 field 성질 #" + x.i, "cut=" + cutOk + " whole=" + wholeOk + " names=" + namesOk + " " + show(x.text)); }
  } else if (mine && mine.full) {
    const want = expected(x.text, x.known);
    if (!want.over && !want.whole.full) { gate2.field[2] += 1; ok(false, "무작위 field 통째 가림 까닭 없음 #" + x.i, show(x.text)); }
  }
}
for (const x of attachInputs) {
  const c = g2cases[k2];
  const sent = sentOf(c, g2[k2++]);
  const model = MODEL.installerAttachment(x.bytes, x.names, { maxBytes: x.cap });
  const same = model === null ? sent === null : sent !== null && !sent.bogus && sent.text === model.text && hex(sent.bytes) === hex(model.bytes) && sent.reason === model.reason && sent.full === model.full
    && JSON.stringify(sent.names) === JSON.stringify(model.names) && sent.overflow === model.overflow;
  gate2.attach[1] += 1;
  if (ok(same, "무작위 attach #" + x.i, hex(x.bytes).slice(0, 60) + " → " + show(sent && sent.text) + " ↔ " + show(model && model.text))) gate2.attach[0] += 1;
  const bad = installerBad(x.bytes, x.names, sent, x.cap);
  if (bad.length > 0) { gate2.attach[2] += 1; ok(false, "무작위 attach 잣대 #" + x.i, bad.join(" · ")); }
}
say("관문 2 — 무작위(씨앗 11160301~04 · JavaScriptCore 한 번 " + jxaMs + "ms): core " + gate2.core[0] + "/" + gate2.core[1] + " 같음 · 성질 위반 " + gate2.core[2]
  + " | field " + gate2.field[0] + "/" + gate2.field[1] + " · 위반 " + gate2.field[2]
  + " | attach " + gate2.attach[0] + "/" + gate2.attach[1] + " · 잣대 위반 " + gate2.attach[2]);
if (JSONL) { writeFileSync(JSONL, jsonl.join("\n") + "\n"); say("JSONL " + jsonl.length + "줄 → " + JSONL); }

// ════ 관문 4m — NSString 엄격 읽기 대 TextDecoder 치명 모드 ════
if (NDEC > 0) {
  const r = rng(11160305);
  const EDGE = [0x00, 0x7f, 0x80, 0xbf, 0xc0, 0xc1, 0xc2, 0xdf, 0xe0, 0xe1, 0xec, 0xed, 0xee, 0xef, 0xf0, 0xf1, 0xf3, 0xf4, 0xf5, 0xff, 0xa0, 0x9f, 0x8f, 0x90, 0xbb, 0xbe, 0xfe, 0x41];
  const samples = [];
  for (let a = 0; a < 256; a += 1) samples.push([a]);
  for (let a = 0; a < 256; a += 1) for (let b = 0; b < 256; b += 1) samples.push([a, b]);
  for (let a = 0xe0; a <= 0xef; a += 1) for (let b = 0x80; b <= 0xbf; b += 1) { samples.push([a, b, 0x80]); samples.push([0x41, a, b, 0xbf, 0x42]); }
  for (let a = 0xf0; a <= 0xf4; a += 1) for (let b = 0x80; b <= 0xbf; b += 1) { samples.push([a, b, 0x80, 0x80]); samples.push([0x41, a, b, 0xbf, 0xbf, 0x42]); }
  const fixedCount = samples.length;
  for (let i = 0; i < NDEC; i += 1) {
    const len = int(r, 1, 12);
    const bytes = [];
    for (let k = 0; k < len; k += 1) bytes.push(r() < 0.6 ? pick(r, EDGE) : int(r, 0, 255));
    if (r() < 0.3) { const ok8 = enc(pick(r, ["가", "😀", "é", "\ufeff", "\uffff", "\ud7ff", "\ue000"])); bytes.splice(int(r, 0, bytes.length), 0, ...ok8); }
    samples.push(bytes);
  }
  const dec = runJxa(samples.map((b) => ({ op: "decode", b64: Buffer.from(b).toString("base64"), n: b.length })));
  const ns = runJxa(samples.map((b) => ({ op: "nsdecode", b64: Buffer.from(b).toString("base64") })));
  let differ = 0; let valid = 0; let nsDiffer = 0; const nsShow = [];
  const stripBomOnce = (text) => (text !== null && text.charCodeAt(0) === 0xfeff ? text.slice(1) : text); // TextDecoder 기본 = 맨 앞 머리표 하나를 뗀다 · 제품 디코더는 떼지 않는다(부르는 쪽이 전부 뗀다)
  const show8 = (b) => Buffer.from(b).toString("hex");
  samples.forEach((b, i) => {
    let want = null;
    try { want = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(b)); } catch { want = null; }
    if (want !== null) valid += 1;
    const hand = strictUtf8(b);
    const got = dec[i];
    // 맨 앞 머리표: 두 쪽 다 하나를 뗀다 — 뗀 뒤의 맨 앞 U+FEFF 는 제품이 전부 뗀다(stripLeadingBoms) → 비교는 그 뒤 글로
    const same = (want === null) === (got === null) && hand === (want !== null) && (want === null || want === stripBomOnce(got));
    if (!same) { differ += 1; ok(false, "디코더 차등 " + show8(b), JSON.stringify([want, got, hand])); }
    const nsGot = ns[i];
    if ((want === null) !== (nsGot === null) || (want !== null && stripBoms(want) !== stripBoms(nsGot))) { nsDiffer += 1; if (nsShow.length < 6) nsShow.push(show8(b) + "→" + JSON.stringify(nsGot)); }
  });
  // 파일 읽기(제품의 readText = stringWithContentsOfFile) 표본 — 위와 같은 판정인가
  const fr = rng(11160306);
  const fileSamples = [];
  for (let i = 0; i < 3000; i += 1) fileSamples.push(samples[int(fr, 0, samples.length - 1)]);
  const fcases = fileSamples.map((b) => { const c = attachCase(Uint8Array.from(b), [], 16); return { op: "readfile", path: c.path }; });
  const fdec = runJxa(fcases);
  let fdiffer = 0;
  fileSamples.forEach((b, i) => {
    let want = null;
    try { want = new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(b)); } catch { want = null; }
    const got = fdec[i];
    if ((want === null) !== (got === null) || (want !== null && want !== stripBomOnce(got))) { fdiffer += 1; ok(false, "파일 읽기 차등 " + show8(b), JSON.stringify([want, got])); }
  });
  say("관문 4m — 디코더 차등: 제품 손 디코더(JavaScriptCore) 대 TextDecoder 치명 모드 대 시험 손 검사기 " + samples.length + "건(1·2바이트 전수 65,792 + 3·4바이트 머리×둘째 바이트 전수 " + (fixedCount - 65792) + " + 무작위 " + NDEC + " · 온전 " + valid + ") 차이 " + differ + " · 제품 파일 읽기 표본 3,000건 차이 " + fdiffer);
  say("  (관측 · 제품이 쓰지 않는 길) NSString(NSUTF8StringEncoding) 대 TextDecoder 치명 모드: 차이 " + nsDiffer + "/" + samples.length + (nsShow.length ? " 예 " + nsShow.join(" · ") : ""));
}

rmSync(work, { recursive: true, force: true });
if (fails.length > 0) { console.log("실패(앞 40):"); for (const line of fails) console.log(line); }
console.log(failed === 0 ? "RESULT: PASS — 실패 0" : "RESULT: FAIL — 실패 " + failed);
process.exit(failed === 0 ? 0 : 1);
