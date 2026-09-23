#!/bin/bash
# D5-F6 검출 시험 — 윈 [2/10] 에서 공식 설치기가 곧바로 끝나고 파일이 안 생겼는데 J-PATH-01(재시작 처방)로 오진하면 적색.
#   원인: 사용자 PATH 를 훑는 루프가 설치기 프로세스 변수($p)를 같은 이름으로 덮어 걸린 시간이 늘 빈칸 → 빠른 종료 갈래가 죽는다.
#   ⚠맥 pwsh 는 'User' 범위 PATH 가 늘 비어 있어(윈 전용 저장소) 그 루프가 아예 안 돈다 — 실물 그대로는 결함이 안 보인다.
#     ⇒ 시험 사본에서 **그 조회식 한 줄만** 윈 모양의 값으로 바꾸고(판정 논리는 무변경 · 바꾼 곳 1곳을 단언) 실물 Step-InstallClaude 를 부른다.
#   ⚠맥 pwsh 는 끝난 자식 프로세스의 StartTime 을 빈 값으로 준다(윈은 준다 · 2026-09-23 실측) — 진짜 자식으로는 걸린 시간을 못 만든다.
#     ⇒ Start-Process 만 가짜 함수로 바꾼다: 1초 전에 시작해 지금 끝난(파일은 안 만든) 설치기 프로세스를 돌려준다. 판정 논리는 실물 그대로다.
#   기대: J-DL-07(빠른 종료 근거 fast-exit) · J-PATH-01 아님. 대조: 빠른 종료 문턱을 0 으로 두면 종전대로 J-PATH-01(시험이 갈래를 가른다).
# 쓰는 법: bash tests/d5-f6-fast-exit-code.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
BASE="$(mktemp -d "${TMPDIR:-/tmp}/d5f6.XXXXXX")" || exit 2
trap '[ -n "${KEEP:-}" ] || rm -rf "$BASE"; [ -n "${KEEP:-}" ] && echo "BASE=$BASE"' EXIT
PS="$BASE/bootstrap.ps1"
python3 - "$SRC" "$PS" <<'PYEOF' || { echo "FAIL 측정 무효: 사용자 PATH 조회식을 1곳으로 못 찾았다"; exit 2; }
import sys
b = open(sys.argv[1], 'rb').read().decode('utf-8')
o = "        $u = [Environment]::GetEnvironmentVariable('Path','User')\n"
if b.count(o) != 1: sys.exit(1)
open(sys.argv[2], 'wb').write(b.replace(o, "        $u = 'C:\\Windows\\fake-a;C:\\Users\\someone\\AppData\\Local\\fake-b'\n").encode('utf-8'))
PYEOF
mkdir -p "$BASE/pbin"; ln -sf "$PW" "$BASE/pbin/pwsh"
run_ps() { # run_ps <이름> <빠른 종료 문턱 초>
  mkdir -p "$BASE/wh-$1" "$BASE/up-$1"
  PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$1" USERPROFILE="$BASE/up-$1" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$1' -Value \$m -Encoding UTF8 }
function Say(\$m) { Add-Content -LiteralPath '$BASE/wsay-$1' -Value \$m -Encoding UTF8 }
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }
function Start-Process { Add-Content -LiteralPath '$BASE/sp-$1' -Value (\$args -join ' ') -Encoding UTF8
  \$o = [pscustomobject]@{ HasExited = \$true; ExitCode = 0; StartTime = (Get-Date).AddSeconds(-1); ExitTime = (Get-Date); Id = 4242 }
  \$o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { return \$true }; return \$o }
\$Mode = 'real'; \$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'; \$ClaudeInstallFastExitSec = $2; \$script:NetFailed = \$false
Write-Output (Step-InstallClaude)" > "$BASE/out-$1" 2>&1
}
run_ps F 60
run_ps C 0
grep -q -- '-PassThru' "$BASE/sp-F" 2>/dev/null || { echo "FAIL 측정 무효: 설치기를 띄우는 자리(Start-Process)에 닿지 않았다"; tail -5 "$BASE/out-F" | sed 's/^/  /'; exit 2; }
grep -q 'J-PATH-01' "$BASE/wsay-C" 2>/dev/null || { echo "FAIL 측정 무효: 대조군(문턱 0)이 J-PATH-01 로 가지 않았다 — 시험이 갈래를 못 가른다"; grep 'J-' "$BASE/wsay-C" | sed 's/^/  /'; exit 2; }
fail=0
if grep -q 'J-PATH-01' "$BASE/wsay-F"; then echo "FAIL 설치기가 곧바로 끝났는데 J-PATH-01(재시작 처방)로 오진했다"; fail=1; fi
grep -q 'J-DL-07' "$BASE/wsay-F" || { echo "FAIL J-DL-07 이 없다:"; grep -E '\[2/10\]|J-' "$BASE/wsay-F" | sed 's/^/  /'; fail=1; }
grep -q '^J-DL-07 by: fast-exit' "$BASE/wlog-F" 2>/dev/null || { echo "FAIL 판정 근거가 fast-exit 가 아니다: $(grep 'J-DL-07 by' "$BASE/wlog-F" 2>/dev/null)"; fail=1; }
grep -Eq '설치기 걸린 시간: [0-9]+초' "$BASE/wsay-F" || { echo "FAIL 걸린 시간 칸이 비었다: $(grep '걸린 시간' "$BASE/wsay-F")"; fail=1; }
[ "$fail" -eq 0 ] && echo "PASS 사용자 PATH 가 있는 기계에서 곧바로 끝난 설치기 → J-DL-07(fast-exit) · 걸린 시간 기록 · 대조군(문턱 0) J-PATH-01"
exit "$fail"
