# 지난 실행 표시 흉내 (pwsh 7 · 맥) — 기록 파일을 먼저 심고 실물을 읽어 Show-PrevRunNote 의 화면 줄을 센다
param([string]$Src, [string]$Scenario, [string]$Sb)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path "$Sb/home/install-jarvis" | Out-Null
$long = ('기록을 봤습니다. [2/10] 클로드 설치 단계에서 백신이 설치 파일을 붙들고 있는 상태입니다(J-AV-01). 이렇게 해 주십시오. ' * 8)
$ts = '2026-09-14T15:54:27+09:00'
$head = @(
    "$ts === 자비스 설치 도우미 v1 (모드: full) ===",
    "$ts [1/10] 이 컴퓨터를 살펴봅니다.",
    "$ts [2/10] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다."
)
switch ($Scenario) {
    'answer'   { $body = @("$ts 다음에 할 일: 작업 표시줄에서 백신 창을 찾아 누르신 뒤 다시 실행해 주십시오.", "$ts remote help: report R2KUS56G", "$ts      보고 번호 R2KUS56G — 운영팀이 곧 봅니다.", "2026-09-14T15:54:54+09:00      처방: $long") }
    'answer-ml' { $body = @("$ts 다음에 할 일: 다시 실행해 주십시오.", "$ts remote help: report R2KUS56G", "2026-09-14T15:54:54+09:00      처방(조치 2): 첫 줄입니다", "       둘째 줄 — 타임스탬프 없는 이어진 줄") }
    'wait'     { $body = @("$ts 다음에 할 일: 다시 실행해 주십시오.", "$ts remote help: report R2KUS56G", "$ts      원격 해결을 기다리는 중입니다 (3분 지남 · 최대 120분 · 창을 닫으면 멈춥니다).") }
    'ended120' { $body = @("$ts 다음에 할 일: 다시 실행해 주십시오.", "$ts remote help: report R2KUS56G", "$ts      원격 해결 시간(120분)이 끝나 멈춥니다.", "$ts   끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다.") }
    'closed'   { $body = @("$ts [3/10] 10분 동안 로그인이 확인되지 않았습니다.", "$ts 다음에 할 일: 브라우저에서 승인을 누르신 뒤 다시 실행해 주십시오.", "$ts      진단을 보내지 못했습니다(서버 답 0). 위 진단 코드로 안내를 찾아보실 수 있습니다.", "$ts   끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다.") }
    'killed'   { $body = @("$ts      아직 설치 중입니다 (3분 0초 지남 · 최대 10분). 작업 표시줄에 백신 창이 떠 있는지 확인해 주십시오 — 「파일 전송」이나 [실행] 을 누르시면 이어집니다. $long") }
    'twoRuns'  { $body = @("$ts 다음에 할 일: 다시 실행해 주십시오.", "$ts remote help: report R2KUS56G", "2026-09-14T16:00:00+09:00 === 자비스 설치 도우미 v1 (모드: full) ===", "2026-09-14T16:00:01+09:00      아직 설치 중입니다 (0분 30초 지남 · 최대 10분).") }
}
Set-Content -Path "$Sb/home/install-jarvis/bootstrap.log" -Value (@($head) + @($body)) -Encoding utf8NoBOM
$env:USERPROFILE = "$Sb/home"
$env:JARVIS_HOME = "$Sb/home/install-jarvis"
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$shown = @(& { Show-PrevRunNote } 6>&1 | ForEach-Object { [string]$_ })
$j = @($shown | Where-Object { $_ -match 'J-AV-03' }).Count
$c = @($shown | Where-Object { $_ -match '\(운영팀 처방을 받은 뒤 창이 닫혔습니다\)' }).Count
$maxLen = 0; foreach ($s in $shown) { if ($s.Length -gt $maxLen) { $maxLen = $s.Length } }
"SCENARIO=$Scenario state=$($script:PrevRunState) lines=$($shown.Count) jav03=$j careLine=$c prevRunCode=$($script:PrevRunCode) maxLineLen=$maxLen"
$shown | ForEach-Object { '  | ' + $_ }
