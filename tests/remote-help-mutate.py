#!/usr/bin/env python3
"""원격 해결(help-s2) 뮤턴트 — 설치기 사본을 한 자리씩 망가뜨려 **그 자리를 재는 시험이** 실제로 빨개지는지 잰다.

★「빨개졌다」로 끝내지 않는다 — 망가뜨린 자리를 재는 **바로 그 시험 이름**이 FAIL 에 있어야 죽인 것으로 센다
  (엉뚱한 시험이 우연히 빨개진 것을 살해로 세면 그 자리는 여전히 아무도 안 잰다).
⛔실물 설치기는 건드리지 않는다 — 임시 사본에만 낸다. 앵커가 정확히 1곳이 아니면 그 자리에서 멈춘다(설치기가 바뀐 것).

쓰는 법: python3 tests/remote-help-mutate.py   · rc 0 = 전부 죽었다
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(HERE), "install-master", "bootstrap.sh")
RUNNER = os.path.join(HERE, "remote-help-run.sh")

# (이름, 옛 글, 새 글, 돌릴 묶음, 빨개져야 할 시험)
MUTANTS = [
    ("M1 세션 밖 명령 실행",
     'if (session === null || typeof session !== "object" || session.open !== true) return "SESSION closed";',
     'if (session === null || typeof session !== "object") return "SESSION closed";',
     "skip", "session-open"),
    ("M2 서명 모양 검사 제거",
     '    if (typeof message.sig !== "string" || !/^[0-9a-f]{64}$/.test(message.sig)) continue;\n',
     "",
     "skip", "sig-shape"),
    ("M3 표시 없이 실행",
     '  say "     운영팀 명령: $shown"',
     '  : "$shown"',
     "display", "display-before-run"),
    ("M4 재검사를 이름 확인으로 줄임",
     "    var verdict = recheckArgv(table, shell, message.argv);",
     '    var verdict = (function (argv) { var e = table.entries.filter(function (x) { return Array.isArray(argv) && x.shell === shell && x.usage.split(" ")[0] === argv[0]; })[0]; return e ? { ok: true, entry: e, argv: argv } : { ok: false, rule: "unknown_command" }; })(message.argv);',
     "forged", "forged-argv"),
    ("M5 실행 번호를 남기지 않음",
     '  remote_help_record "$seq"\n  case "$RH_RECORD" in',
     '  RH_RECORD=OK\n  case "$RH_RECORD" in',
     "seq", "seq-restart"),
    ("M6 셸 글로 이어 실행",
     '    exec "$prog" ${args[@]+"${args[@]}"}',
     '    exec /bin/sh -c "$prog ${args[*]:-}"',
     "display", "exec-cys"),
    ("M7 표 판본 비교 제거",
     '    if (message.table_version !== table.version) { out.push("DECLINE " + seq + " table_version"); continue; }\n',
     "",
     "decline", "table-version-decline"),
    ("M8 경로 성분 경계 제거",
     '    case "$real" in "$root"|"$root"/*) ;; *) return 1 ;; esac',
     "    :",
     "path", "path-outside"),
    ("M9 스크럽 제거",
     "function scrubWith(input, names) {\n  var text = input;",
     "function scrubWith(input, names) {\n  return input;\n  var text = input;",
     "report", "report-scrub"),
    ("M10 argv 없으면 text 로 실행",
     "    var verdict = recheckArgv(table, shell, message.argv);",
     '    var verdict = recheckArgv(table, shell, Array.isArray(message.argv) ? message.argv : String(message.text).split(" "));',
     "text", "text-ignored"),
    ("M11 실행 직전 재계산 제거",
     '    if ! remote_help_confine "$rel" || [ "$RH_REAL" != "$first" ]; then',
     "    if false; then",
     "toctou", "toctou-reconfine-inside"),
    ("M12 연 것과 이름의 정체 대조 제거(외부 검토 1차 BLOCKER)",
     """        [ -n "$opened" ] && [ "$opened" = "$(/usr/bin/stat -L -f '%d:%i' "./$leaf" 2>/dev/null)" ] || refuse path_outside""",
     "        :",
     "toctou", "toctou-open"),
    ("M12b 연 뒤 다시 보는 링크 검사 제거",
     """\n        [ -L "$leaf" ] && refuse path_outside\n""",
     "\n        :\n",
     "toctou", "toctou-open-link"),
    ("M13 출처 헤더 제거",
     '    */ack|*/close) [ -s "$RH_TMP/client-header" ] && extra+=(-H "@$RH_TMP/client-header") ;;',
     "    */ack|*/close) : ;;",
     "report", "client-token"),
    ("M14 창 닫힘 트랩 제거",
     "  trap 'remote_help_on_signal' HUP INT TERM\n",
     "",
     "close", "window-close"),
    ("M15 시간 상한 제거",
     '  ( sleep "$REMOTE_HELP_CMD_TIMEOUT" && { : > "$RH_TMP/timedout"; kill -9 "$pid" 2>/dev/null; } ) </dev/null >/dev/null 2>&1 &',
     "  ( : ) &",
     "timeout", "timeout"),
    ("M16 고지 없이 보냄",
     '  [ "${NOTICE_SHOWN:-0}" = "1" ] && remote_help',
     "  remote_help",
     "gate", "closing-notice-gate"),
    ("M17 기록 잠금 제거(외부 검토 1차: 동시 두 번 = OK,OK)",
     '  until mkdir "$lock" 2>/dev/null; do',
     "  until true; do",
     "seq", "seq-lock"),
    ("M18 CYS_NO_AUTOSTART 제거",
     "    export CYS_NO_AUTOSTART=1\n",
     "",
     "display", "no-autostart"),
    ("M19 토큰을 못 둬도 헤더를 씀",
     '      rm -f "$REMOTE_HELP_TOKEN_FILE" "$RH_TMP/client-header" 2>/dev/null',
     """      printf 'x-help-client: %s\\n' "$token" > "$RH_TMP/client-header\"""",
     "report", "client-token-failclosed"),
    ("M20 직렬화 본문 상한 제거",
     '  fitReport(body, "log_tail", tailBytes);\n  fitReport(body, "env_report", headBytes);\n',
     "",
     "report", "report-size"),
    ("M21 깨우기 전에 REACHED_WAKE(D1)",
     '  say "[9/10] 자비스를 깨웁니다."',
     '  REACHED_WAKE=1\n  say "[9/10] 자비스를 깨웁니다."',
     "gate", "wake-failed"),
    ("M22 없는 폴더 안의 이름을 밖으로 처리",
     "        2) remote_help_ack \"$seq\" declined path_missing; return $? ;;\n",
     "",
     "path", "path-missing"),
]


def main():
    source = open(SRC, encoding="utf-8").read()
    killed = 0
    work = tempfile.mkdtemp(prefix="remote-help-mutate-")
    try:
        for name, old, new, group, expect in MUTANTS:
            if source.count(old) != 1:
                print(f"::error::{name} — 앵커가 {source.count(old)}곳입니다(1곳이어야 한다) — 설치기가 바뀌었습니다")
                return 3
            copy = os.path.join(work, "bootstrap.sh")
            open(copy, "w", encoding="utf-8").write(source.replace(old, new, 1))
            if subprocess.run(["bash", "-n", copy]).returncode != 0:
                print(f"::error::{name} — 사본이 문법에서 깨졌습니다")
                return 3
            run = subprocess.run(["bash", RUNNER, "--src", copy, "--only", group], capture_output=True, text=True, timeout=600)
            fails = [line.strip() for line in run.stdout.splitlines() if line.strip().startswith("FAIL ")]
            hit = any(line.startswith(f"FAIL {expect} ") for line in fails)
            killed += 1 if hit and run.returncode != 0 else 0
            print(f"{'KILLED ' if hit and run.returncode != 0 else 'SURVIVED'} {name} — 기대 {expect} · FAIL {len(fails)}건")
            if not hit:
                print(run.stdout[-1500:])
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"\n뮤턴트 {killed}/{len(MUTANTS)} KILLED")
    return 0 if killed == len(MUTANTS) else 1


if __name__ == "__main__":
    sys.exit(main())
