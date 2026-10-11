#!/bin/bash
# 인텔 맥 cys 핀 대조 — 설치기(bootstrap.sh)의 CYS_FORK_X64_* 가 우리 릴리스가 실제로 낸 x64 zip 과 같은가(크기·지문).
#   (0.3.40 · 2026-10-11) 앞 판까지 릴리스와 대조하는 시험은 arm64 값만 쟀다(tests/mac-pin-release.sh) —
#   인텔 값은 한 글자 틀려도 어느 축도 붉지 않았고, 틀리면 인텔 맥만 「받은 파일의 지문이 다르다」 로 멈춘다.
#
# 재는 것: 판본·파일 이름 선언 → 릴리스 SHA256SUMS.txt 의 그 줄과 지문 바이트 일치 → 릴리스 zip 크기(HEAD) = 핀 크기.
#   ⚠CDHash(CYS_FORK_X64_CDHASH)는 재지 않는다 — zip(약 230MB)을 받아 풀어야 한다. 모양(40자리 16진수)만 본다.
#     값이 맞는지는 핀을 채울 때 발행 zip 을 풀어 codesign -dvvv 로 잰다(arm64 쪽 mac-pin-release.sh 와 같은 방법).
# 결과 코드: 0 = 전건 통과 · 1 = 틀림 · 2 = 측정 못 함(오프라인 — 부르는 쪽이 「건너뜀」 으로 적는다 · 통과로 세지 않는다)
#   ⚠오프라인(curl 6·7·28)만 2 다. 404·SUMS 가 아닌 응답은 1 이다(받은 것이 무엇인지부터 단언한다).
# 쓰는 법: bash tests/mac-pin-x64-release.sh [bootstrap.sh 경로]
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SH="${1:-$DIR/../install-master/bootstrap.sh}"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
offline() { printf '  skip %s  (오프라인 — curl rc=%s · 측정 못 함은 통과가 아니다)\n' "$1" "$2"; echo "통과 ${PASS} · 실패 ${FAIL} · 측정 못 함(오프라인)"; exit 2; }

echo "== 인텔 맥 cys 핀 ↔ 릴리스 대조 (${SH}) =="
decl() { # decl <변수이름> → 그 선언 줄 하나를 DECL 에 담는다 · 정확히 한 줄이 아니면 rc 1(주석 줄은 세지 않는다)
  local n
  n="$(grep -cE "^$1=" "${SH}" 2>/dev/null)" || n=0
  DECL=""
  [ "${n}" = "1" ] || return 1
  DECL="$(grep -E "^$1=" "${SH}")"
}
VER=""; DLDIR=""; FILE=""; BYTES=""; SHA=""; CDH=""
decl CYS_FORK_VERSION && [[ "${DECL}" =~ ^CYS_FORK_VERSION=\"([0-9]+\.[0-9]+\.[0-9]+)\"[[:space:]]*$ ]] && VER="${BASH_REMATCH[1]}"
[ -n "${VER}" ]; ck "[인텔 핀] 판본 선언 한 줄 · 형식 x.y.z (= ${VER:-없음})" $? "판본 핀을 못 읽었다"
decl CYS_FORK_DIR && [[ "${DECL}" =~ ^CYS_FORK_DIR=\"(https://[^\"]+/)\"[[:space:]]*$ ]] && DLDIR="${BASH_REMATCH[1]//\$\{CYS_FORK_VERSION\}/${VER}}"
[ -n "${DLDIR}" ]; ck "[인텔 핀] 받을 자리 선언 한 줄 (= ${DLDIR:-없음})" $? "받을 자리를 못 읽었다"
decl CYS_FORK_X64_FILE && [[ "${DECL}" =~ ^CYS_FORK_X64_FILE=\"([^\"]+)\"[[:space:]]*$ ]] && FILE="${BASH_REMATCH[1]//\$\{CYS_FORK_VERSION\}/${VER}}"
[ -n "${VER}" ] && [ "${FILE}" = "cysr-macos-x64-v${VER}.zip" ]; ck "[인텔 핀] 파일 이름 선언 한 줄 · 판본이 박혔다 (= ${FILE:-없음})" $? "파일 이름을 못 읽었거나 다른 판본이다"
decl CYS_FORK_X64_BYTES && [[ "${DECL}" =~ ^CYS_FORK_X64_BYTES=\"?([0-9]+)\"?[[:space:]]*$ ]] && BYTES="${BASH_REMATCH[1]}"
[ -n "${BYTES}" ]; ck "[인텔 핀] 크기 선언 한 줄 (= ${BYTES:-없음})" $? "크기 핀을 못 읽었다(자리표가 남았을 수 있다)"
decl CYS_FORK_X64_SHA256 && [[ "${DECL}" =~ ^CYS_FORK_X64_SHA256=\"([0-9a-f]{64})\"[[:space:]]*$ ]] && SHA="${BASH_REMATCH[1]}"
[ -n "${SHA}" ]; ck "[인텔 핀] 지문 선언 한 줄 (= ${SHA:-없음})" $? "지문 핀을 못 읽었다(자리표가 남았을 수 있다)"
decl CYS_FORK_X64_CDHASH && [[ "${DECL}" =~ ^CYS_FORK_X64_CDHASH=\"([0-9a-f]{40})\"[[:space:]]*$ ]] && CDH="${BASH_REMATCH[1]}"
[ -n "${CDH}" ]; ck "[인텔 핀] CDHash 선언 한 줄 · 40자리 16진수(값 대조는 이 시험 밖)" $? "CDHash 핀을 못 읽었다"
if [ -z "${DLDIR}" ] || [ -z "${FILE}" ] || [ -z "${SHA}" ] || [ -z "${BYTES}" ]; then echo "통과 ${PASS} · 실패 ${FAIL}"; exit 1; fi

# 릴리스 SUMS 와 바이트 대조
SUMS="${SB}/SHA256SUMS.txt"
code="$(curl -sSL --max-time 60 -o "${SUMS}" -w '%{http_code}' "${DLDIR}SHA256SUMS.txt" 2>/dev/null)"; crc=$?
case "${crc}" in 6|7|28) offline "[릴리스] SHA256SUMS.txt 받기" "${crc}" ;; esac
[ "${crc}" -eq 0 ] && [ "${code}" = "200" ]; ck "[릴리스] SHA256SUMS.txt 를 받았다 (HTTP ${code:-없음})" $? "못 받았다 — 404 는 통과가 아니다"
grep -qE '^[0-9a-f]{64}  [^ ]+$' "${SUMS}" 2>/dev/null; ck "[릴리스] 받은 것이 SUMS 형식이다" $? "SUMS 가 아닌 응답을 받았다"
n_line="$(grep -cxF "${SHA}  ${FILE}" "${SUMS}" 2>/dev/null)" || n_line=0
[ "${n_line}" = "1" ]; ck "[릴리스] 인텔 핀 지문·파일 이름 = SUMS 의 줄과 바이트 일치" $? "SUMS 에 그 줄이 없다(지문이나 파일 이름이 틀렸다)"

# 릴리스 파일 크기 대조(HEAD · 리디렉션 끝의 값) — 마지막 응답이 200 일 때만 그 크기를 쓴다
HDR="$(curl -sSIL --max-time 60 "${DLDIR}${FILE}" 2>/dev/null)"; hrc=$?
case "${hrc}" in 6|7|28) offline "[릴리스] x64 zip 크기 읽기" "${hrc}" ;; esac
REL_BYTES="$(printf '%s\n' "${HDR}" | tr -d '\r' | awk '/^HTTP\//{s=$2; v=""} tolower($1)=="content-length:"{v=$2} END{if (s=="200") print v}')"
[[ "${REL_BYTES}" =~ ^[0-9]+$ ]]; ck "[릴리스] x64 zip 크기를 읽었다 (= ${REL_BYTES:-없음})" $? "크기를 못 읽었다"
[ "${REL_BYTES}" = "${BYTES}" ]; ck "[릴리스] 인텔 핀 크기 = 릴리스 x64 zip 크기" $? "핀 ${BYTES} ≠ 릴리스 ${REL_BYTES:-없음}"

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
