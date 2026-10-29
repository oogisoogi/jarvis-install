#!/bin/bash
# installer-0343 — 맥(bootstrap.sh) 짝 행동 시험: ① J-DL-08 덜 받음 · ② J-APP-02 바탕 프로그램 무응답(자리) · ③ J-NET-04 claude.ai 안전 연결 실패 + 점검 문구.
#   가짜 HOME · JARVIS_LIB_ONLY=1 로 함수만 읽는다 · curl 은 PATH 앞 가짜($BASE/curl-mode 로 갈래) · 받기·설치·GUI 0.
#   ⚠맥 실기 실측 없음: curl 의 인증서 실패 문구(「SSL certificate problem」 류)는 curl 이 찍는 말 그대로를 넣었다(맥 기기에서 claude.ai 가 그렇게 막힌 사례는 아직 0).
# 쓰는 법: bash tests/installer-0343-mac-run.sh [--dir <install-master 자리>]   rc 0 = 전건 통과
set -u
DIR="$(cd "$(dirname "$0")/../install-master" && pwd)"; [ "${1:-}" = "--dir" ] && DIR="$2"
SH="$DIR/bootstrap.sh"
BASE="$(mktemp -d "${TMPDIR:-/tmp}/i0343mac.XXXXXX")"; trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
mkdir -p "$BASE/bin" "$BASE/home"
# 가짜 curl — -I(1-7 연결 점검): curl-mode=trust 면 claude.ai 에 인증서 실패(rc 60) · 받기(-o): sizes 파일에서 회차마다 한 크기씩 꺼내 그만큼 쓴다.
cat > "$BASE/bin/curl" <<EOF
#!/bin/bash
out=""; head=0; url=""
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift ;; -I) head=1 ;; -w|-m|--max-time|--connect-timeout|--speed-limit|--speed-time) shift ;; http*) url="\$1" ;; esac; shift; done
if [ "\$head" = 1 ]; then
  case "\$(cat "$BASE/curl-mode" 2>/dev/null):\$url" in
    trust:*claude.ai/install.sh) echo 'curl: (60) SSL certificate problem: unable to get local issuer certificate' >&2; printf '000'; exit 60 ;;
    plain:*claude.ai/install.sh) echo 'curl: (7) Failed to connect to claude.ai port 443' >&2; printf '000'; exit 7 ;;
  esac
  printf '200'; exit 0
fi
case "\$url" in *downloads.claude.ai*) [ -n "\$out" ] && echo 2.1.300 > "\$out"; printf '200'; exit 0 ;; esac
n="\$(head -1 "$BASE/sizes")"; sed -i '' 1d "$BASE/sizes"
[ -n "\$out" ] && head -c "\$n" /dev/zero > "\$out"
exit 0
EOF
chmod +x "$BASE/bin/curl"
# 이 기계의 진짜 cys·cysd 를 부르지 않는다(1-7 을 품은 detect_stage1 이 판본을 묻는다) — 답 없는 가짜.
for b in cys cysd claude; do printf '#!/bin/sh\nexit 1\n' > "$BASE/bin/$b"; chmod +x "$BASE/bin/$b"; done
run_sh() { HOME="$BASE/home" TMPDIR="$BASE" JARVIS_HOME="$BASE/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 PATH="$BASE/bin:$PATH" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 60 bash -c ". '$SH' >/dev/null 2>&1; LOG_FILE='$BASE/log'; REPORT_FILE='$BASE/report'; ROWS_FILE='$BASE/rows'; $1; exec >/dev/null 2>&1" 2>&1; }

echo "== ③ J-NET-04 · 점검 문구 =="
o="$(run_sh "printf '%s\n' 'curl: (60) SSL certificate problem: unable to get local issuer certificate' | tls_trust_words; echo a=\$?; printf '%s\n' 'irm : 기본 연결이 닫혔습니다. SSL/TLS 보안 채널에 대한 트러스트 관계를 설정할 수 없습니다.' | tls_trust_words; echo b=\$?; printf '%s\n' 'curl: (7) Failed to connect' | tls_trust_words; echo c=\$?")"
[ "$(printf '%s' "$o" | tr '\n' ' ')" = "a=0 b=0 c=1" ]; t $? "낱말 판정: curl 인증서 실패 · 윈 실측 문구 = 참 · 연결 실패 = 거짓" "$o"
for m in trust plain ok; do
  echo "$m" > "$BASE/curl-mode"
  o="$(run_sh "detect_stage1 >/dev/null 2>&1; echo \"P=\$INSTALL_URL_PROBE\"; grep '^1-7' '$BASE/rows'")"
  case "$m" in
    trust) printf '%s' "$o" | grep -q '^P=trust' && printf '%s' "$o" | grep -q 'install.sh=실패(안전 연결)'; t $? "1-7 claude.ai 인증서 실패 → trust · 값 칸 「실패(안전 연결)」" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-240)" ;;
    plain) printf '%s' "$o" | grep -q '^P=fail'; t $? "1-7 claude.ai 연결 실패 → fail(안전 연결 아님)" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-240)" ;;
    ok)    printf '%s' "$o" | grep -q '^P=ok'; t $? "1-7 claude.ai 답함 → ok" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-240)" ;;
  esac
done
rm -f "$BASE/rows"
o="$(run_sh "INSTALL_URL_PROBE=fail; DL_PROBE=ok; dl_probe_words")"
[ "$o" = "claude.ai 에는 설치 시작 전에도 닿지 못했습니다 · downloads.claude.ai 는 설치 시작 전에는 닿았습니다(그 사이에 끊겼을 수 있습니다)." ]; t $? "점검 문구: claude.ai 실패를 먼저 말한다" "$o"
o="$(run_sh "INSTALL_URL_PROBE=ok; DL_PROBE=ok; dl_probe_words")"
[ "$o" = "설치 시작 전에는 닿았습니다(그 사이에 끊겼을 수 있습니다)." ]; t $? "대조: claude.ai ok 면 점검 문구 종전 그대로" "$o"
printf '%s\n' 'Setting up...' > "$BASE/cil"
o="$(run_sh "CLAUDE_INSTALL_LOG='$BASE/cil'; INSTALL_URL_PROBE=fail; claude_tls_trust_fail; echo r1=\$?; INSTALL_URL_PROBE=trust; claude_tls_trust_fail; echo r2=\$?; printf '%s\n' 'curl: (60) SSL certificate problem' >> '$BASE/cil'; INSTALL_URL_PROBE=fail; claude_tls_trust_fail; echo r3=\$?")"
[ "$(printf '%s' "$o" | tr '\n' ' ')" = "r1=1 r2=0 r3=0" ]; t $? "판정: 표지 없음 = 거짓 · 1-7 trust = 참 · 설치기 기록 끝 인증서 실패 = 참" "$o"
o="$(run_sh "CLAUDE_INSTALL_LOG='$BASE/cil'; INSTALL_URL_PROBE=trust; DL_PROBE=ok; write_claude_tls_trust_failed '     사실 줄'; echo \"NEXT=\$NEXT_STEP SHOW=\$SHOW_RERUN\"")"
printf '%s' "$o" | grep -q 'J-NET-04' && printf '%s' "$o" | grep -q '안전한 연결을 맺지 못해' && printf '%s' "$o" | grep -q '처음 점검 결과: claude.ai 에는 설치 시작 전에도 안전한 연결을 맺지 못했습니다' && printf '%s' "$o" | grep -q 'NEXT=휴대폰 핫스팟' && printf '%s' "$o" | grep -q 'SHOW=1' && printf '%s' "$o" | grep -q 'SSL certificate problem'
t $? "화면 = J-NET-04 · 점검 문구 · 설치기 끝말 · 다른 인터넷 처방 · 다시 하시는 법 켬" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-300)"
grep -q 'J-NET-04 by: tls-trust probe=trust' "$BASE/log"; t $? "기록 = J-NET-04 by: tls-trust" "$(tail -2 "$BASE/log" | tr '\n' '|')"
# 갈래 자리 — 두 곳 모두 J-DL-07 판정 앞
a="$(grep -n 'claude_tls_trust_fail; then' "$SH" | cut -d: -f1 | tr '\n' ' ')"
d1="$(grep -n 'log "J-DL-07 by: net-failed rc=' "$SH" | head -1 | cut -d: -f1)"; d2="$(grep -n 'jcode "J-DL-07"' "$SH" | head -1 | cut -d: -f1)"
set -- $a; [ "$#" -eq 2 ] && [ "$1" -lt "$d1" ] && [ "$2" -lt "$d2" ]; t $? "갈래 2곳: 종료 코드 실패 · 명령 안 잡힘 모두 J-DL-07 앞" "자리=$a dl07=$d1,$d2"

echo "== ① J-DL-08 덜 받음 =="
dl() { printf '%s\n' "$@" > "$BASE/sizes"; rm -rf "$BASE/dl"; : > "$BASE/report"
  run_sh "DL_DIR='$BASE/dl'; CYS_MAC_BYTES=3000000; CYS_MAC_FILE=x.zip; CYS_DOWNLOAD_URL='http://127.0.0.1:9/x.zip'; CYS_X64_PIN_PENDING=0; MODE=real; step_download_cys; echo \"RC=\$? NEXT=\$NEXT_STEP\""; }
o="$(dl 1500000 2100000)"
printf '%s' "$o" | grep -q 'J-DL-08' && printf '%s' "$o" | grep -q 'RC=5' && printf '%s' "$o" | grep -q 'NEXT=인터넷이 잘 되는 곳'; t $? "두 번 다 모자람 → J-DL-08 · rc 5 · 처방" "$(printf '%s' "$o" | tr '\n' '|' | cut -c1-400)"
[ "$(printf '%s\n' "$o" | grep -cE '받은 것 약 [0-9]+MB / 3MB · 걸린 시간 [0-9]+분 [0-9]+초 · 초당 약 [0-9]+KB')" = 2 ]; t $? "회차별 받은 양·시간·속도 줄 2개" "$(printf '%s' "$o" | grep '받은 것' | tr '\n' '|')"
grep -q '두 번 다 끝까지 받지 못함' "$BASE/report"; t $? "환경 보고에 받기 사실" "$(cat "$BASE/report" | tr '\n' '|')"
printf '%s' "$o" | grep -q '받습니다 (약 3MB · 잠시 걸립니다)'; t $? "화면 용량 = 핀 값에서 계산(3000000 → 약 3MB)" "$(printf '%s' "$o" | grep '받습니다 (' | head -1)"
o="$(dl 1500000 3000000)"
printf '%s' "$o" | grep -q 'J-DL-08'; [ $? -ne 0 ]; t $? "대조: 한 번만 모자람(둘째는 크기 맞음 → 지문 갈래) → J-DL-08 아님" "$(printf '%s' "$o" | grep 'J-' | tr '\n' '|')"

echo "== ② J-APP-02 자리 =="
awk '/say "\[8\/10\] 준비는 됐는데 아직 응답이 없습니다."/{a=NR} /jcode "J-APP-02"/{b=NR} a&&b&&!c&&/return 8/&&NR>b{c=NR} END{exit !(a && a<b && b<c && c-a<12)}' "$SH"; t $? "무응답 갈래: 화면 → jcode J-APP-02 → return 8(같은 블록)" "순서 다름"
awk '/jcode "J-APP-02"/{f=1} f&&/next_rerun "컴퓨터를 한 번 다시 시작하신 뒤/{ok=1} END{exit !ok}' "$SH"; t $? "다음 할 일 = 재시작 뒤 다시" "없음"

printf '\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
