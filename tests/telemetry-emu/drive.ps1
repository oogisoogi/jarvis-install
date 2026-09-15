# 진행 텔레메트리 흉내 (pwsh · 맥) — 설치기를 「함수 묶음」으로 읽어 진행 전송·첨부·fail-open 을 실제로 부른다.
#   ⛔바깥에 닿지 않는다 — 가짜 서버(127.0.0.1)만 부른다. 화면·창 그림은 맥에 없어 $null 이라 그 첨부만 빠진다(설치는 이어간다).
param([string]$Src, [string]$Sb, [string]$Port)
$ErrorActionPreference = 'Stop'
$env:USERPROFILE = Join-Path $Sb 'home'
$env:HOME = Join-Path $Sb 'home'
$env:JARVIS_HOME = Join-Path (Join-Path $Sb 'home') 'install-jarvis'
New-Item -ItemType Directory -Force -Path $env:JARVIS_HOME | Out-Null
$env:JARVIS_LIB_ONLY = '1'
. $Src
$env:JARVIS_LIB_ONLY = ''
$Mode = 'full'
$base = 'http://127.0.0.1:' + $Port
$env:JARVIS_PROGRESS_URL = $base + '/api/progress'
$HelpApiUrl = $base

# ① 설치 번호 — 같은 실행에서 두 번 불러도 같은 값(재사용)
$id1 = Get-InstallId
Start-Sleep -Milliseconds 10
$id2 = Get-InstallId
Set-Content -LiteralPath (Join-Path $Sb 'id1') -Value $id1 -NoNewline
Set-Content -LiteralPath (Join-Path $Sb 'id2') -Value $id2 -NoNewline

# ② 진행 이벤트 다섯 갈래
Send-Progress '1/10' 'start' $null $null $null
Send-Progress '1/10' 'end'   1 'rc=0' $null
Send-Progress '3/10' 'wait'  60 $null $null
Send-Progress '2/10' 'fail'  $null 'J-TEST' $null
Send-Progress '1/10' 'info'  $null $null (Get-InstallEnv)

# ③ 첨부 — 보고가 열린 뒤(출처 헤더). 로그·환경 보고에 내용을 채워 둔다(화면·창 그림은 맥에서 $null 이라 빠진다).
Set-Content -LiteralPath $LogFile -Value 'log body line' -Encoding UTF8
Set-Content -LiteralPath $ReportFile -Value '# env report' -Encoding UTF8
$script:RhId = 'TEST2345'
$script:RhClientToken = ('a' * 64)
Send-FailAttachments

# ④ 900KB 넘는 항목은 보내지 않는다
$big = New-Object byte[] (1000 * 1024)
$sent = Send-Attachment 'log_full' 'big.txt' $big
Set-Content -LiteralPath (Join-Path $Sb 'bigsent') -Value ([string]$sent) -NoNewline

# ⑤ fail-open — 죽은 서버로 세 번 보내도 튀지 않고, 경고는 한 번만 기록한다
$env:JARVIS_PROGRESS_URL = 'http://127.0.0.1:1/api/progress'
Send-Progress '9/10' 'wait' 1 $null $null
Send-Progress '9/10' 'wait' 2 $null $null
Send-Progress '9/10' 'wait' 3 $null $null
Set-Content -LiteralPath (Join-Path $Sb 'failopen') -Value 'SURVIVED' -NoNewline
