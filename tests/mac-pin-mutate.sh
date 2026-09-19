#!/bin/bash
# 맥 핀 뮤턴트 — checks.sh 의 「[전환] 크기·지문·CDHash」 세 축이 **값을 정말 보는가**(2026-09-16 · 1.0.1 핀 채움과 함께 신설).
#
# ★왜: 윈 쪽은 릴리스를 때려서 대조하는 tests/win-pin-release.sh 가 있고 그 대조의 눈멂은
#   tests/win-pin-mutate.sh 가 잰다. 맥 쪽 핀(크기·지문·CDHash)을 보는 곳은 checks.sh 의 형식 축뿐이라,
#   그 축이 헛도는지를 재는 그물이 없었다. 이 하네스가 그 자리를 메운다.
# ⚠판정 순서: ①원본에서 그 축이 초록인가(원래 붉은 축은 변이를 잡아도 아무것도 증명 못 한다)
#   → ②변이가 그 선언 줄 하나에만 걸렸는가 → ③기대한 축이 붉은가 → ④붉어진 집합이 「원본 + 그 축 하나」인가
#   (곁가지 적색은 킬이 아니다 — 자리표 문자열을 변이값으로 쓰면 「자리표 남았다」 축까지 함께 붉어진다).
# ⛔원본 파일은 건드리지 않는다 — 사본을 떠서 거기에만 변이를 건다.
#
# 쓰는 법: bash tests/mac-pin-mutate.sh <install-master 경로> <그 안의 checks.sh>   · rc 0 = 전건 통과
#   ([사이트] 축은 판정 집합에서 뺀다 — 아래 red() 주석 · 이 하네스가 재는 축과 무관하다)
set -u
SRC="$1"; CHECKS="$2"; SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
PASS=0; FAIL=0
ck(){ if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
# ⚠[사이트] 축은 뺀다 — 그 축은 대상 사본을 **저장소 밖 사이트 폴더**(절대 경로)와 대조하므로, bootstrap.sh 를 한 줄이라도 바꾼
#   변이는 언제나 그 축을 붉힌다(재는 성질과 무관한 곁가지 · installer-0326 C2 에서 확인 — 앞 판 머리 주석의 「건너뛴다」는 사실이 아니었다).
red(){ sed -n 's/^  FAIL \(.*\)  ← .*$/\1/p' "$1" | grep -v '^\[사이트\] ' | sort; }

cp -R "$SRC" "$SB/orig"
bash "$CHECKS" "$SB/orig" > "$SB/orig.out" 2>&1
red "$SB/orig.out" > "$SB/orig.red"
for ax in '[전환] 저희 판 크기 핀(숫자)' '[전환] 저희 판 지문 핀(64자리)' '[전환] 저희 판 CDHash 핀(40자리)' '[전환] 저희 판 핀 = 발행 zip 실측(크기·지문·CDHash · tests/mac-pin-release.sh)'; do
  ! grep -qxF "$ax" "$SB/orig.red"; ck "[①] 원본에서 「${ax}」 는 초록이다" $? "원본부터 붉다"
done

mut(){ # mut <id> <변수> <새 값> <기대 적색 축> [<기대 적색 축 2> …]
  local id="$1" var="$2" new="$3" want="$4" n w
  shift 3
  rm -rf "$SB/$id"; cp -R "$SRC" "$SB/$id"
  python3 - "$SB/$id/bootstrap.sh" "$var" "$new" <<'PY'
import re,sys
p,var,new=sys.argv[1:4]
t=open(p,encoding='utf-8',newline='').read().split('\n')
pat=re.compile(r'^'+re.escape(var)+r'="[^"]*"$')
i=[k for k,l in enumerate(t) if pat.match(l)]
sys.exit(3) if len(i)!=1 else None
t[i[0]]=var+'="'+new+'"'
open(p,'w',encoding='utf-8',newline='').write('\n'.join(t))
PY
  [ $? -eq 0 ] || { ck "[$id] 변이 적용" 1 "선언 줄을 못 찾았다"; return; }
  n="$(diff "$SRC/bootstrap.sh" "$SB/$id/bootstrap.sh" | grep -c '^[<>]')"
  [ "$n" = "2" ]; ck "[$id] 변이 적용 = $var 선언 줄 하나만 달라졌다" $? "다른 줄 수 $n"
  bash "$CHECKS" "$SB/$id" > "$SB/$id.out" 2>&1
  red "$SB/$id.out" > "$SB/$id.red"
  for w in "$@"; do
    grep -qxF "$w" "$SB/$id.red"; ck "[$id] 기대 축이 붉다 — $w" $? "틀린 $var 가 통과한다"
  done
  diff <(sort -u <(cat "$SB/orig.red"; printf '%s\n' "$@")) <(sort -u "$SB/$id.red") >/dev/null
  ck "[$id] 붉어진 축 집합 = 원본 + 기대 축($#개)" $? "곁가지 적색: $(comm -13 <(sort -u <(cat "$SB/orig.red"; printf '%s\n' "$@")) <(sort -u "$SB/$id.red") | tr '\n' '|')"
}

SHA="$(grep -E '^CYS_FORK_SHA256="' "$SRC/bootstrap.sh" | sed -E 's/.*"([0-9a-f]+)".*/\1/')"
CDH="$(grep -E '^CYS_FORK_CDHASH="' "$SRC/bootstrap.sh" | sed -E 's/.*"([0-9a-f]+)".*/\1/')"
# (installer-0326 C2) 형식 축을 깨는 변이는 발행 zip 대조 축도 함께 붉힌다 — 그것이 기대다(곁가지가 아니다).
REL='[전환] 저희 판 핀 = 발행 zip 실측(크기·지문·CDHash · tests/mac-pin-release.sh)'
mut M601 CYS_FORK_BYTES  '471843743x'   '[전환] 저희 판 크기 핀(숫자)' "$REL"
mut M602 CYS_FORK_SHA256 "${SHA:0:63}" '[전환] 저희 판 지문 핀(64자리)' "$REL"
mut M603 CYS_FORK_CDHASH "${CDH:0:39}" '[전환] 저희 판 CDHash 핀(40자리)' "$REL"
# ★M604 = 799 가 적발한 구멍 그 자체 — **형식은 맞는(40자리) 한 글자 틀린 CDHash**. 형식 축은 초록이어야 하고
#   발행 zip 대조 축 **하나만** 붉어야 한다(형식 축까지 붉으면 이 변이가 무엇을 재는지 흐려진다).
#   마지막 글자를 다른 16진수 한 글자로 바꾼다(0↔1 · 그 밖은 0).
last="${CDH: -1}"; case "$last" in 0) rep=1 ;; *) rep=0 ;; esac
mut M604 CYS_FORK_CDHASH "${CDH:0:39}${rep}" "$REL"
# 같은 구멍의 크기 판(형식은 숫자 그대로 · 값만 1 차이)
mut M605 CYS_FORK_BYTES "$(( $(grep -E '^CYS_FORK_BYTES="' "$SRC/bootstrap.sh" | sed -E 's/.*"([0-9]+)".*/\1/') + 1 ))" "$REL"
echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
