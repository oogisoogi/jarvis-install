#!/bin/bash
# D5-F1 검출 시험 — 저희 판 자산이 404 일 때 맥 설치기가 원작자 판(idoforgod dmg)을 받으러 가면 적색.
#   박사님 09-18 절대 규칙: 참가자 기기도 저희 릴리스로만 받는다(원작자 판 폴백 금지) · 윈판 J-DL-05 와 같은 끝.
#   망에 나가지 않는다 — curl 을 셸 함수로 바꿔 끼워 저희 판 자리는 404 로 답하고, 모든 호출을 기록한다.
# 쓰는 법: bash tests/d5-f1-no-vendor-on-404.sh [bootstrap.sh 경로]   · rc 0 = 통과(원작자 판 시도 0 · J-DL-05)
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.sh}"
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f1.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/home"
CALLS="$T/curl-calls.txt"; : > "$CALLS"
OUT="$T/out.txt"
(
  export HOME="$T/home" JARVIS_HOME="$T/home/install-jarvis" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1
  set --
  # shellcheck disable=SC1090
  source "$SRC" >/dev/null 2>&1 || exit 3
  curl() {
    printf '%s\n' "$*" >> "$CALLS"
    case "$*" in
      *"%{http_code}"*) printf '404'; return 0 ;;   # cys_http_code 의 물음 — 자리에 파일이 없다
    esac
    return 22                                      # 받기(-f) = HTTP 오류
  }
  sleep() { :; }                                   # 연결 대기 고리에 빠져도 시험이 멈추지 않게
  NET_WAIT_TIMEOUT=0
  MODE=full
  [ "$(uname -m)" = "arm64" ] || { cys_use_fork_x64_pin; CYS_X64_PIN_PENDING=0; }
  step_download_cys; echo "rc=$? J_CODE=${J_CODE:-}"
) > "$OUT" 2>&1
fail=0
if [ ! -s "$CALLS" ]; then echo "FAIL 측정 무효: curl 호출이 0건(대상에 닿지 않았다)"; exit 2; fi
if ! grep -q 'oogisoogi/cys-ro/releases/download/' "$CALLS"; then echo "FAIL 측정 무효: 저희 판 자리를 한 번도 묻지 않았다"; exit 2; fi
n_vendor="$(grep -c 'idoforgod' "$CALLS")"
if [ "$n_vendor" -ne 0 ]; then echo "FAIL 원작자 판 자리 호출 ${n_vendor}건:"; grep 'idoforgod' "$CALLS" | sed 's/^/  /'; fail=1; fi
if ! grep -q 'J_CODE=J-DL-05' "$OUT"; then echo "FAIL 끝이 J-DL-05 가 아니다:"; tail -3 "$OUT" | sed 's/^/  /'; fail=1; fi
if ! grep -q '^rc=5 ' "$OUT"; then echo "FAIL rc 가 5 가 아니다(윈판 return 5 와 같아야 한다):"; grep '^rc=' "$OUT" | sed 's/^/  /'; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS 저희 판 404 → 원작자 판 시도 0 · J-DL-05 · rc=5 (curl 호출 $(wc -l < "$CALLS" | tr -d ' ')건)"
exit "$fail"
