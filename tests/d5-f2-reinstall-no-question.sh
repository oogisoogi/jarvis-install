#!/bin/bash
# D5-F2 검출 시험 — 맥 「다시 설치하기」 한 줄(reinstall.sh)이 사람에게 묻지 않고 설치 단계까지 가는가.
#   박사님 09-21 「중간에 묻는 단계 전부 삭제」 · 윈판 reinstall.ps1 = -KeepApp -Yes(질문 0) 와 같은 끝.
#   입력(stdin)을 닫고 제어 터미널 없이 돈다 — 묻는 줄이 있으면 답을 못 받아 「그만둡니다」로 빠지고 설치 도우미에 닿지 못한다.
# ⛔라이브 무접촉: reset-clean.sh 는 /Applications/cysr.app 의 cys 로 데몬 등록을 떼고 launchctl bootout·그 자리 프로세스를 끈다.
#   ⇒ 시험 사본에서 절대경로 /Applications/·/usr/local/bin/cys 를 가짜 루트로 바꾸고, launchctl·security 는 PATH 가짜로 막는다.
#   받기는 file:// 로(망 0). 설치 도우미 자리에는 「닿았다」만 적는 가짜를 둔다.
# 쓰는 법: bash tests/d5-f2-reinstall-no-question.sh [install-master 경로]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
DIR="${1:-$(cd "$(dirname "$0")/../install-master" && pwd)}"
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f2.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
FR="$T/fakeroot"; SRV="$T/srv"; H="$T/home"; BIN="$T/bin"
mkdir -p "$FR/Applications/cysr.app/Contents/MacOS" "$SRV" "$H" "$BIN"
# 가짜 cys(데몬 해제 요청을 적기만 한다)
printf '#!/bin/bash\necho "fake-cys $*" >> "%s/calls"\n' "$T" > "$FR/Applications/cysr.app/Contents/MacOS/cys"; chmod +x "$FR/Applications/cysr.app/Contents/MacOS/cys"
for b in launchctl security sudo osascript; do printf '#!/bin/bash\necho "%s $*" >> "%s/calls"\nexit 1\n' "$b" "$T" > "$BIN/$b"; chmod +x "$BIN/$b"; done
# 시험 사본 — 절대경로만 가짜 루트로(판정 논리는 무변경)
sed -e "s#/Applications/#$FR/Applications/#g" -e "s#/usr/local/bin/cys#$FR/usr/local/bin/cys#g" "$DIR/reset-clean.sh" > "$SRV/reset-clean.sh"
n_left="$(grep -vE '^[[:space:]]*#' "$SRV/reset-clean.sh" | grep -cE '"/Applications/|[ =]/Applications/')"
[ "$n_left" -eq 0 ] || { echo "FAIL 측정 무효: 사본에 실제 /Applications 경로가 ${n_left}곳 남았다"; exit 2; }
printf '#!/bin/bash\necho BOOTSTRAP-REACHED\n' > "$SRV/bootstrap.sh"
# 지울 것이 있어야 묻는 자리까지 간다 — 설치가 남기는 흔적을 심는다
mkdir -p "$H/install-jarvis" "$H/.cys" "$H/.local/state/cys"
printf 'jarvis-installer-owned v1\n' > "$H/install-jarvis/.jarvis-owned"; : > "$H/install-jarvis/bootstrap.log"
OUT="$T/out.txt"
( cd "$H" && env -i PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$H" LANG=ko_KR.UTF-8 TMPDIR="$T" \
    JARVIS_BASE_URL="file://$SRV" perl -e 'alarm 600; exec @ARGV or exit 126' bash "$DIR/reinstall.sh" ) < /dev/null > "$OUT" 2>&1
rc=$?
fail=0
grep -q '=== 이 컴퓨터의 상태 ===' "$OUT" || { echo "FAIL 측정 무효: 지우기 도구가 돌지 않았다(rc=$rc)"; tail -5 "$OUT" | sed 's/^/  /'; exit 2; }
grep -q '\[있음\]' "$OUT" || { echo "FAIL 측정 무효: 지울 대상이 목록에 없다(묻는 자리까지 못 감)"; exit 2; }
if grep -nE '입력해 주십시오|Enter 를 눌러|Enter 를 누르면' "$OUT" >/dev/null; then
  echo "FAIL 사람에게 묻는 줄이 있다:"; grep -nE '입력해 주십시오|Enter 를 눌러|Enter 를 누르면' "$OUT" | sed 's/^/  /'; fail=1
fi
if ! grep -q '^BOOTSTRAP-REACHED$' "$OUT"; then echo "FAIL 설치 도우미까지 가지 못했다(rc=$rc):"; tail -4 "$OUT" | sed 's/^/  /'; fail=1; fi
if grep -q '=== 지웁니다 ===' "$OUT"; then :; else echo "FAIL 지우기 단계가 실행되지 않았다"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS 입력 닫힌 채 목록 표시 → 지우기 → 설치 도우미 도달 · 묻는 줄 0 (가짜 호출 $(wc -l < "$T/calls" 2>/dev/null | tr -d ' ')건)"
exit "$fail"
