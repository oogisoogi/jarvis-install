#!/bin/bash
# installer-0343 행동 시험 — 도움 사례 오진 표(answers-2026-10-29-b 의 D 표) ①②③ 의 기록 모양을 가짜로 만들어 갈래를 잰다(윈 bootstrap.ps1).
#   ① MGHSX9GL 모양: [5/10] 두 번 다 크기가 모자란 채 받기 끝 → J-DL-08 + 받은 양·걸린 시간·초당 속도 줄 · 화면 용량 = 핀 값에서 계산.
#      대조: 두 번째가 404 면 J-DL-05(새 갈래가 삼키지 않는다).
#   ② Sandbox 5건 모양: [8/10] 등록됨 · 직접 열 짝 파일 없음 · 끝내 무응답 → J-APP-02(코드 없이 rc 8 이던 것).
#   ③ XQ9GKXWJ·MSN5EB74 모양: 공식 설치기 끝말 「SSL/TLS 보안 채널에 대한 트러스트 관계를 설정할 수 없습니다」 · 1-7 claude.ai 실패 · 받는 자리 ok
#      → J-NET-04 (종료 코드 읽음 · 못 읽음 두 갈래) · 점검 문구가 「claude.ai 에는 설치 시작 전에도 닿지 못했습니다」.
#      대조: 같은 조건에서 끝말에 그 문구가 없으면 종전대로 J-DL-07(문구는 claude.ai 실패를 먼저 말함) · claude.ai 가 ok 였으면 점검 문구 종전 그대로.
#      판정 낱말: 5.1 WebException.Status=TrustFailure · 7 안쪽 AuthenticationException 은 참 · ConnectFailure 는 거짓.
#   ⚠실제 설치기·받기·데몬을 부르지 않는다 — Start-Process·Invoke-WebRequest·Invoke-WithCysTxnEnv 등은 가짜 함수 · HOME 은 임시 폴더 · 외부 프로그램 실행 0.
# 쓰는 법: bash tests/installer-0343-run.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
BASE="$(mktemp -d "${TMPDIR:-/tmp}/i0343.XXXXXX")" || exit 2
trap '[ -n "${KEEP:-}" ] || rm -rf "$BASE"; [ -n "${KEEP:-}" ] && echo "BASE=$BASE"' EXIT
PS="$BASE/bootstrap.ps1"; cp "$SRC" "$PS"
mkdir -p "$BASE/pbin"; ln -sf "$PW" "$BASE/pbin/pwsh"
# 도움 XQ9GKXWJ 설치기 끝말 그대로
printf '%s\n' 'irm : 기본 연결이 닫혔습니다. SSL/TLS 보안 채널에 대한 트러스트 관계를 설정할 수 없습니다.' > "$BASE/log-trust"
printf '%s\n' 'irm : 원격 서버에 연결할 수 없습니다.' > "$BASE/log-plain"

COMMON='function Write-Log([string]$m) { Add-Content -LiteralPath "$env:T_BASE/wlog-$env:T_NAME" -Value $m -Encoding UTF8 }
function Say($m) { Add-Content -LiteralPath "$env:T_BASE/wsay-$env:T_NAME" -Value $m -Encoding UTF8 }
function Add-ReportLines($l) { Add-Content -LiteralPath "$env:T_BASE/wrep-$env:T_NAME" -Value $l -Encoding UTF8 }
function Seed-LocalBinPath { }
function Send-EvidenceOnce { }
function Send-Progress { }'
pw() { # pw <이름> <본문>
  mkdir -p "$BASE/wh-$1" "$BASE/up-$1"
  T_BASE="$BASE" T_NAME="$1" PATH="$BASE/pbin:/usr/bin:/bin" JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 JARVIS_HOME="$BASE/wh-$1" USERPROFILE="$BASE/up-$1" \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -Command ". '$PS' *> \$null;
$COMMON
$2" > "$BASE/out-$1" 2>&1
}
install_case() { # install_case <이름> <설치기 기록> <ExitCode 식> <claude.ai 점검 ok|fail>
  pw "$1" "function Start-Process { Copy-Item -LiteralPath '$2' -Destination (Join-Path '$BASE/wh-$1' 'claude-install.log') -Force
  \$o = [pscustomobject]@{ HasExited = \$true; ExitCode = $3; StartTime = \$null; ExitTime = \$null; Id = 4242 }
  \$o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { return \$true }; return \$o }
\$Mode = 'real'; \$ClaudeInstallUrl = 'http://127.0.0.1:9/install.ps1'; \$script:NetFailed = \$true; \$script:DlProbe = 'ok'; \$script:InstallUrlProbe = '$4'
Write-Output ('RC=' + (Step-InstallClaude))"
}
dl_case() { # dl_case <이름> <두 회차 크기 식(-404 = 404)>
  pw "$1" "function Test-CysBody { return [pscustomobject]@{ Body = \$false; Path = '' } }
function Get-WebErrorStatus(\$e) { return 404 }
\$script:FakeN = @($2); \$script:FakeI = 0
function Invoke-WebRequest { param(\$Uri, \$OutFile, [switch]\$UseBasicParsing, \$TimeoutSec, \$Method)
  \$n = \$script:FakeN[\$script:FakeI]; \$script:FakeI++
  if (\$n -lt 0) { throw 'fake 404' }
  [IO.File]::WriteAllBytes(\$OutFile, (New-Object byte[] \$n)) }
\$Mode = 'real'; \$DlDir = '$BASE/dl-$1'; \$CysWinBytes = 3000000; \$CysDownloadUrl = 'http://127.0.0.1:9/setup.exe'
Write-Output ('RC=' + (Step-DownloadCys))"
}

install_case N1 "$BASE/log-trust" 1 fail          # ③ 종료 코드 읽음
install_case N2 "$BASE/log-trust" '$null' fail    # ③ 종료 코드 못 읽음 → 명령 안 잡힘 갈래
install_case N3 "$BASE/log-plain" 1 fail          # 대조: 끝말에 안전 연결 문구 없음 → J-DL-07
install_case N4 "$BASE/log-plain" 1 ok            # 대조: claude.ai 점검 ok → 점검 문구 종전 그대로
pw W1 "Write-Output ('A=' + (Test-TlsTrustWords (Get-ErrorChainText ([System.Net.WebException]::new('m', [System.Net.WebExceptionStatus]::TrustFailure)))))
Write-Output ('B=' + (Test-TlsTrustWords (Get-ErrorChainText ([System.Net.Http.HttpRequestException]::new('The SSL connection could not be established', [System.Security.Authentication.AuthenticationException]::new('Authentication failed, see inner exception.'))))))
Write-Output ('C=' + (Test-TlsTrustWords (Get-ErrorChainText ([System.Net.WebException]::new('m', [System.Net.WebExceptionStatus]::ConnectFailure)))))"
dl_case D1 '1500000, 2100000'                     # ① 두 번 다 모자람
dl_case D2 '1500000, -404'                        # 대조: 두 번째 404 → J-DL-05
pw A1 "function Invoke-CysTxnLogged { }
function Set-AllProfiles { }
function Copy-LoginToIsolated { }
function Test-CysPong(\$c) { return \$false }
function Get-CysAutoStartState(\$c) { return 'yes' }
function Invoke-WithCysTxnEnv([scriptblock]\$Body) { return 'no answer' }
\$Mode = 'real'; \$script:CysCli = '$BASE/nope/cys.exe'; \$DaemonPingCapSec = 0; \$DaemonPingGapMs = 1
Write-Output ('RC=' + (Step-PrepareAccount)); Write-Output ('NEXT=' + \$script:NextStep)"

grep -q 'RC=' "$BASE/out-N1" && grep -q 'RC=' "$BASE/out-D1" && grep -q 'RC=' "$BASE/out-A1" || { echo "FAIL 측정 무효: 갈래까지 닿지 않았다"; tail -5 "$BASE/out-N1" "$BASE/out-D1" "$BASE/out-A1" | sed 's/^/  /'; exit 2; }
grep -qE 'J-DL-07|J-NET-04' "$BASE/wsay-N3" 2>/dev/null || { echo "FAIL 측정 무효: 대조군 N3 이 [2/10] 판정 갈래에 닿지 않았다"; grep 'J-' "$BASE/wsay-N3" | sed 's/^/  /'; exit 2; }
grep -q 'J-DL-05' "$BASE/wsay-D2" 2>/dev/null || { echo "FAIL 측정 무효: 대조군 D2 가 J-DL-05 로 가지 않았다"; grep 'J-\|5/10' "$BASE/wsay-D2" | sed 's/^/  /'; exit 2; }
fail=0
for n in N1 N2; do
  grep -q 'J-NET-04' "$BASE/wsay-$n" || { echo "FAIL ③ $n 안전 연결 실패인데 J-NET-04 가 아니다:"; grep -E '\[2/10\]|J-' "$BASE/wsay-$n" | sed 's/^/  /'; fail=1; }
  grep -q 'J-DL-07' "$BASE/wsay-$n" && { echo "FAIL ③ $n 이 J-DL-07(서버에 못 닿음)도 말한다"; fail=1; }
  grep -q 'claude.ai 에는 설치 시작 전에도 닿지 못했습니다' "$BASE/wsay-$n" || { echo "FAIL ③ $n 점검 문구가 실제 실패한 주소(claude.ai)를 말하지 않는다"; fail=1; }
  grep -q '트러스트 관계' "$BASE/wsay-$n" || { echo "FAIL ③ $n 설치기 끝말을 보여 주지 않았다"; fail=1; }
  grep -q 'RC=4' "$BASE/out-$n" || { echo "FAIL ③ $n rc 가 4 가 아니다: $(grep RC= "$BASE/out-$n")"; fail=1; }
done
grep -q '^J-NET-04 by: tls-trust' "$BASE/wlog-N1" || { echo "FAIL ③ 판정 근거 기록이 없다"; fail=1; }
grep -q 'claude.ai 에는 설치 시작 전에도 닿지 못했습니다' "$BASE/wsay-N3" || { echo "FAIL ③ 대조 N3(J-DL-07)도 claude.ai 실패를 먼저 말해야 한다"; fail=1; }
grep -q 'J-NET-04' "$BASE/wsay-N3" && { echo "FAIL ③ 안전 연결 문구가 없는데 J-NET-04 로 갔다(과잉)"; fail=1; }
grep -q 'J-DL-07' "$BASE/wsay-N3" || { echo "FAIL ③ 대조 N3(안전 연결 문구 없음 · 망 점검 실패)이 종전 J-DL-07 이 아니다"; fail=1; }
grep -q '내려받는 자리 점검 결과: 설치 시작 전에는 닿았습니다(그 사이에 끊겼을 수 있습니다).$' "$BASE/wsay-N4" || { echo "FAIL ③ claude.ai ok 일 때 점검 문구가 종전과 다르다:"; grep '점검 결과' "$BASE/wsay-N4" | sed 's/^/  /'; fail=1; }
grep -q '^A=True$' "$BASE/out-W1" && grep -q '^B=True$' "$BASE/out-W1" && grep -q '^C=False$' "$BASE/out-W1" || { echo "FAIL ③ 안전 연결 낱말 판정(5.1 TrustFailure · 7 AuthenticationException · 대조 ConnectFailure):"; sed 's/^/  /' "$BASE/out-W1"; fail=1; }
grep -q 'J-DL-08' "$BASE/wsay-D1" || { echo "FAIL ① 두 번 다 모자랐는데 J-DL-08 이 아니다:"; grep -E '\[5/10\]|J-' "$BASE/wsay-D1" | sed 's/^/  /'; fail=1; }
[ "$(grep -cE '받은 것 약 [0-9]+MB / 3MB · 걸린 시간 [0-9]+분 [0-9]+초 · 초당 약 [0-9]+KB' "$BASE/wsay-D1")" = 2 ] || { echo "FAIL ① 회차별 받은 양·시간·속도 줄이 2개가 아니다"; grep '받은 것' "$BASE/wsay-D1" | sed 's/^/  /'; fail=1; }
grep -q '두 번 다 끝까지 받지 못함' "$BASE/wrep-D1" 2>/dev/null || { echo "FAIL ① 환경 보고에 받기 사실이 없다"; fail=1; }
grep -q 'RC=5' "$BASE/out-D1" || { echo "FAIL ① rc 가 5 가 아니다"; fail=1; }
grep -q '받습니다 (약 3MB · 잠시 걸립니다)' "$BASE/wsay-D1" || { echo "FAIL ① 화면 용량이 핀 값(3000000 → 약 3MB)에서 계산되지 않았다:"; grep '받습니다 (' "$BASE/wsay-D1" | sed 's/^/  /'; fail=1; }
grep -q 'J-DL-08' "$BASE/wsay-D2" && { echo "FAIL ① 404 대조가 J-DL-08 로 삼켜졌다"; fail=1; }
grep -nE "^[^#]*(Say|say)[^#]*132MB" "$SRC" "$(dirname "$SRC")/bootstrap.sh" && { echo "FAIL ① 손으로 적은 132MB 가 화면 문장에 남았다"; fail=1; }
grep -q 'J-APP-02' "$BASE/wsay-A1" || { echo "FAIL ② 바탕 프로그램 무응답인데 J-APP-02 가 아니다:"; grep -E '\[8/10\]|J-' "$BASE/wsay-A1" | sed 's/^/  /'; fail=1; }
grep -q 'RC=8' "$BASE/out-A1" || { echo "FAIL ② rc 가 8 이 아니다: $(grep RC= "$BASE/out-A1")"; fail=1; }
grep -q '^NEXT=컴퓨터를 한 번 다시 시작하신 뒤' "$BASE/out-A1" || { echo "FAIL ② 다음 할 일이 재시작이 아니다: $(grep NEXT= "$BASE/out-A1")"; fail=1; }
[ "$fail" = 0 ] && echo "PASS installer-0343 ①②③ 갈래 + 대조 4(J-DL-07 · 점검 문구 종전 · J-DL-05 · 낱말 판정 음성)"
exit "$fail"
