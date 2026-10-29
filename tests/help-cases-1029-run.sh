#!/bin/bash
# help-cases-1029 행동 시험 — 도움 사례 4건(10-21~26)의 기록 모양을 가짜로 만들어 [2/10]·[3/10] 판정 갈래를 잰다.
#   ⓐ KUDTUSU9 모양: 공식 설치기가 「× Installation failed · EBUSY … · (exit code 1)」을 남기고 파일 없음 · 종료 코드 못 읽음
#      → J-INST-01(busy) · J-PATH-01 아님. 대조: 같은 조건에서 설치기 기록에 실패 말이 없으면 종전대로 J-PATH-01.
#   ⓑ 종료 코드를 읽은 갈래(rc=1) + 같은 실패 말 → J-INST-01(failed 또는 busy).
#   ⓒ KXA5QUM5 모양: 10분 상한 · 백신 창 0 · 1분 멈춤 판정 0 · 직접 받기 실패 → J-AV-01 의 말이 「가능성」(백신 단정 아님).
#      대조: 백신 창 제목이 보이면 종전 문장(백신이 붙들고 있는 것으로 보입니다).
#   ⓓ QSFYDUAH·H3SRXDCT 모양: 로그인 대기 중 사람 입력 0 → away · 입력 있음+브라우저 흔적 0 → no-browser
#      · 새 브라우저+Claude 제목 → browser-seen · 못 잼 → unmeasured. 그리고 Step-Login 이 대기 바퀴마다 재고 실패 때 판정을 적는가(배선).
#   ⚠실제 설치기·로그인을 부르지 않는다 — Start-Process·Install-ClaudeDirect·Get-UserIdleMs 등은 가짜 함수 · HOME 은 임시 폴더.
# 쓰는 법: bash tests/help-cases-1029-run.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
BASE="$(mktemp -d "${TMPDIR:-/tmp}/hc1029.XXXXXX")" || exit 2
trap '[ -n "${KEEP:-}" ] || rm -rf "$BASE"; [ -n "${KEEP:-}" ] && echo "BASE=$BASE"' EXIT
PS="$BASE/bootstrap.ps1"; cp "$SRC" "$PS"
mkdir -p "$BASE/pbin"; ln -sf "$PW" "$BASE/pbin/pwsh"
# 도움 KUDTUSU9 설치기 기록 끝 그대로(사용자 폴더만 ~)
cat > "$BASE/log-busy" <<'EOF'

× Installation failed

EBUSY: resource busy or locked, rm '~\.cache\claude\staging\2.1.306.20240.1792625521341.e5ff30b8'


Try running with --force to override checks

[claude-install error] Installation failed (exit code 1)
EOF
printf 'Downloading Claude Code...\nSome other line\n' > "$BASE/log-quiet"

run_install() { # run_install <이름> <설치기 기록 파일> <ExitCode 식>
  mkdir -p "$BASE/wh-$1" "$BASE/up-$1"
  PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$1" USERPROFILE="$BASE/up-$1" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$1' -Value \$m -Encoding UTF8 }
function Say(\$m) { Add-Content -LiteralPath '$BASE/wsay-$1' -Value \$m -Encoding UTF8 }
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }
function Send-Progress { }
function Start-Process { Add-Content -LiteralPath '$BASE/sp-$1' -Value (\$args -join ' ') -Encoding UTF8
  Copy-Item -LiteralPath '$2' -Destination (Join-Path '$BASE/wh-$1' 'claude-install.log') -Force
  \$o = [pscustomobject]@{ HasExited = \$true; ExitCode = $3; StartTime = \$null; ExitTime = \$null; Id = 4242 }
  \$o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { return \$true }; return \$o }
\$Mode = 'real'; \$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'; \$script:NetFailed = \$false
Write-Output (Step-InstallClaude)" > "$BASE/out-$1" 2>&1
}
run_hold() { # run_hold <이름> <백신 창 제목('' = 없음)>
  mkdir -p "$BASE/wh-$1" "$BASE/up-$1"
  PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$1" USERPROFILE="$BASE/up-$1" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-$1' -Value \$m -Encoding UTF8 }
function Say(\$m) { Add-Content -LiteralPath '$BASE/wsay-$1' -Value \$m -Encoding UTF8 }
function Add-ReportLines(\$l) { Add-Content -LiteralPath '$BASE/wrep-$1' -Value \$l -Encoding UTF8 }
function Send-EvidenceOnce { }
function Send-Progress { }
function Write-ClaudeInstallDiag(\$p, \$where) { return @() }
function Stop-ProcTree(\$p, \$tree) { }
function Install-ClaudeDirect { return \$false }
function Get-AvWindowTitles { if ('$2') { return @('$2') }; return @() }
function Start-Process { Add-Content -LiteralPath '$BASE/sp-$1' -Value (\$args -join ' ') -Encoding UTF8
  \$o = [pscustomobject]@{ HasExited = \$false; ExitCode = \$null; StartTime = \$null; ExitTime = \$null; Id = 4243 }
  \$o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { return \$true }; return \$o }
\$Mode = 'real'; \$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'; \$script:NetFailed = \$false
\$ClaudeInstallWaitMs = 2000; \$ClaudeInstallRetryWaitMs = 2000; \$InstallNoteEverySec = 1
Write-Output (Step-InstallClaude)" > "$BASE/out-$1" 2>&1
}
run_presence() {
  PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-p" USERPROFILE="$BASE/up-p" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
function Fake-Sw(\$s) { return [pscustomobject]@{ Elapsed = [pscustomobject]@{ TotalSeconds = \$s } } }
function Run-Case(\$name, \$idleFn, \$browserFn) {
  \$script:T = 0; \$script:BrowserFn = \$browserFn; \$script:IdleFn = \$idleFn
  function global:Get-LoginBrowserProcs { return @(& \$script:BrowserFn \$script:T) }
  function global:Get-UserIdleMs { return [long](& \$script:IdleFn \$script:T) }
  \$pr = New-LoginPresence
  for (\$t = 0; \$t -le 1200; \$t += 2) { \$script:T = \$t; \$pr.Sw = Fake-Sw \$t; Update-LoginPresence \$pr }
  \$v = Resolve-LoginPresence \$pr
  Write-Output (\$name + '=' + \$v.Tag + ' | ' + \$v.Input + ' | ' + \$v.Browser) }
Run-Case 'away' { param(\$t) (\$t * 1000) + 30000 } { param(\$t) @(@{ Id = 11; Title = 'YouTube - Chrome' }) }
Run-Case 'nobrowser' { param(\$t) 800 } { param(\$t) @(@{ Id = 11; Title = 'YouTube - Chrome' }) }
Run-Case 'seen' { param(\$t) 800 } { param(\$t) if (\$t -ge 30) { @(@{ Id = 11; Title = 'x' }, @{ Id = 12; Title = 'Claude - Google Chrome' }) } else { @(@{ Id = 11; Title = 'x' }) } }
Run-Case 'unmeasured' { param(\$t) -1 } { param(\$t) @() }
function Add-ReportLines(\$l) { Add-Content -LiteralPath '$BASE/wrep-p' -Value \$l -Encoding UTF8 }
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/wlog-p' -Value \$m -Encoding UTF8 }
Add-LoginReport @{ Win = 'w'; Proc = 'p'; Reopen = 'r'; Send = 's'; Confirm = 'c'; Answer = 'a'; Keys = 'k'; Input = '있었다'; Browser = 'BROWSER-MARK'; Presence = 'TAG-MARK' }" > "$BASE/out-presence" 2>&1
}

run_install A "$BASE/log-busy" '$null'
run_install C "$BASE/log-quiet" '$null'
run_install B "$BASE/log-busy" '1'
run_hold H ''
run_hold V 'V3 Lite'
run_presence

fail=0
grep -q -- '-PassThru' "$BASE/sp-A" 2>/dev/null || { echo "FAIL 측정 무효: 설치기를 띄우는 자리에 닿지 않았다"; tail -5 "$BASE/out-A" | sed 's/^/  /'; exit 2; }
grep -q 'J-PATH-01' "$BASE/wsay-C" 2>/dev/null || { echo "FAIL 측정 무효: 대조군(실패 말 없음)이 J-PATH-01 로 가지 않았다 — 시험이 갈래를 못 가른다"; grep 'J-' "$BASE/wsay-C" | sed 's/^/  /'; exit 2; }
grep -q '설치기가 마지막에 한 말' "$BASE/wsay-V" 2>/dev/null && { echo "FAIL 측정 무효: 상한 갈래가 아니다"; exit 2; }
# ⓐ
if grep -q 'J-PATH-01' "$BASE/wsay-A"; then echo "FAIL ⓐ 공식 설치기가 실패를 말했는데 J-PATH-01(재시작 처방)로 오진했다"; fail=1; fi
grep -q 'J-INST-01' "$BASE/wsay-A" || { echo "FAIL ⓐ J-INST-01 이 없다:"; grep -E '\[2/10\]|J-' "$BASE/wsay-A" | sed 's/^/  /'; fail=1; }
grep -q '^J-INST-01 by: vendor-said-failed kind=busy' "$BASE/wlog-A" 2>/dev/null || { echo "FAIL ⓐ 판정 근거가 busy 가 아니다: $(grep 'J-INST-01 by' "$BASE/wlog-A" 2>/dev/null)"; fail=1; }
grep -q '설치기 종료 코드: 읽지 못함' "$BASE/wsay-A" || { echo "FAIL ⓐ 사실 칸(종료 코드 읽지 못함)이 빠졌다"; fail=1; }
grep -q 'EBUSY' "$BASE/wsay-A" || { echo "FAIL ⓐ 설치기가 한 말(꼬리)을 보여 주지 않았다"; fail=1; }
# ⓑ
grep -q 'J-INST-01' "$BASE/wsay-B" || { echo "FAIL ⓑ 종료 코드 1 + 실패 말인데 J-INST-01 이 아니다:"; grep -E '\[2/10\]|J-' "$BASE/wsay-B" | sed 's/^/  /'; fail=1; }
grep -q '설치기 종료 코드: 1' "$BASE/wsay-B" || { echo "FAIL ⓑ 종료 코드 칸이 없다"; fail=1; }
# ⓒ
grep -q '^J-AV-01 by: av-evidence=False' "$BASE/wlog-H" 2>/dev/null || { echo "FAIL ⓒ 백신 근거 없음 판정이 기록에 없다: $(grep 'J-AV-01 by' "$BASE/wlog-H" 2>/dev/null)"; fail=1; }
grep -q '진단 코드: J-AV-01 — .*가능성' "$BASE/wsay-H" || { echo "FAIL ⓒ 백신 근거가 없는데 「가능성」 문장이 아니다:"; grep 'J-AV-01' "$BASE/wsay-H" | sed 's/^/  /'; fail=1; }
if grep -q '백신이 그 파일을 붙들고 있는 것으로 보입니다' "$BASE/wsay-H"; then echo "FAIL ⓒ 근거 없이 백신으로 단정했다"; fail=1; fi
grep -q '판정: 백신 근거 없음' "$BASE/wrep-H" 2>/dev/null || { echo "FAIL ⓒ 환경 보고에 가르기 줄이 없다"; fail=1; }
grep -q '^J-AV-01 by: av-evidence=True' "$BASE/wlog-V" 2>/dev/null || { echo "FAIL ⓒ 대조: 백신 창이 보였는데 근거 있음이 아니다: $(grep 'J-AV-01 by' "$BASE/wlog-V" 2>/dev/null)"; fail=1; }
grep -q '백신이 그 파일을 붙들고 있는 것으로 보입니다' "$BASE/wsay-V" || { echo "FAIL ⓒ 대조: 백신 창이 보였는데 종전 백신 안내가 안 나갔다"; fail=1; }
# ⓓ
for want in 'away=away' 'nobrowser=no-browser' 'seen=browser-seen' 'unmeasured=unmeasured'; do
  grep -q "^$want " "$BASE/out-presence" || { echo "FAIL ⓓ $want 가 아니다:"; sed 's/^/  /' "$BASE/out-presence"; fail=1; }
done
# 0.3.43(운영 결정 2026-10-30 · 승인 범위 = 키보드·마우스 사용 여부뿐): 보내는 값 = 있었다/없었다/잴 수 없었다 그대로 · 브라우저 줄·판정 꼬리표는 보고·기록에 없다
for want in 'away=away | 없었다 |' 'nobrowser=no-browser | 있었다 |' 'seen=browser-seen | 있었다 |' 'unmeasured=unmeasured | 잴 수 없었다 |'; do
  grep -qF "$want" "$BASE/out-presence" || { echo "FAIL ⓓ 보내는 입력 값이 있었다/없었다만이 아니다($want):"; sed 's/^/  /' "$BASE/out-presence"; fail=1; }
done
grep -q '키보드·마우스 사용(이 컴퓨터 전체): 있었다$' "$BASE/wrep-p" 2>/dev/null || { echo "FAIL ⓓ 환경 보고에 사용 여부 줄이 없다"; fail=1; }
grep -qE 'BROWSER-MARK|TAG-MARK|브라우저:|판정:' "$BASE/wrep-p" "$BASE/wlog-p" 2>/dev/null && { echo "FAIL ⓓ 브라우저 줄·판정 꼬리표가 보고·기록에 실렸다(승인 밖)"; fail=1; }
python3 - "$PS" <<'PYEOF' || fail=1
import sys, re
t = open(sys.argv[1], encoding='utf-8').read()
a = t.find('function Step-Login'); b = t.find('\nfunction ', a + 10); s = t[a:b]
ok = True
def need(cond, msg):
    global ok
    if not cond: print('FAIL ⓓ 배선: ' + msg); ok = False
need('$pres = New-LoginPresence' in s, 'Step-Login 이 재기 시작(New-LoginPresence)을 하지 않는다')
w = s.find('while (-not $loginProc.WaitForExit($LoginTickMs))'); u = s.find('Update-LoginPresence $pres', w)
need(w >= 0 and u > w and u < s.find('if ($w -ge $LoginWaitTimeout)', w), '대기 바퀴 안에서 Update-LoginPresence 를 부르지 않는다')
f = s.find("Write-JCode 'J-LOGIN-01'"); r = s.rfind('Resolve-LoginPresence $pres', 0, f)
need(f >= 0 and r >= 0 and s.find('Add-LoginReport $info', r) < f, 'J-LOGIN-01 전에 판정을 환경 보고에 싣지 않는다')
nb = s.find("elseif ($pv.Tag -eq 'no-browser')", r); nb2 = s.find('Add-LoginReport $info', nb)
need(nb >= 0 and "Say '" not in s[nb:nb2] and 'Write-Host' in s[nb:nb2], '브라우저에서 나온 화면 안내가 기록(Say)으로 간다 — 화면(Write-Host)에만')
need("('login input: ' + $pv.Input)" in s and 'browser ' + "' + $pv.Browser" not in s, '기록 줄에 브라우저·꼬리표가 남았다')
sys.exit(0 if ok else 1)
PYEOF
[ "$fail" -eq 0 ] && echo "PASS ⓐ EBUSY·Installation failed → J-INST-01(busy) · 대조 J-PATH-01 ⓑ rc=1 → J-INST-01 ⓒ 백신 근거 0 → J-AV-01 「가능성」 · 대조 백신 창 → 종전 안내 ⓓ away·no-browser·browser-seen·unmeasured + Step-Login 배선"
exit "$fail"
