#!/bin/bash
# 0.3.38 윈 설치기 결함 묶음 — 윈 설치기 결함 묶음(거짓 성공 · 옛 설치 자리 오판 · 마법사 폴백 · 창 없음 · V3 보류) 흉내 시험.
#   PowerShell 7 로 실물 bootstrap.ps1 을 함수 묶음(JARVIS_LIB_ONLY)으로 읽고, 설치 목록·실행 파일 판·설치기 실행만 가짜로 준다.
#   ⛔바깥에 닿지 않는다 — 실제 설치 0 · 쓰기는 mktemp -d 안에서만.
#   ⚠여기서 안 재는 것(윈도우 실기 몫): 실제 NSIS 가 /D 로 옛 기억 값을 이기는가 · V3 확인 창이 다시 뜨는가 · 앱이 master 자리를 스스로 만드는가.
# 쓰는 법: bash tests/defect-0930-run.sh [--dir <install-master 자리>] [--only <묶음>] · rc 0 = 통과 · 1 = 실패 · 2 = 잴 수 없음(pwsh 없음)
export JARVIS_NO_PROGRESS=1
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
ONLY=""   # --only <묶음> = body|install|verify|wake|avhold 하나만(변이 구동기가 쓴다 · 없으면 전부)
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2 ;; --only) ONLY="$2"; shift 2 ;; *) echo "모르는 인자: $1" >&2; exit 2 ;; esac; done
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "잴 수 없음: pwsh 가 없다" >&2; exit 2; }
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"; EMU="$HERE/defect-0930-emu"
BASE="$(mktemp -d -t d0930)" || exit 2; BASE="$(cd "$BASE" && pwd -P)"
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
run() { # run <스크립트> <칸>
  [ -z "$ONLY" ] || [ "$ONLY" = "$1" ] || return 0
  local sb="$BASE/$1-$2"; mkdir -p "$sb"
  local out; out="$("$PW" -NoProfile -NonInteractive -File "$EMU/$1.ps1" -Src "$PS" -Sb "$sb" -Case "$2" 2>&1)"
  printf '%s\n' "$out" | grep -E '^  (ok|FAIL) '
  local r; r="$(printf '%s\n' "$out" | sed -n 's/^RESULT pass=\([0-9]*\) fail=\([0-9]*\)$/\1 \2/p' | tail -1)"
  if [ -z "$r" ]; then fail=$((fail+1)); echo "  FAIL $1/$2 결과 줄 없음 ← $(printf '%s' "$out" | tail -3 | tr '\n' '|' | cut -c1-300)"; return; fi
  pass=$((pass+${r% *})); fail=$((fail+${r#* }))
}
echo "== ⓑ 본체 판정 =="
for c in laptop quoted-elsewhere no-cys-exe envvar; do run body "$c"; done
echo "== ⓐⓒ [6/10] 설치 =="
for c in upgrade-fail first-fail-no-wizard d-arg d-cysr-elsewhere d-cysr-partial d-cysr-gone-fixed install-partial d-oldpf d-localcysr refresh-fail skip-missing-app mem-stale-removed mem-gone-dir-removed mem-same-kept mem-exe-kept mem-unread-kept mem-none mem-fail-kept mem-skip-removed mem-remove-throws refresh-late-bins refresh-fail-no-left mem-log-fail f11-skipped-log; do run install "$c"; done
echo "== ⓐⓑ [5/10] · [7/10] =="
for c in dl-skip-missing verify-old verify-body-dir app-body-dir rh-body-dir skipped-no-error verify-ok autostart-old-folder autostart-one-value autostart-body; do run verify "$c"; done
echo "== ⓓ [9/10] 창 실행 파일 =="
for c in no-app-exe card-hint; do run wake "$c"; done
echo "== ⓔ 백신 보류 1분 판정 =="
for c in progress-count except-once button-words vendor-progress-ok vendor-grow-stop vendor-v3-title vendor-growing vendor-none vendor-transcript-grows vendor-setup-done vendor-delete-fail vendor-unread-log vendor-delete-late vendor-no-ok-before direct-none direct-full-size direct-unknown-size direct-first-seen-complete direct-after-vendor direct-exit-fail; do run avhold "$c"; done
echo "== defect-0930: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
