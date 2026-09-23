#!/bin/bash
# D5-F7 검출 시험 — 32비트 창 재실행 인자(Build-Ps32RelaunchArgs)를 Start-Process -ArgumentList 로 넘길 때
#   사용자 폴더 이름에 공백이 있으면 -File 경로가 쪼개져 다시 열린 창이 설치 도우미를 못 찾으면 적색.
#   Start-Process 는 배열 원소를 따옴표 없이 공백으로 이어 붙여 넘긴다(윈 PowerShell 5.1 · 이 맥의 pwsh 7 도 같다) ⇒
#   이 맥에서 **실제로** 재실행해 본다: 공백·우리말이 든 폴더의 자식 스크립트를 실물 함수가 만든 인자로 띄운다.
#   ⚠진짜 32비트 창·sysnative 경로는 여기서 못 잰다(윈 실기 몫) — 재는 것은 「인자가 한 덩어리로 도착하는가」 하나다.
# 쓰는 법: bash tests/d5-f7-relaunch-space-path.sh [bootstrap.ps1]   · rc 0 = 통과 · 1 = 결함 · 2 = 측정 무효
set -u
PS1="${1:-$(cd "$(dirname "$0")/.." && pwd)/install-master/bootstrap.ps1}"
PW="$(command -v pwsh 2>/dev/null)"; [ -n "$PW" ] || { echo "FAIL 측정 무효: pwsh 가 없다"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/d5f7.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
D="$T/홍 길동 test"; mkdir -p "$D"
CHILD="$D/install-jarvis.ps1"
cat > "$CHILD" <<'EOF'
param([switch]$DetectOnly, [switch]$DryRun)
Set-Content -LiteralPath (Join-Path (Split-Path -Parent $PSCommandPath) 'ARRIVED') -Value ("detect=" + $DetectOnly.IsPresent + " dry=" + $DryRun.IsPresent)
EOF
out="$(JARVIS_LIB_ONLY=1 perl -e 'alarm 60; exec @ARGV or exit 126' "$PW" -NoProfile -Command "
. '$PS1' *> \$null
\$a = Build-Ps32RelaunchArgs '$CHILD' \$true \$false
\$p = Start-Process -FilePath '$PW' -ArgumentList \$a -NoNewWindow -Wait -PassThru
Write-Output ('rc=' + \$p.ExitCode)
" 2>&1)"
fail=0
if [ ! -f "$D/ARRIVED" ]; then echo "FAIL 공백 든 폴더에서 다시 연 창이 설치 도우미를 못 찾았다:"; printf '%s\n' "$out" | tail -4 | sed 's/^/  /'; fail=1
elif ! grep -q '^detect=True dry=False$' "$D/ARRIVED"; then echo "FAIL 원래 인자가 그대로 넘어가지 않았다: $(cat "$D/ARRIVED")"; fail=1; fi
[ "$fail" -eq 0 ] && echo "PASS 공백·우리말 폴더에서 재실행 인자가 한 덩어리로 도착 · -DetectOnly 보존 ($(printf '%s' "$out" | grep '^rc=' | tail -1))"
exit "$fail"
