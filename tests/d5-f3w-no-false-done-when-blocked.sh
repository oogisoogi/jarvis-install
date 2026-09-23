#!/bin/bash
# D5-F3 윈 짝 검출 시험 — 윈 [5/10]~[8/10] 이 막혔는데 자비스를 깨우러 [9/10] 으로 가면 적색(맥판 tests/d5-f3-no-false-done-when-blocked.sh 의 pwsh 판).
#   master 확정(2026-09-23 20:00 결정 A): 막히면 각성 단계에 들어가지 않고 「설치가 끝나지 않았습니다 · 진단 코드」로 끝난다 · rc≠0.
#   실물 bootstrap.ps1 을 JARVIS_LIB_ONLY=1 로 함수 묶음으로 읽고, 본문의 [5/10] 루프부터 Step-Wake 까지를 글자 그대로 떼어
#   본문과 같은 try/finally(끝맺음 Write-ClosingNote) 안, 스크립트 최상위에 이어 붙여 돌린다. 망 0 · 라이브 서버 0.
#   두 갈래를 잰다:
#     가) 옛 cys(1.0.2)가 깔린 기계 + [5/10] 받을 자리 404 — 실물 Step-DownloadCys 가 J-DL-05 를 낸다.
#         ⚠맥 pwsh 로는 404 응답을 가진 예외를 만들 망이 없다 ⇒ Invoke-WebRequest 만 가짜(Response.StatusCode=404 를 단 예외를 던짐) ·
#         깔린 cys 판정 두 함수(Test-CysBody · Get-CysInstalledVersion)만 「1.0.2 가 있다」로 흉내. 판정 논리는 실물 그대로다.
#     나) 진단 코드 없이 막힌 단계(흉내 [5/10] 이 rc 5 만 돌려줌) — 화면 코드 J-UNK-00 · 실패 이벤트는 정확히 1건(루프 F10 ① 것 · 두 번 보내지 않음).
#   Step-Wake 는 가짜다 — 닿으면 표지만 남긴다(닿는 것 자체가 결함의 경로다). 끝맺음의 원격 해결 대기는 끈다(Invoke-RemoteHelp).
# 쓰는 법: bash tests/d5-f3w-no-false-done-when-blocked.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
SRC="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
BASE="$(mktemp -d "${TMPDIR:-/tmp}/d5f3w.XXXXXX")" || exit 2
trap '[ -n "${KEEP:-}" ] || rm -rf "$BASE"; [ -n "${KEEP:-}" ] && echo "BASE=$BASE"' EXIT
# 본문 [5/10] 루프 ~ Step-Wake 구간을 글자 그대로 떼어 낸다(실물 줄 · 사본에서 바꾸는 것 0).
python3 - "$SRC" "$BASE/tail.ps1" <<'PYEOF' || { echo "FAIL 측정 무효: 본문 끝 구간([5/10] 루프 … Step-Wake)을 찾지 못했다"; exit 2; }
import sys
lines = open(sys.argv[1], encoding='utf-8-sig').read().split('\n')
s = [i for i, l in enumerate(lines) if l == '    foreach ($st in @(']
e = [i for i, l in enumerate(lines) if l == '    Step-Wake']
if len(s) != 1 or len(e) != 1 or e[0] <= s[0]: sys.exit(1)
open(sys.argv[2], 'w', encoding='utf-8').write('\n'.join(lines[s[0]:e[0] + 1]) + '\n')   # ⚠BOM 금지 — 실행 파일 한가운데 이어 붙인다
PYEOF
run_case() { # run_case <이름> <[5/10] 흉내 방식: real404 | nocode>
  local n="$1"
  mkdir -p "$BASE/up-$n/install-jarvis"
  cat > "$BASE/run-$n.ps1" <<PSEOF
. '$SRC' *> \$null
function Say(\$m) { Add-Content -LiteralPath '$BASE/say-$n' -Value \$m -Encoding UTF8 }
function Write-Log([string]\$m) { Add-Content -LiteralPath '$BASE/log-$n' -Value \$m -Encoding UTF8 }
function Send-Progress { param(\$a, \$b, \$c, \$d, \$e) Add-Content -LiteralPath '$BASE/ev-$n' -Value ('' + \$a + '|' + \$b + '|' + \$d) -Encoding UTF8 }
function Send-EvidenceOnce([string]\$Reason) { Add-Content -LiteralPath '$BASE/evd-$n' -Value \$Reason -Encoding UTF8 }
function Invoke-RemoteHelp { }; function Update-HelpAttempts { }; function Write-HelpEscalation { }
function Invoke-CaptureRequested { }; function Send-CaptureEvidence { }
function Invoke-DetectStage1 { }; function Invoke-DetectStage2 { }; function Write-Report { }
function Step-Wake { Add-Content -LiteralPath '$BASE/calls-$n' -Value 'reached:wake' -Encoding UTF8; Say '[9/10] 자비스를 깨웁니다.'; Say '설치가 끝났습니다.' }
function Step-InstallCys { Add-Content -LiteralPath '$BASE/calls-$n' -Value 'reached:6' -Encoding UTF8; return 0 }
function Step-VerifyCys { return 0 }; function Step-PrepareAccount { return 0 }
function Test-CysBody { return @{ Body = 'C:\fake\cys\cys.exe' } }
function Get-CysInstalledVersion { return '1.0.2' }
function Invoke-WebRequest { Add-Content -LiteralPath '$BASE/calls-$n' -Value ('iwr ' + (\$args -join ' ')) -Encoding UTF8
  \$ex = [System.Exception]::new('The remote server returned an error: (404) Not Found.')
  \$ex | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{ StatusCode = 404 })
  throw \$ex }
if ('$2' -eq 'nocode') { function Step-DownloadCys { Add-Content -LiteralPath '$BASE/calls-$n' -Value 'reached:5' -Encoding UTF8; return 5 } }
\$Mode = 'full'; \$script:NoticeShown = \$true; \$script:JCode = ''; \$script:NextStep = ''; \$script:BlockedStep = ''
try {
PSEOF
  # ⚠구간은 점 소싱(. tail.ps1)하지 않고 글자째 이어 붙인다 — 점 소싱한 파일 안의 exit 는 그 파일만 끝내고 부른 쪽으로 돌아온다
  #   (실측: 수리본이 rc 0 · tail-returned). 실물은 본문 스크립트 최상위의 exit 라 프로세스가 끝난다 — 같은 자리에 둬야 같은 뜻이다.
  cat "$BASE/tail.ps1" >> "$BASE/run-$n.ps1"
  cat >> "$BASE/run-$n.ps1" <<PSEOF
    Add-Content -LiteralPath '$BASE/calls-$n' -Value 'tail-returned' -Encoding UTF8
} finally {
    Write-ClosingNote
}
PSEOF
  PATH="/usr/bin:/bin" HOME="$BASE/up-$n" USERPROFILE="$BASE/up-$n" JARVIS_HOME="$BASE/up-$n/install-jarvis" \
  JARVIS_NO_PROGRESS=1 JARVIS_LIB_ONLY=1 \
  perl -e 'alarm shift; exec @ARGV or exit 126' 120 "$PW" -NoProfile -File "$BASE/run-$n.ps1" > "$BASE/out-$n" 2>&1
  echo $?
}
rcA="$(run_case A real404)"
rcB="$(run_case B nocode)"
grep -q '^iwr ' "$BASE/calls-A" 2>/dev/null || { echo "FAIL 측정 무효: 가) [5/10] 받기(Invoke-WebRequest)에 닿지 않았다(rc=$rcA)"; tail -5 "$BASE/out-A" | sed 's/^/  /'; exit 2; }
grep -q 'J-DL-05' "$BASE/say-A" 2>/dev/null || { echo "FAIL 측정 무효: 가) 404 가 J-DL-05 로 가지 않았다 — 흉내가 404 갈래에 못 닿았다"; grep -E '5/10|J-' "$BASE/say-A" | sed 's/^/  /'; exit 2; }
grep -q '^reached:5$' "$BASE/calls-B" 2>/dev/null || { echo "FAIL 측정 무효: 나) [5/10] 흉내에 닿지 않았다(rc=$rcB)"; tail -5 "$BASE/out-B" | sed 's/^/  /'; exit 2; }
fail=0
bad() { echo "FAIL $1"; fail=1; }
for n in A B; do
  rc="$(eval echo "\$rc$n")"
  grep -q '^reached:wake$' "$BASE/calls-$n" 2>/dev/null && bad "[$n] 막혔는데 각성 단계(Step-Wake)에 들어갔다"
  grep -q '^reached:6$' "$BASE/calls-$n" 2>/dev/null && bad "[$n] 막힌 [5/10] 뒤에 [6/10] 으로 갔다"
  grep -qE '설치가 끝났습니다|설치는 여기까지 끝났습니다|자비스가 깨어났습니다' "$BASE/say-$n" && bad "[$n] 막혔는데 끝났다고 말한다"
  grep -q '설치가 끝나지 않았습니다 — 「cys 설치 파일 받기」 단계에서 멈췄습니다' "$BASE/say-$n" || bad "[$n] 결과 줄 「설치가 끝나지 않았습니다 — 「cys 설치 파일 받기」 …」가 없다"
  [ "$rc" = 5 ] || bad "[$n] 종료 코드가 5 가 아니다(rc=$rc · 막힌 설치를 다른 코드로 끝냄)"
  [ "$(grep -c '^5/10|info|blocked:no-wake ' "$BASE/ev-$n" 2>/dev/null)" = 1 ] || bad "[$n] 정보 이벤트 blocked:no-wake 가 정확히 1건이 아니다: $(tr '\n' ';' < "$BASE/ev-$n" 2>/dev/null)"
  grep -q '^9/10|' "$BASE/ev-$n" 2>/dev/null && bad "[$n] [9/10] 진행 이벤트가 나갔다"
  grep -q '^다음에 할 일: ' "$BASE/say-$n" || bad "[$n] 끝맺음(다음에 할 일)이 돌지 않았다"
done
grep -q '(진단 코드 J-DL-05)\.$' "$BASE/say-A" || bad "[A] 결과 줄에 진단 코드 J-DL-05 가 없다"
grep -q '^5/10|info|blocked:no-wake J-DL-05$' "$BASE/ev-A" || bad "[A] 정보 이벤트에 J-DL-05 가 안 실렸다"
grep -q '^다음에 할 일: 이 진단 코드와 함께 알려 주십시오' "$BASE/say-A" || bad "[A] 404 갈래의 다음에 할 일(알려 달라)이 덮였다"
grep -q '(진단 코드 J-UNK-00)\.$' "$BASE/say-B" || bad "[B] 코드 없는 막힘의 결과 줄에 J-UNK-00 이 없다"
grep -q '진단 코드: J-UNK-00' "$BASE/say-B" || bad "[B] 화면에 진단 코드 줄(J-UNK-00)이 없다"
[ "$(grep -c '|fail|' "$BASE/ev-B" 2>/dev/null)" = 1 ] || bad "[B] 실패 이벤트가 정확히 1건이 아니다(두 번 보내거나 0건): $(grep '|fail|' "$BASE/ev-B" 2>/dev/null | tr '\n' ';')"
grep -q '^fail$' "$BASE/evd-B" 2>/dev/null || bad "[B] 실패 증거(Send-EvidenceOnce fail)를 안 보냈다 — 맥판 jcode 는 보낸다"
grep -q '^다음에 할 일: 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 끝난 단계는 건너뛰고' "$BASE/say-B" || bad "[B] 다시 실행 안내가 없다"
grep -q '== 다시 하시는 법' "$BASE/say-B" || bad "[B] 「다시 하시는 법」 명령이 인쇄되지 않았다"
[ "$fail" -eq 0 ] && echo "PASS 윈 [5/10] 막힘 → 각성 진입 0 · 「끝났습니다」 0 · 「설치가 끝나지 않았습니다」 + 코드(가 J-DL-05 · 나 J-UNK-00 · 실패 이벤트 1건) · rc 5 · blocked:no-wake 1건"
exit "$fail"
