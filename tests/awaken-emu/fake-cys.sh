#!/bin/bash
# 가짜 cys — tests/awaken-emu/fleet.ps1(윈도우판 흉내)과 tests/awaken-emu-run.sh 맥 구역이 함께 쓴다.
#   자리 = 이 파일이 놓인 bin/ 의 부모 폴더(SB) · SB/scenario 가 시나리오 · SB/opened 가 있으면 자비스 자리가 열린 뒤다.
#   read-screen 은 클로드 화면 모양을 흉내 낸다 · send-key Return 은 SB/ret-<번호> 에 센다 · send·send-key 는 SB/sent 에 적는다.
#   ★자식 자리(10=cso · 11=worker)의 깸은 화면이 아니라 세션 기록(jsonl)으로 흉내 낸다(installer-awaken-jsonl):
#     기록 자리 = SB/home/.cys/claude/projects/<폴더 이름>/<세션>.jsonl · 파일은 첫 제출 때 생긴다(맥 실측 2026-09-16)
#     폴더 이름은 이 파일이 python 으로 따로 짓는다(설치기의 perl·PowerShell 규칙과 다른 구현 — 같은 코드로 짓고 같은 코드로 찾으면 시험이 비어 있다)
SB="$(cd "$(dirname "$0")/.." && pwd)"
S="$(cat "$SB/scenario")"
PROJ="$SB/home/.cys/claude/projects"
seat_cwd() { case "$1" in 10) printf '%s' "$SB/seats/cso" ;; 11) printf '%s' "$SB/seats/일꾼 w'1" ;; esac; }
row() { printf 'surface:%s\trole=%s\tpid=1\texited=false\t%s\t%s\n' "$1" "$2" "$3" "${4:-/tmp}"; }
# sess <자리> <user|assistant> [old] — 그 자리 세션 기록에 한 줄 더한다 · old = 기준선보다 먼저 생긴 지난 설치의 기록
sess() {
  python3 - "$PROJ" "$(seat_cwd "$1")" "$2" "$1" "$S" "${3:-}" <<'PY'
import sys, os, re, json
root, cwd, kind, sid, scen, old = sys.argv[1:7]
d = re.sub(r"[^A-Za-z0-9]", "-", cwd)
if scen == "fallback-dir" and sid == "11" and not old:
    d = "-long-path-shortened-0badc0de"   # 폴더 이름 규칙이 안 맞는 자리(긴 경로를 줄인 모양) — 파일 안 cwd 로만 찾을 수 있다
os.makedirs(os.path.join(root, d), exist_ok=True)
p = os.path.join(root, d, ("old-" if old else "new-") + sid + ".jsonl")
rec = {"parentUuid": None, "type": kind, "cwd": cwd, "sessionId": "s-" + sid, "message": {"role": kind, "content": "[Pasted text #1 +529 lines]"}}
with open(p, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False, separators=(",", ":")) + "\n")
if old:
    os.utime(p, (1577804400, 1577804400))   # 2020-01-01 — 맥에서는 생긴 시각도 함께 당겨진다(실측)
PY
}
awake() { sess "$1" user; sess "$1" assistant; }
reveal() { # 자식 자리가 목록에 처음 설 때 한 번 — 시나리오별 세션 기록의 첫 상태
  [ -f "$SB/revealed" ] && return 0
  touch "$SB/revealed"
  awake 10
  case "$S" in
    child-awake|fallback-success) awake 11 ;;
    no-answer) sess 11 user ;;                       # 제출은 됐는데 답 레코드가 끝내 없다
    stale-session) sess 11 user old; sess 11 assistant old ;;   # 같은 폴더에 지난 설치의 깬 기록만 있다
  esac
}
RULE='────────────────────────────────────────'
new_box() { printf '%s\n' "$RULE" "> $1" "$RULE" '  ? for shortcuts'; }
welcome() { printf '%s\n' ' Claude Code' ' Welcome back!' ''; }
replied() { welcome; printf '%s\n' '> [Pasted text #1 +529 lines]' '⏺ DIRECTIVE-ACK'; new_box ''; }
case "$1" in
  list)
    n=$(( $(cat "$SB/listcalls" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SB/listcalls"
    row 3 cso old-install
    if [ -f "$SB/opened" ]; then
      row 9 master jarvis
      if [ "$S" = "claim-denied" ]; then echo "warning: stale entry role=worker-9 skipped"; fi
      show=0
      case "$S" in
        success|child-awake|paste-late|child-stall|screen-lies|stale-session|fallback-dir|no-answer|grace) [ "$n" -ge 3 ] && show=1 ;;
        fallback-success) [ "$n" -ge 5 ] && show=1 ;;
      esac
      if [ "$show" = 1 ]; then reveal; row 10 cso cso "$(seat_cwd 10)"; row 11 worker-2 worker "$(seat_cwd 11)"; fi
    fi
    exit 0 ;;
  new-surface)
    if [ "$2" = "--help" ]; then echo "      --agent <AGENT>"; exit 0; fi
    printf '%s\n' "$@" > "$SB/newsurface-args"
    # 거절 문구는 cys 0.14.36 이 내는 거절 사유 글자를 따른다(자리 번호는 싣지 않는다 — 실물 명령 출력 모양은 아직 안 쟀다)
    if [ "$S" = "no-surface" ]; then echo "Error: claim_denied: privileged role held by live surface" >&2; exit 7; fi
    touch "$SB/opened"; echo "surface:9"; exit 0 ;;
  read-screen)
    id="${3#surface:}"
    case "$S:$id" in
      child-stall:11) welcome; printf '%s\n' 'cwd: /Users/hong/install-jarvis' 'account: hong@example.com'; new_box '[Pasted text #1 +529 lines]' ;;
      screen-lies:11|*:10) replied ;;   # screen-lies = 화면은 답한 모양인데 세션 기록은 없다(2026-09-16 샌드박스 5차 거짓 양성의 모양)
      *) welcome ;;
    esac
    exit 0 ;;
  send-key)
    printf '%s\n' "$*" >> "$SB/sent"
    if [ "$2" = "--surface" ] && [ "$4" = "Return" ]; then
      id="${3#surface:}"; k=$(( $(cat "$SB/ret-$id" 2>/dev/null || echo 0) + 1 )); echo "$k" > "$SB/ret-$id"
      # Return 이 제출을 일으키는 순간 = 세션 기록이 생긴다(사용자 레코드 + 답 레코드)
      case "$S:$id:$k" in
        success:11:1|stale-session:11:1|fallback-dir:11:1|paste-late:11:2) awake "$id" ;;
        # grace = 세 번째 Return 에 제출은 일어났는데 기록이 1초 늦게 생긴다 · 답 레코드는 아직 없다(installer-awaken-verify-r2)
        grace:11:3) ( sleep 1; sess "$id" user ) >/dev/null 2>&1 </dev/null & ;;
      esac
    fi
    exit 0 ;;
  send)
    printf '%s\n' "$*" >> "$SB/sent"; exit 0 ;;
esac
exit 0
