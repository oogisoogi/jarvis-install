#!/bin/bash
# D5-F3 검출 시험 — [5/10]~[8/10] 이 막혔는데 이미 깔린 옛 cys(1.0.2 등)로 자비스를 깨우고 「설치가 끝났습니다」라고 하면 적색.
#   master 16:14 확정: 다운로드·설치 단계가 실패하면 각성 단계에 들어가지 않고 「설치가 끝나지 않았습니다 · 진단 코드」로 끝난다.
#   실물 bootstrap.sh 를 JARVIS_LIB_ONLY=1 로 읽고, 본문의 [5/10]~ 끝 구간(for st_row … step_wake)을 그대로 돌린다.
#   망 0: curl 은 가짜(자산 자리 = 404). 옛 cys 가 깔린 기계 = 가짜 cys 명령 + 자리 열기·함대 확인 함수를 「성공」으로 흉내.
#   ⇒ 흉내가 성공을 돌려줘도 설치기가 「끝났습니다」를 말하지 않아야 한다.
# 쓰는 법: bash tests/d5-f3-no-false-done-when-blocked.sh [bootstrap.sh]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.sh}"
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f3.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home/install-jarvis" "$T/bin"
printf 'jarvis-installer-owned v1\n' > "$T/home/install-jarvis/.jarvis-owned"
printf '#!/bin/bash\necho "fake-old-cys $*" >> "%s/calls"\necho "cys 1.0.2"\n' "$T" > "$T/bin/cys"; chmod +x "$T/bin/cys"
sed -n '/^for st_row in/,$p' "$SRC" > "$T/tail.sh"
grep -q '^step_wake$' "$T/tail.sh" || { echo "FAIL 측정 무효: 본문 끝 구간(for st_row … step_wake)을 찾지 못했다"; exit 2; }
OUT="$T/out.txt"
env -i PATH="$T/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$T/home" LANG=ko_KR.UTF-8 TMPDIR="$T" \
  JARVIS_HOME="$T/home/install-jarvis" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 SRC="$SRC" TAIL="$T/tail.sh" CALLS="$T/calls" \
  perl -e 'alarm 120; exec @ARGV or exit 126' bash -c '
set --; . "$SRC" || exit 5
curl() { echo "curl $*" >> "$CALLS"; case "$*" in *"%{http_code}"*) printf 404; return 0;; esac; return 22; }
sleep() { :; }
MODE=full; CYS_CLI="$(command -v cys)"; NOTICE_SHOWN=1
# 옛 cys 가 살아 있는 기계의 함대 = 전부 성공으로 흉내(이 흉내에 닿는 것 자체가 결함의 경로다)
cys_open_master_seat() { echo "reached:open-seat" >> "$CALLS"; printf "surface:9"; }
live_roles() { printf "master cso worker"; }
confirm_master_awake() { MASTER_STATE=verified; }
confirm_child_seats() { :; }; post_install_evidence() { :; }; raise_cys_app_window() { :; }; note_daemon_group() { :; }
set_fleet_baseline() { FLEET_BASELINE_OK=1; }; clear_master_mark() { :; }; archive_old_round() { :; }
remote_help_run() { :; }; remote_help_maybe() { :; }
ROWS_FILE="$TMPDIR/rows"; : > "$ROWS_FILE"
. "$TAIL"
echo "__TAIL_RETURNED__"
' > "$OUT" 2>&1
rc=$?
fail=0
grep -q 'curl .*releases/download' "$T/calls" 2>/dev/null || { echo "FAIL 측정 무효: [5/10] 받기에 닿지 않았다(rc=$rc)"; tail -5 "$OUT" | sed 's/^/  /'; exit 2; }
if grep -nE '설치가 끝났습니다|설치는 여기까지 끝났습니다|자비스가 깨어났습니다' "$OUT" >/dev/null; then
  echo "FAIL 막혔는데 끝났다고 말한다:"; grep -nE '설치가 끝났습니다|설치는 여기까지 끝났습니다|자비스가 깨어났습니다|진단 코드' "$OUT" | sed 's/^/  /'; fail=1
fi
if grep -q 'reached:open-seat' "$T/calls" 2>/dev/null; then echo "FAIL 막혔는데 각성 단계(자리 열기)에 들어갔다"; fail=1; fi
grep -q '설치가 끝나지 않았습니다' "$OUT" || { echo "FAIL 결과 줄 「설치가 끝나지 않았습니다」가 없다"; fail=1; }
grep -q 'J-DL-05' "$OUT" || { echo "FAIL 진단 코드(J-DL-05)가 화면에 없다"; fail=1; }
[ "$rc" -ne 0 ] || { echo "FAIL 종료 코드가 0 이다(막힌 설치를 성공 코드로 끝냄)"; fail=1; }
[ "$fail" -eq 0 ] && echo "PASS 옛 cys 잔존 + 자산 404 → 각성 진입 0 · 「끝났습니다」 0 · 「설치가 끝나지 않았습니다」 + J-DL-05 · rc=$rc"
exit "$fail"
