#!/bin/bash
# 0.3.36 F12 행동 시험 — 연결 대기의 「N분 지남」과 30분 상한이 **시계로 잰 지난 시간**을 보는가(두 OS) ·
#   맥 [5/10] 받기(첫 시도·다시 해 보기)에 멈춘 흐름을 끊는 상한(--speed-limit/--speed-time)이 있는가.
#
# 재는 것
#   ⓐ 맥 wait_for_connection · 윈 Wait-ForConnection: 가짜 시계(쉬기 = +30초 · 다시 해 보는 일 = +900초 후 실패)
#      · 상한 1800초에서 다시 해 보는 일은 **2번 이하**(앞 판 = 쉬는 간격만 세어 60번 · 실제 약 15시간)
#      · 화면의 「N분 지남」·「N분을 기다렸지만」 숫자가 그 순간 가짜 시계의 지난 분과 같다
#      · 대조군: 첫 시도에 붙으면 곧바로 성공(한 번만 해 본다)
#   ⓑ 맥 step_download_cys: 받기가 실패하고(가짜 curl) 기다림에 들어가도 — 설치 파일을 받는 curl 호출 **전부**에
#      --speed-limit · --speed-time · --connect-timeout 이 있다(첫 시도 + 다시 해 보기 ≥ 2회)
#
# 쓰는 법: bash tests/d5-f12-wall-clock-wait.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음
#   원본(v0.3.35) 사본의 install-master 를 --dir 로 주면 적색이어야 한다.
# ⛔바깥에 닿지 않는다 — 네트워크 0(curl·원인 가르기는 가짜 함수) · 실제로 쉬지 않는다(sleep·Start-Sleep 가짜) · 가짜 HOME.
# ⚠여기서 안 재는 것: 실물 curl 이 흐름이 멎은 연결을 60초에 끊는지 · 윈도우 5.1 Invoke-WebRequest 의 멈춘 받기(실기 몫).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
[ -f "$SH" ] && [ -f "$PS" ] || { echo "잴 수 없음: $DIR 에 bootstrap.sh·bootstrap.ps1 이 없다" >&2; exit 2; }
BASE="$(mktemp -d "${TMPDIR:-/tmp}/d5f12.XXXXXX")" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

# 화면 줄(「시계|말」)의 분 수가 가짜 시계의 지난 분과 같은가 — 시작 시계 1000
minutes_truthful() {  # $1 = 기록 파일 → rc 0 = 전부 맞다 · 분 줄이 3개 미만이면 1(잰 것이 없다)
  python3 - "$1" <<'PYEOF'
import re, sys
n = bad = 0
for l in open(sys.argv[1], encoding='utf-8'):
    clk, _, msg = l.rstrip('\n').partition('|')
    m = re.search(r'\((\d+)분 지남', msg) or re.search(r'(\d+)분을 기다렸지만', msg)
    if not m: continue
    n += 1
    want = (int(clk) - 1000) // 60
    if int(m.group(1)) != want:
        bad += 1; print('  화면 %s분 · 시계 %d분: %s' % (m.group(1), want, msg.strip()))
print('  분 줄 %d개 · 어긋남 %d개' % (n, bad))
sys.exit(0 if n >= 3 and not bad else 1)   # 최소 = 대기 줄 2 + 끝 줄 1
PYEOF
}

echo "== 맥 wait_for_connection =="
runsh() { # runsh <이름> <sh 글> — 실물을 함수 묶음으로 읽고 시계·쉬기·원인 가르기·말하기만 바꿔 끼운다
  mkdir -p "$BASE/h-$1"
  local body="$2"
  ( export HOME="$BASE/h-$1" JARVIS_HOME="$BASE/h-$1/install-jarvis" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1
    CLK="$BASE/clk-$1"; CNT="$BASE/cnt-$1"; SAYF="$BASE/say-$1"; ARGS="$BASE/args-$1"
    echo 1000 > "$CLK"; : > "$CNT"; : > "$SAYF"; : > "$ARGS"; set --
    . "$SH" >/dev/null 2>&1 || exit 97
    date() { if [ "${1:-}" = "+%s" ]; then cat "$CLK"; else command date "$@"; fi; }
    sleep() { echo $(( $(cat "$CLK") + $1 )) > "$CLK"; }
    net_cause() { printf none; }
    progress_send() { :; }
    say() { printf '%s|%s\n' "$(cat "$CLK")" "$*" >> "$SAYF"; }
    eval "$body" ) > "$BASE/out-$1" 2>&1
  echo $?
}
rc="$(runsh stall 'NET_WAIT_TIMEOUT=1800; NET_WAIT_INTERVAL=30
wait_for_connection "[5/10]" '"'"'echo 1 >> "$CNT"; echo $(( $(cat "$CLK") + 900 )) > "$CLK"; false'"'"'
echo "rc=$?"')"
[ "$rc" = 97 ] && { echo "잴 수 없음: bootstrap.sh 를 함수 묶음으로 읽지 못했다" >&2; exit 2; }
grep -q '^rc=' "$BASE/out-stall" || { echo "잴 수 없음: wait_for_connection 이 돌아오지 않았다" >&2; tail -3 "$BASE/out-stall" >&2; exit 2; }
n="$(wc -l < "$BASE/cnt-stall" | tr -d ' ')"
grep -q '^rc=1$' "$BASE/out-stall"; t $? "[맥] 끝내 안 붙으면 상한 뒤 rc 1" "$(grep '^rc=' "$BASE/out-stall")"
[ "$n" -ge 1 ] && [ "$n" -le 2 ]; t $? "[맥] 한 번에 900초 걸리는 시도는 30분 상한 안에서 2번 이하(지금 ${n}번)" "지난 시간을 쉬는 간격만 센다 — 실제 약 $(( n * 930 / 60 ))분 기다림"
minutes_truthful "$BASE/say-stall" > "$BASE/mt-stall" 2>&1; t $? "[맥] 화면 「N분 지남」·「N분을 기다렸지만」 = 시계로 잰 지난 분($(tail -1 "$BASE/mt-stall" | sed "s/^ *//"))" "$(head -3 "$BASE/mt-stall" | tr '\n' '|' | cut -c1-300)"
runsh okfirst 'NET_WAIT_TIMEOUT=1800; NET_WAIT_INTERVAL=30
wait_for_connection "[5/10]" '"'"'echo 1 >> "$CNT"; true'"'"'
echo "rc=$?"' >/dev/null
grep -q '^rc=0$' "$BASE/out-okfirst" && [ "$(wc -l < "$BASE/cnt-okfirst" | tr -d ' ')" = 1 ]
t $? "[맥 대조군] 첫 시도에 붙으면 rc 0 · 한 번만 해 본다" "$(grep '^rc=' "$BASE/out-okfirst") · $(wc -l < "$BASE/cnt-okfirst" | tr -d ' ')번"

echo "== 맥 [5/10] 받기 — 멈춘 흐름 상한 =="
runsh dl 'NET_WAIT_TIMEOUT=60; NET_WAIT_INTERVAL=30; MODE=full
curl() { case "$*" in *"%{http_code}"*) printf 503; return 0;; esac; printf "%s\n" "$*" >> "$ARGS"; return 28; }
[ "$(uname -m)" = "arm64" ] || { cys_use_fork_x64_pin; CYS_X64_PIN_PENDING=0; }
step_download_cys; echo "rc=$?"' >/dev/null
grep -q 'J-HOME-01' "$BASE/out-dl" "$BASE/say-dl" && { echo "잴 수 없음: 설치 폴더 조건(J-HOME-01)에 걸려 받기에 못 닿았다" >&2; exit 2; }
grep -q '^rc=' "$BASE/out-dl" || { echo "잴 수 없음: step_download_cys 가 돌아오지 않았다" >&2; tail -3 "$BASE/out-dl" >&2; exit 2; }
nd="$(grep -c -- ' -o ' "$BASE/args-dl")"
[ "${nd:-0}" -ge 2 ]; t $? "[맥 받기] 첫 시도 + 다시 해 보기가 불렸다(${nd}번)" "받기 갈래에 닿지 못했다"
for o in '--speed-limit 1024' '--speed-time 60' '--connect-timeout 20'; do
  nm="$(grep -- ' -o ' "$BASE/args-dl" | grep -vcE -- "${o}( |\$)")"   # 낱말 경계까지(적대 검토 지적: 600 을 60 으로 읽지 않게)
  [ "${nd:-0}" -ge 2 ] && [ "${nm:-0}" = 0 ]; t $? "[맥 받기] 받기 호출 전부에 $o" "${nm}번이 빠졌다(흐름이 멎으면 최대 15분 말 없이 붙든다)"
done

echo "== 윈 Wait-ForConnection =="
PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  echo "잴 수 없음: pwsh 가 없다(윈 축)" >&2; exit 2
fi
wrun() { # wrun <이름> <Try 본문>
  JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 HOME="$BASE/wh-$1" JARVIS_HOME="$BASE/wh-$1/install-jarvis" \
    perl -e 'alarm 120; exec @ARGV or exit 126' "$PW" -NoProfile -Command "
. '$PS' *> \$null
\$script:Clk = 1000; \$script:N = 0
\$script:Said = [System.Collections.Generic.List[string]]::new()
function Get-NowSec { return \$script:Clk }
function Start-Sleep { param([int]\$Seconds) \$script:Clk += \$Seconds }
function Get-NetCause { return 'none' }
function Say(\$msg) { \$script:Said.Add(('' + \$script:Clk + '|' + \$msg)) }
function Write-JCode { param(\$a, \$b) }
function Write-Log([string]\$m) { }
\$NetWaitTimeoutSec = 1800; \$NetWaitIntervalSec = 30
\$r = Wait-ForConnection '[5/10]' { $2 }
foreach (\$l in \$script:Said) { Write-Output ('SAY=' + \$l) }
Write-Output ('N=' + \$script:N)
Write-Output ('R=' + \$r)
" > "$BASE/wout-$1" 2>&1
}
mkdir -p "$BASE/wh-stall" "$BASE/wh-okfirst"
wrun stall '$script:N++; $script:Clk += 900; return $false'
grep -q '^R=' "$BASE/wout-stall" || { echo "잴 수 없음: 윈 Wait-ForConnection 결과 줄이 없다" >&2; tail -3 "$BASE/wout-stall" >&2; exit 2; }
wn="$(sed -n 's/^N=//p' "$BASE/wout-stall")"
grep -q '^R=False$' "$BASE/wout-stall"; t $? "[윈] 끝내 안 붙으면 상한 뒤 거짓" "$(grep '^R=' "$BASE/wout-stall")"
[ "${wn:-0}" -ge 1 ] && [ "${wn:-0}" -le 2 ]; t $? "[윈] 한 번에 900초 걸리는 시도는 30분 상한 안에서 2번 이하(지금 ${wn}번)" "지난 시간을 쉬는 간격만 센다 — 실제 약 $(( ${wn:-0} * 930 / 60 ))분 기다림"
sed -n 's/^SAY=//p' "$BASE/wout-stall" > "$BASE/wsay-stall"
minutes_truthful "$BASE/wsay-stall" > "$BASE/wmt-stall" 2>&1; t $? "[윈] 화면 「N분 지남」·「N분을 기다렸지만」 = 시계로 잰 지난 분($(tail -1 "$BASE/wmt-stall" | sed "s/^ *//"))" "$(head -3 "$BASE/wmt-stall" | tr '\n' '|' | cut -c1-300)"
wrun okfirst '$script:N++; return $true'
grep -q '^R=True$' "$BASE/wout-okfirst" && grep -q '^N=1$' "$BASE/wout-okfirst"
t $? "[윈 대조군] 첫 시도에 붙으면 참 · 한 번만 해 본다" "$(grep -E '^(R|N)=' "$BASE/wout-okfirst" | tr '\n' ' ')"

echo "── 합계: 통과 $pass · 실패 $fail"
[ "$fail" -eq 0 ] && exit 0 || exit 1
