#!/bin/bash
# help-cases-1029-r2 — 맥(bootstrap.sh) 짝 행동 시험: J-INST-01 판정 · J-LOGIN-01 사람·브라우저 포착.
#   가짜 HOME · JARVIS_LIB_ONLY=1 로 함수만 읽는다 · ioreg·ps 는 PATH 앞 가짜(이 기계 실값을 쓰지 않는다) · 설치·로그인·GUI 0.
# 쓰는 법: bash tests/help-cases-1029-mac-run.sh [--dir <install-master 자리>]   rc 0 = 전건 통과
set -u
DIR="$(cd "$(dirname "$0")/../install-master" && pwd)"; [ "${1:-}" = "--dir" ] && DIR="$2"
SH="$DIR/bootstrap.sh"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/hc1029mac.XXXXXX")"; trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
mkdir -p "$BASE/bin" "$BASE/home"   # ⚠install-jarvis 는 만들지 않는다 — 설치 도우미는 자기가 만든 폴더만 쓴다(J-HOME-01)
# 가짜 ioreg = $BASE/idle-ns 값 · 가짜 ps = $BASE/ps-out 그대로(브라우저 목록만 쓰는 자리)
printf '#!/bin/sh\n[ -f "%s/idle-ns" ] || exit 1\nprintf "    | |   \\"HIDIdleTime\\" = %%s\\n" "$(cat "%s/idle-ns")"\n' "$BASE" "$BASE" > "$BASE/bin/ioreg"
printf '#!/bin/sh\ncat "%s/ps-out"\n' "$BASE" > "$BASE/bin/ps"
chmod +x "$BASE/bin/ioreg" "$BASE/bin/ps"
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 PATH="$BASE/bin:$PATH" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 30 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$BASE/log'; REPORT_FILE='$BASE/report'; $1; exec >/dev/null 2>&1" 2>&1; }   # 끝 exec = 끝맺음 안내가 출력에 섞이지 않게(v0331 같은 관용구)

echo "== ⓐ J-INST-01 판정(설치기 기록 끝) =="
kind() { printf '%s\n' "$@" > "$BASE/cil"; run_sh "CLAUDE_INSTALL_LOG='$BASE/cil'; printf '[%s]' \"\$(claude_install_fail_kind)\""; }
o="$(kind 'Setting up Claude Code...' '× Installation failed' 'EBUSY: resource busy or locked, rename')"; [ "$o" = "[busy]" ]; t $? "Installation failed + EBUSY → busy" "$o"
o="$(kind 'Setting up Claude Code...' '× Installation failed' 'something else')"; [ "$o" = "[failed]" ]; t $? "Installation failed 만 → failed" "$o"
o="$(kind 'Installation was killed before it could finish (exit code 143).')"; [ "$o" = "[failed]" ]; t $? "맥 설치 스크립트 신호 종료 문구 → failed" "$o"
o="$(kind 'Download failed')"; [ "$o" = "[]" ]; t $? "대조군: 실패 표지 없음(Download failed) → 빈칸(J-DL-07·J-PATH-01 갈래 그대로)" "$o"
printf '%s\n' '× Installation failed' 'EBUSY' > "$BASE/cil"
o="$(run_sh "CLAUDE_INSTALL_LOG='$BASE/cil'; write_claude_install_failed busy '     사실 줄'; echo \"NEXT=\$NEXT_STEP SHOW=\$SHOW_RERUN\"")"
printf '%s' "$o" | grep -q 'J-INST-01' && printf '%s' "$o" | grep -q '공식 설치기가 설치를 끝내지 못했다고' && printf '%s' "$o" | grep -q '터미널 창을 모두 닫고' && printf '%s' "$o" | grep -q 'SHOW=1'
t $? "화면 = J-INST-01 · 안내 · 다른 터미널 창 닫기 · 다시 하시는 법 켬" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-300)"
grep -q 'J-INST-01 by: vendor-said-failed kind=busy' "$BASE/log"; t $? "기록 = J-INST-01 by: vendor-said-failed kind=busy" "$(tail -3 "$BASE/log" | tr '\n' '|')"
# 갈래 자리 — 두 곳 모두 J-PATH-01·「연결이 된 뒤」 앞에서 판정한다(글자 순서로 잰다)
a="$(grep -n 'claude_install_fail_kind)" ] ; then\|\[ -n "\$(claude_install_fail_kind)" \]' "$SH" | cut -d: -f1 | tr '\n' ' ')"
p="$(grep -n 'jcode "J-PATH-01"' "$SH" | head -1 | cut -d: -f1)"; c="$(grep -n '연결이 된 뒤 아래' "$SH" | head -1 | cut -d: -f1)"
set -- $a; [ "$#" -eq 2 ] && [ "$1" -lt "$c" ] && [ "$2" -lt "$p" ]; t $? "갈래 2곳: 종료 코드 실패(「연결이 된 뒤」 앞) · 명령 안 잡힘(J-PATH-01 앞)" "자리=$a 연결=$c path=$p"

echo "== ⓑ J-LOGIN-01 사람·브라우저 포착(가짜 ioreg·ps) =="
CH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'; HE='/Applications/Google Chrome.app/Contents/Frameworks/x/Google Chrome Helper'
pres() { # pres <시작 ps> <바퀴 ps> <idle 초(빈칸=못 잼)> <바퀴 초>
  printf '%s\n' "$1" > "$BASE/ps-out"; rm -f "$BASE/idle-ns"
  run_sh "login_presence_start; printf '%s\n' \"$2\" > '$BASE/ps-out'; $( [ -n "$3" ] && printf "echo %s000000000 > '$BASE/idle-ns';" "$3" ) login_presence_tick $4; login_presence_resolve $4; echo \"[\$LOGIN_INFO_PRESENCE] \$LOGIN_INFO_INPUT / \$LOGIN_INFO_BROWSER\"; ls -a '$BASE/home/install-jarvis' | grep -c login-presence"
}
o="$(pres "  11 $CH" "  11 $CH" 600 60)"; printf '%s' "$o" | grep -q '^\[away\]'; t $? "입력 0(idle 600초 > 60초) → away" "$o"
o="$(pres "  11 $CH" "  11 $CH" 10 60)"; printf '%s' "$o" | grep -q '^\[browser-unknown\].*이미 떠 있던 브라우저 1개'; t $? "입력 있음 · 떠 있던 브라우저뿐 → browser-unknown(단정 안 함)" "$o"
o="$(pres "  11 $CH" "$(printf '  11 %s\n  22 %s\n  23 %s' "$CH" '/Applications/Safari.app/Contents/MacOS/Safari' "$HE")" 10 60)"; printf '%s' "$o" | grep -q '^\[browser-seen\].*새로 뜬 브라우저 1개'; t $? "새 브라우저 본체 1(도우미는 안 셈) → browser-seen" "$o"
o="$(pres "" "  31 /usr/bin/true" 10 60)"; printf '%s' "$o" | grep -q '^\[no-browser\].*떠 있는 브라우저 0'; t $? "입력 있음 · 브라우저 0 → no-browser" "$o"
o="$(pres "" "" "" 60)"; printf '%s' "$o" | grep -q '^\[unmeasured\] 잴 수 없었다'; t $? "ioreg 못 읽음 → unmeasured" "$o"
o="$(pres "" "" 58 60)"; printf '%s' "$o" | grep -q '^\[away\]'; t $? "로그인 연 뒤 5초 안의 입력(2초)은 세지 않는다 → away" "$o"
printf '%s' "$o" | tail -1 | grep -qx 0; t $? "판정 뒤 상태 파일을 지운다" "$(printf '%s' "$o" | tail -1)"
o="$(run_sh "login_presence_tick 60; echo rc=\$?")"; [ "$o" = "rc=0" ]; t $? "재기 시작 전(파일 없음) tick 은 아무것도 안 한다(감시자만 도는 옛 시험 자리)" "$o"
# 배선 — 감시자 한 바퀴 · 로그인 끝 1번 · J-LOGIN-01 직전 기록 · 보고 3줄
grep -q '^    login_presence_tick "\$waited"$' "$SH"; t $? "배선: login_waiter 한 바퀴마다 login_presence_tick" "없음"
grep -q '^  login_presence_start$' "$SH" && grep -q '^  login_presence_resolve "\$login_w"$' "$SH"; t $? "배선: 시작·끝 판정" "없음"
awk '/log "login input: /{a=NR} /^  add_login_report$/{b=NR} /jcode "J-LOGIN-01"/{c=NR} END{exit !(a && a<b && b<c)}' "$SH"; t $? "배선: login input 기록 → 보고 → J-LOGIN-01 순" "순서 다름"
# 0.3.43(운영 결정 2026-10-30 · 승인 범위 = 키보드·마우스 사용 여부뿐): 보내는 보고·기록 = 있었다/없었다/잴 수 없었다 만 · 브라우저 줄·판정 꼬리표 없음
o="$(pres "" "  31 /usr/bin/true" 10 60)"; printf '%s' "$o" | grep -q '^\[no-browser\] 있었다 /'; t $? "보내는 입력 값 = 「있었다」 그대로(횟수·시각 없음)" "$o"
o="$(pres "  11 $CH" "  11 $CH" 600 60)"; printf '%s' "$o" | grep -q '^\[away\] 없었다 /'; t $? "보내는 입력 값 = 「없었다」 그대로" "$o"
: > "$BASE/report"; : > "$BASE/log"
run_sh "LOGIN_INFO_WIN=w LOGIN_INFO_PROC=p LOGIN_INFO_REOPEN=r LOGIN_INFO_SEND=s LOGIN_INFO_CONFIRM=c LOGIN_INFO_ANSWER=a LOGIN_INFO_KEYS=k; LOGIN_INFO_INPUT=있었다; LOGIN_INFO_BROWSER=BROWSER-MARK; LOGIN_INFO_PRESENCE=TAG-MARK; add_login_report" >/dev/null
grep -q '키보드·마우스 사용(이 컴퓨터 전체): 있었다$' "$BASE/report" && ! grep -qE 'BROWSER-MARK|TAG-MARK|브라우저:|판정:' "$BASE/report" "$BASE/log"
t $? "보고·기록 = 사용 여부 줄만 · 브라우저 줄·판정 꼬리표 없음" "$(cat "$BASE/report" "$BASE/log" | tr '\n' '|' | cut -c1-300)"
awk '/^    no-browser\)/{f=1} f&&/;;/{f=0} f&&/^ *say /{bad=1} END{exit bad}' "$SH"; t $? "브라우저에서 나온 화면 안내는 기록(say)으로 안 간다 — 화면(printf)에만" "say 가 남음"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
