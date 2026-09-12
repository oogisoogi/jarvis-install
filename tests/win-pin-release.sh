#!/bin/bash
# 윈 cys 핀 대조 — 설치기(bootstrap.ps1)가 받을 파일의 **판본·크기·지문**이 우리 릴리스가 실제로 적은 값과 같은가.
#
# ★왜 네트워크를 때리는가: checks.sh 의 [5] 축은 「핀이 있다 · 64자리 16진수다」까지만 잰다.
#   한 글자 틀린 지문도 그 축은 초록이다 — 그러면 모든 사람의 설치가 [5/10] 지문 불일치로 멈춘다.
#   틀림은 **릴리스와 대조해야만** 보인다.
# ⚠측정 못 함 = 실패다. 오프라인·404·빈 응답·SUMS 가 아닌 응답은 통과가 아니라 FAIL 로 센다
#   (부재를 세는 측정은 자기 실패를 0건으로 표현한다 — 받은 것이 SUMS 인지부터 단언한다).
# ⚠값은 **주석이 아닌 선언 줄**(줄 머리 `$Cys…`)에서만 읽고, 선언이 정확히 한 줄인지부터 잰다.
#
# 쓰는 법: bash tests/win-pin-release.sh [bootstrap.ps1 경로]   · rc 0 = 전건 통과
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
PS="${1:-$DIR/../install-master/bootstrap.ps1}"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }

echo "== 윈 cys 핀 ↔ 릴리스 대조 (${PS}) =="

# ── 1. 선언 줄에서 핀을 읽는다 ────────────────────────────────────────────
decl() { # decl <변수이름> → 그 선언 줄 하나를 DECL 에 담는다 · 정확히 한 줄이 아니면 rc 1
  local n
  n="$(grep -cE "^\\\$$1[[:space:]]+=" "${PS}" 2>/dev/null)" || n=0
  DECL=""
  [ "${n}" = "1" ] || return 1
  DECL="$(grep -E "^\\\$$1[[:space:]]+=" "${PS}")"
}
VER=""; DLDIR=""; WINFILE=""; BYTES=""; SHA=""
decl CysVersion && [[ "${DECL}" =~ ^\$CysVersion[[:space:]]+=[[:space:]]+\'([0-9]+\.[0-9]+\.[0-9]+)\'[[:space:]]*$ ]] && VER="${BASH_REMATCH[1]}"
[ -n "${VER}" ]; ck "[핀] 판본 선언 한 줄 · 형식 x.y.z (= ${VER:-없음})" $? "판본 핀을 못 읽었다"
decl CysDownloadDir && [[ "${DECL}" =~ ^\$CysDownloadDir[[:space:]]+=[[:space:]]+\"(https://[^\"]+/)\"[[:space:]]*$ ]] && DLDIR="${BASH_REMATCH[1]//\$\{CysVersion\}/${VER}}"
[ -n "${DLDIR}" ]; ck "[핀] 받을 자리 선언 한 줄 (= ${DLDIR:-없음})" $? "받을 자리를 못 읽었다"
decl CysWinFile && [[ "${DECL}" =~ ^\$CysWinFile[[:space:]]+=[[:space:]]+\"([^\"]+)\"[[:space:]]*$ ]] && WINFILE="${BASH_REMATCH[1]//\$\{CysVersion\}/${VER}}"
[ -n "${WINFILE}" ]; ck "[핀] 파일 이름 선언 한 줄 (= ${WINFILE:-없음})" $? "파일 이름을 못 읽었다"
decl CysWinBytes && [[ "${DECL}" =~ ^\$CysWinBytes[[:space:]]+=[[:space:]]+([0-9]+)[[:space:]]*$ ]] && BYTES="${BASH_REMATCH[1]}"
[ -n "${BYTES}" ]; ck "[핀] 크기 선언 한 줄 (= ${BYTES:-없음})" $? "크기 핀을 못 읽었다"
decl CysWinSha256 && [[ "${DECL}" =~ ^\$CysWinSha256[[:space:]]+=[[:space:]]+\'([0-9a-f]{64})\' ]] && SHA="${BASH_REMATCH[1]}"
[ -n "${SHA}" ]; ck "[핀] 지문 선언 한 줄 (= ${SHA:-없음})" $? "지문 핀을 못 읽었다"
# 판본이 받을 자리와 파일 이름에 실제로 박혔는가 — 한쪽만 올리면 옛 파일을 받는다.
case "${DLDIR}" in *"/v${VER}/") r=0 ;; *) r=1 ;; esac
[ -n "${VER}" ] && [ "${r}" -eq 0 ]; ck "[핀] 받을 자리에 판본이 박혔다" $? "받을 자리가 다른 판본을 가리킨다"
[ -n "${VER}" ] && [ "${WINFILE}" = "cys_${VER}_x64-setup.exe" ]; ck "[핀] 파일 이름에 판본이 박혔다" $? "파일 이름이 다른 판본이다"

# ── 2. 릴리스 SUMS 와 바이트 대조 ─────────────────────────────────────────
SUMS="${SB}/SHA256SUMS.txt"
got_sums=1
if [ -n "${DLDIR}" ]; then
  curl -fsSL --max-time 60 -o "${SUMS}" "${DLDIR}SHA256SUMS.txt" && got_sums=0
fi
ck "[릴리스] SHA256SUMS.txt 를 받았다 (${DLDIR}SHA256SUMS.txt)" "${got_sums}" "못 받았다 — 오프라인·404 는 통과가 아니다"
# 받은 것이 정말 SUMS 인가(HTML 오류 쪽이 200 으로 와도 여기서 붉어진다)
grep -qE '^[0-9a-f]{64}  [^ ]+$' "${SUMS}" 2>/dev/null; ck "[릴리스] 받은 것이 SUMS 형식이다" $? "SUMS 가 아닌 응답을 받았다"
n_line="$(grep -cxF "${SHA}  ${WINFILE}" "${SUMS}" 2>/dev/null)" || n_line=0
[ -n "${SHA}" ] && [ "${n_line}" = "1" ]; ck "[릴리스] 핀 지문·파일 이름 = SUMS 의 줄과 바이트 일치" $? "SUMS 에 그 줄이 없다(지문이나 파일 이름이 틀렸다)"

# ── 3. 릴리스 파일 크기 대조(HEAD · 리디렉션 끝의 값) ──────────────────────
REL_BYTES=""
if [ -n "${DLDIR}" ] && [ -n "${WINFILE}" ]; then
  REL_BYTES="$(curl -fsSIL --max-time 60 "${DLDIR}${WINFILE}" 2>/dev/null | tr -d '\r' | awk 'tolower($1)=="content-length:"{v=$2} END{print v}')"
fi
[[ "${REL_BYTES}" =~ ^[0-9]+$ ]]; ck "[릴리스] 설치 파일 크기를 읽었다 (= ${REL_BYTES:-없음})" $? "크기를 못 읽었다 — 오프라인·404 는 통과가 아니다"
[ -n "${BYTES}" ] && [ "${REL_BYTES}" = "${BYTES}" ]; ck "[릴리스] 핀 크기 = 릴리스 파일 크기" $? "핀 ${BYTES:-없음} ≠ 릴리스 ${REL_BYTES:-없음}"

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
