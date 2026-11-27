#!/bin/bash
# review-fix-jarvis-1115 — 맥 설치기 지적 2건을 실물 함수로 잰다(JARVIS_LIB_ONLY=1 · 네트워크 0 · 쓰기는 스크래치 안에서만)
#   M1 글자 첨부(bootstrap.log·env-report.md·proc-tree.txt)는 지운 뒤 보낸다 — 로그인 이름·집 폴더·이메일·토큰 · 상한 · 못 지우면 <전부 지움> 한 낱말
#      (TICKET=scrub-v3-port-1116 · 「둘로 가름」 = 파일 전체를 엄격히 읽기 → 전체 가림 → 끝에서 자름 · 이름 묶음 파일 = JSON { names, overflow })
#   ※ 가림 함수의 공용 벡터·무작위 차등은 tests/scrub-v3-mac.mjs(관문 1·2) — 여기서는 bash 길(help_scrubbed_tail · 보고 · 첨부 묶음) 끝끝을 잰다
#   M2 폴링 GET /api/help/<번호> 에 출처 헤더(x-help-client) — 다른 GET 에는 붙이지 않는다 · ack 는 앞 판처럼
# 쓰는 법: bash tests/review-1115-mac.sh [--dir install-master]   · rc 0 = 전건 통과
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && SRC_DIR="$2"
SH="$SRC_DIR/bootstrap.sh"
BASH_BIN=/bin/bash; [ -x "$BASH_BIN" ] || BASH_BIN=bash
SB="$(mktemp -d)"; mkdir -p "$SB/home" "$SB/tmp" "$SB/bin" "$SB/rh" "$SB/bodies"
# 프로세스 목록 시험용 실행 파일 자리 — 집 폴더(/Users/…) 밑이어야 ps comm= 에 /Users/ 가 찍힌다 → 이 작업 폴더 안의 임시 폴더(끝나면 지움)
PROC="$(mktemp -d "$HERE/.proc-tree-XXXXXX")"
trap 'rm -rf "$SB" "$PROC"' EXIT
PASS=0; FAIL=0
ck() { if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL %s  ← %s\n' "$1" "${3:-}"; fi; }

# 가짜 curl — 받은 인자를 적고 200 을 돌려준다(네트워크 0)
cat > "$SB/bin/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$CURL_LOG"
out=""; prev=""
for a in "$@"; do [ "$prev" = "-o" ] && out="$a"; [ "$prev" = "--data-binary" ] && [ -n "${CURL_BODIES:-}" ] && cp "${a#@}" "$CURL_BODIES/$(ls "$CURL_BODIES" | wc -l | tr -d ' ').json" 2>/dev/null; prev="$a"; done
[ -n "$out" ] && printf '{}' > "$out"
printf '200'
EOF
chmod +x "$SB/bin/curl"

cat > "$SB/case.sh" <<'EOF'
. "$T_SH" || exit 9
CLOSING_DONE=1
RH_ID=K7M2Q9XR
RH_TMP="$T_RH"
printf 'x-help-client: %s\n' "$(printf 'a%.0s' $(seq 1 64))" > "$RH_TMP/client-header"
nameset() { printf '{"names":[%s],"overflow":%s}' "$1" "${2:-false}" > "$RH_TMP/names"; }
nameset '"hongtester"'
# M1 — 지울 것이 든 기록
LOG_FILE="$T_SB/bootstrap.log"
{
  printf 'USER=macuser77\n'
  printf 'seed: path /Users/macuser77/.local/bin\n'
  printf 'from report names: hongtester did it\n'
  printf 'mail: someone.here@example.org\n'
  printf 'Authorization: Bearer abcdEFGH1234\n'
  printf 'keep this line [3/10]\n'
} > "$LOG_FILE"
if help_scrubbed_tail "$LOG_FILE" 4096 "$T_SB/out.log"; then echo "M1RC=0"; else echo "M1RC=1"; fi
# 상한
BIG="$T_SB/big.log"
{ for i in $(seq 1 60); do printf '가%.0s' $(seq 1 300); printf '\n'; done; printf 'END-LINE /Users/macuser77/x\n'; } > "$BIG"
help_scrubbed_tail "$BIG" 2048 "$T_SB/out.big"; echo "BIGRC=$?"
# F10 — 비밀값 한 줄이 상한보다 길다(토큰 400자 · 상한 100): 전체를 가린 뒤 자르므로 토큰 조각이 남지 않는다
{ printf 'head line\n'; printf 'Authorization: Bearer '; printf 'T%.0s' $(seq 1 400); printf '\n'; } > "$T_SB/long.log"
help_scrubbed_tail "$T_SB/long.log" 100 "$T_SB/out.long"; echo "LONGRC=$?"
{ printf 'Authorization: Bearer '; printf 'T%.0s' $(seq 1 400); printf '\nshort tail line\n'; } > "$T_SB/long2.log"
help_scrubbed_tail "$T_SB/long2.log" 100 "$T_SB/out.long2"; echo "LONG2RC=$?"
# M32 재현(설계 split/model test.js) — Bearer 뒤 빈 줄이 앞 판의 창(2×상한)을 넘어 토큰이 창 안에만 있다: 앞 판 = 토큰이 남음 · 새 판 = 남지 않음
{ printf 'x%.0s' $(seq 1 100); printf '\nBearer'; head -c $((4096 * 2 - 200)) /dev/zero | tr '\0' '\n'; printf 'abcdefghij0123456789ABCDEFGHIJ\n'; for i in $(seq 1 18); do printf 'tail line\n'; done; } > "$T_SB/m32.log"
help_scrubbed_tail "$T_SB/m32.log" 4096 "$T_SB/out.m32"; echo "M32RC=$?"
# M1b 지우는 순서 — 이름이 sk·Bearer 여도 토큰 값이 남지 않는다(보고 본문·ack·첨부 = 같은 가림)
nameset '"sk"'
printf 'key=sk-abcdefgh12345678 saved\n' > "$T_SB/s1.log"
help_scrubbed_tail "$T_SB/s1.log" 4096 "$T_SB/out.s1"; echo "S1RC=$?"
nameset '"Bearer"'
printf 'Authorization: Bearer abcDEF1234567890\n' > "$T_SB/s2.log"
help_scrubbed_tail "$T_SB/s2.log" 4096 "$T_SB/out.s2"; echo "S2RC=$?"
nameset '"키 지움","토큰","지움","이메일","Users","user","a.b+(c)","hello"'
printf 'mail a.b@example.com key sk-abcdefgh12345678 Authorization: Bearer tok12345678 path /Users/hong/x who a.b+(c) and axb+(c) hello\n' > "$T_SB/s3.log"
help_scrubbed_tail "$T_SB/s3.log" 4096 "$T_SB/out.s3"; echo "S3RC=$?"
# M1d 알려진 이름은 원본 그대로(codex split 1R 발견 1) — 한 글자 계정 q · 따옴표 든 계정 acct'77 이 첨부와 보고 본문 두 칸 모두에서 가려진다
nameset '"q"'
printf "USERNAME=q\nstatus q ok\n" > "$T_SB/q.log"
help_scrubbed_tail "$T_SB/q.log" 4096 "$T_SB/out.q"; echo "QRC=$?"
nameset "\"acct'77\""
printf "USERNAME=acct'77\nstatus acct'77 ok\n" > "$T_SB/a77.log"
help_scrubbed_tail "$T_SB/a77.log" 4096 "$T_SB/out.a77"; echo "A77RC=$?"
for acct in q "acct'77"; do
  printf 'USERNAME=%s\nstatus %s ok\n' "$acct" "$acct" > "$T_SB/rep.env"; printf 'log %s line\n' "$acct" > "$T_SB/rep.log"
  RH_ENV_FILE="$T_SB/rep.env" RH_LOG_FILE="$T_SB/rep.log" RH_EXTRA_NAMES="$acct" RH_CODE=J-NET-02 RH_STEP=5/10 RH_VERSION=0.0.1 \
    RH_REPORT_OUT="$T_SB/rep-$acct.json" RH_NAMES_OUT="$T_SB/rep-names-$acct.json" remote_help_js report >/dev/null 2>&1; echo "REPRC=$?"
done
# M1h 보고 본문의 넘침(독립 검증 M1·M5) — 표시 이름 65개(acct000~acct064)가 든 환경 보고로 modeReport → 두 본문 칸 모두 <전부 지움>(묶음째 넘겨야 한다)
{ for i in $(seq 0 64); do printf 'USER=acct%03d\n' "$i"; done; } > "$T_SB/ovf.env"; printf 'log line plain\n' > "$T_SB/ovf-rep.log"
RH_ENV_FILE="$T_SB/ovf.env" RH_LOG_FILE="$T_SB/ovf-rep.log" RH_EXTRA_NAMES="" RH_CODE=J-NET-02 RH_STEP=5/10 RH_VERSION=0.0.1 \
  RH_REPORT_OUT="$T_SB/rep-ovf.json" RH_NAMES_OUT="$T_SB/rep-names-ovf.json" remote_help_js report >/dev/null 2>&1; echo "OVFREPRC=$?"
# M1i 명령 결과(ack) — Bearer 로 시작하고 4KB 를 넘는 출력: 전체를 가린 뒤 끝 4KB(독립 검증 M3 — 가리기 전에 자르면 토큰 꼬리가 남는다)
nameset '"hongtester"'
{ printf 'Bearer '; printf 'T%.0s' $(seq 1 5000); printf '\nend of output\n'; } > "$T_SB/ack-big"
RH_OUTPUT_FILE="$T_SB/ack-big" RH_NAMES_FILE="$RH_TMP/names" RH_ACK_OUT="$T_SB/ack-big.json" remote_help_js ack 8 ran 0 0 30 >/dev/null 2>&1; echo "ACKBIGRC=$?"
# M1e 닫힌 실패 = <전부 지움> 한 낱말(파일이 있었다는 사실만) — 틀린 UTF-8 · UTF-16 · NUL · 넘친 이름 묶음 · 크기 초과 · JS 실패 / 보낼 것 없음 = 빈 파일 · 머리표뿐
nameset '"hongtester"'
printf 'hongtester \xb1\xe8\n' > "$T_SB/cp949.log"; help_scrubbed_tail "$T_SB/cp949.log" 4096 "$T_SB/out.cp949"; echo "CPRC=$?"
printf 'A\xa9hongtester\n' > "$T_SB/a9.log"; help_scrubbed_tail "$T_SB/a9.log" 4096 "$T_SB/out.a9"; echo "A9RC=$?"
printf '\xff\xfeh\x00o\x00n\x00g\x00' > "$T_SB/u16.log"; help_scrubbed_tail "$T_SB/u16.log" 4096 "$T_SB/out.u16"; echo "U16RC=$?"
printf 'ab\x00hongtester\n' > "$T_SB/nul.log"; help_scrubbed_tail "$T_SB/nul.log" 4096 "$T_SB/out.nul"; echo "NULRC=$?"
: > "$T_SB/empty.log"; help_scrubbed_tail "$T_SB/empty.log" 4096 "$T_SB/out.empty"; echo "EMPTYRC=$?"
printf '\xef\xbb\xbf' > "$T_SB/bom.log"; help_scrubbed_tail "$T_SB/bom.log" 4096 "$T_SB/out.bom"; echo "BOMRC=$?"
# 크기 문지기는 읽기 전 파일 바이트 수로 — 한글 기록(3바이트 글자)은 바이트로는 상한을 넘어도 코드 단위로는 안 넘는다(칸 문지기만으로는 못 잡는 꼴)
python3 -c 'import sys; sys.stdout.buffer.write("가".encode() * 1398102)' > "$T_SB/huge.log"; help_scrubbed_tail "$T_SB/huge.log" 4096 "$T_SB/out.huge"; echo "HUGERC=$?"
help_scrubbed_tail "$LOG_FILE" 0 "$T_SB/out.bad"; echo "BADRC=$?"
nameset '' true
printf 'nothing secret here\n' > "$T_SB/ovf.log"; help_scrubbed_tail "$T_SB/ovf.log" 4096 "$T_SB/out.ovf"; echo "OVFRC=$?"
cp "$RH_TMP/names" "$T_SB/names-after-ovf"
# M1f 첨부가 합친 이름 묶음을 다시 적는다(다음 칸이 이어받음) — 첨부 글의 USER= 이름이 그 뒤 ack 결과에서도 가려진다
nameset '"hongtester"'
printf 'USER=laterfound9\n' > "$T_SB/grow.log"; help_scrubbed_tail "$T_SB/grow.log" 4096 "$T_SB/out.grow" >/dev/null
printf 'later output laterfound9 hongtester\n' > "$T_SB/ack-out"
RH_OUTPUT_FILE="$T_SB/ack-out" RH_NAMES_FILE="$RH_TMP/names" RH_ACK_OUT="$T_SB/ack.json" remote_help_js ack 7 ran 0 0 30 >/dev/null 2>&1; echo "ACKRC=$?"
# M1g 프로세스 목록(proc-tree.txt) — 집 폴더 밑의 실행 파일로 자식을 띄우고 help_fail_attachments 가 실제로 보낸 바이트를 본다(가짜 curl 이 본문을 남긴다)
evidence_kind_jpeg() { return 1; }   # 그림 첨부는 이 시험 밖(화면을 찍지 않는다)
REPORT_FILE="$T_SB/env-report.md"; printf 'USER=macuser77\n' > "$REPORT_FILE"
ln -s /bin/sleep "$T_PROC/sleeper"   # 복사본은 서명 검사로 죽는다(rc 137 실측) — 이름 링크면 ps comm= 에 링크 경로가 찍힌다
"$T_PROC/sleeper" 30 & SLEEPER=$!
proc_tree_file "$T_SB/proc-raw.txt"; echo "PROCRAW=$?"
nameset '"hongtester"'
help_fail_attachments
kill "$SLEEPER" 2>/dev/null; wait "$SLEEPER" 2>/dev/null
# M2
remote_help_http GET "/api/help/K7M2Q9XR"
remote_help_http GET "/api/help/K7M2Q9XR/x"
remote_help_http GET "/api/help/ZZZZZZZZ"
remote_help_http POST "/api/help/K7M2Q9XR/ack" "$LOG_FILE"
EOF

PATH="$SB/bin:$PATH" CURL_LOG="$SB/curl.log" CURL_BODIES="$SB/bodies" T_SH="$SH" T_SB="$SB" T_RH="$SB/rh" T_PROC="$PROC" HOME="$SB/home" TMPDIR="$SB/tmp" \
  JARVIS_HOME="$SB/home/install-jarvis" JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 "$BASH_BIN" "$SB/case.sh" > "$SB/case.out" 2>&1

out="$(cat "$SB/out.log" 2>/dev/null)"
FULLW='<전부 지움>'
isfull() { [ "$(cat "$1" 2>/dev/null)" = "$FULLW" ]; }
rc_is() { grep -q "^$1=$2\$" "$SB/case.out"; }
rc_is M1RC 0; ck "M1 지운 첨부를 만든다(rc 0)" $? "$(tr '\n' '|' < "$SB/case.out" | cut -c1-300)"
printf '%s' "$out" | grep -qE 'macuser77|hongtester|someone\.here@|abcdEFGH1234|/Users/'; [ $? -ne 0 ]
ck "M1 로그인 이름(USER= 줄 · 보고 이름 묶음) · 집 폴더 · 이메일 · 토큰이 남지 않는다" $? "$(printf '%s' "$out" | tr '\n' '|')"
printf '%s' "$out" | grep -qF 'keep this line [3/10]' && printf '%s' "$out" | grep -qF 'seed: path ~/.local/bin'
ck "M1 지운 자리 말고는 남는다(진단 가치)" $? "$(printf '%s' "$out" | tr '\n' '|')"
big_size="$(/usr/bin/stat -f %z "$SB/out.big" 2>/dev/null || echo 99999)"
rc_is BIGRC 0 && [ "$big_size" -le 2048 ] && tail -c 20 "$SB/out.big" | grep -qF 'END-LINE ~/x' && iconv -f UTF-8 -t UTF-8 "$SB/out.big" >/dev/null 2>&1
ck "M1 상한 안 · 끝을 남긴다 · 올바른 UTF-8(글자 단위로 자름)" $? "size=$big_size"
rc_is BADRC 0 && isfull "$SB/out.bad"
ck "M1 가림 프로그램이 실패하면 <전부 지움> 한 낱말(원문을 대신 보내지 않음)" $? "$(grep BADRC "$SB/case.out") [$(cat "$SB/out.bad" 2>/dev/null)]"
l1o="$(cat "$SB/out.long" 2>/dev/null)"; l2o="$(cat "$SB/out.long2" 2>/dev/null)"
! printf '%s\n%s' "$l1o" "$l2o" | grep -q 'TTTTTTTTTT' && printf '%s' "$l1o" | grep -qF 'Bearer <토큰 지움>'
ck "M1 상한보다 긴 비밀값 줄 — 전체를 가린 뒤 자르므로 토큰 조각이 남지 않는다(F10)" $? "out.long=[$l1o] out.long2=[$l2o]"
printf '%s' "$l2o" | grep -qF 'short tail line'
ck "M1 끝의 온전한 줄은 남는다" $? "[$l2o]"
m32="$(cat "$SB/out.m32" 2>/dev/null)"
rc_is M32RC 0 && ! printf '%s' "$m32" | grep -qF 'abcdefghij0123456789ABCDEFGHIJ' && printf '%s' "$m32" | grep -qF 'tail line'
ck "M32 앞 판의 「끝 2×상한을 떼고 첫 줄 버림 → 가림」 재현 파일 — 첨부 본문에 토큰이 남지 않는다 · 끝 줄은 남는다" $? "$(printf '%s' "$m32" | tr '\n' '|' | tail -c 200)"
s1o="$(cat "$SB/out.s1" 2>/dev/null)"; s2o="$(cat "$SB/out.s2" 2>/dev/null)"; s3o="$(cat "$SB/out.s3" 2>/dev/null)"
rc_is S1RC 0 && ! printf '%s' "$s1o" | grep -qF 'abcdefgh12345678' && printf '%s' "$s1o" | grep -qF '<키 지움>'
ck "M1b 이름이 sk 여도 sk- 키 값이 남지 않는다" $? "[$s1o]"
rc_is S2RC 0 && ! printf '%s' "$s2o" | grep -qF 'abcDEF1234567890'
ck "M1b 이름이 Bearer 여도 토큰 값이 남지 않는다" $? "[$s2o]"
rc_is S3RC 0 && ! printf '%s' "$s3o" | grep -qE 'abcdefgh12345678|tok12345678|hong|a\.b@|hello'
ck "M1b 이름이 표식 낱말·Users·정규식 특수문자여도 값이 남지 않는다" $? "[$s3o]"
[ "$(cat "$SB/out.q" 2>/dev/null)" = "USERNAME=~user
status ~user ok" ] && [ "$(cat "$SB/out.a77" 2>/dev/null)" = "USERNAME=~user
status ~user ok" ]
ck "M1d 알려진 이름 원본 — 첨부: 한 글자 계정 q · 따옴표 든 acct'77 이 원문 자리 전부 가려진다" $? "q=[$(cat "$SB/out.q" 2>/dev/null)] a77=[$(cat "$SB/out.a77" 2>/dev/null)]"
python3 - "$SB/rep-q.json" "$SB/rep-acct'77.json" <<'PY' > "$SB/rep-verdict" 2>&1
import json, sys
ok = True
for p in sys.argv[1:]:
    b = json.load(open(p, encoding="utf-8"))
    ok = ok and b["env_report"] == "USERNAME=~user\nstatus ~user ok\n" and b["log_tail"] == "log ~user line"
print("REP", ok)
PY
[ "$(grep -c '^REPRC=0$' "$SB/case.out")" = "2" ] && grep -qx 'REP True' "$SB/rep-verdict"
ck "M1d 알려진 이름 원본 — 보고 본문(env_report · log_tail) 두 칸에서도 q · acct'77 이 가려진다" $? "$(cat "$SB/rep-verdict"; cat "$SB/rep-q.json" 2>/dev/null | cut -c1-200)"
python3 - "$SB/rep-ovf.json" "$SB/rep-names-ovf.json" <<'PY' > "$SB/ovfrep-verdict" 2>&1
import json, sys
b = json.load(open(sys.argv[1], encoding="utf-8")); n = json.load(open(sys.argv[2], encoding="utf-8"))
print("OVFREP", b["env_report"] == "<전부 지움>" and b["log_tail"] == "<전부 지움>" and n.get("overflow") is True)
PY
rc_is OVFREPRC 0 && grep -qx 'OVFREP True' "$SB/ovfrep-verdict"
ck "M1h 보고 본문 — 표시 이름 65개(넘침)면 env_report · log_tail 둘 다 <전부 지움> · 묶음에 넘침을 적는다" $? "$(cat "$SB/ovfrep-verdict") $(cut -c1-200 "$SB/rep-ovf.json" 2>/dev/null)"
python3 - "$SB/ack-big.json" <<'PY' > "$SB/ackbig-verdict" 2>&1
import json, sys
b = json.load(open(sys.argv[1], encoding="utf-8")); t = b["output_tail"]
print("ACKBIG", "TTTTTTTTTT" not in t and "Bearer <토큰 지움>" in t and t.endswith("end of output\n") and len(t.encode()) <= 4096)
PY
rc_is ACKBIGRC 0 && grep -qx 'ACKBIG True' "$SB/ackbig-verdict"
ck "M1i 명령 결과 — Bearer 로 시작해 4KB 를 넘는 출력도 전체를 가린 뒤 끝 4KB(토큰 조각 0)" $? "$(cat "$SB/ackbig-verdict") $(cut -c1-160 "$SB/ack-big.json" 2>/dev/null)"
rc_is CPRC 0 && isfull "$SB/out.cp949" && rc_is A9RC 0 && isfull "$SB/out.a9" && rc_is U16RC 0 && isfull "$SB/out.u16" && rc_is NULRC 0 && isfull "$SB/out.nul"
ck "M1e 틀린 UTF-8(CP949 · NSString 이 받아 주는 41 A9 꼴) · UTF-16 머리표 · NUL = <전부 지움> 한 낱말" $? "$(for f in cp949 a9 u16 nul; do printf '%s=[%s] ' $f "$(cat "$SB/out.$f" 2>/dev/null)"; done)"
grep -qF 'attach scrub: 통째 가림(decode): cp949.log' "$SB/bootstrap.log" && grep -qF 'attach scrub: 통째 가림(nul): nul.log' "$SB/bootstrap.log" && grep -qF 'attach scrub: 통째 가림(size): huge.log' "$SB/bootstrap.log"
ck "M1e 통째 가림의 까닭을 기록에 남긴다(값은 남기지 않는다)" $? "$(grep 'attach scrub' "$SB/bootstrap.log" | tr '\n' '|')"
rc_is EMPTYRC 1 && [ ! -e "$SB/out.empty" ] && rc_is BOMRC 1 && [ ! -e "$SB/out.bom" ]
ck "M1e 빈 파일 · 머리표뿐인 파일은 보내지 않는다" $? "$(grep -E 'EMPTYRC|BOMRC' "$SB/case.out" | tr '\n' ' ')"
rc_is HUGERC 0 && isfull "$SB/out.huge"
ck "M1e 크기 상한(4,194,304 바이트) 초과 = 읽지 않고 <전부 지움>" $? "$(grep HUGERC "$SB/case.out") [$(head -c 40 "$SB/out.huge" 2>/dev/null)]"
rc_is OVFRC 0 && isfull "$SB/out.ovf" && grep -q '"overflow":true' "$SB/names-after-ovf"
ck "M1e 넘친 이름 묶음으로는 가리지 않는다(통째 가림) · 넘침을 잃지 않고 다시 적는다" $? "[$(cat "$SB/out.ovf" 2>/dev/null)] $(cat "$SB/names-after-ovf" 2>/dev/null)"
python3 - "$SB/ack.json" <<'PY' > "$SB/ack-verdict" 2>&1
import json, sys
b = json.load(open(sys.argv[1], encoding="utf-8"))
print("ACK", b["output_tail"] == "later output ~user ~user\n")
PY
rc_is ACKRC 0 && grep -qx 'ACK True' "$SB/ack-verdict"
ck "M1f 첨부가 찾은 이름을 묶음에 더해 다시 적는다 — 그 뒤 명령 결과(ack)에서도 가려진다" $? "$(cat "$SB/ack-verdict") $(cat "$SB/ack.json" 2>/dev/null)"
rc_is PROCRAW 0 && grep -qF "$PROC/sleeper" "$SB/proc-raw.txt" && printf '%s' "$PROC" | grep -q '^/Users/'
ck "M1g 대조군 — 가리기 전 프로세스 목록에는 집 폴더 밑 실행 파일의 전체 경로(/Users/…)가 찍힌다" $? "$(grep -c '/Users/' "$SB/proc-raw.txt" 2>/dev/null) PROC=$PROC"
python3 - "$SB/bodies" <<'PY' > "$SB/attach-verdict" 2>&1
import base64, json, os, sys
d = sys.argv[1]
kinds = {}
for f in sorted(os.listdir(d)):
    try: b = json.load(open(os.path.join(d, f), encoding="utf-8"))
    except Exception: continue
    if "content_b64" in b: kinds[b["kind"]] = base64.b64decode(b["content_b64"])
pt = kinds.get("proc_tree")
print("KINDS", ",".join(sorted(kinds)))
print("PROC", pt is not None and b"/Users/" not in pt and len(pt) > 0 and pt.decode("utf-8").count("\n") >= 2)
print("PROCSHOW", (pt or b"")[:300].decode("utf-8", "replace").replace("\n", "|"))
env = kinds.get("env_full")
print("ENV", env is not None and b"macuser77" not in env)
PY
grep -qx 'PROC True' "$SB/attach-verdict" && grep -qx 'ENV True' "$SB/attach-verdict"
ck "M1g help_fail_attachments 가 실제로 보낸 proc-tree.txt 에 /Users/ 0건(가린 뒤 보냄) · env-report.md 도 가림" $? "$(tr '\n' ' ' < "$SB/attach-verdict" | cut -c1-400)"
body="$(awk '/^help_fail_attachments\(\) \{/{f=1} f{print} f&&/^}/{exit}' "$SH" | grep -vE '^[[:space:]]*#')"
printf '%s\n' "$body" | grep -qF 'help_scrubbed_tail "$LOG_FILE" "$ATTACH_MAX_BYTES" "$d/bootstrap.log" && help_attach log_full' \
  && printf '%s\n' "$body" | grep -qF 'help_scrubbed_tail "$REPORT_FILE" "$ATTACH_MAX_BYTES" "$d/env-report.md" && help_attach env_full' \
  && printf '%s\n' "$body" | grep -qF 'help_scrubbed_tail "$d/proc-tree.raw" "$ATTACH_MAX_BYTES" "$d/proc-tree.txt" && help_attach proc_tree' \
  && ! printf '%s\n' "$body" | grep -qF 'file_tail_capped'
ck "M1 help_fail_attachments 의 글자 첨부 셋(기록 · 환경 보고 · 프로세스 목록)은 지운 파일로만" $? "$(printf '%s\n' "$body" | grep -nE 'tail|attach' | tr '\n' '|' | cut -c1-300)"
hst="$(awk '/^help_scrubbed_tail\(\) \{/{f=1} f{print} f&&/^}/{exit}' "$SH" | grep -vE '^[[:space:]]*#')"
! printf '%s\n' "$hst" | grep -qE 'iconv|tail -c|sed '
ck "M1 help_scrubbed_tail 에 가림 앞 줄이기(tail -c · 첫 줄 버림)·느슨한 읽기(iconv -c)가 없다" $? "$(printf '%s\n' "$hst" | grep -nE 'iconv|tail|sed' | tr '\n' '|')"

# M2 의 네 호출은 case.sh 맨 끝이다(앞의 첨부 호출 수와 무관하게 끝 4줄)
l1="$(tail -n 4 "$SB/curl.log" | sed -n '1p')"; l2="$(tail -n 4 "$SB/curl.log" | sed -n '2p')"; l3="$(tail -n 4 "$SB/curl.log" | sed -n '3p')"; l4="$(tail -n 4 "$SB/curl.log" | sed -n '4p')"
printf '%s' "$l1" | grep -qF -- "-X GET -H @$SB/rh/client-header" && printf '%s' "$l1" | grep -qF '/api/help/K7M2Q9XR'
ck "M2 폴링 GET /api/help/<내 번호> 에 출처 헤더" $? "$l1"
! printf '%s\n%s' "$l2" "$l3" | grep -qF 'client-header'
ck "M2 다른 GET(하위 경로 · 남의 번호)에는 붙이지 않는다" $? "$l2 | $l3"
printf '%s' "$l4" | grep -qF "@$SB/rh/client-header"
ck "M2 ack 는 앞 판처럼 붙인다" $? "$l4"

printf '\n통과 %s · 실패 %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
