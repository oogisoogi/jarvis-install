#!/bin/bash
# 0.3.39 맥 원격 해결이 부르는 cys — [7/10] 이 고른 CYS_CLI(절대 경로)가 먼저 · 없으면 종전 고정 순서.
#
# 재는 것
#   ⓐ CYS_CLI = 절대 경로 · 실행 가능 → 그것(옛 ~/.local/bin/cys 가 먼저 있어도)
#   ⓑ 대조군: CYS_CLI 비었음 → 종전 순서의 첫 것(~/.local/bin/cys)
#   ⓒ CYS_CLI = 'cys'(PATH 이름 · 절대 경로 아님) → 종전 순서(PATH 조회 0)
# 쓰는 법: bash tests/defect-0930-mac-rh.sh [--dir <install-master 자리>] · rc 0 = 통과 · 1 = 실패
# ⛔바깥에 닿지 않는다 — 가짜 HOME · JARVIS_LIB_ONLY · 진행 전송 끔 · 쓰기는 mktemp -d 안에서만.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
BASE="$(mktemp -d -t d0930mrh)" || exit 2
BASE="$(cd "$BASE" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
mkdir -p "$BASE/home/.local/bin" "$BASE/new"
printf '#!/bin/sh\necho old\n' > "$BASE/home/.local/bin/cys"; chmod +x "$BASE/home/.local/bin/cys"
printf '#!/bin/sh\necho new\n' > "$BASE/new/cys"; chmod +x "$BASE/new/cys"
rh() { # rh <CYS_CLI 값> → 원격 해결이 고른 경로
  HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 \
    perl -e 'alarm shift; exec @ARGV or exit 126' 30 /bin/bash -c ". '$SH' >/dev/null 2>&1; CYS_CLI='$1'; remote_help_cys_path > '$BASE/res'" >/dev/null 2>&1
  cat "$BASE/res" 2>/dev/null; rm -f "$BASE/res"
}
r="$(rh "$BASE/new/cys")"; [ "$r" = "$BASE/new/cys" ]; t $? "ⓐ CYS_CLI 절대 경로 → 그것 먼저" "고른 것=$r"
r="$(rh "")"; [ "$r" = "$BASE/home/.local/bin/cys" ]; t $? "ⓑ 대조군: CYS_CLI 없음 → 종전 순서 첫 것" "고른 것=$r"
r="$(rh "cys")"; [ "$r" = "$BASE/home/.local/bin/cys" ]; t $? "ⓒ CYS_CLI = 이름(절대 경로 아님) → 종전 순서" "고른 것=$r"
echo "== 맥 원격 해결 cys: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
