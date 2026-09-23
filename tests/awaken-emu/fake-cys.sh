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
# sess_cwd <자리 폴더> <user|assistant> <기록 이름> [old] — 그 폴더의 세션 기록에 한 줄 더한다
sess_cwd() {
  python3 - "$PROJ" "$1" "$2" "$3" "$S" "${4:-}" <<'PY'
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
sess() { sess_cwd "$(seat_cwd "$1")" "$2" "$1" "${3:-}"; }
awake() { sess "$1" user; sess "$1" assistant; }
# ── 마스터 자리(surface:9) 흉내 (TICKET=installer-0322-awaken) ────────────────────────────
#   설치기는 마스터를 두 축으로 잰다: 그 자리 세션 기록의 **답 레코드**와 지침이 시키는 **표지 파일**.
#   여기서 둘을 따로 켤 수 있어야 「받았으나 시작 안 함」(거부의 모양)과 「각성 확인」이 갈린다.
master_jh() { cat "$SB/jarvis-home" 2>/dev/null; }
master_mark() {
  jh="$(master_jh)"; [ -n "$jh" ] || return 0
  printf '%s\n' "2026-09-16T14:00:00+09:00" "pid=4242" > "$jh/awake-master.ok"
}
# 지난 설치가 남긴 표지 — **시각이 옛날**이다(이번 기준선보다 앞). 시각 검사가 이것을 걸러야 한다.
master_mark_old() {
  jh="$(master_jh)"; [ -n "$jh" ] || return 0
  printf '%s\n' "2020-01-01T00:00:00+09:00" "pid=1111" > "$jh/awake-master.ok"
  python3 -c 'import os,sys; os.utime(sys.argv[1], (1577804400, 1577804400))' "$jh/awake-master.ok"
}
master_answer() {
  jh="$(master_jh)"; [ -n "$jh" ] || return 0
  sess_cwd "$jh" user master; sess_cwd "$jh" assistant master
}
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
        master-refuse|master-retry-late|master-unknown|master-stale-mark|master-prior-mark|master-mark-only) [ "$n" -ge 3 ] && show=1 ;;   # 동료는 선다(편성 자동 복구) — 마스터만 안 깼다
        master-late-fleet) [ "$n" -ge 3 ] && { show=1; master_mark; } ;;   # H-M1: 첫 마스터 판정이 끝난 뒤(동료가 서는 순간)에야 표지가 생긴다 → 최종 판정 직전 재측정만이 잡는다
        fallback-success) [ "$n" -ge 5 ] && show=1 ;;
        master-verified-fleet-late) : ;;   # N13(t4-fix): 마스터는 깼는데(새 자리 기본 갈래 = 답+표지) 동료는 시험 상한 안에 끝내 안 선다

      esac
      if [ "$show" = 1 ]; then reveal; row 10 cso cso "$(seat_cwd 10)"; row 11 worker-2 worker "$(seat_cwd 11)"; fi
    fi
    exit 0 ;;
  ping)
    # N16(t4-fix): SB/slow-ping 이 있으면 답 없이 2초 걸린다(앱 창 대기 한 바퀴가 1초보다 길 때 기록이 바퀴 수가 아니라 실제 초인지 잰다)
    [ -f "$SB/slow-ping" ] && sleep 2
    exit 0 ;;
  new-surface)
    if [ "$2" = "--help" ]; then echo "      --agent <AGENT>"; exit 0; fi
    printf '%s\n' "$@" > "$SB/newsurface-args"
    # 거절 문구는 cys 0.14.36 이 내는 거절 사유 글자를 따른다(자리 번호는 싣지 않는다 — 실물 명령 출력 모양은 아직 안 쟀다)
    if [ "$S" = "no-surface" ]; then echo "Error: claim_denied: privileged role held by live surface" >&2; exit 7; fi
    touch "$SB/opened"
    # 자비스 자리가 열린 순간 마스터가 무엇을 하는지 — 시나리오가 정한다
    case "$S" in
      master-unknown) : ;;                                   # 아무 말도 안 한다(답 레코드 0 · 표지 0) → 판정 못 함
      master-mark-only) master_mark ;;                       # 표지는 썼는데 답 기록이 아직 안 내려갔다 → 표지만으로 각성 확인(이종 검토 1R)
      master-refuse|master-retry-late|master-prior-mark|master-late-fleet) master_answer ;;   # 말은 했는데 준비 작업을 시작하지 않았다(2026-09-16 거부의 모양)
      master-stale-mark) master_answer; master_mark_old ;;   # 말은 했고, 표지는 **지난 설치의 것**이 남아 있다(시각 검사 축)
      *) master_answer; master_mark ;;                       # 읽고 판단한 뒤 준비 작업 1번을 했다
    esac
    echo "surface:9"; exit 0 ;;
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
    printf '%s\n' "$*" >> "$SB/sent"
    # 재시도(보충 한 줄)를 받고 나서야 시작하는 갈래 — 재시도가 실제로 무언가를 바꾸는지 재려고
    if [ "$S" = "master-retry-late" ] && [ "$3" = "surface:9" ]; then master_mark; fi
    exit 0 ;;
  rotate)
    # 0.3.29: 설치기가 재설치 끝에 부른다. 1.1.2 앞 cys 의 실제 답(09-21 이 맥 cys 1.0.2 실측)을 흉내 낸다 —
    #   모르는 하위명령 · rc 2 ⇒ 설치기는 종전 [재시작] 안내로 폴백한다(이 흉내의 자리 선점 기대가 그 문장이다).
    echo "error: unrecognized subcommand 'rotate'" >&2; exit 2 ;;
esac
exit 0
