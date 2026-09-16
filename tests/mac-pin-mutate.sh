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
#   (사본에는 사이트 폴더가 없으므로 [사이트] 축은 건너뛴다 — 이 하네스가 재는 축과 무관하다)
set -u
SRC="$1"; CHECKS="$2"; SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
PASS=0; FAIL=0
ck(){ if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }
red(){ sed -n 's/^  FAIL \(.*\)  ← .*$/\1/p' "$1" | sort; }

cp -R "$SRC" "$SB/orig"
bash "$CHECKS" "$SB/orig" > "$SB/orig.out" 2>&1
red "$SB/orig.out" > "$SB/orig.red"
for ax in '[전환] 저희 판 크기 핀(숫자)' '[전환] 저희 판 지문 핀(64자리)' '[전환] 저희 판 CDHash 핀(40자리)'; do
  ! grep -qxF "$ax" "$SB/orig.red"; ck "[①] 원본에서 「${ax}」 는 초록이다" $? "원본부터 붉다"
done

mut(){ # mut <id> <변수> <새 값> <기대 적색 축>
  local id="$1" var="$2" new="$3" want="$4" n
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
  grep -qxF "$want" "$SB/$id.red"; ck "[$id] 기대 축이 붉다 — $want" $? "틀린 $var 가 통과한다"
  diff <(cat "$SB/orig.red"; echo "$want") <(cat "$SB/$id.red") >/dev/null 2>&1 \
    || diff <(sort -u <(cat "$SB/orig.red"; echo "$want")) <(sort -u "$SB/$id.red") >/dev/null
  ck "[$id] 붉어진 축 집합 = 원본 + 그 축 하나" $? "곁가지 적색: $(comm -13 <(sort -u <(cat "$SB/orig.red"; echo "$want")) <(sort -u "$SB/$id.red") | tr '\n' '|')"
}

SHA="$(grep -E '^CYS_FORK_SHA256="' "$SRC/bootstrap.sh" | sed -E 's/.*"([0-9a-f]+)".*/\1/')"
CDH="$(grep -E '^CYS_FORK_CDHASH="' "$SRC/bootstrap.sh" | sed -E 's/.*"([0-9a-f]+)".*/\1/')"
mut M601 CYS_FORK_BYTES  '471843743x'   '[전환] 저희 판 크기 핀(숫자)'
mut M602 CYS_FORK_SHA256 "${SHA:0:63}" '[전환] 저희 판 지문 핀(64자리)'
mut M603 CYS_FORK_CDHASH "${CDH:0:39}" '[전환] 저희 판 CDHash 핀(40자리)'
echo "통과 ${PASS} · 실패 ${FAIL}"
[ "${FAIL}" -eq 0 ] && [ "${PASS}" -gt 0 ]
