# 프로브 진단 — 윈도우에서 「우리 서버 응답 없음」이 왜 나오는지 **한 줄씩 찍는다** (2026-09-09)
#
# ⛔여기서 고치지 않는다. 이 파일은 **재는 것만** 한다(관리자 지시: 로그 먼저 · 추측 수정 금지).
#   러너 로그에 방법별 결과를 남겨 원인을 확정한 뒤에 수정한다.
# ★언제나 exit 0 이다 — 진단이 잡을 붉히면 정작 진단 줄을 못 읽게 된다.
param([string]$Dir = 'install-master')

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

Write-Host '=== 이 창이 무엇인가 ==='
Write-Host ("PSVersion   = " + $PSVersionTable.PSVersion + " · Edition = " + $PSVersionTable.PSEdition)
Write-Host ("OS          = " + [System.Environment]::OSVersion.VersionString)
Write-Host ("SecurityProtocol = " + [Net.ServicePointManager]::SecurityProtocol)
Write-Host ("env:HTTPS_PROXY = [" + $env:HTTPS_PROXY + "] · env:HTTP_PROXY = [" + $env:HTTP_PROXY + "]")

# 설치기가 쓰는 실제 상수를 그대로 읽는다(우리가 손으로 적은 값이 아니라).
$env:JARVIS_LIB_ONLY = '1'
$env:JARVIS_HOME = Join-Path $env:TEMP 'netdiag-home'
New-Item -ItemType Directory -Force -Path $env:JARVIS_HOME | Out-Null
. (Join-Path $Dir 'bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''
Write-Host ("JarvisSiteUrl    = " + $JarvisSiteUrl)
Write-Host ("ClaudeInstallUrl = " + $ClaudeInstallUrl)

function Probe($label, $url) {
    Write-Host ""
    Write-Host ("--- " + $label + " : " + $url + " ---")
    $u = [System.Uri]$url
    # ① 이름 풀기
    try {
        $ips = [System.Net.Dns]::GetHostAddresses($u.Host) | ForEach-Object { $_.IPAddressToString }
        Write-Host ("  DNS         = " + ($ips -join ', '))
    } catch { Write-Host ("  DNS         = 실패: " + $_.Exception.GetType().Name + " · " + $_.Exception.Message) }
    # ② 443 포트가 열리는가(HTTP 이전 층)
    try {
        $t = Test-NetConnection -ComputerName $u.Host -Port 443 -WarningAction SilentlyContinue
        Write-Host ("  TCP 443     = " + $t.TcpTestSucceeded)
    } catch { Write-Host ("  TCP 443     = 못 잼: " + $_.Exception.Message) }
    # ③ 프록시가 끼는가
    try {
        $p = [System.Net.WebRequest]::DefaultWebProxy
        if ($p) { Write-Host ("  Proxy       = " + $p.GetProxy($u)) } else { Write-Host "  Proxy       = 없음" }
    } catch { Write-Host ("  Proxy       = 못 잼: " + $_.Exception.Message) }
    # ④ 우리가 실제로 쓰는 방법 = IWR HEAD (지금 판별 함수와 같은 인자)
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 6 -UseBasicParsing -ErrorAction Stop
        Write-Host ("  IWR HEAD    = " + $r.StatusCode)
    } catch {
        $code = ''
        try { if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } } catch { }
        Write-Host ("  IWR HEAD    = 예외 " + $_.Exception.GetType().Name + " · 상태코드=[" + $code + "] · " + $_.Exception.Message)
    }
    # ⑤ GET 은 되는가(HEAD 만 막는 서버가 있다)
    try {
        $r = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
        Write-Host ("  IWR GET     = " + $r.StatusCode + " · " + $r.RawContentLength + " bytes")
    } catch {
        $code = ''
        try { if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } } catch { }
        Write-Host ("  IWR GET     = 예외 " + $_.Exception.GetType().Name + " · 상태코드=[" + $code + "] · " + $_.Exception.Message)
    }
    # ⑥ 상한을 늘리면 달라지는가(6초가 빠듯한 것인지)
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 30 -UseBasicParsing -ErrorAction Stop
        $sw.Stop()
        Write-Host ("  IWR HEAD 30s= " + $r.StatusCode + " · " + $sw.ElapsedMilliseconds + "ms")
    } catch {
        $sw.Stop()
        Write-Host ("  IWR HEAD 30s= 예외 " + $_.Exception.GetType().Name + " · " + $sw.ElapsedMilliseconds + "ms · " + $_.Exception.Message)
    }
    # ⑦ 맥이 쓰는 방법과 같은 성질(curl 은 상태코드가 무엇이든 0 을 돌려준다)
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        $out = & curl.exe -sS -m 6 -o NUL -I -w "%{http_code}" $url 2>&1
        Write-Host ("  curl.exe -I = " + ($out -join ' ') + " (rc=" + $LASTEXITCODE + ")")
    } else { Write-Host "  curl.exe    = 없음" }
}

Probe '우리 서버'   $JarvisSiteUrl
Probe '바깥(클로드)' $ClaudeInstallUrl
Probe '중립 ①'      'https://1.1.1.1'
Probe '중립 ②'      'https://8.8.8.8'

Write-Host ""
Write-Host '=== 판별 함수가 지금 무엇이라고 하는가 ==='
$c = Get-NetCause
Write-Host ("Get-NetCause = " + $c + " · 말 = " + (Get-NetCauseWords $c) + " · 코드 = " + (Get-NetCauseCode $c))
Write-Host '(진단만 했습니다 — 아무것도 고치지 않았고 언제나 0 으로 끝납니다.)'
exit 0
