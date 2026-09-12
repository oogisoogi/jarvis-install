#!/bin/bash
# 승인 대기 구간 더블 — 「말하는 대기」가 정말 말하고, 정말 끝내고, **붙여넣기를 안 죽이고**,
#   **제 표적만 겨누고**, **고아를 안 남기는가**.
#
# ★왜 더블인가: 진짜 `claude auth login` 은 벤더 것이라 우리가 시간을 줄일 수 없다.
#   20분을 기다리는 시험은 아무도 안 돌린다 ⇒ 간격을 초 단위로 줄인 **같은 모양**으로 잰다.
#
# ★무게중심은 ②가 아니라 ③·⑥이다.
#   ③ 승인 프로세스를 배경으로 돌리면 화면에 말하기는 쉬워지지만 **사람이 코드를 못 넣는다.**
#   ⑥ 상한이 표적을 **다시 찾으면** 그 사이 바뀐 무관한 프로세스를 맞힌다(외부 검토 1차 HIGH).
#
# ⚠부품을 **awk 로 떼어 오지 않는다**(외부 검토 1차 LOW). 실물을 `JARVIS_LIB_ONLY=1` 로 **그대로 읽어** 쓴다 —
#   떼어 낸 조각은 파일 전체의 문법 오류나 전역 상태 문제를 가려 준다.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SH="$DIR/../install-master/bootstrap.sh"
SB="$(mktemp -d)"; mkdir -p "$SB/home"
cleanup() { pkill -f "sleep 97" 2>/dev/null; rm -rf "$SB"; }
trap cleanup EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }

# 🔴**살아 있는가**를 `kill -0` 로만 재지 마라 — 끝났지만 아직 거두지 않은 자식(좀비)에도 **성공한다.**
#   그러면 「안 끝났다」와 「끝났는데 안 거뒀다」가 같은 값이 되어 축이 눈이 먼다(작성 중 뮤턴트가 잡았다).
#   ⇒ 프로세스 상태를 보고 **Z 는 끝난 것**으로 센다. 없는 것도 끝난 것이다.
alive() {
  local st
  st="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"
  [ -n "$st" ] || return 1                 # 아예 없다 = 끝났다
  case "$st" in Z*) return 1 ;; esac       # 좀비 = 끝났다
  return 0
}
# 잠깐 기다렸다가 본다(신호가 닿는 데 시간이 든다). **기다림으로 결과를 바꾸지 않는다** —
# `wait` 로 붙들면 안 죽은 표적도 제 수명이 다할 때까지 기다려 「끝났다」가 되어 버린다(같은 뮤턴트가 잡았다).
ended_within() {
  local pid="$1" n="${2:-5}" i=0
  while [ "$i" -lt "$n" ]; do alive "$pid" || return 0; sleep 1; i=$((i+1)); done
  return 1
}

# ⚠경로는 **환경변수로** 넘긴다. `bash -c '...' _ "$SH"` 처럼 위치 인자로 주면 bootstrap 의
#   인자 파서(`for a in "$@"`)가 그것을 「모르는 인자」로 보고 **exit 2** 로 죽는다(작성 중 실측).
#   ★읽히는 쪽이 인자를 본다는 것을 잊으면, 시험이 「부품이 없다」고 거짓말한다.
T_SH="$SH" HOME="$SB/home" JARVIS_LIB_ONLY=1 bash -c '. "$T_SH" && type login_waiter >/dev/null && type login_end_wait >/dev/null && type tell >/dev/null' >/dev/null 2>&1
ck "[더블] 실물을 통째로 읽어 세 부품을 얻는다" $? "파일을 못 읽거나 이름이 바뀌었다"

run_case() { # run_case <이름> <say> <timeout> <가운데서 할 일>
  local name="$1" say="$2" to="$3" body="$4"
  cat > "$SB/$name.sh" <<CASE
set -u
. "$SH" || exit 9
LOGIN_SAY_INTERVAL=$say
LOGIN_WAIT_TIMEOUT=$to
MARK="$SB/mark.$name"; PIDF="$SB/pid.$name"
: > "\$MARK"; rm -f "\$PIDF"
login_waiter "\$MARK" "\$PIDF" &
W=\$!
echo "\$W" > "$SB/watcher.$name"
$body
rm -f "\$PIDF"; rm -f "\$MARK"
kill "\$W" 2>/dev/null
wait "\$W" 2>/dev/null || true
CASE
  ( HOME="$SB/home" JARVIS_LIB_ONLY=1 bash "$SB/$name.sh" >"$SB/$name.out" 2>"$SB/$name.err" )
}

# 승인 프로세스 흉내 — 자기 번호와 시작 시각을 적고 나서 오래 자는 것으로 바뀐다(실물과 같은 모양).
FAKE='/bin/sh -c '"'"'echo $$ > "$0"; ps -o lstart= -p $$ >> "$0"; exec sleep 300'"'"' "$PIDF"'

echo "== ① 기다리는 동안 말하는가 =="
run_case say 2 600 'sleep 7'
n=$(grep -c '붙여넣고 Enter' "$SB/say.err")
[ "$n" -ge 2 ]; ck "[대기] 간격마다 안내를 인쇄한다(2초×7초 = ${n}회)" $? "말이 없다 — 사람은 멈춘 줄 안다"
grep -q '기다린 지' "$SB/say.err"; ck "[대기] 얼마나 기다렸는지 함께 말한다" $? "언제까지인지 모른다"
grep -q 'Ctrl-C' "$SB/say.err";   ck "[대기] 빠져나가는 법을 함께 말한다" $? "갇힌 느낌을 준다"
! grep -q '붙여넣고 Enter' "$SB/say.out"
ck "[대기] 안내는 화면(stderr)에만 간다" $? "표준출력으로 새면 기록이 같은 줄로 뒤덮인다"

echo "== ② 상한에 스스로 끝내는가 =="
t0=$(date +%s); run_case cap 2 4 "$FAKE"; t1=$(date +%s); el=$((t1-t0))
[ "$el" -lt 40 ]; ck "[상한] 상한에서 기다림이 끝난다(${el}초 · 가짜는 300초짜리였다)" $? "상한이 안 듣는다"
grep -q '기다림을 끝냅니다' "$SB/cap.err"; ck "[상한] 끝낸다는 것을 말하고 끝낸다" $? "말없이 끊으면 고장으로 읽는다"

echo "== ③ ★붙여넣기가 살아 있는가 (이 설계가 걸려 있는 자리) =="
mkfifo "$SB/fifo" 2>/dev/null
run_case paste 2 600 'read -r code < "'"$SB"'/fifo"; printf "GOT:%s\n" "$code" > "'"$SB"'/got"' &
CASE_PID=$!
( sleep 3; printf 'CODE-ABC123\n' > "$SB/fifo" ) & FEED_PID=$!
wait "$CASE_PID" 2>/dev/null; wait "$FEED_PID" 2>/dev/null; sleep 1
grep -q 'GOT:CODE-ABC123' "$SB/got" 2>/dev/null
ck "[붙여넣기] 감시자가 도는 동안에도 앞쪽이 입력을 받는다" $? "감시자가 stdin 을 뺏었다 — 코드를 못 넣는다"
grep -q '붙여넣고 Enter' "$SB/paste.err"
ck "[붙여넣기] 그 사이에도 안내는 나왔다" $? "둘 중 하나만 되면 고친 것이 아니다"

echo "== ④ 상한 전에 끝나면 조용히 물러나는가 =="
run_case quiet 30 600 'sleep 1'
! grep -q '붙여넣고 Enter' "$SB/quiet.err"
ck "[조용] 금방 끝난 승인에는 한 줄도 안 보탠다" $? "빨리 끝낸 사람에게 잔소리를 한다"

echo "== ⑤ ★고아를 안 남기는가 (외부 검토 1차 MEDIUM) =="
# 간격을 97초로 둬서 **우리 sleep 만** 이름으로 가려낸다. 성공 경로(금방 끝남)를 돈 뒤 남아 있으면 고아다.
pkill -f "sleep 97" 2>/dev/null; sleep 1
run_case orphan 97 600 'sleep 2'
sleep 2
left=$(pgrep -f "sleep 97" 2>/dev/null | wc -l | tr -d ' ')
[ "$left" -eq 0 ]
ck "[고아] 감시자가 끝나며 제 자식(sleep)도 데려간다(남은 것 ${left}개)" $? "성공할 때마다 고아가 하나씩 쌓인다"

echo "== ⑥ ★제 표적만 겨누는가 (외부 검토 1차 HIGH) =="
# ⑴ 번호는 맞는데 **시작 시각이 다르면**(번호 재사용) 보내지 않는다 — 무관한 프로세스를 지켜야 한다.
sleep 300 & VICTIM=$!
printf '%s\n' "$VICTIM" > "$SB/pid.wrong"
printf '%s\n' "Mon Jan  1 00:00:00 2001" >> "$SB/pid.wrong"
T_SH="$SH" T_PID="$SB/pid.wrong" HOME="$SB/home" JARVIS_LIB_ONLY=1 bash -c '. "$T_SH"; LOGIN_WAIT_TIMEOUT=1; login_end_wait "$T_PID"' >/dev/null 2>"$SB/wrong.err"
sleep 2
# ★**효과가 아니라 판단을 잰다.** 「죽었는가」로만 보면 눈이 먼다 — 비대화 셸의 배경 자식은
#   **SIGINT 를 무시**하도록 태어나므로(POSIX), 잘못 쏜 INT 가 아무 흔적도 안 남긴다(작성 중 뮤턴트가 잡았다).
#   ⇒ 「끝냅니다」라고 **말했는가**를 본다. 그 말은 **쏘기로 결정했을 때만** 나온다.
[ ! -s "$SB/wrong.err" ] && alive "$VICTIM"
ck "[표적] 시작 시각이 다르면 그 번호에 안 보낸다(번호 재사용 방어)" $? "무관한 프로세스를 겨눴다 — 폴링 단계를 우리 손으로 깨뜨린다"
kill "$VICTIM" 2>/dev/null
# ⑵ **막지 말아야 할 것** — 제대로 된 표적은 실제로 끝나야 한다(방어가 제 범위를 넘지 않는가).
/bin/sh -c 'echo $$ > "$0"; ps -o lstart= -p $$ >> "$0"; exec sleep 300' "$SB/pid.right" &
TARGET_JOB=$!
sleep 1; TARGET=$(sed -n 1p "$SB/pid.right")
T_SH="$SH" T_PID="$SB/pid.right" HOME="$SB/home" JARVIS_LIB_ONLY=1 bash -c '. "$T_SH"; LOGIN_WAIT_TIMEOUT=1; login_end_wait "$T_PID"' >/dev/null 2>&1
# ⚠`wait` 로 거두지 **않는다** — 안 죽은 표적까지 제 수명(300초)이 다할 때까지 기다려 주면
#   「끝났다」가 되어 축이 눈먼다. 대신 **상태로** 본다(좀비도 끝난 것으로 센다).
ended_within "$TARGET" 5
ck "[표적] 제 표적은 실제로 끝낸다" $? "방어만 늘고 상한이 안 듣는다"
# ⑶ 표적 파일이 없으면(성공 경로) 아무 일도 하지 않는다
# ★rc 가 0인지가 아니라 **아무 말도 안 했는가**로 잰다 — rc 는 어느 갈래로 나가든 0이라 눈이 먼다.
T_SH="$SH" T_PID="$SB/pid.none" HOME="$SB/home" JARVIS_LIB_ONLY=1 bash -c '. "$T_SH"; login_end_wait "$T_PID"' >/dev/null 2>"$SB/none.err"
[ ! -s "$SB/none.err" ]
ck "[표적] 표적이 치워졌으면 조용히 물러난다" $? "없는 것을 두고 「끝냅니다」라고 말한다"

printf '\n통과 %d · 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
