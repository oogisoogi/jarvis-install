#!/bin/bash
# v0.3.17 흉내 실행 시험 — PowerShell 7 로 실물 bootstrap.ps1 을 「함수 묶음」으로 읽고, 가짜 claude 로 새 창 로그인의 갈래를 실제로 부른다.
#
# 무엇을 재는가 (2026-09-15 · 로그인 막힘 표본 3건 · 워크숍 로그인 막힘 9건)
#   ① 다섯 갈래 — 승인 지연(창이 스스로 끝남) · 즉시 반환(코드 실패 → 한 번 다시 열기 → J-LOGIN-01) · 무한 대기(20분 상한)
#      · 파일만 생김(창이 안 닫혀도 로그인을 알아채고 닫아 준다) · 확인 명령 없음(로그인 파일로 판정)
#   ② 확인 명령이 「아니다」라고 답하면 로그인 파일이 새로 생겨도 성공으로 읽지 않는다 · 예전 로그인이 남긴 파일로도 성공을 선언하지 않는다
#   ③ 상한에 닿은 실패에서만 숫자 하나를 묻고 답을 분류 표지로 기록·환경 보고에 싣는다 · 5분 점검은 한 번
#   ④ 성공하면 구독 종류만 적는다(같은 답의 이메일은 기록·보고에 안 남는다)
#   ⑤ 새 창을 못 띄우면 이 창에서 한다 — 벤더 출력이 화면으로 가고 결과는 스크립트 변수로 돌아온다
#   ⑥ 끝맺음 — 조용히 넘긴 확인 오류를 끝난 원인처럼 적지 않는다
#   ⑦ 확인 명령이 멈춰도 한 번의 상한에서 끄고 20분 상한이 밀리지 않는다(이종 검토 1R 지적)
#   ⑧ 코드 넣기(2026-09-15 윈도우 샌드박스) — 복사된 코드를 로그인 입력에 한 줄로 넣는다 · 예전 코드·모양 아닌 내용은 안 넣는다
#      · 같은 코드는 한 번 · 한 번 연 로그인에서 최대 3회 · 코드·복사 내용은 기록에 안 남는다(흉내 파일만 읽는다 — 진짜 클립보드 무접촉)
#
# 쓰는 법: bash tests/v0317-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 실제 설치·실제 로그인 0 · 쓰기는 mktemp -d 안에서만(USERPROFILE · JARVIS_HOME 모두 그 안).
# ⚠여기서 **안 재는 것**(윈도우에서만 있는 것): 새 콘솔 창이 실제로 뜨는가 · 그 창에 주소가 찍히는가 · 창 제목 ·
#   붙여넣기가 그 창에 닿는가 · 키 하나 읽기(맥 흉내에는 콘솔 입력이 없어 「입력 불가」 갈래만 탄다 · 답 갈래는 함수를 바꿔 끼워 잰다).
export JARVIS_NO_PROGRESS=1   # 🔴흉내·검사는 라이브 서버로 진행 이벤트를 보내지 않는다(2026-09-15 15:49 master 게이트 실행이 라이브 progress에 가짜 4건을 남긴 사고 · Send-Progress의 레버)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="$2"; shift 2 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done
PW="$(command -v pwsh 2>/dev/null)"
[ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
EMU="$HERE/v0317-emu"
BASE="$(mktemp -d -t v0317-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
cleanup() { pkill -f 'sleep 307[1-8]' 2>/dev/null; rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
# 멈춘 흉내가 시험 전체를 세우지 않게 상한을 건다(맥에는 timeout 명령이 없다) · 입력은 비워 둔다(키 읽기가 결정론이 되게)
run_ps() { perl -e 'alarm shift; exec @ARGV' 60 "$PW" -NoProfile -File "$@" </dev/null; }
has() { grep -qE -- "$2" "$1"; }
cnt() { grep -cE -- "$2" "$1" 2>/dev/null; }
left() { pgrep -f "$1" 2>/dev/null | wc -l | tr -d ' '; }

echo "== v0.3.17 [3/10] 새 창 로그인 =="
for s in slow-approve instant-return hang hang-ask file-only no-status file-not-logged stale-file status-hang inline closing-quiet closing-loud clip-inject clip-stale clip-junk clip-repeat clip-many; do
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/login.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"; R="$SB/home/install-jarvis/env-report.md"
  [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  has "$L" 'TEST finally'; t $? "[$s] 흉내가 끝까지 돌았다" "마지막 줄이 없다 — 멈췄거나 죽었다(err: $(head -c 160 "$SB/err.txt"))"
  calls="$(cat "$SB/calls" 2>/dev/null || echo 0)"; n2="$(cnt "$L" 'jcode J-LOGIN-02')"
  case "$s" in
    slow-approve)
      has "$L" 'TEST rc=0 JCode= LoggedIn=True' && [ "$calls" = "1" ] && [ "$n2" = "0" ]
      t $? "[승인 지연] 창이 스스로 끝나면 곧바로 확인해 통과한다(다시 열지 않는다)" "승인 창 ${calls}번 · J-LOGIN-02 ${n2}회"
      has "$L" 'login stage: done by status after window ended' && has "$L" 'login proc exit=0 after [0-9]+s \(self\)'
      t $? "[승인 지연] 단계 표지·종료 코드·걸린 초를 적는다" "표지 줄이 없다"
      has "$L" 'login subscription: pro$' && ! grep -q 'example\.com' "$L" && { [ ! -f "$R" ] || ! grep -q 'example\.com' "$R"; }
      t $? "[승인 지연] 구독 종류만 적고 같은 답의 이메일은 남기지 않는다" "구독 줄이 없거나 이메일이 남았다"
      ;;
    instant-return)
      has "$L" 'TEST rc=5 JCode=J-LOGIN-01' && [ "$calls" = "2" ] && [ "$n2" = "1" ]
      t $? "[즉시 반환] 한 번만 다시 열고 J-LOGIN-01 로 닫힌다" "승인 창 ${calls}번 · J-LOGIN-02 ${n2}회"
      [ "$(cnt "$L" 'login poll failed')" = "0" ] && [ "$(cnt "$L" 'login stage: confirm')" = "2" ] && ! has "$L" '최대 10분'
      t $? "[즉시 반환] 창이 끝나면 몇 번만 확인하고 곧바로 갈래를 정한다(10분 헛 대기 없음)" "확인 단계 $(cnt "$L" 'login stage: confirm')회"
      has "$R" '^## \[3/10\] 로그인 단계에서 본 것' && has "$R" '^- 다시 열기: 1회 했다' && has "$R" '^- 승인 프로세스: 스스로 끝났다 · 종료 코드 1 · '
      t $? "[즉시 반환] 로그인 단계에서 본 것을 환경 보고(보내는 본문)에 싣는다" "보고 절이 없거나 칸이 틀렸다"
      ;;
    hang)
      has "$L" 'login wait timeout [0-9]+min: CloseMainWindow' && has "$L" 'login wait timeout: (Kill|closed without Kill)' && has "$L" 'TEST rc=5 JCode=J-LOGIN-01'
      t $? "[무한 대기] 상한에서 창을 끝내고 J-LOGIN-01" "상한 기록 줄 또는 끝 코드가 없다"
      sec="$(sed -nE 's/.*login proc exit=[^ ]* after ([0-9]+)s \(cap\).*/\1/p' "$L" | head -1)"
      [ -n "$sec" ] && [ "$sec" -ge 10 ] && [ "$sec" -le 17 ]
      t $? "[무한 대기] 상한은 벽시계로 잰다(10초 상한 → ${sec:-없음}초)" "걸린 초가 상한과 맞지 않는다"
      has "$L" 'login fail answer: no-console-input' && has "$R" '^- 상한에서 받은 답: no-console-input'
      t $? "[무한 대기] 상한 실패에서 묻는다 — 콘솔 입력이 없으면 그 사실을 표지로 적는다" "답 표지가 없다"
      [ "$(cnt "$L" '\[5분 점검\]')" = "1" ]; t $? "[무한 대기] 5분 점검은 한 번만 말한다" "$(cnt "$L" '\[5분 점검\]')번"
      has "$L" '스스로 푸는 법: 새 PowerShell 창을 열고 claude 를 입력해 Enter' && [ "$(cnt "$L" '스스로 푸는 법')" = "1" ]
      t $? "[무한 대기] 로그인이 끝내 안 되면 스스로 푸는 법(새 창에서 claude 직접)을 한 번 말한다" "$(cnt "$L" '스스로 푸는 법')번"
      ! grep -q '1) 열려 있는 Claude 탭' "$SB/err.txt"; t $? "[무한 대기] 기다리는 동안 설치 창에 카드를 되풀이하지 않는다" "되풀이됐다"
      [ "$(left 'sleep 3071')" = "0" ]; t $? "[무한 대기] 끝낸 창이 남지 않는다" "남은 대기 프로세스 $(left 'sleep 3071')개"
      ;;
    hang-ask)
      has "$L" 'login fail answer: no-approval-screen \(key=2\)' && has "$R" '^- 상한에서 받은 답: no-approval-screen'
      t $? "[무한 대기 · 답 2] 누른 숫자를 분류 표지로 기록·보고에 싣는다" "답 표지가 없다"
      ;;
    file-only)
      has "$L" 'login stage: done by status while window open after [0-9]+s' && has "$L" 'login window closed after login - exited=True' && has "$L" 'TEST rc=0'
      t $? "[파일만 생김] 창이 안 닫혀도 로그인을 알아채고 창을 닫아 준다" "창이 살아 있는 동안의 판정·닫기 줄이 없다"
      ! has "$L" 'login wait timeout'; t $? "[파일만 생김] 상한까지 기다리지 않는다" "상한에 닿았다"
      [ "$(left 'sleep 3072')" = "0" ]; t $? "[파일만 생김] 닫은 창이 남지 않는다" "남은 대기 프로세스 $(left 'sleep 3072')개"
      ;;
    no-status)
      has "$L" 'login stage: done by file while window open' && has "$L" 'login subscription: unknown$' && has "$L" 'TEST rc=0'
      t $? "[확인 명령 없음] 로그인 파일이 이번에 생겼으면 그것으로 판정한다" "파일 판정 줄이 없다"
      ;;
    file-not-logged)
      has "$L" 'TEST rc=5 JCode=J-LOGIN-01' && ! has "$L" 'login stage: done by'
      t $? "[아니다라는 답] 확인 명령이 「아니다」라고 하면 파일이 새로 생겨도 성공으로 읽지 않는다" "성공으로 읽었다"
      ;;
    stale-file)
      has "$L" 'TEST rc=5 JCode=J-LOGIN-01' && ! has "$L" 'login stage: done by'
      t $? "[예전 파일] 예전 로그인이 남긴 파일은 이번에 고쳐지지 않았으면 성공으로 읽지 않는다" "성공으로 읽었다"
      ;;
    status-hang)
      has "$L" 'login status timeout [0-9]+s: killed' && has "$L" 'login wait timeout [0-9]+min: CloseMainWindow' && has "$L" 'TEST rc=5 JCode=J-LOGIN-01'
      t $? "[확인 명령 멈춤] 확인 명령이 멈춰도 한 번의 상한에서 끄고 J-LOGIN-01 로 닫힌다" "확인 상한·대기 상한 줄 또는 끝 코드가 없다"
      sec="$(sed -nE 's/.*login proc exit=[^ ]* after ([0-9]+)s \(cap\).*/\1/p' "$L" | head -1)"
      [ -n "$sec" ] && [ "$sec" -le 20 ]
      t $? "[확인 명령 멈춤] 20분 상한이 밀리지 않는다(10초 상한 → ${sec:-없음}초)" "상한이 밀렸다"
      [ "$(left 'sleep 307[67]')" = "0" ]; t $? "[확인 명령 멈춤] 멈춘 확인 명령과 창이 남지 않는다" "남은 대기 프로세스 $(left 'sleep 307[67]')개"
      ;;
    inline)
      ! grep -q 'EMU-VENDOR-LOGIN-OUTPUT' "$SB/out.txt" && [ "$calls" = "0" ] && has "$L" 'login stage: start-failed' && has "$L" 'TEST rc=5 JCode=J-LOGIN-01' && has "$L" '스스로 푸는 법'
      t $? "[띄우기 실패] 로그인 프로세스를 못 띄우면 이 창에서 벤더 로그인을 부르지 않고 스스로 푸는 법과 함께 J-LOGIN-01" "벤더 호출 ${calls}번 · 또는 단계 표지·끝 코드·스스로 푸는 법 중 어긋남"
      ;;
    closing-quiet)
      has "$L" 'unexpected end: no error recorded' && has "$L" 'unexpected end: skipped 1 quietly handled' && ! has "$L" 'unexpected end: last error' && has "$L" 'unexpected end: last login stage = confirm'
      t $? "[끝맺음] 조용히 넘긴 확인 오류만 있으면 원인처럼 적지 않는다(마지막 로그인 단계는 적는다)" "$(grep 'unexpected end' "$L" | head -3 | tr '\n' '|' | cut -c1-200)"
      ;;
    closing-loud)
      has "$L" 'unexpected end: last error \(참고 · 끝난 원인이 아닐 수 있음\) = System\.Management\.Automation\.ItemNotFoundException' && has "$L" 'unexpected end: skipped 1 quietly handled'
      t $? "[끝맺음] 조용히 넘기지 않은 오류는 「참고」 표지를 달아 적는다" "$(grep 'unexpected end' "$L" | head -3 | tr '\n' '|' | cut -c1-200)"
      ;;
    clip-inject)
      lines="$(cat "$SB/lines" 2>/dev/null || echo 0)"
      has "$L" 'TEST rc=0 JCode= LoggedIn=True' && has "$L" 'login code sent from clipboard 1 after [0-9]+s' && [ "$lines" = "1" ] && [ "$calls" = "1" ]
      t $? "[클립보드 코드] 복사만 하면 설치기가 코드를 로그인 입력에 넣어 통과한다" "넣은 줄 ${lines} · 승인 창 ${calls}번"
      ! grep -q 'EMUgood' "$L" "$SB/out.txt" && { [ ! -f "$R" ] || ! grep -q 'EMUgood' "$R"; }
      t $? "[클립보드 코드] 코드 원문을 기록·화면·보고에 남기지 않는다" "코드 원문이 남았다"
      ;;
    clip-stale)
      lines="$(cat "$SB/lines" 2>/dev/null || echo 0)"
      [ "$lines" = "0" ] && has "$L" 'TEST rc=5 JCode=J-LOGIN-01' && ! has "$L" 'login code sent'
      t $? "[클립보드 예전 코드] 로그인을 열기 전부터 복사돼 있던 코드는 넣지 않는다" "넣은 줄 ${lines}"
      has "$R" '^- 코드 넣기: 복사된 코드 0회 · 설치 창 붙여넣기 0회'
      t $? "[클립보드 예전 코드] 코드 넣기 횟수를 환경 보고에 싣는다" "보고에 코드 넣기 줄이 없다"
      ;;
    clip-junk)
      lines="$(cat "$SB/lines" 2>/dev/null || echo 0)"
      [ "$lines" = "0" ] && ! grep -qE 'oauth/authorize|short#code|EMUJUNK|emu-before-login' "$L" "$SB/out.txt" && { [ ! -f "$R" ] || ! grep -qE 'oauth/authorize|short#code|EMUJUNK|emu-before-login' "$R"; }
      t $? "[클립보드 모양 아님] 코드 모양이 아닌 복사 내용은 넣지도 적지도 않는다" "넣은 줄 ${lines} · 또는 복사 내용이 남았다"
      ;;
    clip-repeat)
      lines="$(cat "$SB/lines" 2>/dev/null || echo 0)"
      [ "$lines" = "1" ] && [ "$(cnt "$L" 'login code sent from clipboard')" = "1" ]
      t $? "[클립보드 같은 코드] 받아들여지지 않은 같은 코드는 한 번만 넣는다" "넣은 줄 ${lines}"
      ;;
    clip-many)
      lines="$(cat "$SB/lines" 2>/dev/null || echo 0)"
      [ "$lines" = "3" ]
      t $? "[클립보드 여러 코드] 한 번 연 로그인에서 서로 다른 코드도 최대 3회만 넣는다" "넣은 줄 ${lines}"
      ;;
  esac
done

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
