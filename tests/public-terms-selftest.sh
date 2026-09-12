#!/bin/bash
# 공개 용어 검사기 자체 시험 + 뮤턴트(M500~M505) — 검사기가 눈먼 초록이 아닌지 잰다.
#
# 쓰는 법: bash tests/public-terms-selftest.sh   · rc 0 = 사례 전건 통과 + 뮤턴트 전부 기대한 사례에서 적색
# ★낱말은 가짜(ZZALPHA 등)만 쓴다 — 이 파일도 공개된다.
# ⚠순서가 판정의 일부다: ①원본 사례 전건 초록 ②뮤턴트마다 변이 적용을 먼저 단언(정확히 1곳)
#   ③변이본으로 사례를 돌려 **기대한 사례가** 붉어졌는지로 귀속(다른 사례만 붉으면 킬로 세지 않는다).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
CHK="${DIR}/public-terms-check.sh"
SB="$(mktemp -d)"
trap 'rm -rf "${SB}"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }

# ── 가짜 트리 ─────────────────────────────────────────────────────────────
F="${SB}/fx"
mkdir -p "${F}/clean/.git" "${F}/dirty/sub" "${F}/empty"
printf 'ZZALPHA\nqq[0-9]{3}qq\n' > "${F}/terms.txt"
printf '# 주석뿐\n\n' > "${F}/terms-empty.txt"
printf 'hello\n' > "${F}/clean/a.txt"
printf 'ZZALPHA 는 .git 안에 있다\n' > "${F}/clean/.git/config"
printf 'line one\n  keep ZZALPHA here\nqq123qq\n' > "${F}/dirty/sub/b.sh"
mkdir -p "${F}/double"
printf 'ZZALPHA 와 qq456qq 가 한 줄에\n' > "${F}/double/d.txt"   # 두 패턴이 한 줄에 — 한 줄은 한 번만 센다
printf 'sub/b.sh\t  keep ZZALPHA here\n' > "${F}/allow.txt"
printf 'sub/b.sh\tkeep ZZALPHA here\n' > "${F}/allow-loose.txt"
: > "${F}/allow-none.txt"

# 사례 표: 이름 · 기대 rc · 출력에 있어야 할 문구(없으면 -) · 인자
run_cases() { # run_cases <검사기> → 붉은 사례 이름을 공백으로 이어 RED 에 담는다
  local c="$1" out rc
  RED=""
  one() {
    local name="$1" want="$2" must="$3"; shift 3
    out="$(cd "${F}" && bash "${c}" "$@" 2>&1)"; rc=$?
    if [ "${rc}" != "${want}" ]; then RED="${RED} ${name}"; return; fi
    if [ "${must}" != "-" ] && ! printf '%s\n' "${out}" | grep -qF "${must}"; then RED="${RED} ${name}"; fi
  }
  one C1-clean 0 '적중 0' --root clean --terms terms.txt --allow allow-none.txt
  one C2-hits 1 '적중 2' --root dirty --terms terms.txt --allow allow-none.txt
  one C3-allow-exact 1 '허용 선언으로 뺀 줄 1' --root dirty --terms terms.txt --allow allow.txt
  one C4-no-patterns 2 '-' --root dirty --terms terms-empty.txt --allow allow-none.txt
  one C5-no-files 2 '-' --root empty --terms terms.txt --allow allow-none.txt
  one C6-missing-list 2 '-' --root clean --terms nope.txt --allow allow-none.txt
  one C7-allow-loose 1 '허용 선언으로 뺀 줄 0' --root dirty --terms terms.txt --allow allow-loose.txt
  one C8-double 1 '적중 1 ' --root double --terms terms.txt --allow allow-none.txt
}

echo "== 공개 용어 검사기 사례 =="
run_cases "${CHK}"
[ -z "${RED}" ]; ck "[사례] 원본 8건 전부 기대대로" $? "붉은 사례:${RED}"

echo "== 뮤턴트 =="
mutant() { # mutant <번호> <찾을 글> <바꿀 글> <붉어져야 할 사례>
  local id="$1" from="$2" to="$3" expect="$4" m="${SB}/chk-$1.sh" n
  n="$(grep -cF -- "${from}" "${CHK}")"
  if [ "${n}" != "1" ]; then ck "[${id}] 변이 적용(찾을 글 정확히 1곳)" 1 "찾을 글이 ${n}곳이다"; return; fi
  python3 - "${CHK}" "${m}" "${from}" "${to}" <<'PY'
import sys
src, dst, a, b = sys.argv[1:5]
t = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(t.replace(a, b, 1))
PY
  cmp -s "${CHK}" "${m}"; [ $? -ne 0 ]; ck "[${id}] 변이 적용 확인" $? "사본이 원본과 같다"
  run_cases "${m}"
  case " ${RED} " in *" ${expect} "*) r=0 ;; *) r=1 ;; esac
  ck "[${id}] 기대한 사례 ${expect} 가 붉다" "${r}" "붉은 사례:${RED:- 없음}"
}
mutant M500 'if key in allow:' 'if (key[0], key[1].strip()) in {(p, t.strip()) for p, t in allow}:' C7-allow-loose
mutant M501 'if scanned == 0 or unreadable:' 'if unreadable:' C5-no-files
mutant M502 'sys.exit(1 if hits else 0)' 'sys.exit(0)' C2-hits
mutant M503 'if not pats:' 'if False:' C4-no-patterns
mutant M504 'dns[:] = [d for d in dns if d != ".git"]' 'dns[:] = list(dns)' C1-clean
mutant M505 '                    break' '                    pass' C8-double

echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
