#!/bin/bash
# 재설치 사람 손 0 흉내 실행 시험 — PowerShell 7 로 실물 reinstall.ps1 을 처음부터 끝까지 부르고, 그 안에서 실물 reset-clean.ps1 이 -KeepApp -Yes 로 돈다.
#
# 무엇을 재는가 (2026-09-15 · 재설치 길 = 사람 키 입력 0 티켓)
#   ⓐ 재설치 길에서 사람에게 묻는 자리가 0 — Read-Host 를 기록 함수로 바꿔 끼워, 한 번이라도 불리면 그 문구가 남는다
#   ⓑ cys 프로그램 폴더(제거 프로그램 포함)를 지우지 않는다
#   ⓒ 지운 뒤 설치 도우미까지 간다 — 가짜 설치 도우미가 표지를 남기고 재설치가 0 으로 끝난다
#   ⓓ 살펴보기 목록에 「[남김] cys 프로그램」 한 줄
#   ⓔ 나머지는 종전대로 지운다 — ~\.cys · ~\install-jarvis
#   ⓕ 프로그램 폴더 안의 지난 편성 기록(topology.json · phoenix\ · boot-intents\ · dept_tombstones.json · topology.json.*)은 지우고
#      프로그램 파일(cys.exe · pack.tar.gz · runtime\)은 남긴다 — 윈도우 기본 cys 의 상태 자리가 곧 프로그램 폴더라서다(2026-09-15 윈 2차 재설치)
#
# 쓰는 법: bash tests/reinstall-keepapp-emu-run.sh [--dir <install-master 자리>]
#   rc 0 = 전건 통과 · 1 = 실패 있음 · 2 = 잴 수 없음(pwsh 가 없다)
# ⛔바깥에 닿지 않는다 — Invoke-RestMethod 를 가짜 함수로 덮는다(받기 = install-master 사본 복사) · 실제 설치 0 ·
#   쓰기는 mktemp -d 안에서만(USERPROFILE · LOCALAPPDATA · TEMP · JARVIS_HOME · HOME 모두 그 안).
# 🔴Stop-Process 는 흉내에서 아무것도 끄지 않는다 — reset-clean 은 이름(cys-app · cysd · cys)으로 끄는데, 이 맥에서 도는 cys 터미널이 바로 그 이름이다.
# ⚠여기서 **안 재는 것**(윈도우에서만 있는 것): 레지스트리(샌드박스 폴더를 HKCU: 드라이브로 흉내) · 작업 스케줄러(맥에 명령이 없어 빈 목록) ·
#   시작 메뉴 바로가기 · 윈도우 PowerShell 5.1(여기는 pwsh 7) · 백신 개입 · 실제 cys 프로세스 끄기.
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
SRC="$(cd "$DIR" && pwd)"
EMU="$HERE/reinstall-keepapp-emu"
# ⚠mktemp 는 /var/… 를 주는데 /var 는 링크다 — 실경로로 바꿔 둬야 지우개의 링크 관문(Test-SafeJarvisDir)이 조상 링크로 읽지 않는다
BASE="$(mktemp -d -t reinstall-keepapp-emu)" || exit 2
BASE="$(cd "$BASE" && pwd -P)" || exit 2
# 흉내는 뒤에 도는 프로세스를 띄우지 않는다 — 치울 것은 샌드박스뿐이다(다른 러너의 대기 프로세스 이름표는 건드리지 않는다)
cleanup() { rm -rf "$BASE"; }
trap cleanup EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$1" "$2"; }
t() { if [ "$1" -eq 0 ]; then ok "$2"; else bad "$2" "$3"; fi; }
# 멈춘 흉내가 시험 전체를 세우지 않게 상한을 건다(맥에는 timeout 명령이 없다) · 입력은 비워 둔다(묻는 자리가 멈추지 않고 기록되게)
run_ps() { perl -e 'alarm shift; exec @ARGV' 180 "$PW" -NoProfile -NonInteractive -File "$@" </dev/null; }
has() { grep -qE -- "$2" "$1"; }
val() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -1; }

echo "== 재설치 (-KeepApp -Yes) =="
SB="$BASE/keepapp"; mkdir -p "$SB"
run_ps "$EMU/host.ps1" -Src "$SRC" -Sb "$SB" -Pw "$PW" >"$SB/out.txt" 2>"$SB/err.txt"
S="$SB/summary.txt"; U="$SB/C:/Users/emu"; H="$SB/readhost.log"
if [ ! -f "$S" ]; then
  bad "[재설치] 흉내가 끝까지 돌았다" "요약이 없다 — 멈췄거나 죽었다(err: $(head -c 200 "$SB/err.txt"))"
else
  ok "[재설치] 흉내가 끝까지 돌았다"
  n="$( [ -f "$H" ] && wc -l < "$H" | tr -d ' ' || echo 0)"
  [ ! -s "$H" ]
  t $? "[재설치] 재설치 길에서 사람에게 묻는 자리가 0" "묻는 자리 ${n}곳: $(head -3 "$H" 2>/dev/null | tr '\n' '|' | cut -c1-200)"
  [ -d "$U/AppData/Local/cys" ] && [ -f "$U/AppData/Local/cys/uninstall.exe" ]
  t $? "[재설치] cys 프로그램 폴더를 지우지 않는다" "cys 폴더 또는 제거 프로그램이 사라졌다"
  has "$SB/bootstrap-marker.txt" '^FAKE-BOOTSTRAP-RAN$' && [ "$(val "$S" reinstall_rc)" = "0" ]
  t $? "[재설치] 지운 뒤 설치 도우미까지 간다" "설치 도우미 표지 $( [ -f "$SB/bootstrap-marker.txt" ] && echo 있음 || echo 없음) · 재설치 rc=$(val "$S" reinstall_rc) · 지우개 rc=$(val "$S" reset_rc)"
  has "$SB/reset-out.txt" '\[남김\] cys 프로그램'
  t $? "[재설치] 목록에 「[남김] cys 프로그램」 한 줄" "지우개 출력에 그 줄이 없다"
  # ⓔ 는 Drop(파일 자리) 두 곳을 본다 — 윈도우 모양 경로(C:\Users\emu)를 샌드박스의 「C:」 폴더로 흉내 내서 실물 삭제 길이 그대로 탄다.
  #   ~\install-jarvis.ps1 은 여기서 안 본다: 지운 뒤 재설치가 같은 자리에 설치 도우미를 새로 받아 둔다(윈도우도 같다).
  [ ! -e "$U/.cys" ] && [ ! -e "$U/install-jarvis" ]
  t $? "[재설치] 나머지는 종전대로 지운다" "남은 자리: $( [ -e "$U/.cys" ] && echo '~/.cys ')$( [ -e "$U/install-jarvis" ] && echo '~/install-jarvis') · $(grep -E '\[남음\]' "$SB/reset-out.txt" 2>/dev/null | head -2 | tr '\n' '|' | cut -c1-200)"
  C="$U/AppData/Local/cys"
  left=""; for x in topology.json topology.json.corrupt-1 phoenix boot-intents dept_tombstones.json; do [ -e "$C/$x" ] && left="$left $x"; done
  gone=""; for x in cys.exe uninstall.exe pack.tar.gz runtime/emu.txt; do [ -f "$C/$x" ] || gone="$gone $x"; done
  [ -z "$left" ] && [ -z "$gone" ]
  t $? "[재설치] 지난 편성 기록(동료 좌석을 되살리는 기록)은 지우고 프로그램 파일은 남긴다" "남은 기록:${left:- 없음} · 사라진 프로그램 파일:${gone:- 없음}"
fi

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
