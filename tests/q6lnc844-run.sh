#!/bin/bash
# Q6LNC844(2026-11-09 · 0.3.44 윈 [3/10] 「unexpected end」) 시험
#
# 재는 것
#   A ⓐ 설치 창 그림(Get-InstallerWindowJpeg)을 한 번 부르면 Jarvis.Win 형식이 생긴다
#     ⓑ 그 호출이 TypeNotFound 오류를 $Error 에 남기지 않는다(끝맺음의 「마지막 오류」를 가리지 않는다)
#     ⓒ 맥에서 잴 수 없는 것: PrintWindow 가 실제로 설치 창을 담는지 · GetConsoleWindow 가 손잡이를 주는지(윈 실기 몫)
# 쓰는 법: bash tests/q6lnc844-run.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송 끔 · mktemp -d 안에서만 쓴다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
command -v pwsh >/dev/null 2>&1 || { echo "  skip pwsh 가 없다(통과로 세지 않는다)"; exit 2; }
BASE="$(mktemp -d -t q6lnc844)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
fact() { grep -E "^$1=" "$BASE/facts" 2>/dev/null | tail -1 | cut -d= -f2-; }

echo "== A 설치 창 그림 형식 =="
HOME="$BASE/home" perl -e 'alarm 120; exec @ARGV or exit 126' pwsh -NoProfile -File "$HERE/q6lnc844-drive.ps1" -Src "$PS" -Sb "$BASE" >"$BASE/drive.out" 2>&1
[ "$(fact type_before)" = "False" ]; t $? "[A] 부르기 전에는 형식이 없다(축이 대상에 닿는다)" "before=$(fact type_before) · $(tail -3 "$BASE/drive.out")"
[ "$(fact type_after)" = "True" ];   t $? "[A] 설치 창 그림을 부르면 Jarvis.Win 형식이 생긴다" "after=$(fact type_after) — 손잡이 0 에서 먼저 돌아가 형식이 영영 안 생긴다(설치 창 그림이 늘 빠진다)"
[ "$(fact typenotfound)" = "0" ];    t $? "[A] TypeNotFound 오류를 남기지 않는다(끝맺음의 마지막 오류를 가리지 않는다)" "TypeNotFound $(fact typenotfound)건"

echo "== B 로그인 대기 중 설치 창 Ctrl+C (가상 터미널 · 실물 Step-Login) =="
B="$BASE/b"; mkdir -p "$B"
python3 "$HERE/q6lnc844-ctrlc.py" "$HERE/q6lnc844-ctrlc-drive.ps1" "$PS" "$B" >"$B/py.out" 2>&1
bf() { grep -E "^$1=" "$B/facts" 2>/dev/null | tail -1 | cut -d= -f2-; }
grep -q 'login stage: wait' "$B/home/install-jarvis/bootstrap.log" 2>/dev/null; t $? "[B] 대기에 들어갔다(축이 대상에 닿는다)" "$(cat "$B/py.out")"
[ "$(bf returned)" = "True" ]; t $? "[B] Ctrl+C 를 눌러도 설치가 끊기지 않고 로그인 대기가 제 길(상한)로 끝난다" "returned=$(bf returned) — Ctrl+C 가 설치를 그 자리에서 끊는다(Q6LNC844 의 끝 모양)"
[ "$(bf loginrc)" = "5" ]; t $? "[B] 끝은 종전 실패 갈래(J-LOGIN-01 · rc 5)다" "loginrc=$(bf loginrc)"
grep -q 'login wait: Ctrl+C in installer window' "$B/home/install-jarvis/bootstrap.log" 2>/dev/null; t $? "[B] Ctrl+C 를 누른 사실이 기록에 남는다(다음 사례에서 가를 수 있다)" "기록 줄 없음"
[ "$(bf treat_after)" = "False" ]; t $? "[B] 로그인 대기가 끝나면 Ctrl+C 가 다시 중단 키로 돌아온다" "treat_after=$(bf treat_after)"

echo "== C 설치 창 그림 격리(별도 프로세스 + 상한) =="
C="$BASE/c"; mkdir -p "$C"
HOME="$C/home" perl -e 'alarm 150; exec @ARGV or exit 126' pwsh -NoProfile -File "$HERE/q6lnc844-iso-drive.ps1" -Src "$PS" -Sb "$C" >"$C/drive.out" 2>&1
cf() { grep -E "^$1=" "$C/facts" 2>/dev/null | tail -1 | cut -d= -f2-; }
CL="$C/home/install-jarvis/bootstrap.log"
awk '/^function Get-InstallerWindowJpeg/{f=1} f&&/Invoke-IsolatedWindowJpeg/{a=1} f&&/Get-WindowJpeg \(/{b=1} f&&/^}/{exit} END{exit !(a&&!b)}' "$PS"
t $? "[C] 설치 창 그림은 격리 함수로 찍는다(이 프로세스에서 PrintWindow 를 부르지 않는다 · 정적)" "Get-InstallerWindowJpeg 가 Get-WindowJpeg 를 직접 부르거나 격리 함수를 안 부른다"
grep -qE '^\$WindowCaptureCapSec *= *10\b' "$PS"; t $? "[C] 상한 = 10초(맥판 perl alarm 10 과 같다)" "상한 상수가 10 이 아니다"
[ "$(cf has_fn)" = "True" ]; t $? "[C] 격리 함수가 있다(축이 대상에 닿는다)" "has_fn=$(cf has_fn) · $(tail -3 "$C/drive.out")"
[ "$(cf ok_len)" = "64" ] && [ "$(cf ok_same)" = "True" ]; t $? "[C] 자식이 찍은 그림이 그대로 돌아온다" "len=$(cf ok_len) same=$(cf ok_same)"
grep -q 'window capture (격리): stub-child-line' "$CL" 2>/dev/null; t $? "[C] 자식이 적은 기록 줄이 설치 기록으로 옮겨진다" "옮겨진 줄 없음"
[ "$(cf ok_left)" = "0" ]; t $? "[C] 성공 뒤 임시 파일이 남지 않는다" "남은 파일 $(cf ok_left)"
[ "$(cf hang_null)" = "True" ]; t $? "[C] 자식이 멈추면 그림 없이 돌아온다" "hang_null=$(cf hang_null)"
hs="$(cf hang_sec)"; [ -n "$hs" ] && [ "$hs" -le 8 ]; t $? "[C] 멈춘 자식을 상한(시험 3초)에 맞춰 놓는다(설치기는 붙들리지 않는다)" "걸린 ${hs:-?}초"
[ "$(cf hang_child_alive)" = "False" ]; t $? "[C] 멈춘 자식은 끝난다(고아 0)" "alive=$(cf hang_child_alive)"
grep -q 'window capture: 3s cap' "$CL" 2>/dev/null; t $? "[C] 상한에 닿으면 기록 1줄" "기록 줄 없음"
[ "$(cf hang_left)" = "0" ]; t $? "[C] 멈춘 뒤에도 임시 파일이 남지 않는다" "남은 파일 $(cf hang_left)"

grep -q 'window capture: 3s cap — child pid [0-9]* killed' "$CL" 2>/dev/null; t $? "[C] 끈 뒤 실제로 끝났는지 보고 「killed」로 적는다(확인 없이 적지 않는다)" "$(grep 'window capture: 3s cap' "$CL" 2>/dev/null | tail -1)"
[ "$(cf err_null)" = "True" ]; t $? "[C] 자식 안에서 오류가 나면 그림 없이 돌아온다" "err_null=$(cf err_null)"
grep -q 'window capture (격리): child error: stub-child-boom' "$CL" 2>/dev/null; t $? "[C] 자식 오류 사유가 설치 기록에 남는다" "사유 줄 없음"
grep -q 'window capture (격리): child exit 3' "$CL" 2>/dev/null; t $? "[C] 자식 종료 코드가 0 이 아니면 기록에 남는다(못 돈 끝과 못 찍은 끝을 가른다)" "종료 코드 줄 없음"
[ "$(cf err_left)" = "0" ]; t $? "[C] 오류 뒤에도 임시 파일이 남지 않는다" "남은 파일 $(cf err_left)"
awk '/^function Get-InstallerWindowJpeg/{f=1} f&&/IsWindowVisible\(\$h\)/{a=NR} f&&/Invoke-IsolatedWindowJpeg \$h/{b=NR} f&&/^}/{exit} END{exit !(a&&b&&a<b)}' "$PS"
t $? "[C] 보이지 않는 콘솔 창(Windows Terminal 대리 창)이면 자식을 띄우기 전에 그림 없이 간다(정적)" "보임 검사가 없거나 격리 호출 뒤에 있다"
grep -q "if (-not \$printed) { \$bmp.Dispose(); Write-Log 'window capture skip (PrintWindow 실패)'; return \$null }" "$PS"
t $? "[C] PrintWindow 가 실패를 돌려주면 빈 그림을 보내지 않는다(정적 · 맥에서 못 부른다)" "반환값 검사가 없다"
awk '/^function Get-InstallerWindowJpeg/{f=1} f&&/\$env:WT_SESSION/{a=NR} f&&/Invoke-IsolatedWindowJpeg \$h/{b=NR} f&&/^}/{exit} END{exit !(a&&b&&a<b)}' "$PS"
t $? "[C] Windows Terminal(WT_SESSION)이면 자식을 띄우기 전에 그림 없이 간다(윈 실기 11-09 · 26200 은 대리 창이 보임)" "WT_SESSION 검사가 없거나 격리 호출 뒤에 있다"
grep -q "Write-Log 'window capture (격리): 그림 없음" "$PS"
t $? "[C] 자식이 정상 종료인데 그림이 없으면 사유 줄을 남긴다(윈 실기 11-09)" "사유 줄 없음"
echo "== 결과: 통과 $pass · 실패 $fail =="
[ "$fail" -eq 0 ]
