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
      [ "$rcl" = "0" ] && has "$L" 'minor=runtime-sanity' && has "$L" '주의: 자가진단 1 가지가 통과하지 못했습니다 \(runtime-sanity\)' && ! has "$L" '가지가 통과하지 못했습니다\.$'
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

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
