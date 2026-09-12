#!/bin/bash
# 윈 핀 대조 뮤턴트 — tests/win-pin-release.sh 가 핀 3값(판본·크기·지문)의 틀림을 각각 정말 붉히는가.
#
# ★왜: checks.sh 는 핀을 글자로만 본다. 릴리스와 대조해 틀림을 잡는 곳은 win-pin-release.sh 하나뿐이다.
#   그 대조가 눈먼 초록이 아닌지, 값마다 따로 변이를 걸어 잰다.
# ⚠순서가 판정의 일부다:
#   ① 원본이 **초록**이어야 한다 — 원래 빨간 시험은 변이를 「잡아도」 아무것도 증명하지 않는다.
#   ② 변이가 **실제로 적용**됐는지(그 선언 줄 하나만 달라졌는지) 먼저 단언한다.
#   ③ 판정은 **종료코드**로 하고, **붉어진 축의 집합**이 기대한 집합과 정확히 같은지로 귀속한다
#      (다른 이유로 죽은 적색은 킬이 아니다).
# 기대 집합:
#   M506 지문 첫 글자 변경       → {SUMS 줄 대조}
#   M507 크기 +1                 → {크기 대조}
#   M508 판본 0.14.36 → 0.14.35  → {SUMS 줄 대조, 크기 대조}
#        (판본은 받을 자리·파일 이름을 함께 바꾸므로 한 축만 붉을 수 없다 — 옛 판본 릴리스가 실재해
#         SUMS 는 받아지고, 그 SUMS 에 새 지문 줄이 없고, 옛 파일 크기가 핀과 다르다)
# 원본 파일은 건드리지 않는다 — 사본에만 변이를 건다.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
PS="$DIR/../install-master/bootstrap.ps1"
T="$DIR/win-pin-release.sh"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
L_SUMS='[릴리스] 핀 지문·파일 이름 = SUMS 의 줄과 바이트 일치'
L_SIZE='[릴리스] 핀 크기 = 릴리스 파일 크기'

red_set() { # red_set <출력 파일> → 붉은 축 이름표를 정렬해 한 줄에 하나씩
  sed -n 's/^  FAIL \(.*\)  ← .*$/\1/p' "$1" | sort
}

echo "== 윈 핀 대조 뮤턴트 =="

# ① 원본 초록
bash "${T}" "${PS}" > "${SB}/orig.out" 2>&1; rc=$?
ck "[①] 원본은 초록이다" "${rc}" "원본부터 붉다(rc=${rc}) — 변이를 잡아도 증명이 안 된다: $(grep -m1 FAIL "${SB}/orig.out")"

mutant() { # mutant <번호> <변수 이름> <새 값> <기대 적색 이름표…>
  local id="$1" var="$2" newval="$3"; shift 3
  local m="${SB}/${id}.ps1" old nd want got
  old="$(python3 - "${PS}" "${m}" "${var}" "${newval}" <<'PY'
import re, sys
src, dst, var, new = sys.argv[1:5]
text = open(src, encoding="utf-8", newline="").read()
lines = text.split("\n")
pat = re.compile(r"^(\$" + re.escape(var) + r"[ \t]+=[ \t]+)('?)([^'\s#]+)('?)(.*)$")
idx = [i for i, l in enumerate(lines) if pat.match(l)]
if len(idx) != 1:
    sys.exit(3)
m = pat.match(lines[idx[0]])
if m.group(3) == new:
    sys.exit(4)
lines[idx[0]] = m.group(1) + m.group(2) + new + m.group(4) + m.group(5)
open(dst, "w", encoding="utf-8", newline="").write("\n".join(lines))
print(m.group(3))
PY
)"
  nd="$(diff "${PS}" "${m}" 2>/dev/null | grep -c '^[<>]')"
  [ -n "${old}" ] && [ "${nd}" = "2" ] && grep -q "^\$${var}" "${m}"
  ck "[${id}] 변이 적용 = \$${var} 선언 줄 하나만 달라졌다 (${old} → ${newval})" $? "변이가 안 걸렸거나 다른 줄도 바뀌었다(다른 줄 수 ${nd:-?})"
  bash "${T}" "${m}" > "${SB}/${id}.out" 2>&1; rc=$?
  [ "${rc}" -ne 0 ]; ck "[${id}] 변이는 적색이다(rc=${rc})" $? "틀린 ${var} 가 초록으로 통과한다"
  want="$(printf '%s\n' "$@" | sort)"
  got="$(red_set "${SB}/${id}.out")"
  [ "${want}" = "${got}" ]
  ck "[${id}] 붉어진 축 집합 = 기대 집합" $? "기대={$(printf '%s' "${want}" | tr '\n' '|')} 실제={$(printf '%s' "${got}" | tr '\n' '|')}"
}

SHA="$(grep -E "^\\\$CysWinSha256[[:space:]]+=" "${PS}" | sed -E "s/.*'([0-9a-f]{64})'.*/\1/")"
first="${SHA:0:1}"; [ "${first}" = "0" ] && rep="1" || rep="0"
BYTES="$(grep -E '^\$CysWinBytes[[:space:]]+=' "${PS}" | sed -E 's/.*=[[:space:]]+([0-9]+).*/\1/')"

mutant M506 CysWinSha256 "${rep}${SHA:1}" "${L_SUMS}"
mutant M507 CysWinBytes "$((BYTES + 1))" "${L_SIZE}"
mutant M508 CysVersion "0.14.35" "${L_SUMS}" "${L_SIZE}"

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
