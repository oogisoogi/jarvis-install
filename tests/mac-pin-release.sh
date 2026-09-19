#!/bin/bash
# 맥 cys 핀 대조 — 설치기(bootstrap.sh)가 받을 zip 의 **판본·크기·지문·CDHash** 가 우리 릴리스가 실제로 낸 값과 같은가.
#   (TICKET=installer-0326 C2 · 2026-09-18 · 799 적발: checks.sh 는 CYS_FORK_CDHASH 가 40자리인지만 봤다)
#
# ★왜 네트워크를 때리는가: checks.sh 의 [전환] 핀 축은 「40자리 16진수다」까지만 잰다. 한 글자 틀린 CDHash 도
#   그 축은 초록이다 — 그러면 깔린 판을 매번 「다른 판」으로 읽어 [6/10] 에서 471MB 를 다시 받고 바꿔 넣거나,
#   바꿔 넣은 직후 확인(cdh != CYS_FORK_CDHASH)에서 「설치 실패」로 멈춘다. 틀림은 **발행된 zip 과 대조해야만** 보인다.
# ★CDHash 는 SUMS 에 없다 — zip 을 받아 풀어(ditto -x -k) codesign -dvvv 로 잰다(핀을 채울 때와 같은 방법 · bootstrap.sh 핀 주석).
#   471MB 를 매번 받지 않도록, **지문이 릴리스 SUMS 와 일치한 zip 에서 잰 CDHash** 를 그 지문 이름으로 보관해 둔다.
#   같은 지문 = 같은 바이트 = 같은 CDHash 이므로 보관값을 다시 쓰는 것은 재측정과 같다(지문 대조는 매번 새로 한다).
#
# 결과 코드: 0 = 전건 통과 · 1 = 틀림(FAIL) · 2 = 측정 못 함(오프라인 — 부르는 쪽이 「건너뜀」으로 적는다 · 통과로 세지 않는다)
# ⚠오프라인만 2 다. 404·빈 응답·SUMS 가 아닌 응답·풀기/서명 읽기 실패는 전부 1(FAIL)이다
#   (부재를 세는 측정은 자기 실패를 0건으로 표현한다 — 받은 것이 무엇인지부터 단언한다).
# ⚠값은 **주석이 아닌 선언 줄**(줄 머리 `CYS_FORK_…=`)에서만 읽고, 선언이 정확히 한 줄인지부터 잰다.
#
# 쓰는 법: bash tests/mac-pin-release.sh [bootstrap.sh 경로]
#   MAC_PIN_CACHE=<폴더>  보관 자리(기본 ~/.cache/jarvis-habitat/mac-pin-cdhash) · MAC_PIN_NO_CACHE=1 이면 보관값을 안 쓰고 다시 잰다.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SH="${1:-$DIR/../install-master/bootstrap.sh}"
CACHE="${MAC_PIN_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/jarvis-habitat/mac-pin-cdhash}"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
offline() { printf '  skip %s  (오프라인 — curl rc=%s · 측정 못 함은 통과가 아니다)\n' "$1" "$2"; echo "통과 ${PASS} · 실패 ${FAIL} · 측정 못 함(오프라인)"; exit 2; }

echo "== 맥 cys 핀 ↔ 릴리스 대조 (${SH}) =="

# ── 1. 선언 줄에서 핀을 읽는다 ────────────────────────────────────────────
decl() { # decl <변수이름> → 그 선언 줄 하나를 DECL 에 담는다 · 정확히 한 줄이 아니면 rc 1
  local n
  n="$(grep -cE "^$1=" "${SH}" 2>/dev/null)" || n=0
  DECL=""
  [ "${n}" = "1" ] || return 1
  DECL="$(grep -E "^$1=" "${SH}")"
}
VER=""; DLDIR=""; FILE=""; BYTES=""; SHA=""; CDH=""
decl CYS_FORK_VERSION && [[ "${DECL}" =~ ^CYS_FORK_VERSION=\"([0-9]+\.[0-9]+\.[0-9]+)\"[[:space:]]*$ ]] && VER="${BASH_REMATCH[1]}"
[ -n "${VER}" ]; ck "[핀] 판본 선언 한 줄 · 형식 x.y.z (= ${VER:-없음})" $? "판본 핀을 못 읽었다"
decl CYS_FORK_DIR && [[ "${DECL}" =~ ^CYS_FORK_DIR=\"(https://[^\"]+/)\"[[:space:]]*$ ]] && DLDIR="${BASH_REMATCH[1]//\$\{CYS_FORK_VERSION\}/${VER}}"
[ -n "${DLDIR}" ]; ck "[핀] 받을 자리 선언 한 줄 (= ${DLDIR:-없음})" $? "받을 자리를 못 읽었다"
decl CYS_FORK_FILE && [[ "${DECL}" =~ ^CYS_FORK_FILE=\"([^\"]+)\"[[:space:]]*$ ]] && FILE="${BASH_REMATCH[1]//\$\{CYS_FORK_VERSION\}/${VER}}"
[ -n "${FILE}" ]; ck "[핀] 파일 이름 선언 한 줄 (= ${FILE:-없음})" $? "파일 이름을 못 읽었다"
decl CYS_FORK_BYTES && [[ "${DECL}" =~ ^CYS_FORK_BYTES=\"?([0-9]+)\"?[[:space:]]*$ ]] && BYTES="${BASH_REMATCH[1]}"
[ -n "${BYTES}" ]; ck "[핀] 크기 선언 한 줄 (= ${BYTES:-없음})" $? "크기 핀을 못 읽었다"
decl CYS_FORK_SHA256 && [[ "${DECL}" =~ ^CYS_FORK_SHA256=\"([0-9a-f]{64})\"[[:space:]]*$ ]] && SHA="${BASH_REMATCH[1]}"
[ -n "${SHA}" ]; ck "[핀] 지문 선언 한 줄 (= ${SHA:-없음})" $? "지문 핀을 못 읽었다"
decl CYS_FORK_CDHASH && [[ "${DECL}" =~ ^CYS_FORK_CDHASH=\"([0-9a-f]{40})\"[[:space:]]*$ ]] && CDH="${BASH_REMATCH[1]}"
[ -n "${CDH}" ]; ck "[핀] CDHash 선언 한 줄 (= ${CDH:-없음})" $? "CDHash 핀을 못 읽었다"
case "${DLDIR}" in *"/v${VER}/") r=0 ;; *) r=1 ;; esac
[ -n "${VER}" ] && [ "${r}" -eq 0 ]; ck "[핀] 받을 자리에 판본이 박혔다" $? "받을 자리가 다른 판본을 가리킨다"
[ -n "${VER}" ] && [ "${FILE}" = "cysr-macos-arm64-v${VER}.zip" ]; ck "[핀] 파일 이름에 판본이 박혔다" $? "파일 이름이 다른 판본이다"
if [ -z "${DLDIR}" ] || [ -z "${FILE}" ] || [ -z "${SHA}" ]; then echo "통과 ${PASS} · 실패 ${FAIL}"; exit 1; fi

# ── 2. 릴리스 SUMS 와 바이트 대조 ─────────────────────────────────────────
SUMS="${SB}/SHA256SUMS.txt"
code="$(curl -sSL --max-time 60 -o "${SUMS}" -w '%{http_code}' "${DLDIR}SHA256SUMS.txt" 2>/dev/null)"; crc=$?
# 이름 풀기·연결·시간 초과(6·7·28)만 오프라인이다 — 그 밖의 실패는 FAIL 로 센다.
case "${crc}" in 6|7|28) offline "[릴리스] SHA256SUMS.txt 받기" "${crc}" ;; esac
[ "${crc}" -eq 0 ] && [ "${code}" = "200" ]; ck "[릴리스] SHA256SUMS.txt 를 받았다 (HTTP ${code:-없음})" $? "못 받았다 — 404 는 통과가 아니다"
grep -qE '^[0-9a-f]{64}  [^ ]+$' "${SUMS}" 2>/dev/null; ck "[릴리스] 받은 것이 SUMS 형식이다" $? "SUMS 가 아닌 응답을 받았다"
n_line="$(grep -cxF "${SHA}  ${FILE}" "${SUMS}" 2>/dev/null)" || n_line=0
[ "${n_line}" = "1" ]; ck "[릴리스] 핀 지문·파일 이름 = SUMS 의 줄과 바이트 일치" $? "SUMS 에 그 줄이 없다(지문이나 파일 이름이 틀렸다)"
SUMS_OK=$([ "${n_line}" = "1" ] && echo 1 || echo 0)

# ── 3. 릴리스 파일 크기 대조(HEAD · 리디렉션 끝의 값) ──────────────────────
# 마지막 응답이 200 일 때만 그 크기를 쓴다 — 404 본문(「Not Found」 9바이트)의 길이를 파일 크기로 읽지 않는다.
REL_BYTES="$(curl -sSIL --max-time 60 "${DLDIR}${FILE}" 2>/dev/null | tr -d '\r' | awk '/^HTTP\//{s=$2; v=""} tolower($1)=="content-length:"{v=$2} END{if (s=="200") print v}')"
[[ "${REL_BYTES}" =~ ^[0-9]+$ ]]; ck "[릴리스] zip 크기를 읽었다 (= ${REL_BYTES:-없음})" $? "크기를 못 읽었다"
[ "${REL_BYTES}" = "${BYTES}" ]; ck "[릴리스] 핀 크기 = 릴리스 zip 크기" $? "핀 ${BYTES} ≠ 릴리스 ${REL_BYTES:-없음}"

# ── 4. CDHash — 발행된 zip 을 풀어 잰다(지문이 SUMS 와 맞은 zip 에서만) ──────
REL_CDH=""; how=""
if [ "${SUMS_OK}" = "1" ]; then
  if [ "${MAC_PIN_NO_CACHE:-}" != "1" ] && [ -f "${CACHE}/${SHA}" ]; then
    REL_CDH="$(tr -d '[:space:]' < "${CACHE}/${SHA}")"; how="보관값(지문 ${SHA:0:12}… 에서 잰 값)"
  else
    zip="${SB}/${FILE}"
    curl -fsSL --max-time 1800 -o "${zip}" "${DLDIR}${FILE}"; zrc=$?
    case "${zrc}" in 6|7|28) offline "[릴리스] zip 받기" "${zrc}" ;; esac
    got="$(shasum -a 256 "${zip}" 2>/dev/null | awk '{print $1}')"
    [ "${zrc}" -eq 0 ] && [ "${got}" = "${SHA}" ]; ck "[릴리스] 받은 zip 의 지문 = 핀 지문" $? "받은 zip 이 핀과 다르다(${got:-못 잼})"
    if [ "${got}" = "${SHA}" ]; then
      mkdir -p "${SB}/x" && ditto -x -k "${zip}" "${SB}/x" 2>/dev/null
      n_app="$(find "${SB}/x" -maxdepth 1 -name '*.app' | wc -l | tr -d ' ')"
      [ "${n_app}" = "1" ] && [ -d "${SB}/x/cysr.app" ]; ck "[릴리스] zip 최상위 = cysr.app 하나" $? "zip 안 앱이 ${n_app}개이거나 이름이 다르다"
      REL_CDH="$(codesign -dvvv "${SB}/x/cysr.app" 2>&1 | sed -n 's/^CDHash=//p' | head -1)"
      how="방금 받은 zip 에서 잼"
      if [[ "${REL_CDH}" =~ ^[0-9a-f]{40}$ ]]; then mkdir -p "${CACHE}" && printf '%s\n' "${REL_CDH}" > "${CACHE}/${SHA}"; fi
    fi
  fi
fi
[[ "${REL_CDH}" =~ ^[0-9a-f]{40}$ ]]; ck "[릴리스] 발행 zip 의 CDHash 를 읽었다 (= ${REL_CDH:-없음} · ${how:-못 잼})" $? "CDHash 를 못 읽었다(지문 불일치면 재지 않는다)"
[ "${REL_CDH}" = "${CDH}" ]; ck "[릴리스] 핀 CDHash = 발행 zip 의 CDHash" $? "핀 ${CDH} ≠ 발행 ${REL_CDH:-없음} — 깔린 판을 매번 다른 판으로 읽는다"

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
