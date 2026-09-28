#!/bin/bash
# 설치기는 앱의 재시도 표식(.pending-restore)을 만들지도 · 읽지도 · 지우지도 않는다 — 0.3.36 A2 결정 ① 의 고정 시험.
#
# 까닭: 이 표식은 cys rotate 가 팩 반영에 실패했을 때(rc 24) 남겨 **앱이 다음 기동에 다시 시도**하게 하는 자가치유 장치다.
#   설치기가 이것을 건드리면(예: 새 설치처럼 보인다고 지우면) 데몬이 죽어 있던 기존 설치의 정당한 재시도까지 죽는다.
#   만들고·읽고·지우는 쪽은 앱·CLI 다(조사 2026-09-24). 설치기 여섯 파일 안의 자리 = 0곳이 지금의 정답이다.
#   (reset-clean 은 작업 폴더를 통째로 지워 표식도 함께 사라진다 — 표식 이름을 따로 부를 까닭이 없다.)
# ⚠알려진 한계(이 시험이 막지 않는 것): 첫 설치 뒤 앱 [재시작] + 팩 반영 실패라는 드문 경로에서 다음 기동이
#   빈 조직 복원 · 「직원 복귀」 알림 1회를 낼 수 있다 — 앱 쪽 판정 몫(설치기 밖).
#
# 쓰는 법: bash tests/pending-restore-untouched.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 설치기가 표식을 부른다
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
RE='pending[-_. ]?restore'
fail=0; n=0
scan() { # scan <폴더> → 적중 줄을 찍는다 · 읽은 파일 수는 SEEN 에
  local f
  SEEN=0
  for f in bootstrap.sh bootstrap.ps1 reset-clean.sh reset-clean.ps1 reinstall.sh reinstall.ps1; do
    [ -f "$1/$f" ] || { echo "  FAIL 파일이 없다: $f"; return 2; }
    SEEN=$((SEEN + 1))
    grep -niE "$RE" "$1/$f" | sed "s|^|  $f:|"
  done
}
out="$(scan "$DIR")"; rc=$?
[ "$rc" -eq 0 ] || { printf '%s\n' "$out"; exit 2; }
if [ -n "$out" ]; then
  echo "  FAIL 설치기가 재시도 표식(.pending-restore)을 부른다:"; printf '%s\n' "$out"; fail=1
else
  echo "  ok   설치기 여섯 파일에서 재시도 표식 자리 0곳"
fi
# 대조군 — 검사가 눈먼 초록이 아닌지: 사본에 한 줄을 넣으면 붉어져야 한다
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$DIR"/bootstrap.sh "$DIR"/bootstrap.ps1 "$DIR"/reset-clean.sh "$DIR"/reset-clean.ps1 "$DIR"/reinstall.sh "$DIR"/reinstall.ps1 "$T/"
printf 'rm -f "$HOME/.cys/.pending-restore"\n' >> "$T/reset-clean.sh"
if [ -n "$(scan "$T")" ]; then echo "  ok   대조군: 한 줄을 넣은 사본은 붉어진다"; else echo "  FAIL 대조군: 넣은 줄을 못 잡는다(검사가 눈멀었다)"; fail=1; fi
exit "$fail"
