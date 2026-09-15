#!/bin/bash
# v0.3.18 흉내 실행 시험 — PowerShell 7 로 실물 bootstrap.ps1 을 「함수 묶음」으로 읽고, 가짜 바깥 프로그램으로 v0.3.18 의 갈래를 실제로 부른다.
#
# 무엇을 재는가 (2026-09-15 · 윈 2·3차 재설치 실기)
#   ⑨ [8/10] 자가진단 — 자비스 창(cys 좌석)을 여는 데 필요한 항목(pack-version · pack-state · install-manifest · hook)이 실패일 때만 막는다(rc 8)
#      · 나머지 실패는 주의로 알리고 이어 간다(rc 0) · 항목 줄을 못 읽으면 앞 판대로 실패 수 전체로 막는다 · 못 읽은 실패 줄은 막는 쪽으로 센다
#
# 쓰는 법: bash tests/v0318-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — 실제 설치·실제 cys 0 · 쓰기는 mktemp -d 안에서만(USERPROFILE · JARVIS_HOME 모두 그 안).
# ⚠여기서 **안 재는 것**(윈도우에서만 있는 것): 실제 cys doctor 의 문안(v0.14.36 코드의 줄 모양을 흉내 낸다) · 데몬 생존(ping 은 가짜가 늘 답한다) ·
#   [9/10] 이 실제로 cys 안에 창을 여는가.
export JARVIS_NO_PROGRESS=1   # 🔴흉내·검사는 라이브 서버로 진행 이벤트를 보내지 않는다(2026-09-15 15:49 사고 · Send-Progress의 레버)
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
EMU="$HERE/v0318-emu"
BASE="$(mktemp -d -t v0318-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
cleanup() { rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
run_ps() { perl -e 'alarm shift; exec @ARGV' 90 "$PW" -NoProfile -File "$@" </dev/null; }
has() { grep -qE -- "$2" "$1"; }

echo "== v0.3.18 ⑨ [8/10] 자가진단 판정 =="
for s in all-ok minor-fail fatal-fail unreadable unread-fail; do
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/prepare.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"
  [ -f "$L" ] || { bad "[⑨ $s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  has "$L" 'TEST finally'; t $? "[⑨ $s] 흉내가 끝까지 돌았다" "마지막 줄이 없다 — 멈췄거나 죽었다(err: $(head -c 160 "$SB/err.txt"))"
  rcl="$(sed -n 's/.*TEST rc=//p' "$L" | tail -1)"
  case "$s" in
    all-ok)
      [ "$rcl" = "0" ] && has "$L" '자리를 잡았습니다 \(실패 0\)'
      t $? "[⑨ 전부 통과] 실패 0 이면 자리를 잡는다" "rc=$rcl" ;;
    minor-fail)
      [ "$rcl" = "0" ] && has "$L" 'minor=runtime-sanity' && has "$L" '참고: 자가진단 1 가지는 자비스 창과 무관한 항목이라 이어 갑니다 \(runtime-sanity · 고장이 아닙니다' && has "$L" 'doctor minor \(not a failure\): runtime-sanity' && ! has "$L" '통과하지 못했습니다'
      t $? "[⑨ 주의만] 자비스 창과 무관한 항목 실패는 막지 않고 주의로 알린다" "rc=$rcl · $(grep -E 'doctor seat judgment' "$L" | tail -1 | cut -c1-200)" ;;
    fatal-fail)
      [ "$rcl" = "8" ] && has "$L" '자비스 창을 여는 데 필요한 항목: hook'
      t $? "[⑨ 막음] 자비스 창에 필요한 항목(hook)이 실패면 막는다" "rc=$rcl" ;;
    unreadable)
      [ "$rcl" = "8" ] && has "$L" 'items=0 fail=1 .* block=1'
      t $? "[⑨ 못 읽음] 항목 줄을 못 읽으면 실패 수 전체로 막는다" "rc=$rcl · $(grep -E 'doctor seat judgment' "$L" | tail -1 | cut -c1-200)" ;;
    unread-fail)
      [ "$rcl" = "8" ] && has "$L" 'unread=1 block=1'
      t $? "[⑨ 못 읽은 실패] 요약의 실패 수보다 읽은 실패 줄이 적으면 막는 쪽으로 센다" "rc=$rcl · $(grep -E 'doctor seat judgment' "$L" | tail -1 | cut -c1-200)" ;;
  esac
done

echo "== v0.3.18 ①② [5/10]·[6/10] 판본 · 판번+지문 이중 대조 · 웹 표식 · 대기 표지 =="
for s in ver-same ver-same-pin ver-same-exe ver-same-refresh-fail ver-old ver-old-fail ver-fresh ver-unknown motw-badsha wait-hb evidence-stall; do
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"
  [ -f "$L" ] || { bad "[$s] 기록 파일" "흉내가 기록을 남기지 못했다(err: $(head -c 200 "$SB/err.txt"))"; continue; }
  has "$L" 'TEST finally'; t $? "[$s] 흉내가 끝까지 돌았다" "마지막 줄이 없다(err: $(head -c 160 "$SB/err.txt"))"
  r="$(sed -n 's/.*TEST //p' "$L" | grep '^r5=' | tail -1)"
  niwr="$(grep -c '^IWR ' "$SB/iwr.log" 2>/dev/null)"; niwr="${niwr:-0}"
  nrun="$(grep -c '^RUN ' "$SB/installer.log" 2>/dev/null)"; nrun="${nrun:-0}"
  nsw="$(grep -c '^RUN .* \[/S\]$' "$SB/installer.log" 2>/dev/null)"; nsw="${nsw:-0}"
  nub="$(grep -c '^UNBLOCK ' "$SB/motw.log" 2>/dev/null)"; nub="${nub:-0}"
  stamp_pin="$(grep -c "\"setup_sha256\": *\"$(printf 'emu cys installer v0318' | shasum -a 256 | cut -d' ' -f1)\"" "$SB/cysdir/jarvis-cys-pin.json" 2>/dev/null)"; stamp_pin="${stamp_pin:-0}"
  why="$r · 받기 ${niwr} · 설치기 ${nrun}(/S ${nsw}) · 표식 지우기 ${nub} · 표지 핀 ${stamp_pin}"
  case "$s" in
    ver-same)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "0" ] && [ "$nrun" = "0" ] && has "$L" '같은 판\(v[0-9.]+\)의 cys 가 이미 설치돼 있습니다 \(지문 확인\) — 받지 않고'
      t $? "[② 같은 판·같은 지문] 판번과 지문이 둘 다 같으면 받지도 설치하지도 않는다" "$why" ;;
    ver-same-pin)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "1" ] && [ "$nsw" = "1" ] && has "$L" 'cys same version content pin-changed' && has "$L" 'cys refresh same version [0-9.]+ \(pin-changed\)' && has "$L" '\[6/10\] 설치를 마쳤습니다' && [ "$stamp_pin" = "1" ]
      t $? "[이중 대조 · 핀 바뀜] 판번이 같아도 핀 지문이 표지와 다르면 다시 받아 덮어 깔고 표지를 새 핀으로 고친다" "$why" ;;
    ver-same-exe)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "1" ] && [ "$nsw" = "1" ] && has "$L" 'cys same version content exe-changed' && has "$L" '\[6/10\] 설치를 마쳤습니다' && has "$L" 'cys pin stamp: written'
      t $? "[이중 대조 · 깔린 파일 다름] 판번·핀이 같아도 깔린 cys.exe 실측 지문이 표지와 다르면 덮어 깐다" "$why" ;;
    ver-same-refresh-fail)
      [ "$r" = "r5=0 r6=0" ] && [ "$nsw" = "1" ] && has "$L" 'cys refresh same version [0-9.]+ \(no-stamp\)' && ! has "$L" '설치를 마쳤습니다' && ! has "$L" 'cys pin stamp: written' && has "$L" 'cys upgrade failed - continue with'
      t $? "[이중 대조 · 덮어 깔기 실패] 설치기가 성공(0)을 답하지 않으면 마쳤다고 하지 않고 표지도 쓰지 않는다(판번은 처음부터 같다)" "$why" ;;
    ver-old)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "1" ] && [ "$nrun" = "1" ] && [ "$nsw" = "1" ] && has "$L" 'cys upgrade 0\.14\.30 -> ' && has "$L" '\[6/10\] 설치를 마쳤습니다' && has "$L" 'cys pin stamp: written'
      t $? "[① 옛 판] 판본이 다르면 받아서 조용한 설치(/S)로 덮어 깔고 표지를 남긴다" "$why" ;;
    ver-old-fail)
      [ "$r" = "r5=0 r6=0" ] && [ "$nrun" = "1" ] && [ "$nsw" = "1" ] && ! has "$L" '설치를 마쳤습니다' && has "$L" 'cys upgrade failed - continue with 0\.14\.30'
      t $? "[① 덮어 깔기 실패] 판본이 안 바뀌면 마쳤다고 하지 않고 · 설치 창을 띄우지 않고 · 쓰던 판으로 이어 간다" "$why" ;;
    ver-fresh)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "1" ] && [ "$nsw" = "1" ] && has "$L" '\[6/10\] 설치를 마쳤습니다'
      t $? "[① 새 기계] cys 가 없으면 종전대로 받아 설치한다" "$why"
      [ "$nub" = "1" ] && has "$L" 'motw: removed after sha256 match - cys_[0-9.]+_x64-setup\.exe'
      t $? "[MOTW 해제] 지문이 핀과 같다고 확인한 설치 파일의 웹 표식을 지운다" "$why" ;;
    ver-unknown)
      [ "$r" = "r5=0 r6=0" ] && [ "$niwr" = "0" ] && [ "$nrun" = "0" ] && has "$L" 'cys installed version unknown - keep'
      t $? "[① 판본 모름] 판본을 못 읽으면 있는 것을 그대로 쓴다(받기·설치 0)" "$why" ;;
    motw-badsha)
      [ "$r" = "r5=5 r6=skip" ] && [ "$nub" = "0" ] && [ "$nrun" = "0" ] && ! has "$L" 'motw: '
      t $? "[MOTW 경계] 지문이 핀과 다른 파일은 표식을 지우지 않는다(검증이 먼저)" "$why"
      [ "$(grep -c '"reason":"fail"' "$SB/evidence.log" 2>/dev/null)" = "1" ] && grep -q '"masked":true' "$SB/evidence.log"
      t $? "[증거 · 실패] 진단 코드(실패)를 남기면 증거 이벤트를 한 번 보낸다(reason=fail · masked)" "$(head -c 200 "$SB/evidence.log" 2>/dev/null)" ;;
    wait-hb)
      [ "$r" = "r5=0 r6=0" ] && [ "$(grep -c '^PROG 6/10 wait ' "$SB/progress.log" 2>/dev/null)" = "2" ] && grep -qx 'PROG 6/10 wait 60' "$SB/progress.log" && grep -qx 'PROG 6/10 wait 120' "$SB/progress.log" && [ "$(grep -c '^WAIT 60000$' "$SB/wait.log")" = "2" ] && grep -qx 'WAIT 30000' "$SB/wait.log"
      t $? "[대기 표지] [6/10] 설치기를 기다리는 동안 60초마다 대기 표지를 보내고 · 조각 합이 상한을 넘지 않는다" "$why · $(tr '\n' '|' < "$SB/progress.log" 2>/dev/null) · $(tr '\n' '|' < "$SB/wait.log" 2>/dev/null)"
      [ ! -s "$SB/evidence.log" ]
      t $? "[증거 · 정체 문턱] 3분 전(120초)에는 증거를 보내지 않는다" "$(head -c 200 "$SB/evidence.log" 2>/dev/null)" ;;
    evidence-stall)
      E="$SB/evidence.log"
      [ "$(grep -c '^EVID 6/10 ' "$E" 2>/dev/null)" = "1" ] && grep -q '"reason":"stall"' "$E" && grep -q '"masked":true' "$E" && [ "$(grep -c '^PROG 6/10 wait ' "$SB/progress.log")" = "4" ]
      t $? "[증거 · 정체] 대기 3분을 넘기면 증거를 (단계당) 한 번만 보낸다(reason=stall · masked)" "$(cut -c1-160 "$E" 2>/dev/null | tr '\n' '|') · 대기 $(grep -c '^PROG 6/10 wait ' "$SB/progress.log")"
      grep -qF '<EMAIL>' "$E" && grep -qF 'Users\\<USER>\\install-jarvis' "$E" && grep -qF '<TOKEN>' "$E" && grep -qF 'Paste code here if prompted > <LOGIN_CODE>' "$E" && grep -qF 'USERNAME=<USER>' "$E" && ! grep -qE 'hong\.gildong|emuSECRET123|emu-not-hash-shaped|hongemu|Users\\hong' "$E"
      t $? "[증거 · 마스킹] 보내는 글에서 이메일·토큰·로그인 코드·홈 경로 계정명·표시된 이름이 지워졌다" "$(grep -o 'EMU screen[^|]*' "$E" | head -3 | tr '\n' '|' | cut -c1-300)" ;;
  esac
done

echo "== v0.3.18 증거 마스킹 — 대조표(mask-vectors.json) 전건 · 식 드리프트 =="
SB="$BASE/mask-vectors"; mkdir -p "$SB"
V0318_MASK_VECTORS="$HERE/mask-vectors.json" run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario mask-vectors -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
nv="$(grep -c 'TEST vec [0-9]* ok ' "$L" 2>/dev/null)"; nbad="$(grep -c 'TEST vec [0-9]* BAD ' "$L" 2>/dev/null)"
[ "${nv:-0}" -ge 13 ] && [ "${nbad:-0}" = "0" ] && has "$L" "TEST vectors=${nv} drift=none"
t $? "[마스킹 벡터] 대조표 vectors 전건이 같은 입력 → 같은 출력이고 · 식이 대조표 ps1_regex 와 글자까지 같다" "통과 ${nv:-0} · 불일치 ${nbad:-0} · $(grep -a -E 'TEST (vec [0-9]+ BAD|drift|vectors)' "$L" | tr '\n' '|' | cut -c1-300) (err: $(head -c 160 "$SB/err.txt"))"
# 대조표 사본이 정본(web-install 725093c)과 같은 바이트인가 — 사본만 고치고 정본을 안 고치는 드리프트를 막는다
[ "$(shasum -a 256 "$HERE/mask-vectors.json" | cut -d' ' -f1)" = "dbafa096016b550709af1dd28b88a5ae2df39a42de82a04e2d68db0e0f945990" ]
t $? "[마스킹 벡터] 사본(tests/mask-vectors.json)이 정본 web-install 8571653(725093c 이후 순서 골든 4건 추가) 과 바이트가 같다" "사본 지문이 다르다 — 정본을 고친 뒤 사본을 새로 떠라"

SB="$BASE/progress-body"; mkdir -p "$SB"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario progress-body -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
has "$SB/home/install-jarvis/bootstrap.log" 'TEST body event=evidence reason=stall masked=True text=emu <EMAIL> tail step=6/10'
t $? "[증거 · 본문 칸] 실물 Send-Progress 가 evidence 의 text·reason·masked 를 요청 본문에 싣는다" "$(grep -a 'TEST body' "$SB/home/install-jarvis/bootstrap.log" | tail -1 | cut -c1-200) (err: $(head -c 160 "$SB/err.txt"))"

echo "== v0.3.18 ⓗ 맥 로그인 코드 자동 넣기(tests/v0318-mac-login-run.sh) =="
MAC_OUT="$(bash "$HERE/v0318-mac-login-run.sh" --dir "$DIR" 2>&1)"; mrc=$?
printf '%s\n' "$MAC_OUT" | grep -E '^  (ok|FAIL) ' | sed 's/^  ok   /  ok   /'
[ "$mrc" -eq 0 ]; t $? "[맥 로그인] 맥 로그인 흉내 전건 통과" "$(printf '%s' "$MAC_OUT" | grep -E 'FAIL' | head -3 | tr '\n' '|')"

echo "== v0.3.18 ⓓ 클로드 stable 채널 =="
SB="$BASE/settings"; mkdir -p "$SB"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario settings -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
has "$L" 'TEST channel=stable skip=True'
t $? "[stable 설정] settings.json 에 autoUpdatesChannel=stable 을 심는다(윈)" "$(grep -a 'TEST channel' "$L" | tail -1) (err: $(head -c 160 "$SB/err.txt"))"
grep -vE '^[[:space:]]*#' "$PS" | grep -qF -e "-ArgumentList @('-NoProfile', '-Command', \"& ([scriptblock]::Create((irm '\$ClaudeInstallUrl' -UseBasicParsing))) \$ClaudeChannel\")" && grep -qE "^\\\$ClaudeChannel +=[[:space:]]+'stable'" "$PS" && grep -vE '^[[:space:]]*#' "$PS" | grep -qF "(\$ClaudeDirectBaseUrl + '/' + \$ClaudeChannel)" && grep -vE '^[[:space:]]*#' "$PS" | grep -qF -e "-ArgumentList 'install',\$ClaudeChannel"
t $? "[stable 설치] 윈 설치기 세 자리(공식 설치기 인자 · 직접 받기 판본 자리 · install 하위명령)가 stable 채널을 쓴다" "한 자리 이상이 latest 로 남았다"
SHF="$(cd "$DIR" && pwd)/bootstrap.sh"
[ "$(grep -vE '^[[:space:]]*#' "$SHF" | grep -cF '| bash -s "$CLAUDE_CHANNEL" )')" = "2" ] && grep -qE '^CLAUDE_CHANNEL="stable"$' "$SHF" && grep -vE '^[[:space:]]*#' "$SHF" | grep -qF 'plutil -replace autoUpdatesChannel -string "$CLAUDE_CHANNEL"'
t $? "[stable 맥] 맥 설치기 두 자리(설치·재시도)가 bash -s stable 이고 settings.json 에 채널을 심는다" "맥 쪽이 latest 로 남았다"

echo "== v0.3.18 ⓔ 화면 머리글 · 핀 자리 =="
grep -vE '^[[:space:]]*#' "$PS" | grep -qF 'Say "=== 자비스 설치 도우미 — $CysDisplayName $CysVersion · 설치 도우미 $InstallerVersion (모드: $Mode) ==="' && [ "$(grep -cE '^\$CysDisplayName +=' "$PS")" = "1" ]
t $? "[머리글 윈] 「<이름> <판> · 설치 도우미 <설치기 판>」 을 핀 변수로 찍는다" "머리글이 핀 변수를 안 쓴다"
grep -vE '^[[:space:]]*#' "$SHF" | grep -qF 'say "=== 자비스 설치 도우미 — ${CYS_DISPLAY_NAME} ${CYS_PIN_VERSION} · 설치 도우미 ${INSTALLER_VERSION} (모드: $MODE) ==="' && [ "$(grep -cE '^CYS_DISPLAY_NAME=' "$SHF")" = "1" ]
t $? "[머리글 맥] 맥도 같은 모양을 핀 변수로 찍는다" "맥 머리글이 핀 변수를 안 쓴다"

echo "== v0.3.18 ④ 기록 글자표 =="
SB="$BASE/log-utf8"; mkdir -p "$SB"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario log-utf8 -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
LC_ALL=C grep -qF "$(printf 'EMU-UTF8 \342\206\222 \355\225\234\352\270\200')" "$L" 2>/dev/null
t $? "[④ 기록 글자표] 기본 글자표가 UTF-8 이 아니어도 「→」·한글을 UTF-8 로 적는다" "$(grep -a 'EMU-UTF8' "$L" 2>/dev/null | head -1 | od -c | head -2 | tr -s ' ' | tr '\n' '|' | cut -c1-200)"
SB="$BASE/prev-read"; mkdir -p "$SB/home/install-jarvis"
printf '2026-09-15T10:00:00+09:00 === 자비스 설치 도우미 v0.3.17 ===\n2026-09-15T10:05:00+09:00 다음에 할 일: 없습니다 — 설치가 끝났습니다\n' > "$SB/home/install-jarvis/bootstrap.log"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario prev-read -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
has "$L" 'TEST prev=closed$'
t $? "[④ 지난 실행] 기본 글자표가 UTF-8 이 아니어도 지난 실행의 한글 줄을 읽어 상태를 가른다" "$(grep -a 'TEST prev=' "$L" | tail -1 | cut -c1-120) (err: $(head -c 120 "$SB/err.txt"))"

echo "== v0.3.18 ⑤ 끝맺음 — 조용히 넘긴 확인 =="
for s in closing-forms closing-forms-loud; do
  SB="$BASE/$s"; mkdir -p "$SB"
  run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario "$s" -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
  L="$SB/home/install-jarvis/bootstrap.log"
  case "$s" in
    closing-forms)
      has "$L" 'unexpected end: no error recorded' && has "$L" 'unexpected end: skipped 6 quietly handled' && ! has "$L" 'last error'
      t $? "[⑤ 조용한 형태] -EA 0 · 콜론 · 여러 줄 · 2>\$null · 바깥 명령에서 막은 오류를 끝난 원인처럼 적지 않는다" "$(grep -a 'unexpected end' "$L" | tr '\n' '|' | cut -c1-240)" ;;
    closing-forms-loud)
      has "$L" 'unexpected end: last error \(참고 · 끝난 원인이 아닐 수 있음\) = System.Management.Automation.ItemNotFoundException' && has "$L" 'skipped 7 quietly handled'
      t $? "[⑤ 섞임] 조용한 오류 사이의 조용하지 않은 오류는(같은 줄에 조용한 확인이 있어도) 여전히 참고로 적는다" "$(grep -a 'unexpected end' "$L" | tr '\n' '|' | cut -c1-240)" ;;
  esac
done

echo "== v0.3.18 ⑥ 사용자 PATH 에 cys 자리 =="
SB="$BASE/path-new"; mkdir -p "$SB"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario path-new -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
has "$L" 'TEST userpath=C:\\Windows;C:\\Users\\emu\\AppData\\Local\\cys$' && [ "$(grep -c 'seed-cys-path: added' "$L")" = "1" ] && [ "$(grep -c 'seed-cys-path: already' "$L")" = "1" ]
t $? "[⑥ 멱등] 없으면 한 번 넣고 · 두 번째(끝 역슬래시)는 넣지 않는다" "$(grep -a -E 'TEST userpath|seed-cys-path' "$L" | tr '\n' '|' | cut -c1-240)"
SB="$BASE/path-dup"; mkdir -p "$SB"
run_ps "$EMU/cys.ps1" -Src "$PS" -Scenario path-dup -Sb "$SB" >"$SB/out.txt" 2>"$SB/err.txt"
L="$SB/home/install-jarvis/bootstrap.log"
has "$L" 'TEST userpath=C:\\Windows;C:\\Users\\emu\\AppData\\Local\\CYS\\$' && [ ! -f "$SB/pathset.log" ]
t $? "[⑥ 멱등 · 다른 표기] 대소문자·끝 역슬래시만 다른 자리가 있으면 건드리지 않는다" "$(grep -a -E 'TEST userpath|seed-cys-path' "$L" | tr '\n' '|' | cut -c1-240)"
awk '/^function Step-VerifyCys/{f=1} f&&/^[[:space:]]*if .*Seed-CysPath \(Split-Path \$b\.Cli -Parent\)/{ok=1} f&&/^}/{f=0} END{exit !ok}' "$PS"
t $? "[⑥ 부르는 자리] [7/10] 이 cys 를 확인한 뒤 cys 자리를 사용자 PATH 에 넣는다" "Step-VerifyCys 안에 Seed-CysPath 호출이 없다"
RS="$(cd "$DIR" && pwd)/reset-clean.ps1"
awk '/^function Get-UserPathSeedDirs/{f=1} f&&/^[[:space:]]*if \(-not \$KeepApp\) \{ \$d \+= \$CysDir/{ok=1} f&&/^}/{f=0} END{exit !ok}' "$RS" && [ "$(grep -vE '^[[:space:]]*#' "$RS" | grep -c 'Get-UserPathSeedDirs')" = "3" ]
t $? "[⑥ 지우는 쪽] 지우개는 프로그램까지 지울 때만 cys 자리를 사용자 PATH 에서 뺀다(-KeepApp 이면 남긴다)" "Get-UserPathSeedDirs 갈래 또는 확인·지우기 두 자리의 사용이 없다"

echo "== v0.3.18 ③ 화면 줄의 기호 이모지(정적 축 · 윈 콘솔 글자 폭은 흉내로 못 잰다) =="
# 윈 4차 실기: ⚠(U+26A0) 가 든 절만 뒤 줄이 겹쳐 찍혔다 — 지우개·재설치의 화면 줄(주석 밖 Write-Host)에 그 글자가 없어야 한다
for f in reset-clean.ps1 reinstall.ps1; do
  n="$(grep -vE '^[[:space:]]*#' "$(cd "$DIR" && pwd)/$f" | grep 'Write-Host' | grep -c "$(printf '\342\232\240')")"
  [ "$n" = "0" ]
  t $? "[③ 기호 이모지] $f 의 화면 줄에 ⚠ 가 없다" "화면 줄 ${n}곳에 ⚠ 가 있다"
done

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
