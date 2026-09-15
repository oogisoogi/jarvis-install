# [9/10]~[10/10] 자동 각성 흉내 (pwsh 7 · 맥 · 2026-09-15)
#   실물 bootstrap.ps1 을 함수 묶음으로 읽고, 가짜 cys·claude 로 Step-Wake → Step-Fleet 를 끝까지 부른다.
#   success      = 자비스를 연 뒤 두 번째 목록 조회부터 동료 자리(cso·worker)가 선다 · 자비스 폴더 경로에 작은따옴표가 있다
#   claim-denied = 자리는 열렸는데 동료가 끝내 안 선다(부트의 역할 점유가 거절된 모양) · 지난 설치의 cso 자리가 기준선에 남아 있다
#                  · 목록 출력에 자리 번호 없는 경고 줄(역할 글자 포함)이 섞인다
#   fallback-success = 자동 관측 상한 안에는 안 서고, 사람 카드가 뜬 뒤에 동료가 선다(2026-09-15 윈 실기에서 난 모양)
#   no-surface   = 자비스 자리 자체를 못 연다(도달 실패) → 종전 폴백(이 창에서 띄움)
# 목록 한 줄 모양 = cys 실물(탭 구분): surface:N<TAB>role=R<TAB>pid=P<TAB>exited=false<TAB>제목<TAB>폴더
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
$jh = if ($Scenario -eq 'success') { "$Sb/home/o'k/install-jarvis" } else { "$Sb/home/install-jarvis" }
New-Item -ItemType Directory -Force -Path $jh, "$Sb/bin" | Out-Null
$fakeCys = @'
#!/bin/bash
SB="$(cd "$(dirname "$0")/.." && pwd)"
S="$(cat "$SB/scenario")"
row() { printf 'surface:%s\trole=%s\tpid=1\texited=false\t%s\t/tmp\n' "$1" "$2" "$3"; }
case "$1" in
  list)
    n=$(( $(cat "$SB/listcalls" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$SB/listcalls"
    row 3 cso old-install
    if [ -f "$SB/opened" ]; then
      row 9 master jarvis
      if [ "$S" = "claim-denied" ]; then echo "warning: stale entry role=worker-9 skipped"; fi
      if [ "$S" = "success" ] && [ "$n" -ge 3 ]; then row 10 cso cso; row 11 worker-2 worker; fi
      if [ "$S" = "fallback-success" ] && [ "$n" -ge 5 ]; then row 10 cso cso; row 11 worker-2 worker; fi
    fi
    exit 0 ;;
  new-surface)
    if [ "$2" = "--help" ]; then echo "      --agent <AGENT>"; exit 0; fi
    printf '%s\n' "$@" > "$SB/newsurface-args"
    # 거절 문구는 cys 0.14.36 이 내는 거절 사유 글자를 따른다(자리 번호는 싣지 않는다 — 실물 명령 출력 모양은 아직 안 쟀다)
    if [ "$S" = "no-surface" ]; then echo "Error: claim_denied: privileged role held by live surface" >&2; exit 7; fi
    touch "$SB/opened"; echo "surface:9"; exit 0 ;;
  send|send-key)
    printf '%s\n' "$*" >> "$SB/sent"; exit 0 ;;
esac
exit 0
'@
# 가짜 claude — 받은 인자를 하나씩 base64 한 줄로 적는다(줄바꿈·따옴표가 든 인자도 글자 그대로 대조하려고)
$fakeClaude = @'
#!/bin/bash
SB="$(cd "$(dirname "$0")/.." && pwd)"
: > "$SB/claude-args"
for a in "$@"; do printf '%s' "$a" | base64 | tr -d '\n' >> "$SB/claude-args"; echo >> "$SB/claude-args"; done
echo "EMU-CLAUDE-INLINE"
exit 0
'@
Set-Content -Path "$Sb/bin/cys" -Value $fakeCys -NoNewline
Set-Content -Path "$Sb/bin/claude" -Value $fakeClaude -NoNewline
& chmod +x "$Sb/bin/cys" "$Sb/bin/claude"
Set-Content -Path "$Sb/scenario" -Value $Scenario -NoNewline
Set-Content -Path "$Sb/jarvis-home" -Value $jh -NoNewline
$env:PATH = "$Sb/bin:" + $env:PATH
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = $jh
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$script:CysCli = 'cys'
# 실물 상한을 줄이기 전에 적어 둔다(시험이 상한 값 자체를 재게)
Write-Log ("TEST default awake cap=" + ($FleetAwakeTries * $FleetPollSec) + "s")
$FleetPollSec = 0; $FleetAwakeTries = 3; $FleetWaitTries = 2
# 실물 본문처럼 끝맺음을 finally 에서 부른다 — 성공 끝에 「다시 실행」 안내가 나가는지 재려고
try { Step-Wake; Write-Log ("TEST reached=" + $script:ReachedWake + " hands=" + $script:HumanHands) }
finally { Write-ClosingNote; Write-Log 'TEST finally' }
