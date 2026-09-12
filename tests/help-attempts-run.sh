#!/bin/bash
# 반복 막힘 단계별 안내(v0.3.15) 실행 시험 — 셈·단계·되돌림(D4)·깨진 파일·보고서 줄을 **실물 함수**로 잰다.
#
# ★실물을 `JARVIS_LIB_ONLY=1` 로 그대로 읽는다 — 떼어 낸 조각은 파일 전체의 문법·전역 상태 문제를 가려 준다.
# ★셸 하나 = 설치 실행 한 번. 같은 작업 폴더를 여러 셸이 차례로 읽어 「다시 실행」을 흉내 낸다.
# ★기대 문구는 이 파일에 베껴 두지 않고 정본(tests/help-escalation.tsv)에서 만든다 — 베낀 기대는 정본과 함께 늙는다.
# 네트워크 0 · 실제 설치 0 · 쓰기는 스크래치(mktemp -d) 안에서만(HOME·TMPDIR·JARVIS_HOME 모두 그 안).
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
SH="$DIR/../install-master/bootstrap.sh"
TSV="$DIR/help-escalation.tsv"
PHONE="010-7745-5885"
BASH_BIN=/bin/bash; [ -x "$BASH_BIN" ] || BASH_BIN=bash   # 맥 기본 bash 3.2 로 잰다
SB="$(mktemp -d)"; mkdir -p "$SB/home" "$SB/tmp"
trap 'rm -rf "$SB"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }

# ⚠경로는 **환경변수로** 넘긴다 — 위치 인자로 주면 설치기의 인자 파서가 「모르는 인자」로 exit 2 한다.
cat > "$SB/prelude.sh" <<'EOF'
. "$T_SH" || exit 9
CLOSING_DONE=1     # 시험 셸이 끝날 때 트랩이 한 번 더 세지 않게(끝맺음을 부르는 케이스는 0 으로 되돌린다)
endrun() {   # endrun <코드> <단계 n> — 그 단계에서 그 코드로 끝난 실행 한 번(셈 + 화면 블록)
  J_CODE="$1"; log "[$2/10] 시험 단계"
  help_attempts_update
  printf 'STAGE=%s\nFIRST=%s\nPREV=%s\n' "$HELP_STAGE" "$HELP_FIRST" "$HELP_PREV_REPORT"
  printf 'MARK\n'; help_escalation_print; printf 'END\n'
}
EOF
run() {   # run <케이스> <본문> — 화면 = $SB/<케이스>.out
  local c="$1"
  mkdir -p "$SB/$c"
  { cat "$SB/prelude.sh"; printf '%s\n' "$2"; } > "$SB/$c.snip"
  T_SH="$SH" HOME="$SB/home" TMPDIR="$SB/tmp" JARVIS_HOME="$SB/$c/install-jarvis" JARVIS_LIB_ONLY=1 \
    "$BASH_BIN" "$SB/$c.snip" > "$SB/$c.out" 2>&1
}
F()    { printf '%s' "$SB/$1/install-jarvis/help-attempts.json"; }
LOGF() { printf '%s' "$SB/$1/install-jarvis/bootstrap.log"; }
val()  { sed -n "s/^$2=//p" "$SB/$1.out"; }
sect() { awk '/^MARK$/{f=1;next} /^END$/{f=0} f' "$SB/$1.out"; }
col()  { awk -F'\t' -v k="$1" -v key="$2" '$1==k && $2==key {print $3}' "$TSV"; }
exp2() {   # 2회째 블록 = 빈 줄 + stage2(<WAY> 자리에 그 코드 way · 첫 줄 「   - 」 · 다음 줄 「     」)
  local l
  printf '\n'
  col stage2 - | while IFS= read -r l; do
    if [ "$l" = "<WAY>" ]; then col way "$1" | awk 'NR==1{print "   - " $0; next} {print "     " $0}'
    else printf '%s\n' "$l"; fi
  done
}
exp3() { printf '\n'; col stage3 - | sed -e "s/<PHONE>/$PHONE/" -e "s/<CODE>/$1/"; }
TS_RE='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{4}'

[ -f "$SH" ] && [ -f "$TSV" ] && [ -n "$(col stage2 -)" ] && [ -n "$(col stage3 -)" ]
ck "[준비] 설치기와 문구 정본을 읽는다" $? "파일이 없거나 정본 모양이 다르다"

echo "== ①②③ 같은 코드로 거듭 끝나면 단계가 오른다 =="
run a 'endrun J-AV-02 2'
[ "$(val a STAGE)" = "1" ] && [ -z "$(sect a)" ]
ck "① 첫 셈 = 단계 1 · 화면에 더하는 줄 0" $? "STAGE=$(val a STAGE) · $(sect a | head -2 | tr '\n' '|')"
# 고정 모양 = 첫 줄 · codes 여는 줄 · 코드 줄 · 닫는 줄 둘(보고가 없으면 last_report 줄 없음)
printf '%s\n' '{"v":1,' '"codes":{' 'CODE' '}' '}' > "$SB/a.shape"
sed -E 's/^"J-AV-02":\{"count":1,"first":"'"$TS_RE"'","last":"'"$TS_RE"'","step":"2"\}$/CODE/' "$(F a)" 2>/dev/null | cmp -s - "$SB/a.shape"
ck "① 상태 파일 = 고정 모양 · count=1 · step=2 · 시각 +0900 모양" $? "$(tr '\n' '|' < "$(F a)" 2>/dev/null)"
grep -q 'help attempts: J-AV-02 count=1 step=2$' "$(LOGF a)"
ck "① 기록 파일에 셈 한 줄" $? "$(grep 'help attempts' "$(LOGF a)")"
# 첫 기록 시각을 옛 값으로 바꿔 둔다 — 「첫 기록이 남는가」를 같은 초 안의 우연과 가르려고.
sed 's/"first":"[^"]*"/"first":"2026-01-01T00:00:00+0900"/' "$(F a)" > "$SB/a.tmp" && mv "$SB/a.tmp" "$(F a)"
run a 'endrun J-AV-02 2'
[ "$(val a STAGE)" = "2" ] && [ "$(sect a)" = "$(exp2 J-AV-02)" ]
ck "② 같은 코드 2번째 = 단계 2 · 빈 줄 + stage2 + 그 코드 way 줄" $? "$(sect a | tr '\n' '|')"
run a 'endrun J-AV-02 2'
[ "$(val a STAGE)" = "3" ] && [ "$(sect a)" = "$(exp3 J-AV-02)" ] && grep -q "담당자 전화 $PHONE " "$SB/a.out"
ck "③ 3번째 = 단계 3 · 빈 줄 + stage3 4줄 + 담당자 번호 + 코드" $? "$(sect a | tr '\n' '|')"
[ "$(val a FIRST)" = "2026-01-01T00:00:00+0900" ] && grep -q '"J-AV-02":{"count":3,"first":"2026-01-01T00:00:00+0900",' "$(F a)"
ck "③ 첫 기록 시각은 그대로 남는다" $? "FIRST=$(val a FIRST)"
run a 'endrun J-AV-02 2'
[ "$(val a STAGE)" = "4" ] && [ "$(sect a)" = "$(exp3 J-AV-02)" ]
ck "③ 4번째도 stage3(3회째부터)" $? "STAGE=$(val a STAGE)"

echo "== ④⑤ 단계를 지나가면 앞 코드를 지운다(D4) =="
run d4 'endrun J-AV-02 2'
run d4 'endrun J-AV-02 2'
run d4 'endrun J-LOGIN-01 3'
! grep -q '^"J-AV-02"' "$(F d4)" && grep -q '^"J-LOGIN-01":{"count":1,' "$(F d4)" && [ "$(val d4 STAGE)" = "1" ]
ck "④ 더 뒤 단계에서 다른 코드가 나면 앞 코드가 지워진다" $? "$(tr '\n' '|' < "$(F d4)")"
run d4 'endrun J-AV-02 2'
[ "$(val d4 STAGE)" = "1" ]
ck "④ 지워진 코드가 다시 나면 1회째부터 센다" $? "STAGE=$(val d4 STAGE)"
run d5 'endrun J-LOGIN-01 3'
run d5 'endrun J-AV-02 3'
run d5 'endrun J-DL-04 5'
run d5 'endrun J-NET-02 4'
# 기대: 단계 3 의 두 코드는 단계 4 에서 지워지고 · 단계 5(더 뒤)는 남는다
grep -q '^"J-DL-04":' "$(F d5)" && grep -q '^"J-NET-02":' "$(F d5)" && ! grep -q '^"J-AV-02"' "$(F d5)"
ck "⑤ 기록 단계가 현재 단계보다 뒤인 코드는 안 지워진다" $? "$(tr '\n' '|' < "$(F d5)")"
run d5b 'endrun J-LOGIN-01 3'
run d5b 'endrun J-AV-02 3'
printf '%s\n' '{"v":1,' '"codes":{' 'AV,' 'LOGIN' '}' '}' > "$SB/d5b.shape"
sed -E -e 's/^"J-AV-02":\{"count":1,.*"step":"3"\},$/AV,/' -e 's/^"J-LOGIN-01":\{"count":1,.*"step":"3"\}$/LOGIN/' "$(F d5b)" | cmp -s - "$SB/d5b.shape"
ck "⑤ 같은 단계의 다른 코드는 안 지워진다 · 코드 이름순 · 마지막 줄만 쉼표 없음" $? "$(tr '\n' '|' < "$(F d5b)")"

echo "== ⑥ 성공 끝이면 코드 줄을 비운다 =="
run d6 'endrun J-AV-02 2; help_last_report_save CGVJ9YVQ'
run d6 'J_CODE=""; REACHED_WAKE=0; help_attempts_update'
grep -q '^"J-AV-02":{"count":1,' "$(F d6)"
ck "⑥ 코드 없이 깨우기 전에 끝난 실행은 아무것도 안 지운다" $? "$(tr '\n' '|' < "$(F d6)")"
run d6 'J_CODE=""; REACHED_WAKE=1; help_attempts_update'
printf '%s\n' '{"v":1,' '"codes":{' '},' 'REPORT' '}' > "$SB/d6.shape"
sed -E 's/^"last_report":\{"id":"CGVJ9YVQ","at":"'"$TS_RE"'","code":"J-AV-02"\}$/REPORT/' "$(F d6)" | cmp -s - "$SB/d6.shape"
ck "⑥ 깨우기 도달(코드 없음) = 코드 줄 전부 지움 · last_report 유지" $? "$(tr '\n' '|' < "$(F d6)")"

echo "== ⑦ 깨진 파일 = 1회째 + 올바른 모양으로 다시 쓴다 =="
run d7 ''
[ ! -e "$(F d7)" ]
ck "⑦ 설치기를 읽기만 해서는 상태 파일이 안 생긴다(부작용 0)" $? "$(ls "$SB/d7/install-jarvis")"
printf '%s\n' '{"v":2,' '"J-AV-02":{"count":7,"first":"","last":"","step":"2"}' > "$(F d7)"
run d7 'endrun J-AV-02 2'
[ "$(val d7 STAGE)" = "1" ] && grep -q 'help attempts: unreadable - reset$' "$(LOGF d7)" &&
  sed -E 's/^"J-AV-02":\{"count":1,"first":"'"$TS_RE"'","last":"'"$TS_RE"'","step":"2"\}$/CODE/' "$(F d7)" | cmp -s - "$SB/a.shape"
ck "⑦ 첫 줄이 다른 파일 = 빈 상태로 보고 1회째 · 기록 한 줄 · 고정 모양으로 다시 씀" $? "STAGE=$(val d7 STAGE) · $(tr '\n' '|' < "$(F d7)")"
printf 'garbage' > "$(F d7)"
run d7 'endrun J-AV-02 2'
[ "$(val d7 STAGE)" = "1" ] && head -1 "$(F d7)" | grep -qx '{"v":1,'
ck "⑦ 알아볼 수 없는 글 = 1회째 · 다시 씀" $? "STAGE=$(val d7 STAGE)"

echo "== ⑧ 다른 방법이 없는 코드(direct) =="
run d8 'endrun J-DL-05 7'
[ "$(val d8 STAGE)" = "1" ] && [ -z "$(sect d8)" ]
ck "⑧ direct(J-DL-05) 1번째 = 더하는 줄 0" $? "$(sect d8 | tr '\n' '|')"
run d8 'endrun J-DL-05 7'
[ "$(val d8 STAGE)" = "2" ] && [ "$(sect d8)" = "$(exp3 J-DL-05)" ]
ck "⑧ direct(J-DL-05) 2번째 = 곧바로 stage3" $? "$(sect d8 | tr '\n' '|')"
run d8b 'endrun J-XX-99 7'
run d8b 'endrun J-XX-99 7'
s2="$(sect d8b)"
run d8b 'endrun J-XX-99 7'
[ -z "$s2" ] && [ "$(sect d8b)" = "$(exp3 J-XX-99)" ]
ck "⑧ way 없는 코드 = 2번째는 1회째처럼 · 3번째는 stage3" $? "2번째=$(printf '%s' "$s2" | tr '\n' '|')"

echo "== ⑨ 미리보기·감지만 = 세지 않는다 =="
run d9 'MODE=dry; endrun J-AV-02 2'
run d9 'MODE=dry; endrun J-AV-02 2'
[ ! -e "$(F d9)" ] && [ "$(val d9 STAGE)" = "1" ] && [ -z "$(sect d9)" ]
ck "⑨ 미리보기(dry) = 파일 안 생김 · 단계 1" $? "STAGE=$(val d9 STAGE)"
run d9 'MODE=detect; endrun J-AV-02 2'
[ ! -e "$(F d9)" ] && ! grep -q 'help attempts' "$(LOGF d9)"
ck "⑨ 감지만(detect) = 파일 안 생김 · 셈 기록 없음" $? "$(grep 'help attempts' "$(LOGF d9)")"
# 거절한 자리(우리 표식 없는 기존 폴더 · J-HOME-01)는 우리 것이 아니다 — 끝맺음이 그 안에 쓰면 안 된다.
mkdir -p "$SB/d9h/install-jarvis"; printf 'x\n' > "$SB/d9h/install-jarvis/mine.txt"
T_SH="$SH" HOME="$SB/home" TMPDIR="$SB/tmp" JARVIS_HOME="$SB/d9h/install-jarvis" JARVIS_LIB_ONLY=1 \
  "$BASH_BIN" -c '. "$T_SH"' > "$SB/d9h.out" 2>&1
grep -q 'J-HOME-01' "$SB/d9h.out" && [ ! -e "$(F d9h)" ]
ck "⑨ 거절한 남의 폴더(J-HOME-01)에는 상태 파일을 쓰지 않는다" $? "$(ls "$SB/d9h/install-jarvis" | tr '\n' ' ')"

echo "== ⑩ 이전 보고 =="
run d10 'endrun J-AV-02 2; help_last_report_save CGVJ9YVQ; help_last_report_save "bad id"'
grep -q '^"last_report":{"id":"CGVJ9YVQ",' "$(F d10)" && grep -q 'help attempts: report not saved$' "$(LOGF d10)"
ck "⑩ 보고 번호 저장 · 모양이 틀린 번호는 저장하지 않는다(앞 번호 유지)" $? "$(tr '\n' '|' < "$(F d10)")"
at="$(sed -nE 's/^"last_report":\{"id":"CGVJ9YVQ","at":"([^"]*)".*/\1/p' "$(F d10)")"
run d10 'endrun J-AV-02 2'
[ "$(val d10 PREV)" = "CGVJ9YVQ ($at · 같은 코드)" ] && printf '%s' "$at" | grep -qE "^$TS_RE\$"
ck "⑩ 다음 셈의 이전 보고 = 「ID (시각 · 같은 코드)」" $? "PREV=$(val d10 PREV)"
run d10 'endrun J-LOGIN-01 3'
[ "$(val d10 PREV)" = "CGVJ9YVQ ($at · 다른 코드 J-AV-02)" ]
ck "⑩ 다른 코드로 끝나면 「ID (시각 · 다른 코드 코드명)」" $? "PREV=$(val d10 PREV)"
run d10 'J_CODE=J-LOGIN-01; help_last_report_save MBX2345Z'
run d10 'endrun J-LOGIN-01 3'
printf '%s' "$(val d10 PREV)" | grep -qE "^MBX2345Z \($TS_RE · 같은 코드\)\$"
ck "⑩ 다시 보내면 매번 갱신한다" $? "PREV=$(val d10 PREV)"

echo "== ⑪ 끝맺음 — 보고서 두 줄 교체 · 화면 자리 · 3회째 마지막 줄 =="
CL='CLOSING_DONE=0; NEXT_STEP="시험"; SHOW_RERUN=0; J_CODE=J-AV-02; log "[2/10] 시험 단계"'
run d11 'printf "%s\n" "$REPORT_HEAD" "" "- 언제: 시험" "- 진단 코드: **J-OLD-01** (옛 줄)" "  - 끝 줄" > "$REPORT_FILE"
'"$CL"'; NOTICE_SHOWN=0; closing_note; help_last_report_save CGVJ9YVQ'
run d11 "$CL; NOTICE_SHOWN=0; closing_note"
RF="$SB/d11/install-jarvis/env-report.md"
[ "$(grep -c '^- 진단 코드: ' "$RF")" = "1" ] && [ "$(grep -c '^- 같은 진단 코드: ' "$RF")" = "1" ] && [ "$(grep -c '^- 이전 보고: ' "$RF")" = "1" ] &&
  grep -qE "^- 같은 진단 코드: 2회째 \(이 컴퓨터 · 첫 기록 $TS_RE\)\$" "$RF" &&
  grep -qE "^- 이전 보고: CGVJ9YVQ \($TS_RE · 같은 코드\)\$" "$RF" && grep -q '^- 진단 코드: \*\*J-AV-02\*\*' "$RF"
ck "⑪ 보고서 세 줄이 지금 값으로 교체된다(중복 0)" $? "$(grep '^- ' "$RF" | tr '\n' '|')"
[ "$(awk '/^  진단 코드: J-AV-02/{f=1;next} /^  막히면 이 두 파일/{f=0} f' "$SB/d11.out")" = "$(exp2 J-AV-02)" ]
ck "⑪ 화면: stage2 블록은 「진단 코드:」 줄 바로 다음 · 「막히면 이 두 파일」 앞" $? "$(grep -n '진단 코드\|막히면\|같은 자리' "$SB/d11.out" | tr '\n' '|')"
run d11 "$CL; NOTICE_SHOWN=0; closing_note"
[ "$(awk '/^  진단 코드: J-AV-02/{f=1;next} /^  막히면 이 두 파일/{f=0} f' "$SB/d11.out")" = "$(exp3 J-AV-02)" ] &&
  [ "$(grep -cxF "$(col sent no)" "$SB/d11.out")" = "1" ] && ! grep -qxF "$(col sent ok)" "$SB/d11.out" &&
  awk -v s="$(col sent no)" '/^  여는 법: /{a=NR} $0==s{b=NR} END{exit !(a && b && a < b)}' "$SB/d11.out"
ck "⑪ 3회째 · 원격 해결 안 돎 = stage3 + 끝에 sent no(전달됐다고 말하지 않는다)" $? "$(tail -4 "$SB/d11.out" | tr '\n' '|')"
[ "$(grep -c '^- 같은 진단 코드: ' "$RF")" = "1" ] && grep -q '^- 같은 진단 코드: 3회째 ' "$RF"
ck "⑪ 세 번째 끝맺음 뒤에도 보고서 줄은 하나" $? "$(grep '^- ' "$RF" | tr '\n' '|')"
if [ -x /usr/bin/osascript ] && command -v curl >/dev/null 2>&1; then
  # 전송 성공만 흉내 낸다(서버·네트워크 0) — 보고와 폴링 두 함수를 바꿔 끼운다.
  run d11 "$CL; NOTICE_SHOWN=1; remote_help_report() { return 0; }; remote_help_loop() { return 0; }; closing_note"
  [ "$(grep -cxF "$(col sent ok)" "$SB/d11.out")" = "1" ] && ! grep -qxF "$(col sent no)" "$SB/d11.out"
  ck "⑪ 3회째 · 전송 성공 = sent ok 한 줄 · sent no 없음(D3)" $? "$(tail -6 "$SB/d11.out" | tr '\n' '|')"
  run d11b "J_CODE=J-AV-02; CLOSING_DONE=0; NEXT_STEP=\"시험\"; SHOW_RERUN=0; NOTICE_SHOWN=1; remote_help_report() { return 0; }; remote_help_loop() { return 0; }; closing_note"
  ! grep -qxF "$(col sent ok)" "$SB/d11b.out" && ! grep -qxF "$(col sent no)" "$SB/d11b.out"
  ck "⑪ 1회째 = 전송이 성공해도 sent 줄 없음" $? "$(tail -4 "$SB/d11b.out" | tr '\n' '|')"
else
  printf '  skip ⑪ sent ok — osascript·curl 이 없는 기계(원격 해결이 시작하지 않는다)\n'
fi

printf '\n통과 %d · 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
