#!/bin/bash
# 가짜 cys — tests/awaken-emu/fleet.ps1(윈도우판 흉내)과 tests/awaken-emu-run.sh 맥 구역이 함께 쓴다.
#   자리 = 이 파일이 놓인 bin/ 의 부모 폴더(SB) · SB/scenario 가 시나리오 · SB/opened 가 있으면 자비스 자리가 열린 뒤다.
#   read-screen 은 클로드 화면 모양을 흉내 낸다 · send-key Return 은 SB/ret-<번호> 에 센다 · send·send-key 는 SB/sent 에 적는다.
SB="$(cd "$(dirname "$0")/.." && pwd)"
S="$(cat "$SB/scenario")"
row() { printf 'surface:%s\trole=%s\tpid=1\texited=false\t%s\t/tmp\n' "$1" "$2" "$3"; }
RULE='────────────────────────────────────────'
new_box() { printf '%s\n' "$RULE" "> $1" "$RULE" '  ? for shortcuts'; }
old_box() { printf '%s\n' '╭──────────────────────────────────────╮' "│ > $1 │" '╰──────────────────────────────────────╯'; }
welcome() { printf '%s\n' ' Claude Code' ' Welcome back!' ''; }
stalled() { welcome; new_box '[Pasted text #1 +529 lines]'; }
answering() { welcome; printf '%s\n' '> [Pasted text #1 +529 lines]' '✻ Reading… (esc to interrupt)'; new_box ''; }
replied() { welcome; printf '%s\n' '> [Pasted text #1 +529 lines]' '⏺ DIRECTIVE-ACK'; new_box ''; }
case "$1" in
  list)
    n=$(( $(cat "$SB/listcalls" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SB/listcalls"
    row 3 cso old-install
    if [ -f "$SB/opened" ]; then
      row 9 master jarvis
      if [ "$S" = "claim-denied" ]; then echo "warning: stale entry role=worker-9 skipped"; fi
      case "$S" in
        success|child-awake|paste-late|child-stall) if [ "$n" -ge 3 ]; then row 10 cso cso; row 11 worker-2 worker; fi ;;
      esac
      if [ "$S" = "fallback-success" ] && [ "$n" -ge 5 ]; then row 10 cso cso; row 11 worker-2 worker; fi
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
    rc="$(cat "$SB/ret-$id" 2>/dev/null || echo 0)"
    case "$S:$id" in
      success:11) if [ "$rc" -ge 1 ]; then answering; else stalled; fi ;;
      paste-late:11)
        if [ "$rc" -ge 2 ]; then welcome; printf '%s\n' '> [Pasted text #1 +529 lines]' '  Reading the file'; old_box ' '
        else welcome; old_box '[Pasted text #1 +529 lines]'; fi ;;
      child-stall:11) welcome; printf '%s\n' 'cwd: /Users/hong/install-jarvis' 'account: hong@example.com'; new_box '[Pasted text #1 +529 lines]' ;;
      *:10|fallback-success:11|child-awake:11) replied ;;
      *) welcome ;;
    esac
    exit 0 ;;
  send-key)
    printf '%s\n' "$*" >> "$SB/sent"
    if [ "$2" = "--surface" ] && [ "$4" = "Return" ]; then id="${3#surface:}"; echo $(( $(cat "$SB/ret-$id" 2>/dev/null || echo 0) + 1 )) > "$SB/ret-$id"; fi
    exit 0 ;;
  send)
    printf '%s\n' "$*" >> "$SB/sent"; exit 0 ;;
esac
exit 0
