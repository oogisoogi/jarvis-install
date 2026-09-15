#!/bin/bash
# v0.3.16 흉내 실행 시험 — PowerShell 7 로 실물 bootstrap.ps1 · reset-clean.ps1 을 「함수 묶음」으로 읽고,
#   가짜 공식 설치기 · 가짜 클로드 · 가짜 네트워크 함수로 **실제로 불러** 기록 파일에 남은 줄을 잰다.
#
# 무엇을 재는가 (2026-09-14 워크숍 도움 채널 12건 · 현장 사진 3장에서 나온 것)
#   ① [2/10] 공식 설치기가 상한에 닿는다 → 자식 프로세스·창 제목·claude.exe 상태를 적는다 → 설치기를 끈다
#      → 공식 주소에서 받아 해시를 대조한다 → 받은 파일로 공식 설치를 짧은 상한으로 해 본다 → 그것도 멈추면 제자리에 둔다
#      → 판본이 답한다 → [2/10] 완료 → [3/10] 로 들어간다  (+ ⑤가 스스로 끝나는 갈래 · 해시가 틀린 갈래 · 백신 창 제목 갈래)
#   ② [3/10] 승인 창이 상한 전에 끝났는데 로그인이 안 됐다 → J-LOGIN-02 → 로그인 화면을 **한 번만** 더 연다
#      (다시 열어 된다 · 다시 열어도 안 된다 → J-LOGIN-01 · 확인 명령이 한 번 던진다 → 설치 계속 · 20분 상한 기록)
#   ③ 지난 실행 표시 — 처방을 받고 닫힌 창에 J-AV-03 을 붙이지 않는다 · 긴 마지막 줄은 120자에서 자른다
#   ④ 지우기 — 클로드 실행 파일 자리에서 도는 프로그램을 번호와 함께 알리고 끈다
#
# 쓰는 법: bash tests/v0316-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — Invoke-RestMethod · Invoke-WebRequest 를 가짜 함수로 덮고 부른 주소만 적는다 · 실제 설치 0 ·
#   쓰기는 mktemp -d 안에서만(USERPROFILE · JARVIS_HOME 모두 그 안).
# ⚠여기서 **안 재는 것**(윈도우에서만 있는 것): 사용자 PATH 등록(맥 .NET 은 User 대상을 무시해 흉내에서는 이름을 이어 준다) ·
#   CIM 프로세스 목록(PowerShell 7 의 Parent 칸으로 대신 잰다) · 창 제목(가짜 함수로 한 갈래만) · 레지스트리 · 콘솔 붙여넣기.
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
RS="$(cd "$DIR" && pwd)/reset-clean.ps1"
EMU="$HERE/v0316-emu"
# ⚠mktemp 는 /var/… 를 주는데 프로세스 경로는 /private/var/… 로 읽힌다 — 실경로로 바꿔 둬야 자리 비교가 맞는다
BASE="$(mktemp -d -t v0316-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
# 흉내가 띄운 대기 프로세스는 이름표(대기 초 수)로 가른다 — 끝나면 남은 것을 치운다
cleanup() { pkill -f 'sleep 30(11|22|33)' 2>/dev/null; rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
# 멈춘 흉내가 시험 전체를 세우지 않게 상한을 건다(맥에는 timeout 명령이 없다)
run_ps() { perl -e 'alarm shift; exec @ARGV' 150 "$PW" -NoProfile -File "$@"; }
has() { grep -qE -- "$2" "$1"; }
cnt() { grep -cE -- "$2" "$1" 2>/dev/null; }
left() { pgrep -f "$1" 2>/dev/null | wc -l | tr -d ' '; }

echo "== ① [2/10] 상한 → 진단 → 직접 받기 =="
for s in hang5 step5ok mismatch av; do
  SB="$BASE/install-$s"; mkdir -p "$SB"
  run_ps "$EMU/install.ps1" -Src "$PS" -Sb "$SB" -Scenario "$s" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"; R="$SB/home/install-jarvis/env-report.md"; N="$SB/net.log"
  [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  case "$s" in
    hang5)
      has "$L" 'install hold diag \(공식 설치기\): 설치기 프로세스 번호 [0-9]+ · 자식: sleep\(번호 [0-9]+ · 부모 [0-9]+'; t $? "[hang5] 상한에서 자식 프로세스 이름·번호·부모를 적는다" "자식 트리 줄이 없다"
      has "$L" 'install hold diag \(공식 설치기\): 백신으로 보이는 창 제목: '; t $? "[hang5] 창 제목 줄을 적는다(없으면 없음)" "창 제목 줄이 없다"
      has "$L" 'install hold diag \(공식 설치기\): ~\\\.local\\bin\\claude\.exe: '; t $? "[hang5] claude.exe 상태 줄을 적는다" "claude.exe 줄이 없다"
      has "$L" 'install hold diag \(공식 설치기\): 공식 설치기가 받던 파일'; t $? "[hang5] 공식 설치기가 받던 파일 줄을 적는다(③/⑤ 판별)" "받던 파일 줄이 없다"
      has "$R" '^## \[2/10\] 설치가 상한에 닿았을 때 본 것'; t $? "[hang5] 같은 진단이 환경 보고(보내는 본문)에도 있다" "환경 보고에 없다"
      [ "$(sed -n 1p "$N")" = "IRM https://downloads.claude.ai/claude-code-releases/stable" ] && [ "$(sed -n 2p "$N")" = "IRM https://downloads.claude.ai/claude-code-releases/9.9.9/manifest.json" ] && sed -n 3p "$N" | grep -q '^IWR https://downloads.claude.ai/claude-code-releases/9.9.9/win32-x64/claude.exe -> '
      t $? "[hang5] 공식 설치기와 같은 주소를 같은 차례로 부른다(판본 → 해시 → 파일)" "부른 주소가 다르다: $(tr '\n' '|' < "$N" | cut -c1-160)"
      has "$L" 'install direct: step4 checksum ok'; t $? "[hang5] 해시를 대조했다" "대조 줄이 없다"
      has "$L" 'install hold diag \(⑤ 받은 파일로 설치\): 설치기 프로세스 번호'; t $? "[hang5] ⑤가 멈추면 그 자리의 진단을 따로 적는다" "⑤ 진단 줄이 없다"
      has "$L" 'install direct: step5 install stable timeout'; t $? "[hang5] ⑤ 결과(상한)를 기록한다" "⑤ 결과 줄이 없다"
      # ⚠기록 줄만 보면 옮기기(Move-Item)를 지워도 초록이었다(v0316-mutate emu-place-skip 눈멂 · 2026-09-14 22:34) — 파일 자리와 임시 파일까지 본다.
      has "$L" 'install direct: placed ~/\.local/bin/claude\.exe' && [ -f "$SB/home/.local/bin/claude.exe" ] && [ ! -e "$SB/home/.local/bin/claude.exe.jarvis-new" ]
      t $? "[hang5] 받은 파일을 제자리에 둔다" "기록 줄·제자리 파일·임시 파일(.jarvis-new) 중 어긋남: $(ls -a "$SB/home/.local/bin" 2>/dev/null | tr '\n' ' ')"
      has "$L" 'install direct: ok 9\.9\.9'; t $? "[hang5] 둔 파일이 판본을 답한다" "판본 답이 없다"
      has "$L" '\[2/10\] 완료: 9\.9\.9' && has "$L" 'TEST install rc=0 JCode=$' && has "$L" '\[3/10\] '
      t $? "[hang5] [2/10] 완료 뒤 [3/10] 로 들어간다" "완료·진입 줄이 없다"
      ! has "$L" 'jcode J-AV-01'; t $? "[hang5] 끝까지 간 설치에 J-AV-01 을 남기지 않는다" "J-AV-01 이 남았다"
      [ "$(left 'sleep 30(11|22)')" = "0" ]; t $? "[hang5] 끈 설치기의 자식이 남지 않는다" "남은 대기 프로세스 $(left 'sleep 30(11|22)')개"
      ;;
    step5ok)
      has "$L" 'install direct: step5 install stable rc=0' && ! has "$L" 'install direct: placed'
      t $? "[step5ok] ⑤가 스스로 끝나면 공식 설치 결과를 그대로 쓴다(직접 두지 않는다)" "⑤ 결과를 안 썼다"
      has "$L" 'TEST install rc=0'; t $? "[step5ok] 설치가 이어진다" "rc 가 0 이 아니다"
      ;;
    mismatch)
      has "$L" 'install wait cap 3000ms \(J-AV-01 before: 1\)'; t $? "[mismatch] 같은 자리 2회째는 짧은 상한을 쓴다" "상한이 줄지 않았다"
      has "$L" 'install direct: step4 checksum mismatch' && ! has "$L" 'install direct: step5' && ! has "$L" 'install direct: placed'
      t $? "[mismatch] 해시가 틀리면 그 파일을 실행하지도 두지도 않는다" "해시가 틀린 파일을 썼다"
      has "$L" 'TEST install rc=4 JCode=J-AV-01'; t $? "[mismatch] 끝내 못 하면 J-AV-01 · 0 이 아닌 값으로 멈춘다" "멈춤 값이 틀렸다"
      [ "$(cnt "$L" '\[scriptblock\]::Create\(\(irm https://claude\.ai/install\.ps1\)\)\) stable')" = "1" ]; t $? "[mismatch] 2회째부터 공식 설치기 한 줄을 직접 안내한다" "안내가 $(cnt "$L" '\[scriptblock\]::Create\(\(irm https://claude\.ai/install\.ps1\)\)\) stable')번"
      ;;
    av)
      has "$L" '지금 떠 있는 창 가운데 백신 창으로 보이는 것: 『AhnLab V3 프로그램 실행 알림 \(V3UI\)』'; t $? "[av] 백신 창 제목이 보이면 그 이름을 그대로 화면에 적는다" "창 제목 안내가 없다"
      ;;
  esac
done

echo "== ② [3/10] 코드 실패 뒤 한 번 더 열기 =="
for s in reopen-ok reopen-fail reopen-then-poll-exc ok-first timeout; do
  SB="$BASE/login-$s"; mkdir -p "$SB"
  run_ps "$EMU/login.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"
  [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다"; continue; }
  n2="$(cnt "$L" 'jcode J-LOGIN-02')"; calls="$(cat "$SB/calls" 2>/dev/null || echo 0)"
  case "$s" in
    reopen-ok)
      [ "$n2" = "1" ] && [ "$calls" = "2" ] && has "$L" 'TEST rc=0 JCode= LoggedIn=True'
      t $? "[reopen-ok] 일찍 끝나고 로그인 안 됨 → J-LOGIN-02 한 번 → 다시 열어 로그인 → 코드 없이 통과" "J-LOGIN-02 ${n2}회 · 승인 창 ${calls}번"
      ;;
    reopen-fail)
      [ "$n2" = "1" ] && [ "$calls" = "2" ] && has "$L" 'TEST rc=5 JCode=J-LOGIN-01'
      t $? "[reopen-fail] 다시 열어도 안 되면 한 번으로 닫히고 J-LOGIN-01" "J-LOGIN-02 ${n2}회 · 승인 창 ${calls}번"
      ;;
    reopen-then-poll-exc)
      has "$L" 'login poll failed 1: ' && has "$L" 'TEST rc=0'
      t $? "[poll-exc] 확인 명령이 한 번 던져도 설치가 끝나지 않고 로그인을 확인한다" "던진 뒤 이어지지 않았다"
      ;;
    ok-first)
      [ "$n2" = "0" ] && has "$L" 'TEST rc=0' && [ "$(cnt "$L" '로그인은 이렇게 해 주십시오 \(3가지만\)')" = "1" ]
      t $? "[ok-first] 한 번에 되면 다시 열지 않고 카드는 한 번" "J-LOGIN-02 ${n2}회"
      ;;
    timeout)
      has "$L" 'login wait timeout [0-9]+min: CloseMainWindow' && has "$L" 'login wait timeout: (Kill|closed without Kill)'
      t $? "[timeout] 승인 대기 상한 도달과 끝낸 방법을 기록 파일에 적는다" "상한 기록 줄이 없다"
      # v0.3.17 — 로그인은 새 창에서 한다. 설치 창은 기다리는 동안 조용하다(경과는 창 제목에만) ⇒ 되풀이가 **없어야** 한다.
      ! grep -q '1) 열려 있는 Claude 탭' "$SB/err.txt"; t $? "[timeout] 기다리는 동안 설치 창(stderr)에 카드를 되풀이하지 않는다" "카드 줄이 화면에 되풀이됐다"
      ;;
  esac
done

echo "== ③ 지난 실행 표시 =="
for s in answer answer-ml wait ended120 closed killed twoRuns; do
  SB="$BASE/prev-$s"; mkdir -p "$SB"
  out="$(run_ps "$EMU/prevrun.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" 2>&1 | grep '^SCENARIO=')"
  case "$s" in
    answer|answer-ml) echo "$out" | grep -q 'lines=2 jav03=0 careLine=1 prevRunCode= '; t $? "[$s] 처방을 받고 닫힌 창 = 두 줄 · J-AV-03 0 · 「처방을 받은 뒤」 한 번" "$out" ;;
    wait)     echo "$out" | grep -q 'lines=2 jav03=0 careLine=0 prevRunCode= '; t $? "[wait] 원격 해결 대기 중 닫힌 창 = 두 줄 · J-AV-03 0" "$out" ;;
    ended120) echo "$out" | grep -q 'state=ended lines=0 '; t $? "[ended120] 원격 해결 시간이 끝나 멈춘 실행 = 아무 말도 안 붙인다" "$out" ;;
    closed)   echo "$out" | grep -q 'state=closed lines=0 '; t $? "[closed] 끝맺음까지 간 실행 = 아무 말도 안 붙인다" "$out" ;;
    killed)   m="$(echo "$out" | sed -E 's/.*maxLineLen=([0-9]+).*/\1/')"; echo "$out" | grep -q 'jav03=2 careLine=0 prevRunCode=J-AV-03 ' && [ "${m:-999}" -le 130 ]
              t $? "[killed] 정말 도중에 사라진 실행 = J-AV-03 · 마지막 줄은 120자에서 자른다" "$out" ;;
    twoRuns)  echo "$out" | grep -q 'jav03=2 '; t $? "[twoRuns] 앞 실행이 아니라 마지막 실행만 본다" "$out" ;;
  esac
done

echo "== ④ 지우기 전 클로드 끄기 =="
if command -v cc >/dev/null 2>&1; then
  SB="$BASE/reset"; mkdir -p "$SB"
  out="$(run_ps "$EMU/resetproc.ps1" -Src "$RS" -Sb "$SB" 2>&1)"
  echo "$out" | grep -q '^before: count=1 ' && echo "$out" | grep -q '(번호 [0-9]*)가 돌고 있습니다 — 끄고 지웁니다\.' && echo "$out" | grep -q '^after: returned-left=0 process-alive=False'
  t $? "[reset] 클로드 실행 파일 자리에서 도는 것을 번호와 함께 알리고 끈다" "$(echo "$out" | tr '\n' '|' | cut -c1-200)"
else
  printf '  skip [reset] 대기 프로그램을 지을 cc 가 없다\n'
fi

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
