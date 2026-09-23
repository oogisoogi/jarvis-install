#!/bin/bash
# 0.3.28 흉내 실행 시험 — 새 갈래를 **실제로 부른다**(글자 대조가 아니라 실행).
#
# 재는 것
#   ⓐ 자리 선점 판정(윈 Test-SeatClaimDenied · 맥 seat_claim_denied)이 네 가지 답에서 정확히 갈린다
#      — claim_denied 한 줄 · 뜻이 같은 다른 문구 · 성공 답(surface:N) · 빈 답
#   ⓑ 받는 자리 점검의 말 만들기(윈 Get-DlProbeWords · 맥 dl_probe_words)가 네 상태에서 서로 다른 말을 낸다
#      — 「안 쟀다」와 「못 닿았다」가 같은 말이 되면 진단이 뭉개진다
#   ⓒ 자식 설치기 기록 꼬리(윈 Get-ClaudeInstallLogTail · 맥 claude_install_log_tail)가 마지막 20줄만 준다
#      — 파일이 없을 때 조용히 죽지 않고 빈 것을 준다(fail-open)
#
# 쓰는 법: bash tests/v0328-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 네트워크 0 · 앱 실행 0 · 실물 홈 무접촉(가짜 HOME).
# ⚠여기서 안 재는 것: 실제 `cys new-surface` 의 답 문자열(윈·맥 실기 몫) · 실제 앱 창이 앞으로 오는가
#   (WScript.Shell·osascript 는 이 기계에서 못 부른다) · Start-Transcript 가 실제로 적는가(윈 실기 몫).
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
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
BASE="$(mktemp -d -t v0328emu)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }

DENIED='claim_denied: master held by a live surface'
SAME='error: role master held by a live surface (seat 12)'
OKREF='surface:42'

echo "== 윈(ps1) 자리 선점 판정 4가지 =="
out="$(JARVIS_LIB_ONLY=1 perl -e 'alarm shift; exec @ARGV' 60 "$PW" -NoProfile -Command ". '$PS' *> \$null;
Write-Output ('d1=' + (Test-SeatClaimDenied '$DENIED'))
Write-Output ('d2=' + (Test-SeatClaimDenied '$SAME'))
Write-Output ('d3=' + (Test-SeatClaimDenied '$OKREF'))
Write-Output ('d4=' + (Test-SeatClaimDenied ''))
Write-Output ('w1=' + (& { \$script:DlProbe='ok';   Get-DlProbeWords }))
Write-Output ('w2=' + (& { \$script:DlProbe='bad';  Get-DlProbeWords }))
Write-Output ('w3=' + (& { \$script:DlProbe='fail'; Get-DlProbeWords }))
Write-Output ('w4=' + (& { \$script:DlProbe='unknown'; Get-DlProbeWords }))
Write-Output ('tl=' + (@(Get-ClaudeInstallLogTail 20)).Count)
" 2>&1)"
printf '%s' "$out" | grep -q '^d1=True$';  t $? "[윈 d1] claim_denied 한 줄 → 자리 선점이다" "$out"
printf '%s' "$out" | grep -q '^d2=True$';  t $? "[윈 d2] 문구가 달라도 뜻이 같으면 자리 선점이다(master + held by a live surface)" "$out"
printf '%s' "$out" | grep -q '^d3=False$'; t $? "[윈 d3] 성공 답(surface:N)은 자리 선점이 아니다" "$out"
printf '%s' "$out" | grep -q '^d4=False$'; t $? "[윈 d4] 빈 답은 자리 선점이 아니다(못 물어본 것과 구별한다)" "$out"
w="$(printf '%s\n' "$out" | grep -E '^w[1-4]=' | sed 's/^w[1-4]=//' | sort -u | wc -l | tr -d ' ')"
[ "$w" = "4" ]; t $? "[윈 말] 네 상태가 서로 다른 말을 낸다(안 쟀다 ≠ 못 닿았다)" "서로 겹치는 말이 있다: $out"
printf '%s' "$out" | grep -q '^tl=0$'; t $? "[윈 꼬리] 기록 파일이 없으면 빈 것을 준다(죽지 않는다)" "$out"

echo "== 맥(sh) 같은 갈래 =="
mkdir -p "$BASE/home"
: > "$BASE/log"
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV' 60 bash -c ". '$SH' >/dev/null 2>&1; $1" 2>/dev/null; }
out2="$(run_sh '
seat_claim_denied "'"$DENIED"'"; echo "d1=$?"
seat_claim_denied "'"$SAME"'";   echo "d2=$?"
seat_claim_denied "'"$OKREF"'";  echo "d3=$?"
seat_claim_denied "";            echo "d4=$?"
DL_PROBE=ok;      printf "w1=%s\n" "$(dl_probe_words)"
DL_PROBE=bad;     printf "w2=%s\n" "$(dl_probe_words)"
DL_PROBE=fail;    printf "w3=%s\n" "$(dl_probe_words)"
DL_PROBE=unknown; printf "w4=%s\n" "$(dl_probe_words)"
CLAUDE_INSTALL_LOG=""; printf "tl=%s\n" "$(claude_install_log_tail 20 | wc -l | tr -d " ")"
CLAUDE_INSTALL_LOG="'"$BASE"'/big"; for i in $(seq 1 30); do echo "줄 $i" >> "$CLAUDE_INSTALL_LOG"; done
printf "tn=%s\n" "$(claude_install_log_tail 20 | wc -l | tr -d " ")"
printf "tf=%s\n" "$(claude_install_log_tail 20 | head -1)"
')"
printf '%s' "$out2" | grep -q '^d1=0$'; t $? "[맥 d1] claim_denied 한 줄 → 자리 선점이다" "$out2"
printf '%s' "$out2" | grep -q '^d2=0$'; t $? "[맥 d2] 문구가 달라도 뜻이 같으면 자리 선점이다" "$out2"
printf '%s' "$out2" | grep -q '^d3=1$'; t $? "[맥 d3] 성공 답은 자리 선점이 아니다" "$out2"
printf '%s' "$out2" | grep -q '^d4=1$'; t $? "[맥 d4] 빈 답은 자리 선점이 아니다" "$out2"
w2n="$(printf '%s\n' "$out2" | grep -E '^w[1-4]=' | sed 's/^w[1-4]=//' | sort -u | wc -l | tr -d ' ')"
[ "$w2n" = "4" ]; t $? "[맥 말] 네 상태가 서로 다른 말을 낸다" "서로 겹치는 말이 있다: $out2"
printf '%s' "$out2" | grep -q '^tl=0$'; t $? "[맥 꼬리] 기록 파일이 없으면 빈 것을 준다" "$out2"
printf '%s' "$out2" | grep -q '^tn=20$'; t $? "[맥 꼬리] 30줄이면 마지막 20줄만 준다" "$out2"
printf '%s' "$out2" | grep -q '^tf=줄 11$'; t $? "[맥 꼬리] 그 20줄은 **마지막** 20줄이다(11번째 줄부터)" "$out2"

# ★두 OS 의 말이 같은 뜻인가 — 한쪽만 고치면 진단 문구가 갈린다.
wwin="$(printf '%s\n' "$out"  | grep -E '^w[1-4]=' | sed 's/^w[1-4]=//' | sort)"
wmac="$(printf '%s\n' "$out2" | grep -E '^w[1-4]=' | sed 's/^w[1-4]=//' | sort)"
[ "$wwin" = "$wmac" ]; t $? "[동형] 두 OS 의 받는 자리 말 네 가지가 글자까지 같다" "윈[$wwin] ≠ 맥[$wmac]"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
