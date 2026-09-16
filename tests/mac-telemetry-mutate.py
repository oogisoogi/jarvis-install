#!/usr/bin/env python3
"""맥 진행 전송·증거 러너의 뮤턴트 실사격 (TICKET=mac-parity-t2-telemetry · 2026-09-16).
각 뮤턴트 = bootstrap.sh 사본에 결함 하나를 심고(찾을 글이 **정확히 1번** 있는지 먼저 단언 = 변이 적용 확인),
tests/mac-telemetry-run.sh <사본> 을 돌려 **rc≠0(적색)** 이면 KILLED. 초록이면 SURVIVED(그 축은 러너가 못 잰다).
판정은 러너의 종료 코드로만 한다(표준 출력 글자로 읽지 않는다).
"""
import os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "install-master", "bootstrap.sh")
RUN = os.path.join(HERE, "mac-telemetry-run.sh")
M = [
  ("os-win", '    f.os = "mac";\n', '    f.os = "win";\n'),
  ("no-lever", '  [ "${JARVIS_NO_PROGRESS:-}" = "1" ] && return 0   # 흉내 시험이 실제 서버로', '  : && return 0 2>/dev/null || true   # 흉내 시험이 실제 서버로'),
  ("mask-off", '  if (!raw) return raw;\n  // 순서 = 서버', '  return raw;\n  // 순서 = 서버'),
  ("name-lines-drift", 'var MASK_NAME_LINES = /\\b(?:USERNAME|USERPROFILE|LOGNAME|USER|HOME)', 'var MASK_NAME_LINES = /\\b(?:USERNAME|USERPROFILE|LOGNAME|HOME)'),
  ("evidence-no-dedupe", '    case "$EVIDENCE_SENT" in *" $key "*) return 0 ;; esac\n    EVIDENCE_SENT="$EVIDENCE_SENT$key "\n    progress_tmp || return 0\n    tf="$PG_TMP/evidence.txt"', '    EVIDENCE_SENT="$EVIDENCE_SENT$key "\n    progress_tmp || return 0\n    tf="$PG_TMP/evidence.txt"'),
  ("image-cap-ignored", '        EVIDENCE_IMAGE_DONE=1\n', '        EVIDENCE_IMAGE_DONE=0\n'),
  ("token-header-dropped", '-H "@$dir/upload-header" -H \'content-type: image/jpeg\'', '-H \'content-type: image/jpeg\''),
  ("say-hook-off", 'say() { printf \'%s\\n\' "$*"; log "$*"; say_error_text_hook "$*"; }', 'say() { printf \'%s\\n\' "$*"; log "$*"; }'),
  ("install-id-not-saved", '    ( umask 077; printf \'%s\\n\' "$id" > "$f" ) 2>/dev/null   # 윈판은 CRLF', '    :   # 윈판은 CRLF'),
  ("capture-kinds-unfiltered", 'if (KINDS.indexOf(String(k)) >= 0 && seen.indexOf(String(k)) < 0)', 'if (seen.indexOf(String(k)) < 0)'),
  ("env-not-passed", 'PG_ENV_ADMIN="$PG_ENV_ADMIN" PG_OUT="$PG_TMP/body.json"', 'PG_OUT="$PG_TMP/body.json"'),
  # (뺀 것) baseline-null-as-zero — 등가 뮤턴트: Number(null)=0 이라 바로 아래 v <= 0 이 같은 칸을 버린다(동작 불변 · 2026-09-16 실사격 SURVIVED 뒤 판정).
  ("jcode-no-fail-send", '  progress_send "$(current_step)" fail "" "$1"   # 막힌 자리를', '  :   # 막힌 자리를'),
  ("attach-no-client-header", '    */ack|*/close|*/attach) [ -s', '    */ack|*/close) [ -s'),
  # N1(t4-fix) — 켜라는 말 없이도 촬영기를 부르는 판(= 권한 창 위험이 되살아난 판)이 붉어야 한다
  ("evidence-images-no-optin", '  if [ "${JARVIS_EVIDENCE_IMAGES:-}" != "1" ]; then\n', '  if false; then\n'),
  # N12(t4-fix) — 요약 줄이 없을 때 「실패 0」으로 되돌린 판(unknown 갈래 제거)
  ("doctor-summary-missing-as-zero", '      doctor_known=0\n', '      :\n'),
  ("detail-head-unmasked", 'var head = tailBytes(maskEvidenceText("[" + env("PG_REASON") + "] " + env("PG_DETAIL")), 400);', 'var head = tailBytes("[" + env("PG_REASON") + "] " + env("PG_DETAIL"), 400);'),
]
src = open(SRC, encoding="utf-8").read()
killed = survived = na = 0
for name, old, new in M:
    n = src.count(old)
    if n != 1:
        print(f"NOT-APPLIED {name} (찾을 글 {n}번)"); na += 1; continue
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(os.path.join(d, "install-master"))
        p = os.path.join(d, "install-master", "bootstrap.sh")
        mutated = src.replace(old, new, 1)
        assert mutated != src
        open(p, "w", encoding="utf-8").write(mutated)
        r = subprocess.run(["bash", RUN, p], capture_output=True, text=True, timeout=600)
        fails = [l.strip() for l in r.stdout.splitlines() if l.startswith("  FAIL")]
        if r.returncode != 0:
            killed += 1; print(f"KILLED   {name} ← {fails[0][:110] if fails else 'rc=' + str(r.returncode)}")
        else:
            survived += 1; print(f"SURVIVED {name}")
print(f"KILLED {killed} / SURVIVED {survived} / NOT-APPLIED {na}")
sys.exit(0 if survived == 0 and na == 0 else 1)
