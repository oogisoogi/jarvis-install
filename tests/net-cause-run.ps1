# 연결 원인 판별 축 — 윈도우 실행 입구 (우리 서버만 막아 ㉡ 문장을 실측한다)
#
# 무엇을 재는가
#   「서버 사정」 한 문장으로 뭉뚱그리지 않는다는 약속이 **실제로 갈라지는지**를 잰다.
#   hosts 로 우리 주소만 막으면: 인터넷은 되고(1.1.1.1) 우리 서버만 안 답한다 ⇒ ours(J-NET-02)여야 한다.
#
# ⛔살아 있는 기계에서는 시작하지 않는다 — hosts 는 환경변수로 격리되지 않는 기계 전체의 파일이다.
#   이미 우리 줄이 있으면(다른 목적으로 누군가 넣었을 수 있다) 손대지 않고 멈춘다.
#
# 쓰는 법: pwsh -File tests\net-cause-run.ps1 -Dir install-master
param([Parameter(Mandatory=$true)][string]$Dir)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$mark  = '# jarvis-net-cause-test'
$host1 = 'jarvis.godmeyou.kr'

if (-not (Test-Path $hosts)) { Write-Host '::error::hosts 파일을 찾지 못했습니다'; exit 4 }
$before = Get-Content $hosts -Raw -ErrorAction SilentlyContinue
if ($before -and $before.Contains($host1)) {
    Write-Host '::error::hosts 에 이미 우리 주소 줄이 있습니다 — 손대지 않고 멈춥니다.'
    exit 4
}

# 함수 묶음으로만 읽는다(본문은 돌지 않는다).
$env:JARVIS_LIB_ONLY = '1'
$sandbox = Join-Path $env:TEMP 'netcause-home'
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$env:JARVIS_HOME = $sandbox
. (Join-Path $Dir 'bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''

Write-Host '-- 막기 전 --------------------------------------'
$c0 = Get-NetCause
Write-Host ("원인 = " + $c0 + " · 말 = " + (Get-NetCauseWords $c0) + " · 코드 = " + (Get-NetCauseCode $c0))
if ($c0 -ne 'fine') {
    Write-Host '::error::막기 전인데 연결이 정상이 아닙니다 — 이 러너에서는 잴 수 없습니다.'
    exit 1
}

$added = $false
try {
    Write-Host '-- 우리 주소만 막는다 ---------------------------'
    Add-Content -Path $hosts -Value ("`r`n127.0.0.1 " + $host1 + " " + $mark) -Encoding ascii
    $added = $true
    Start-Sleep -Seconds 2
    [System.Net.Dns]::GetHostEntry($host1) 2>$null | Out-Null
    $c1 = Get-NetCause
    Write-Host ("원인 = " + $c1 + " · 말 = " + (Get-NetCauseWords $c1) + " · 코드 = " + (Get-NetCauseCode $c1))
    if ($c1 -ne 'ours') {
        Write-Host ('::error::우리 서버만 막았는데 원인을 ours 로 가르지 못했습니다(' + $c1 + ')')
        exit 1
    }
    if ((Get-NetCauseCode $c1) -ne 'J-NET-02') { Write-Host '::error::코드가 J-NET-02 가 아닙니다'; exit 1 }
    if ((Get-NetCauseWords $c1) -notmatch '우리 서버가 응답하지 않아서') { Write-Host '::error::문장이 ㉡ 가 아닙니다'; exit 1 }
    Write-Host '확인: 우리 서버만 막으면 우리 서버라고 말합니다(J-NET-02).'
    exit 0
} finally {
    if ($added) {
        $keep = (Get-Content $hosts) | Where-Object { $_ -notmatch [regex]::Escape($mark) }
        Set-Content -Path $hosts -Value $keep -Encoding ascii
        Write-Host '(hosts 원상복구)'
    }
}
