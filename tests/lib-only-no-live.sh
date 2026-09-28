#!/bin/bash
# 0.3.36 — 시험이 설치기를 「함수 묶음」으로 읽어 들인 셸(JARVIS_LIB_ONLY=1)은 진행 전송을 라이브 서버로 보내지 못한다.
#
# 까닭: 2026-09-24 19:01 시험 시간대에 판 0.3.36 · 맥 · 0/10 · J-UNK-00 실패 이벤트 2건이 라이브 서버에 도착했다.
#   시험 하네스가 JARVIS_NO_PROGRESS 를 풀거나(env -i 로 환경을 새로 짜면 그 레버가 사라진다) 가짜 전송 함수를 미처 두기 전에
#   끝나면, 끝맺음(EXIT 트랩)이 진짜 주소로 실패 이벤트를 보낼 수 있다. 레버를 기억하는 대신 주소 자체를 막는다.
# 재는 것
#   맥 ⓐ LIB_ONLY 셸에서 MODE=full · 레버 없음 · 가짜 전송 없음 → progress_send + 0 아닌 끝(J-UNK-00) 이 불러도 라이브 주소 호출 0
#      ⓑ 대조군: JARVIS_PROGRESS_URL 을 주면 그 주소로 간다(가짜 curl 이 호출을 실제로 본다 — 「0건」 이 공허하지 않다)
#      ⓒ 읽은 뒤 LIB_ONLY 를 비워도(unset) 같다 — 차단은 읽어 들인 순간에 고정된다(이종 검토)
#      ⓓ 도움 보고(/api/help)도 라이브로 가지 않는다 — jcode 뒤 0 아닌 끝(이종 검토 재현: 종전 라이브 3건)
#   윈 ⓐ LIB_ONLY 로 읽은 뒤 Send-Progress · Get-EvidenceBaseUrl 이 라이브 주소를 쓰지 않는다 ⓑ 대조군: JARVIS_PROGRESS_URL 을 주면 그 주소
#      ⓒ 읽은 뒤 $env:JARVIS_LIB_ONLY = '' (시험 관용구 13곳)여도 같다 ⓓ 도움 보고(Invoke-RemoteHelpHttp)·폰 주소가 라이브가 아니다
# 쓰는 법: bash tests/lib-only-no-live.sh [--dir <install-master 자리>]   · rc 0 = 통과 · 1 = 실패 · 2 = 잴 수 없음
# ⛔바깥에 닿지 않는다 — 가짜 curl(보내지 않고 기록만) · 가짜 Invoke-WebRequest · 임시 HOME.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
DIR="$HERE/../install-master"
[ "${1:-}" = "--dir" ] && DIR="$2"
SH="$(cd "$DIR" && pwd)/bootstrap.sh"
PS="$(cd "$DIR" && pwd)/bootstrap.ps1"
BASE="$(mktemp -d /tmp/libonlyXXXXXX)" || exit 2
trap 'rm -rf "$BASE"' EXIT
pass=0; fail=0
t() { if [ "$1" -eq 0 ]; then pass=$((pass+1)); printf '  ok   %s\n' "$2"; else fail=$((fail+1)); printf '  FAIL %s  ← %s\n' "$2" "$3"; fi; }
mkdir -p "$BASE/bin"
cat > "$BASE/bin/curl" <<EOF
#!/bin/bash
for a in "\$@"; do case "\$a" in http://*|https://*) echo "\$a" >> "\$CURL_LOG" ;; esac; done
printf 000; exit 7
EOF
chmod +x "$BASE/bin/curl"
live_count() { grep -cvE '^http://(127\.0\.0\.1|localhost)[:/]' "$1" 2>/dev/null || true; }

mac_run() { # mac_run <이름> [JARVIS_PROGRESS_URL 값] [읽은 뒤 할 일(기본 = 진행 전송 + exit 1)]
  local h="$BASE/$1"; mkdir -p "$h"; : > "$BASE/$1.calls"
  env -i PATH="$BASE/bin:/usr/bin:/bin:/usr/sbin:/sbin" HOME="$h" TMPDIR="$BASE" JARVIS_HOME="$h/install-jarvis" JARVIS_LIB_ONLY=1 \
      CURL_LOG="$BASE/$1.calls" SH="$SH" ${2:+JARVIS_PROGRESS_URL="$2"} \
    perl -e 'alarm 60; exec @ARGV or exit 126' /bin/bash -c '. "$SH" >/dev/null 2>&1; mkdir -p "$JARVIS_HOME"; MODE=full; NOTICE_SHOWN=1; '"${3:-progress_send \"1/10\" info \"\" \"\" env; exit 1}" >/dev/null 2>&1
}
mac_run a
n="$(live_count "$BASE/a.calls")"; [ "$n" = "0" ]; t $? "[맥 ⓐ] LIB_ONLY 셸의 진행 전송·끝맺음 실패 이벤트가 라이브 주소로 가지 않는다" "라이브 호출 $n 건: $(grep -vE '^http://(127\.0\.0\.1|localhost)' "$BASE/a.calls" | sort -u | head -2 | tr '\n' ' ')"
[ "$(wc -l < "$BASE/a.calls" | tr -d ' ')" = 2 ]
t $? "[맥 ⓐ] (측정 도달) 전송 시도가 정확히 2건 — 진행 1 + 끝맺음 J-UNK-00 1(이종 검토: 끝맺음 경로를 따로 증명)" "호출 $(wc -l < "$BASE/a.calls" | tr -d ' ')건 = 이 시험이 대상을 다 만나지 못했다"
mac_run b "http://127.0.0.1:9/fake-progress"
grep -q '^http://127.0.0.1:9/fake-progress' "$BASE/b.calls"; t $? "[맥 ⓑ 대조군] JARVIS_PROGRESS_URL 을 주면 그 주소로 간다" "$(head -2 "$BASE/b.calls" | tr '\n' ' ')"
mac_run c "" 'unset JARVIS_LIB_ONLY; progress_send "1/10" info "" "" env; exit 1'
n="$(live_count "$BASE/c.calls")"; [ "$n" = "0" ] && [ -s "$BASE/c.calls" ]
t $? "[맥 ⓒ] 읽은 뒤 LIB_ONLY 를 비워도 라이브로 가지 않는다(그리고 전송 시도는 있었다)" "라이브 $n 건 · 호출 $(wc -l < "$BASE/c.calls" | tr -d ' ') 건: $(grep -vE '^http://(127\.0\.0\.1|localhost)' "$BASE/c.calls" | sort -u | head -2 | tr '\n' ' ')"
mac_run d "" 'jcode J-NET-02 "시험"; exit 3'
n="$(live_count "$BASE/d.calls")"; [ "$n" = "0" ]; t $? "[맥 ⓓ] 도움 보고(/api/help)·진행 전송이 라이브로 가지 않는다(jcode 뒤 exit 3)" "라이브 $n 건: $(grep -vE '^http://(127\.0\.0\.1|localhost)' "$BASE/d.calls" | sort -u | head -3 | tr '\n' ' ')"
grep -q '/api/help' "$BASE/d.calls"; t $? "[맥 ⓓ] (측정 도달) 도움 보고 시도 자체는 있었다" "$(sort -u "$BASE/d.calls" | head -3 | tr '\n' ' ')"

PW="$(command -v pwsh 2>/dev/null)"
if [ -z "$PW" ]; then
  echo "  skip [윈] pwsh 가 없다(통과로 세지 않는다)"
else
  win_run() { # win_run [JARVIS_PROGRESS_URL 값] [읽은 뒤 끼울 줄] → 「send=<Uri>|ev=<주소>」
    env -u JARVIS_NO_PROGRESS -u JARVIS_PROGRESS_URL ${1:+JARVIS_PROGRESS_URL="$1"} JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" \
      perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command ". '$PS' *> \$null; ${2:-}; \$script:NoticeShown = \$true; function Write-Log([string]\$m) { }
\$script:seen = @(); function Invoke-WebRequest { param(\$Uri) \$script:seen += [string]\$Uri; throw 'no network in test' }
\$Mode = 'full'; Send-Progress '1/10' 'info' \$null \$null \$null
'send=' + (\$script:seen -join ',') + '|ev=' + (Get-EvidenceBaseUrl)" 2>/dev/null | tail -1
  }
  r="$(win_run)"
  case "$r" in send=http://127.0.0.1*\|ev=http://127.0.0.1*) true ;; *) false ;; esac
  t $? "[윈 ⓐ] LIB_ONLY 로 읽은 뒤 Send-Progress·증거 주소가 라이브가 아니다(그리고 전송 시도는 있었다)" "$r"
  r="$(win_run "http://127.0.0.1:9/fake-progress")"
  [ "$r" = "send=http://127.0.0.1:9/fake-progress|ev=http://127.0.0.1:9/fake-progress" ]; t $? "[윈 ⓑ 대조군] JARVIS_PROGRESS_URL 을 주면 그 주소" "$r"
  r="$(win_run "" "\$env:JARVIS_LIB_ONLY = ''")"
  case "$r" in send=http://127.0.0.1*\|ev=http://127.0.0.1*) true ;; *) false ;; esac
  t $? "[윈 ⓒ] 읽은 뒤 \$env:JARVIS_LIB_ONLY = '' 여도 진행·증거 주소가 라이브가 아니다" "$r"
  r="$(env -u JARVIS_NO_PROGRESS -u JARVIS_PROGRESS_URL JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh" \
      perl -e 'alarm 90; exec @ARGV or exit 126' "$PW" -NoProfile -Command ". '$PS' *> \$null; \$env:JARVIS_LIB_ONLY = ''
\$script:seen = @(); function Invoke-WebRequest { param(\$Uri) \$script:seen += [string]\$Uri; throw 'no network in test' }
[void](Invoke-RemoteHelpHttp 'POST' '/api/help' '{}')
'help=' + (\$script:seen -join ',') + '|base=' + \$HelpApiUrl" 2>/dev/null | tail -1)"
  case "$r" in help=http://127.0.0.1*/api/help\|base=http://127.0.0.1*) true ;; *) false ;; esac
  t $? "[윈 ⓓ] 도움 보고(Invoke-RemoteHelpHttp)·폰 주소 바탕이 라이브가 아니다(그리고 시도는 있었다)" "$r"
fi

echo "== 합계: ok $pass · FAIL $fail =="
[ "$fail" -eq 0 ]
