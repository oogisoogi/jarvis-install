// TICKET=scrub-v3-port-1116 · ROLE=mac — 관문 3: 맥 포팅(bootstrap.sh)에 「규칙 하나를 다르게」 한 뮤턴트를 하나씩 넣고 관문이 죽이는지 실행으로 본다.
//   node tests/scrub-v3-mac-mutants.mjs [--n 1500]      · rc 0 = 전부 KILLED
// ⛔실물 설치기는 건드리지 않는다 — 임시 사본에만 낸다. 앵커가 정확히 1곳이 아니면 그 자리에서 멈춘다(설치기가 바뀐 것).
// 죽이는 쪽: JXA 뮤턴트 = tests/scrub-v3-mac.mjs(관문 1·2 · 4m 은 작게) · bash 뮤턴트 = tests/review-1115-mac.sh(끝끝 · 그 뮤턴트를 재는 시험 이름이 FAIL 에 있어야 KILLED).
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import os from "node:os";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(here, "..", "install-master", "bootstrap.sh");
const args = process.argv.slice(2);
const N = args.includes("--n") ? args[args.indexOf("--n") + 1] : "1500";
const ONLY = args.includes("--only") ? args[args.indexOf("--only") + 1] : null; // 이름 조각 — 그 뮤턴트만

// [이름, 옛 글, 새 글, 죽일 쪽('js' | 'bash:<FAIL 에 있어야 할 시험 이름 조각>')]
const MUTANTS = [
  ["수확 넘침 — 상한에서 조용히 멈춤(3R 발견 3 의 옛 꼴)",
    "    if (names.length >= MAX_NAMES) { overflow = true; return; }",
    "    if (names.length >= MAX_NAMES) { return; }", "js"],
  ["연속 DOMAIN 줄 — 줄 끝 개행을 먹음(3R 발견 4 의 옛 꼴)",
    "[ \\\\t]*(?=\\\\r?\\\\n|$)\",",
    "[ \\\\t]*(?:\\\\r?\\\\n|$)\",", "js"],
  ["크기 문지기 없음 — 칸 처리",
    "    if (source.length > unitsMax) return full(\"size\");\n",
    "", "js"],
  ["크기 문지기 없음 — 첨부 파일(읽기 전 바이트 수 · 한글 큰 파일 = 바이트는 넘고 코드 단위는 안 넘음)",
    "    if (size > unitsMax) return send(MARK.FULL, \"size\");   // 읽기 전에",
    "    if (false) return send(MARK.FULL, \"size\");   // 읽기 전에", "bash:크기 상한(4,194,304 바이트) 초과"],
  ["자르기 순서 가운데 — 자른 뒤 가림(2회차 처분 꼴)",
    "    var result = scrubV3(source, nameList, budget.check);",
    "    var result = scrubV3(opts.maxBytes === undefined ? source : opts.keep === \"head\" ? headBytes(source, opts.maxBytes + 8) : tailBytes(source, opts.maxBytes + 8), nameList, budget.check);", "js"],
  ["넘친 묶음을 그대로 씀(M28)",
    "    if (overflow) return full(\"harvest\");\n",
    "", "js"],
  ["알려진 이름을 손질한 꼴로만(split 1R 발견 1 · M33)",
    "    if (raw.length > 0 && !isBlankName(raw)) put(raw);",
    "    if (false) put(raw);", "js"],
  ["표시 값을 따옴표 뗀 꼴로만(M35)",
    "    push(whole); // 따옴표를 떼기 전의 값과 그 마지막 경로 조각",
    "    // (뮤턴트) 따옴표를 떼기 전의 값을 넣지 않음", "js"],
  ["빈칸뿐인 알려진 이름을 버리지 않음(L16)",
    "    if (raw.length > 0 && !isBlankName(raw)) put(raw);",
    "    if (raw.length > 0) put(raw);", "js"],
  ["시계 초기화가 문지기보다 먼저(M36)",
    "    if (overflow) return full(\"harvest\");\n    var unitsMax = opts.unitsMax === undefined ? FIELD_UNITS_MAX : opts.unitsMax;",
    "    scrubBudget(opts);\n    if (overflow) return full(\"harvest\");\n    var unitsMax = opts.unitsMax === undefined ? FIELD_UNITS_MAX : opts.unitsMax;", "js"],
  ["시계 값을 검증하지 않음(M26 의 반쪽 — NaN·뒤로 가는 시계 통과)",
    "    if (typeof now !== \"number\" || !isFinite(now) || (last !== null && now < last)) throw scrubStop(\"clock\");",
    "", "js"],
  ["이름 구간을 쌓아 합치지 않음(부록 E · M21)",
    "    while (spans.length > 0 && spans[spans.length - 1][1] >= start) {\n      var prev = spans.pop();\n      if (prev[0] < start) start = prev[0];\n    }",
    "", "js"],
  ["정리 순서 뒤집음 — 서러게이트 먼저(M15)",
    "  var text = String(input);\n  if (text.indexOf(\"\\u0000\") >= 0) text = text.split(\"\\u0000\").join(\"\");\n  var i, unit, clean = true;",
    "  var text = String(input);\n  var i, unit, clean = true;", "js"],
  ["재확인 없음(M4)",
    "      var found = scrubStructStreams(rendered.text, tick);",
    "      var found = [[], [], [], [], []];", "js"],
  ["/Users/ 사슬이 첫 /Users/ 하나만 넘음",
    "    while (text.startsWith(anchor, chainEnd)) chainEnd += anchor.length;",
    "    chainEnd += anchor.length;", "js"],
  ["느슨한 읽기 — 첨부를 NSString 으로 읽음(41 A9 를 받아 줌)",
    "    var text = readStrictUtf8File(path);",
    "    var text = readText(path);", "js"],
  ["엄격 디코더가 ED A0~BF(서러게이트 부호값)를 받아 줌",
    "hi = b === 0xed ? 0x9f : 0xbf;",
    "hi = 0xbf;", "js"],
  ["첨부의 NUL 검사 없음",
    "    if (text.indexOf(\"\\u0000\") >= 0) return send(MARK.FULL, \"nul\");\n",
    "", "js"],
  ["맥 앞 판 꼴(M32) — 끝 2×상한을 떼고 첫 줄 버린 뒤 가림",
    "  [ -f \"$1\" ] || return 1\n  local r\n  rm -f \"$3\"\n  r=\"$(RH_IN_FILE=\"$1\"",
    "  [ -f \"$1\" ] || return 1\n  local r\n  rm -f \"$3\"\n  tail -c $(( $2 * 2 )) \"$1\" | sed '1d' > \"$3.win\"\n  r=\"$(RH_IN_FILE=\"$3.win\"", "bash:M32 앞 판의"],
  ["프로세스 목록을 가리지 않고 보냄",
    "proc_tree_file \"$d/proc-tree.raw\" && help_scrubbed_tail \"$d/proc-tree.raw\" \"$ATTACH_MAX_BYTES\" \"$d/proc-tree.txt\" && help_attach proc_tree",
    "proc_tree_file \"$d/proc-tree.txt\" && help_attach proc_tree", "bash:proc-tree.txt 에 /Users/ 0건"],
  ["첨부가 합친 이름 묶음을 다시 적지 않음",
    "  writeNameSet(env(\"RH_NAMES_FILE\"), sent);\n",
    "", "bash:첨부가 찾은 이름을 묶음에 더해"],
  ["보고 env_report 에 묶음 대신 이름 배열을 넘김(독립 검증 M1)",
    "    env_report: scrubFieldBudgeted(envReport, names, ENV_REPORT_MAX_BYTES, \"head\").text,",
    "    env_report: scrubFieldBudgeted(envReport, names.names, ENV_REPORT_MAX_BYTES, \"head\").text,", "bash:M1h 보고 본문"],
  ["보고 수확 묶음의 넘침을 버림(독립 검증 M5)",
    "  var names = harvest(envReport + \"\\n\" + log, env(\"RH_EXTRA_NAMES\").split(\"\\n\"));",
    "  var names = harvest(envReport + \"\\n\" + log, env(\"RH_EXTRA_NAMES\").split(\"\\n\"));\n  names.overflow = false;", "bash:M1h 보고 본문"],
  ["명령 결과를 가리기 전에 끝 4KB 로 자름(독립 검증 M3)",
    "output_tail: scrubFieldBudgeted(output, names, OUTPUT_MAX_BYTES, \"tail\").text",
    "output_tail: scrubFieldBudgeted(tailBytes(output, OUTPUT_MAX_BYTES), names, OUTPUT_MAX_BYTES, \"tail\").text", "bash:M1i 명령 결과"],
  ["기록 끝 200줄을 가리기 전에 자름",
    "  var logField = scrubFieldBudgeted(log, names);",
    "  var logField = scrubFieldBudgeted(log.split(\"\\n\").slice(-LOG_TAIL_LINES).join(\"\\n\"), names);", "js-report"],
];

const work = mkdtempSync(path.join(process.env.TMPDIR || os.tmpdir(), "scrub-v3-mut-"));
const original = readFileSync(SRC, "utf8");
let killed = 0;
const lines = [];
for (const [name, from, to, killer] of MUTANTS) {
  if (ONLY && name.indexOf(ONLY) < 0) continue;
  const count = original.split(from).length - 1;
  if (count !== 1) { console.log("STOP 앵커 " + count + "곳: " + name); process.exit(3); }
  const copyDir = path.join(work, "m" + lines.length);
  spawnSync("mkdir", ["-p", copyDir]);
  const copy = path.join(copyDir, "bootstrap.sh");
  writeFileSync(copy, original.replace(from, to));
  let dead = false;
  let why = "";
  if (killer === "js") {
    const r = spawnSync("node", [path.join(here, "scrub-v3-mac.mjs"), "--n", N, "--decode", "3000", "--quiet"], { env: { ...process.env, SCRUB_SH: copy }, encoding: "utf8", maxBuffer: 1 << 26 });
    dead = r.status !== 0;
    why = (r.stdout.match(/✗ [^\n]*/) || [""])[0].slice(0, 110);
  } else if (killer === "js-report") {
    // 보고 본문(modeReport): Bearer 와 토큰 사이에 빈 줄 300개 — 200줄 창이 Bearer 를 떼어 내면 토큰이 남는다
    const dir = path.join(copyDir, "r");
    spawnSync("mkdir", ["-p", dir]);
    writeFileSync(path.join(dir, "env"), "");
    writeFileSync(path.join(dir, "log"), "start\nBearer" + "\n".repeat(300) + "tok9tok9tok9tok9\nend\n");
    const after = readFileSync(copy, "utf8").split("IFS= read -r -d '' REMOTE_HELP_JS <<'EOF_REMOTE_HELP_JS'")[1];
    const js = after.slice(after.indexOf("\n") + 1).split("\nEOF_REMOTE_HELP_JS\n")[0] + "\n";
    writeFileSync(path.join(dir, "rh.js"), js);
    const r = spawnSync("/usr/bin/osascript", ["-l", "JavaScript", path.join(dir, "rh.js"), "report"], { env: { ...process.env, RH_ENV_FILE: path.join(dir, "env"), RH_LOG_FILE: path.join(dir, "log"), RH_EXTRA_NAMES: "", RH_CODE: "J-NET-02", RH_STEP: "5/10", RH_VERSION: "0.0.1", RH_REPORT_OUT: path.join(dir, "rep.json"), RH_NAMES_OUT: path.join(dir, "names") }, encoding: "utf8" });
    let tail = "";
    try { tail = JSON.parse(readFileSync(path.join(dir, "rep.json"), "utf8")).log_tail; } catch { tail = "(보고 없음 rc=" + r.status + ")"; }
    dead = tail.indexOf("tok9tok9") >= 0;
    why = "log_tail 에 토큰 " + (dead ? "남음" : "없음 · " + JSON.stringify(tail).slice(0, 60));
  } else {
    const want = killer.slice("bash:".length);
    const r = spawnSync("bash", [path.join(here, "review-1115-mac.sh"), "--dir", copyDir], { encoding: "utf8", maxBuffer: 1 << 26 });
    const failLines = r.stdout.split("\n").filter((line) => line.indexOf("FAIL ") >= 0);
    dead = failLines.some((line) => line.indexOf(want) >= 0);
    why = (failLines.find((line) => line.indexOf(want) >= 0) || failLines[0] || "").trim().slice(0, 110);
  }
  if (dead) killed += 1;
  lines.push((dead ? "KILLED   " : "SURVIVED ") + name + (why ? " — " + why : ""));
  console.log(lines[lines.length - 1]);
}
rmSync(work, { recursive: true, force: true });
console.log("\n뮤턴트 KILLED " + killed + "/" + lines.length);
process.exit(killed === lines.length ? 0 : 1);
