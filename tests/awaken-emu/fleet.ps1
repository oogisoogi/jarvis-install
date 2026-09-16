# [9/10]~[10/10] 자동 각성 흉내 (pwsh 7 · 맥 · 2026-09-15)
#   실물 bootstrap.ps1 을 함수 묶음으로 읽고, 가짜 cys·claude 로 Step-Wake → Step-Fleet 를 끝까지 부른다.
#   success      = 자비스를 연 뒤 두 번째 목록 조회부터 동료 자리(cso·worker)가 선다 · 자비스 폴더 경로에 작은따옴표가 있다
#                  · worker 자리는 입력줄에 붙여넣기가 실린 채 멈춰 있다가 Return 한 번에 답을 시작한다 · cso 는 이미 답했다
#   claim-denied = 자리는 열렸는데 동료가 끝내 안 선다(부트의 역할 점유가 거절된 모양) · 지난 설치의 cso 자리가 기준선에 남아 있다
#                  · 목록 출력에 자리 번호 없는 경고 줄(역할 글자 포함)이 섞인다
#   fallback-success = 자동 관측 상한 안에는 안 서고, 사람 카드가 뜬 뒤에 동료가 선다(2026-09-15 윈 실기에서 난 모양) · 두 자식 모두 이미 답했다
#   no-surface   = 자비스 자리 자체를 못 연다(도달 실패) → 종전 폴백(이 창에서 띄움)
#   child-awake  = (installer-awaken-verify) 두 자식이 이미 답했다 → Return 0회
#   paste-late   = (installer-awaken-verify) worker 가 옛 모양 입력줄(╭╮)에 붙여넣기가 남아 Return 두 번째에 비워진다 · 답 머리표 없이 화면만 바뀐다
#                  · 비워진 뒤 위쪽 대화 기록에 「[Pasted text …」 가 남는다(이미 보낸 것 — 멈춘 것으로 세면 안 된다)
#   child-stall  = (installer-awaken-verify) worker 가 Return 을 몇 번 넣어도 붙여넣기가 남는다 · 화면에 로그인 이름·이메일이 섞여 있다
#   ── TICKET=installer-0322-awaken (마스터 각성 판정) · 전제 = 훅이 정상 실행돼 SessionStart 주입(45,644자)이 마스터 자리에 실린 상태 ──
#   master-refuse     = 동료 자리는 서는데 **마스터는 말만 하고 준비 작업을 시작하지 않는다**(2026-09-16 거부의 모양) → 재시도 1회 뒤에도 표지 없음 → no-start + 사람 카드
#   master-retry-late = 같은 모양인데 **재시도 한 줄을 받고 나서 표지를 쓴다** → verified(재시도가 헛일이 아님을 잰다)
#   master-unknown    = 마스터 자리가 아무 말도 하지 않는다(답 레코드 0 · 표지 0) → unknown(「거절」이라고 말하지 않는다)
#   master-stale-mark = 말은 했고 표지가 있는데 **시각이 지난 설치의 것**이다 → 시각 검사가 걸러 no-start(벨트 ②)
#   master-prior-mark = 깨우기 **전부터** 표지가 놓여 있다(지난 설치 잔존) → 깨우기 전 지우기가 걸러 no-start(벨트 ①)
# 목록 한 줄 모양 = cys 실물(탭 구분): surface:N<TAB>role=R<TAB>pid=P<TAB>exited=false<TAB>제목<TAB>폴더
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
$jh = if ($Scenario -eq 'success') { "$Sb/home/o'k/install-jarvis" } else { "$Sb/home/install-jarvis" }
New-Item -ItemType Directory -Force -Path $jh, "$Sb/bin" | Out-Null
# 가짜 cys = 같은 폴더의 fake-cys.sh(맥 구역과 한 벌 · 화면 모양은 그 파일 머리 주석)
$fakeCys = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'fake-cys.sh')
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
# 깨우기 전부터 놓여 있는 표지 — 지우기(Clear-MasterMark)가 이것을 치워야 한다(시각 검사만으로는 못 거른다: 시각이 지금이다)
if ($Scenario -eq 'master-prior-mark') { Set-Content -Path (Join-Path $jh 'awake-master.ok') -Value "prior`npid=1111" }
. $Src
$env:JARVIS_LIB_ONLY = ''
$script:CysCli = 'cys'
# 실물 상한을 줄이기 전에 적어 둔다(시험이 상한 값 자체를 재게)
Write-Log ("TEST default awake cap=" + ($FleetAwakeTries * $FleetPollSec) + "s")
Write-Log ("TEST default child cap=" + $ChildAwakeCapSec + "s gaps=" + ($ChildAwakeGaps -join ' ') + " grace=" + $ChildAwakeGraceSec + "s retry=" + $ChildAwakeMaxRetry)
Write-Log ("TEST default master cap=" + $MasterAwakeCapSec + "s poll=" + $MasterAwakePollSec + "s retrycap=" + $MasterRetryCapSec + "s retry=" + $MasterRetryMax)
$FleetPollSec = 0; $FleetAwakeTries = 3; $FleetWaitTries = 2
$ChildAwakeGaps = @(0, 0, 0); $ChildAwakeGraceSec = 2; $ChildAwakeCapSec = 8
$MasterAwakeCapSec = 2; $MasterAwakePollSec = 0; $MasterRetryCapSec = 2
# 자식 자리 세션 기록(jsonl) 자리 = $env:USERPROFILE/.cys/claude/projects — 가짜 cys 가 SB/home 아래에 만든다(installer-awaken-jsonl)
#   screen-lies    = 화면은 답한 모양인데 세션 기록이 없다(2026-09-16 샌드박스 5차 거짓 양성) → Return 3회 → child-fail
#   stale-session  = 같은 폴더에 기준선 전 지난 설치의 깬 기록만 있다 → 세지 않고 Return 1회 → 새 기록으로 확인
#   fallback-dir   = 폴더 이름 규칙이 안 맞는 자리에 기록이 생긴다 → 파일 안 cwd 로 찾는다
#   no-answer      = 제출(사용자 레코드)은 됐는데 답 레코드가 아직 없다 → Return 0회 → child-verified(installer-awaken-verify-r2 · 답은 늦게 생긴다)
#   grace          = Return 3회 뒤 1초 늦게 사용자 레코드가 생긴다 → 유예 뒤 다시 재서 child-verified(샌드박스 7차 거짓 실패의 모양)
# 진행 전송을 가로채 파일에 적는다 — 실제 서버로는 나가지 않는다(표지·증거 칸을 글자 그대로 재려고)
function Send-Progress($step, $ev, $elapsed, $detail, $envInfo, $extra) {
    $row = [ordered]@{ step = $step; event = $ev; detail = $detail }
    if ($null -ne $extra) { foreach ($k in @($extra.Keys)) { $row[[string]$k] = $extra[$k] } }
    Add-Content -Path "$Sb/progress.jsonl" -Value ($row | ConvertTo-Json -Compress) -Encoding utf8
}
# 🔴증거 이벤트는 v0.3.20 부터 **따로 나간다**(답이 곧 그림 자리라 진행 전송과 길이 다르다).
#   여기서도 가로채 같은 파일에 적는다 — 안 그러면 이 흉내의 증거 축이 **조용히 0건**이 된다(2026-09-16 실측).
#   돌려주는 것은 $null 이라 그림은 올리지 않는다(이 흉내는 바깥에 닿지 않는다).
function Send-EvidenceEvent([string]$Reason, [string]$Text) {
    $row = [ordered]@{ step = (Get-CurrentStep); event = 'evidence'; detail = $null; reason = $Reason; masked = $true }
    if ($Text) { $row['text'] = $Text }
    Add-Content -Path "$Sb/progress.jsonl" -Value ($row | ConvertTo-Json -Compress) -Encoding utf8
    return $null
}
# 실물 본문처럼 끝맺음을 finally 에서 부른다 — 성공 끝에 「다시 실행」 안내가 나가는지 재려고
try { Step-Wake; Write-Log ("TEST reached=" + $script:ReachedWake + " hands=" + $script:HumanHands) }
finally { Write-ClosingNote; Write-Log 'TEST finally' }
