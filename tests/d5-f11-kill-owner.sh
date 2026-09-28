#!/bin/bash
# 0.3.36 F11 보강 — 대기 감시자를 끝낼 때 「내 자식인가」를 먼저 본다(적대 검토 지적).
#
# 재는 것
#   ⓐ 끝맺음(closing_note)에서 LOGIN_WATCHER 번호가 내 자식이 아니면(감시자가 먼저 끝나 번호를 남이 물려받은 경우) 죽이지 않는다
#   ⓑ 대조군: 번호가 살아 있는 내 자식이면 종전대로 끝낸다(거짓 초록 방지 — 가드가 늘 「안 죽임」이면 여기서 붉어진다)
#   ⓒ 로그인 대기 정상 끝의 거두기 자리(login_wait 뒤)도 같은 확인을 거친다 — kill_own_child 를 직접 불러 ⓐⓑ 를 한 번 더
# 쓰는 법: bash tests/d5-f11-kill-owner.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송 끔 · 이 시험이 띄운 프로세스만 번호로 거둔다(이름 매칭 pkill 금지).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
BASE="$(mktemp -d -t d5f11own)" || exit 2
MINE=""   # 이 시험이 띄운 「남」 프로세스 번호들 — 끝에 이것만 거둔다
cleanup() { for p in $MINE; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
mkdir -p "$BASE/home"
run_lib() { # run_lib <본문> — 설치기를 읽어 들인 셸에서 본문을 돌린다(결과는 본문이 $BASE/res 에 적는다 · 끝맺음 글이 화면에 섞이므로)
  rm -f "$BASE/res"
  HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 \
    perl -e 'alarm shift; exec @ARGV or exit 126' 60 /bin/bash -c ". '$SH' >/dev/null 2>&1; mkdir -p \"\$JARVIS_HOME\"; $1"
}

# ⓐ 남의 프로세스(이 시험의 자식 · 설치기 셸의 자식이 아니다)를 감시자 번호로 준다
sleep 60 & other=$!; MINE="$MINE $other"
run_lib "LOGIN_WAIT_MARK=\"\$JARVIS_HOME/.login-wait\"; : > \"\$LOGIN_WAIT_MARK\"; LOGIN_WATCHER=$other; closing_note >/dev/null 2>&1" >/dev/null 2>&1
kill -0 "$other" 2>/dev/null; t $? "[ⓐ] 끝맺음이 내 자식 아닌 번호(남이 물려받은 번호)를 죽이지 않는다" "남의 프로세스가 죽었다"

# ⓑ 대조군 — 살아 있는 내 자식 감시자는 끝낸다
r="$(run_lib "LOGIN_WAIT_MARK=\"\$JARVIS_HOME/.login-wait\"; : > \"\$LOGIN_WAIT_MARK\"; sleep 60 & LOGIN_WATCHER=\$!; w=\$LOGIN_WATCHER; closing_note >/dev/null 2>&1; sleep 0.3; if kill -0 \$w 2>/dev/null; then kill \$w; echo alive; else echo dead; fi > '$BASE/res'" >/dev/null 2>&1; cat "$BASE/res" 2>/dev/null)"
[ "$r" = "dead" ]; t $? "[ⓑ 대조군] 끝맺음이 살아 있는 내 자식 감시자는 끝낸다" "$r"

# ⓒ 도우미 직접 — 남의 번호 = 안 죽임(rc 1) · 내 자식 = 죽임(rc 0)
sleep 60 & other2=$!; MINE="$MINE $other2"
r="$(run_lib "kill_own_child $other2; echo rc=\$? > '$BASE/res'" >/dev/null 2>&1; cat "$BASE/res" 2>/dev/null)"
kill -0 "$other2" 2>/dev/null; a=$?
[ "$a" -eq 0 ] && [ "$r" = "rc=1" ]; t $? "[ⓒ] kill_own_child 가 남의 번호엔 손대지 않는다(rc 1)" "살아 있음=$a · $r"
r="$(run_lib "sleep 60 & p=\$!; kill_own_child \$p; rc=\$?; sleep 0.3; if kill -0 \$p 2>/dev/null; then kill \$p; echo rc=\$rc:alive; else echo rc=\$rc:dead; fi > '$BASE/res'" >/dev/null 2>&1; cat "$BASE/res" 2>/dev/null)"
[ "$r" = "rc=0:dead" ]; t $? "[ⓒ 대조군] kill_own_child 가 내 자식은 끝낸다(rc 0)" "$r"
r="$(run_lib "{ kill_own_child ''; echo rc=\$?; kill_own_child 'x1'; echo rc=\$?; } > '$BASE/res'" >/dev/null 2>&1; tr '\n' ' ' < "$BASE/res" 2>/dev/null)"
[ "$r" = "rc=1 rc=1 " ]; t $? "[ⓒ] 빈 번호·숫자 아닌 번호 → 아무것도 안 하고 rc 1" "$r"

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
