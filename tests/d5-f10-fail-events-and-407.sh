#!/bin/bash
# D5-F10 검출 시험 — ①진단 코드 없이 끝난 실패도 「단계 · 사유 코드」 실패 진행 이벤트를 남기는가 ③맥 [5/10] 이 407(프록시 로그인 요구)을
#   윈판처럼 곧바로 J-NET-01 로 끝내는가(앞 판 = 연결 문제로 읽어 30분 대기).
#   ⛔망 0 · 라이브 서버 0 — 진행 전송 함수를 기록 함수로 바꿔 끼운다(보내는 내용만 센다). 받기(curl)는 셸 함수 가짜.
#   ②(망이 끊긴 동안의 이벤트 유실)는 시험 대상이 아니다 — 끊긴 동안에는 원리상 보낼 길이 없다(보고서에 불가 사유로 적음).
# 쓰는 법: bash tests/d5-f10-fail-events-and-407.sh [install-master 경로]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
DIR="${1:-$(cd "$(dirname "$0")/../install-master" && pwd)}"
SH="$DIR/bootstrap.sh"; PS="$DIR/bootstrap.ps1"
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f10.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
fail=0
bad() { echo "FAIL $1"; fail=1; }
runsh() { # runsh <이름> <sh 글> — 실물을 함수 묶음으로 읽고 진행 전송만 기록으로 바꾼다
  # ⚠JARVIS_HOME 폴더 이름은 install-jarvis 여야 한다(설치기는 제가 만든 그 이름의 폴더만 쓴다 · 아니면 J-HOME-01 로 끝나 대상에 못 닿는다).
  mkdir -p "$T/h-$1"
  local body="$2"   # ⚠아래 `set --` 가 위치 인자를 지우므로 본문을 먼저 담는다(첫 작성 때 빈 글을 돌려 전 갈래가 「못 닿음」이었다)
  ( export HOME="$T/h-$1" JARVIS_HOME="$T/h-$1/install-jarvis" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 EV="$T/ev-$1"
    : > "$EV"; set --
    . "$SH" >/dev/null 2>&1 || exit 97
    progress_send() { printf '%s\n' "$*" >> "$EV"; }
    sleep() { echo "sleep $*" >> "$EV.sleep"; }
    eval "$body" ) > "$T/out-$1" 2>&1
  echo $?
}
# ③ 맥 407 — 받기 실패 뒤 자리 물음이 407 을 답한다
rc="$(runsh p407 'curl() { case "$*" in *"%{http_code}"*) printf 407; return 0;; esac; return 22; }; NET_WAIT_TIMEOUT=1800; MODE=full
[ "$(uname -m)" = "arm64" ] || { cys_use_fork_x64_pin; CYS_X64_PIN_PENDING=0; }
step_download_cys; echo "rc=$? J_CODE=$J_CODE"')"
grep -q 'J-HOME-01' "$T/out-p407" && { echo "FAIL 측정 무효: 설치 폴더 조건(J-HOME-01)에 걸려 대상에 못 닿았다"; exit 2; }
grep -q '^rc=' "$T/out-p407" || { echo "FAIL 측정 무효: step_download_cys 가 돌아오지 않았다"; tail -3 "$T/out-p407" | sed 's/^/  /'; exit 2; }
grep -q '^rc=5 J_CODE=J-NET-01$' "$T/out-p407" || bad "[맥 407] J-NET-01 · rc 5 로 곧바로 끝나지 않았다: $(grep '^rc=' "$T/out-p407")"
grep -q '프록시가 로그인을 요구해서' "$T/out-p407" || bad "[맥 407] 사람에게 까닭(프록시)을 말하지 않았다"
[ ! -s "$T/ev-p407.sleep" ] || bad "[맥 407] 연결 대기에 들어갔다(sleep $(wc -l < "$T/ev-p407.sleep" | tr -d ' ')회)"
grep -q 'fail  J-NET-01' "$T/ev-p407" || bad "[맥 407] 실패 이벤트(사유 J-NET-01)가 없다: $(tr '\n' '|' < "$T/ev-p407")"
# ① 맥 — 코드 없이 0 이 아닌 코드로 끝난 실패 · 대조군 둘(성공 끝 · 코드가 있는 실패)
runsh unk 'log "[3/10] 흉내"; J_CODE=""; exit 3' >/dev/null
runsh ok0 'J_CODE=""; exit 0' >/dev/null
runsh coded 'jcode J-DL-05 "흉내"; exit 5' >/dev/null
grep -q ' fail  J-UNK-00$' "$T/ev-unk" || bad "[맥 ①] 코드 없는 실패 끝에 실패 이벤트(J-UNK-00)가 없다: $(tr '\n' '|' < "$T/ev-unk")"
! grep -q 'J-UNK-00' "$T/ev-ok0" || bad "[맥 ① 대조] 성공 끝(rc 0)에도 J-UNK-00 을 보냈다"
[ "$(grep -c ' fail ' "$T/ev-coded")" = 1 ] && grep -q 'fail  J-DL-05' "$T/ev-coded" || bad "[맥 ① 대조] 코드가 있는 실패에 실패 이벤트가 1건(J-DL-05)이 아니다: $(tr '\n' '|' < "$T/ev-coded")"
[ -s "$T/ev-unk" ] || true
# ① 윈 — 끝맺음의 J-UNK-00 채우기가 실패 이벤트를 보내는가(pwsh 로 실물 함수 호출) + 막힌 단계 이벤트(구문 대조)
if command -v pwsh >/dev/null 2>&1; then
  out="$(JARVIS_LIB_ONLY=1 JARVIS_NO_PROGRESS=1 JARVIS_HOME="$T/wh" perl -e 'alarm 90; exec @ARGV or exit 126' pwsh -NoProfile -Command "
. '$PS' *> \$null
\$script:Ev = [System.Collections.Generic.List[string]]::new()
function Send-Progress { param(\$a, \$b, \$c, \$d, \$e) \$script:Ev.Add(('' + \$a + '|' + \$b + '|' + \$d)) }
function Say(\$m) { }; function Write-Log([string]\$m) { }; function Update-HelpAttempts { }; function Invoke-RemoteHelp { }
function Write-HelpEscalation { }; function Show-RerunHow { }
\$Mode = 'full'; \$script:JCode = ''; \$script:ReachedWake = \$false; \$script:NextStep = ''
Write-ClosingNote
Write-Output ('EV=' + (\$script:Ev -join ';'))
" 2>&1)"
  ev="$(printf '%s\n' "$out" | grep '^EV=' | tail -1)"
  [ -n "$ev" ] || { echo "FAIL 측정 무효: 윈 끝맺음 결과 줄이 없다"; printf '%s\n' "$out" | tail -3 | sed 's/^/  /'; exit 2; }
  printf '%s' "$ev" | grep -q '|fail|J-UNK-00' || bad "[윈 ①] 끝맺음이 J-UNK-00 을 채우고도 실패 이벤트를 안 보냈다: $ev"
else
  echo "SKIP [윈 ①] pwsh 가 없다(끝맺음 호출 시험)"
fi
python3 - "$PS" <<'PYEOF' || bad "[윈 ①] [5/10]~[8/10] 막힘 자리에 코드 없을 때의 실패 이벤트(J-UNK-00)가 없다(구문 대조)"
import re, sys
t = open(sys.argv[1], encoding='utf-8-sig').read()
i = t.find("$script:BlockedStep = $st.Name")
seg = t[i:i + 600] if i >= 0 else ''
sys.exit(0 if (i >= 0 and re.search(r"if \(-not \$script:JCode\) \{[^\n]*Send-Progress \$st\.Step 'fail' \$null 'J-UNK-00'", seg) and seg.find('break') > seg.find("'J-UNK-00'")) else 1)
PYEOF
[ "$fail" -eq 0 ] && echo "PASS 맥 407 → J-NET-01 rc 5 · 대기 0 · 실패 이벤트 / 코드 없는 실패 끝 → J-UNK-00 이벤트(대조군 둘 정상) / 윈 끝맺음·막힘 자리 실패 이벤트"
exit "$fail"
