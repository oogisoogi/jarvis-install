# 자비스 설치 도우미 — 윈도우
#
# 하는 일 4가지
#   1) 이 컴퓨터의 상태를 살펴 환경 보고 1장을 쓴다
#   2) 클로드 코드가 없거나 낡았으면 공식 설치기로 설치한다
#   3) 로그인 화면을 열고 승인이 끝날 때까지 기다린다
#   4) 자비스를 깨워 환경 보고를 사람 말로 옮겨 준다
# 다시 실행하면 끝난 단계는 건너뛰고 이어서 간다.
#   ⛔사람에게 「같은 줄을 다시 돌려 주십시오」라고 말하지 않는다 — 2026-09-10 실기에서
#     **사용자 막힘으로 확정**된 문구다. 대신 Show-RerunHow 가 창 여는 법과 **명령 전체**를 인쇄한다.
#
# 쓰는 법
#   powershell -File bootstrap.ps1                 전 단계
#   powershell -File bootstrap.ps1 -DetectOnly     살펴보기만 하고 환경 보고 1장을 쓴 뒤 끝낸다
#   powershell -File bootstrap.ps1 -DryRun         판정은 다 하되 바깥을 바꾸는 행위는 하지 않는다
#
# 배포 한 줄 (사람이 붙여넣는 것 — cmd 창과 PowerShell 창 어느 쪽에서도 이 명령이 그대로 돈다)
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/bootstrap.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\install-jarvis.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\install-jarvis.ps1')"
#   -ExecutionPolicy Bypass 가 없으면 윈도우 기본값(Restricted)에서 스크립트가 로드되지 않는다.
#   왜 이 모양인가 (구판은 cmd 창에 붙여넣으면 안 돌았다)
#     - 구판은 맨 앞이 irm 이라 cmd 창에서는 그런 명령이 없다는 오류가 난다.
#     - 이 줄에는 $ 도 % 도 없다. 자리는 PowerShell 안에서 .NET 으로 직접 구한다.
#       (cmd 는 큰따옴표 안에서 %이름% 만 바꾸고 $ 는 건드리지 않는다. 그래도 둘 다 안 쓰는 편이
#        읽는 사람에게 「이 줄은 어느 창에서든 같다」를 분명히 보여 준다.)
#     - 폴더 경로에 공백이나 우리말이 있어도 괄호 안의 식이 한 덩어리로 넘어가므로 인자가 쪼개지지 않는다.
#     - cmd 는 큰따옴표 안의 ( 와 ' 를 특별하게 보지 않으므로 그대로 통과한다.
#   내려받는 자리를 임시 폴더에서 사용자 폴더로 옮겼다(2026-09-06)
#     - 임시 폴더는 다른 프로그램이나 정책이 언제든 비울 수 있고, 회사 컴퓨터에서는
#       그 자리에서의 실행 자체를 막아 두는 설정이 흔하다. 그러면 받기는 받았는데 실행에서 막힌다.
#     - 사용자 폴더에 두면 나중에 무엇이 걸렸는지 물을 때 그 파일이 그대로 남아 있다.
#     - 자리는 사용자 폴더 바로 아래 한 파일이다. 새 폴더를 만들지 않는다 —
#       한 줄에 만드는 단계를 더하면 그 단계가 또 하나의 시험 안 된 자리가 된다.
#     - 지우는 법은 reset-clean.ps1 이 안다(옛 임시 폴더 자리도 함께 지운다).
#   이 줄은 아직 윈도우 실물에서 돌려 본 적이 없다. 첫 실기에서 확인한다.
#
# 이 파일은 UTF-8 with BOM 으로 저장한다.
#   Windows PowerShell 5.1 은 BOM 없는 .ps1 을 ANSI(cp949)로 읽어 한글 리터럴과 정규식이 깨진다.
#   파싱은 통과하므로 문법 검사로는 안 잡힌다.
#
# 규율: 관리자 권한으로 스스로 승격하지 않는다 · 시스템 설정을 바꾸지 않는다 · 외부 주소는 공식 2곳만 쓴다

param(
    [switch]$DetectOnly,
    [switch]$DryRun
)

# $ErrorActionPreference = 'Stop' 을 쓰지 않는다: 이 스크립트는 실패를 죽음이 아니라 판정값(enum)으로 적는다.
$ErrorActionPreference = 'Continue'

$BootstrapVersion = 'v1'
$ReportHead = '[자비스] 환경 보고 v0'   # ④단 첫 응답의 고정 첫 줄

# ── 핀 (외부 URL은 이 두 줄이 전부다) ─────────────────────────────
$ClaudeInstallUrl = 'https://claude.ai/install.ps1'
$CysSiteUrl       = 'https://github.com/oogisoogi/cys-ro/releases/latest'   # 손으로 받을 때의 자리 = 우리 릴리스 페이지

# ── 자리 ──────────────────────────────────────────────────────────
$JarvisHome = if ($env:JARVIS_HOME) { $env:JARVIS_HOME } else { Join-Path $env:USERPROFILE 'install-jarvis' }
# 🔴꼬리 빗금을 한 번에 걷어낸다(맥판과 같은 까닭 · 교차 검토 1차 NEW-1 · 2026-09-11).
while ($JarvisHome.Length -gt 1 -and ($JarvisHome.EndsWith('\') -or $JarvisHome.EndsWith('/'))) {
    $JarvisHome = $JarvisHome.Substring(0, $JarvisHome.Length - 1)
}
$LogFile       = Join-Path $JarvisHome 'bootstrap.log'
$ReportFile    = Join-Path $JarvisHome 'env-report.md'
$DirectiveFile = Join-Path $JarvisHome 'install-directive.md'
$DlDir         = Join-Path $JarvisHome 'dl'

# cys 설치 파일 — 판본을 파일 이름에 박아 배포하므로 여기에 핀한다.
# 크기가 안 맞으면 받다 끊긴 것이거나 배포가 바뀐 것이다. 어느 쪽이든 진단하고 멈춘다.
# ★2026-09-09 자체 배포 전환(윈도우): 받을 곳 = 우리가 서명해 발행한 릴리스. 벤더 판을 깔면 그 뒤의
#   업데이트도 벤더 궤도를 타서 우리 수리가 그 기계에 닿지 않는다(노트북 실기 2026-09-09).
#   맥(bootstrap.sh)은 우리 빌드가 무서명이라 아직 벤더 dmg 그대로다.
$CysVersion     = '0.14.36'
$CysDownloadDir = "https://github.com/oogisoogi/cys-ro/releases/download/v${CysVersion}/"
$CysWinFile     = "cys_${CysVersion}_x64-setup.exe"
$CysWinBytes    = 139840459
$CysWinSha256   = '12c9d398b4e11b175370c6fdc7e4fd299b2e74865c5cc0f8bf891a42eaf70066'   # 릴리스 SHA256SUMS.txt 의 줄
$CysDownloadUrl = $CysDownloadDir + $CysWinFile

$LoginPollInterval = 3     # 초
$LoginPollTimeout  = 600   # 초 (10분)
# 🔴★승인 대기 구간에는 **상한이 없었다**(2026-09-11 맥 Tart 실기 · 두 OS 같은 구조).
#   벤더의 `claude auth login` 이 코드 입력을 기다리며 **2시간 32분 동안 화면에 0바이트**를 찍고 섰다.
#   위 10분 상한은 **그 다음 구간(폴링)**에만 있어 여기엔 닿지 않는다.
#   ⇒ 60초마다 한 줄 말하고, 20분이면 이 기다림을 끝낸다(그 뒤는 이미 있는 J-LOGIN-01 회복 경로).
$LoginSayInterval  = 60    # 초 — 기다리는 동안 화면에 한 줄씩 말하는 간격
$LoginWaitTimeout  = 1200  # 초 (20분) — 승인 대기 자체의 상한 (그 뒤 폴링 10분 ⇒ 최악 30분으로 닫힌다)

# 설치기를 기다리는 한도. 한도가 없으면 백신 경고 창 같은 것이 떠 있는 동안 영원히 서 있게 된다.
$InstallWaitMs    = 300000   # 조용한 설치 (5분)
$InstallGuiWaitMs = 900000   # 설치 창을 띄웠을 때 (15분 · 사람이 누르는 시간)
# 🔴2026-09-09 실사용자 3호 실기 — 클로드 설치기가 백신 창에 붙들려 **아무 말 없이** 멈췄다.
#   그 자리에는 상한도 안내도 없었다(설치기를 부르고 그냥 기다렸다). 사람은 화면이 멈춘 것만 보고,
#   정작 눌러야 할 창은 다른 곳에 떠 있었다. ⇒ 기다리는 동안 말을 하고, 끝이 있는 기다림으로 바꾼다.
$ClaudeInstallWaitMs  = 600000   # 클로드 설치 상한 (10분 · 넘으면 조용히 다음으로 가지 않는다)
$InstallNoteEverySec  = 30       # 기다리는 동안 몇 초마다 한 줄을 적는가
# ── 멈추지 않는 설치기 (2026-09-09) ───────────────────────────────
#   못 나가는 단계에서 침묵하거나 즉시 실패하지 않는다. 원인을 갈라 말하고, 기다리고, 이어간다.
$NetWaitTimeoutSec   = 1800      # 30분 — 이 한 줄이 기다림의 상한이다
$NetWaitIntervalSec  = 30        # 다시 해 보는 간격이자 화면에 한 줄 적는 간격
$HelpCodeUrl         = 'https://jarvis.godmeyou.kr/help/'
# 우리 자리(배포 한 줄이 가리키는 곳). 새 바깥 주소가 아니라 이미 쓰던 우리 주소를 상수로 올린 것이다 —
# 연결이 끊겼을 때 「우리 쪽인가 바깥인가」를 가르려면 우리 주소를 물어볼 수 있어야 한다.
$JarvisSiteUrl       = 'https://jarvis.godmeyou.kr/install/'

$Mode = if ($DetectOnly) { 'detect' } elseif ($DryRun) { 'dry' } else { 'full' }

# 바깥 프로그램이 우리말로 낸 글자가 깨져 보이지 않게 한다.
# 깨지면 보기 흉한 데서 끝나지 않는다 — 막힌 자리의 오류 문구를 읽을 수 없게 된다.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# 위 한 줄은 「우리가 화면에 쓰는 글자」만 정한다. 바깥 프로그램이 낸 글자를 우리가 받아
# 기록 파일로 옮길 때 쓰는 것은 이쪽이다. 한쪽만 맞추면 화면은 멀쩡한데 기록만 깨진다.
$OutputEncoding = [System.Text.Encoding]::UTF8


# 백신이 PowerShell 자체를 종료시키면 이 스크립트는 한마디도 남기지 못하고 사라진다(2026-09-05 실측).
# 그때 유일하게 남는 것이 기록 파일의 마지막 줄이다 — 그래서 이번 실행이 한 줄이라도 적기 전에 떠 둔다.
$script:PrevTail = ''
if (Test-Path $LogFile) {
    $prevLines = @(Get-Content $LogFile -ErrorAction SilentlyContinue | Where-Object { $_ -ne '' })
    if ($prevLines.Count -gt 0) { $script:PrevTail = $prevLines[-1] }
}

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    Add-Content -Path $LogFile -Value "$ts $msg"
}
# Write-Output 을 쓰면 안 된다 — PowerShell 함수는 출력 스트림에 나간 것 전부가 반환값이라
#   `$rc = Step-InstallClaude` 가 종료 코드가 아니라 「안내문 여러 줄 + 0」 배열을 받는다.
#   안 찍힌 것이 아니다 — 클로드 TUI 가 화면을 새로 그리면서 덮은 것이다(로그에는 남아 있다).
#   ⇒ 「한 줄씩 더 찍자」는 처방이 안 듣는다. 같은 화면에 찍으면 같이 지워진다.
#   대신 지나온 단계를 보고서에 적는다 — 보고서는 자비스가 읽어 사람에게 다시 보여 준다.
$script:StepLog = New-Object System.Collections.ArrayList
function Say($msg) {
    Write-Host $msg
    Write-Log $msg
    # 단계 수는 늘어난다(4 → 9 → 10). 숫자를 박아 두면 늘어난 순간 이 기록이 조용히 빈다.
    if ($msg -match '^\[\d+/\d+\]') { [void]$script:StepLog.Add($msg) }
}

#   `Set-Content -Encoding UTF8` 은 Windows PowerShell 5.1 에서 BOM 을 붙인다. 우리가 쓰는 `.claude.json` 을
#   같은 실행 안에서 폴더 신뢰 질문이 그대로 떴다 · 맥 실물 `.claude.json` 선두 3바이트 = `7b 0a 20` = BOM 없음).
#   같은 함수가 이 파일 자신에게는 반대로 작동한다 — `.ps1` 은 BOM 이 있어야 5.1 이 한글을 안 깨뜨린다(위 헤더).
# 살펴보기만 하는 호출은 데몬을 깨우지 않는다.
# 데몬이 꺼져 있으면 cys 호출이 디스크에 있는 실행 파일로 데몬을 그 자리에서 켜는데,
# 설치 직후나 파일이 반쯤 풀린 상태에서 그러면 서로 다른 판본의 데몬이 겹칠 수 있다.
# 바깥 프로그램을 부르고 그 출력을 화면과 기록 파일 양쪽에 남긴다.
# 화면은 덮이고 지워지지만 파일은 남는다. 실패한 명령의 출력일수록 남겨야 한다.
# 출력을 그대로 흘리지 않고 Say 로만 내보낸다 — 흘리면 그것이 함수의 반환값에 섞인다.
function Invoke-Logged($what, $cmd, $cmdArgs) {
    $out = & $cmd @cmdArgs 2>&1
    $code = $LASTEXITCODE
    foreach ($ln in $out) { Say "       $ln" }
    Write-Log "[$what] rc=$code"
    return $code
}

# ── 자동 시작 등록을 「말」이 아니라 「자리」로 잰다 (6차 검토 · 2026-09-10) ────────────
# 🔴실기에서 화면이 스스로 모순됐다: 팩이 「작업 스케줄러 등록 완료(ONLOGON + RestartOnFailure)」를
#   찍은 **바로 다음 줄에** 설치기가 「자동으로 켜지도록 등록하지는 못했습니다」를 찍었다.
#   그리고 재부팅 실측 = cys 는 저절로 켜지지 않았다(쓰시는 분이 손으로 여셨다).
#   ⇒ 두 줄 다 **추정**이었다. 팩은 자기가 부른 명령의 종료값을 말했고, 설치기는 「데몬이 안 답한다」를
#     「등록 실패」로 옮겨 적었다. ★둘 다 등록된 자리를 직접 본 적이 없다.
#   ⇒ 여기서 **작업 그 자체를 묻는다.** 이 함수의 답만이 등록 여부의 사실이다.
#   ⚠「등록됨」과 「다음 로그온에 실제로 뜬다」는 다른 명제다 — 우리는 앞의 것만 말한다(뒤는 실기 몫).
function Get-CysAutoStartState {
    param([string]$CysCli = '')
    # 🔴🔴돌려주는 값은 **다섯**이다 — 'yes' · 'off' · 'other' · 'no' · 'unknown'.
    #   ⑴앞 판(1차 검토)은 $true/$false 둘뿐이라 **「모른다」를 「없다」로 바꿔** 말했다.
    #   ⑵그 다음 판(2차 검토 지적)은 XML 을 **글자로** 봤다 — `<Command>` 안에 `cysd` 라는 조각만 있으면
    #     'yes' 였다. 달력 trigger 로 `C:\Other\cysd.exe` 를 도는 남의 작업도 「다음 로그온부터
    #     저절로 켜집니다」가 됐다. ⇒ 재부팅해도 안 켜지는데 등록 완료라고 안내한다.
    #   ⇒ **구조로 읽는다.** 'yes' 는 세 가지가 **모두** 참일 때만이다:
    #     ①실행 파일이 **우리가 깐 그 자리의 cysd.exe** 다(경로 비교 · 이름 조각이 아니다)
    #     ②**지금 이 사용자**의 **로그온 trigger** 가 있고 그것이 켜져 있다
    #     ③작업 자체가 켜져 있다
    #   ⚠XML 을 못 읽거나 어느 하나를 확인할 수 없으면 **'unknown'** 이다 — 모르는 것은 모른다고 한다.
    $xml = ''
    $rc = 1
    try {
        $xml = (& schtasks /Query /TN cysd /XML 2>&1) -join "`n"
        $rc = $LASTEXITCODE
    } catch {
        return 'unknown'
    }
    if ($rc -ne 0) {
        # 「그런 작업이 없다」와 「물어보지 못했다」는 다른 답이다. 섞으면 위 사고가 되풀이된다.
        if ($xml -match '찾을 수 없|cannot find|does not exist|ERROR: The system cannot find') { return 'no' }
        return 'unknown'
    }
    $doc = $null
    try {
        $body = $xml.Substring($xml.IndexOf('<'))   # schtasks 는 앞에 BOM·빈 줄을 붙이기도 한다
        $doc = [xml]$body
    } catch { return 'unknown' }
    if ($null -eq $doc -or $null -eq $doc.Task) { return 'unknown' }

    # ① 실행 파일 — 우리가 깐 자리의 cysd.exe 여야 한다.
    $wantList = @()
    foreach ($d in @($env:LOCALAPPDATA)) {
        if ($d) {
            $wantList += (Join-Path $d 'cys\cysd.exe')
            $wantList += (Join-Path $d 'Programs\cys\cysd.exe')
        }
    }
    if ($CysCli) {
        try { $wantList += (Join-Path (Split-Path $CysCli -Parent) 'cysd.exe') } catch { }
    }
    $cmds = @()
    try { foreach ($a in @($doc.Task.Actions.Exec)) { if ($a -and $a.Command) { $cmds += [string]$a.Command } } } catch { return 'unknown' }
    if ($cmds.Count -eq 0) { return 'other' }
    $mine = $false
    foreach ($c in $cmds) {
        $c2 = $c.Trim().Trim('"')
        try { $c2 = [System.IO.Path]::GetFullPath($c2) } catch { }
        foreach ($w in $wantList) {
            $w2 = $w
            try { $w2 = [System.IO.Path]::GetFullPath($w) } catch { }
            if ($c2 -and $w2 -and ($c2 -eq $w2)) { $mine = $true }
        }
    }
    if (-not $mine) { return 'other' }

    # ③ 작업 자체가 켜져 있는가
    try {
        if ($doc.Task.Settings -and ($doc.Task.Settings.Enabled -eq 'false')) { return 'off' }
    } catch { return 'unknown' }

    # ② 지금 이 사용자의 로그온 trigger 가 있고 켜져 있는가
    $logon = $null
    try { $logon = @($doc.Task.Triggers.LogonTrigger) } catch { return 'unknown' }
    if ($null -eq $logon -or $logon.Count -eq 0 -or $null -eq $logon[0]) { return 'off' }
    # 🔴🔴**사람을 이름으로 견주지 않는다 — SID 로 견준다**(3차 검토 ⑤ 확정 2026-09-10).
    #   앞 판은 세 가지를 이름으로 비교했고 **양쪽으로 틀렸다**:
    #     ⑴`\<이름>` 접미사만 같아도 통과 ⇒ 지금 계정이 `ACME\alice` 인데 trigger 가 `OTHER\alice`
    #       여도 「다음 로그온부터 저절로 켜집니다」였다. **도메인이 다르면 다른 사람이다.**
    #     ⑵작업 스케줄러의 `UserId` 는 **사용자명일 수도 SID 일 수도 있다**(Microsoft 문서 명시).
    #       SID 로 적힌 정상적인 내 작업이 이름 비교에서 안 맞아 `off` 로 오판됐다.
    #   ⇒ **두 형태를 한 축(SID)으로 모아** 견준다: `S-1-…` 이면 그대로, 이름이면 `NTAccount→SID` 변환.
    #   ⚠변환을 못 하면(도메인에 못 닿는 등) **모른다고 한다** — 「아니다」로 단정하지 않는다.
    $mySid = ''
    try { $mySid = [string][System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { $mySid = '' }
    if (-not $mySid) { return 'unknown' }
    $ok = $false
    $unresolved = $false
    foreach ($t in $logon) {
        if ($null -eq $t) { continue }
        if ($t.Enabled -eq 'false') { continue }
        $uid = ''
        try { $uid = ([string]$t.UserId).Trim() } catch { $uid = '' }
        # UserId 가 없으면 「누가 로그온하든」이라는 뜻이다 — 우리도 거기 포함된다.
        if (-not $uid) { $ok = $true; continue }
        $sid = ''
        if ($uid -match '^S-1-') {
            $sid = $uid
        } else {
            try {
                $sid = [string](New-Object System.Security.Principal.NTAccount($uid)).Translate([System.Security.Principal.SecurityIdentifier]).Value
            } catch { $sid = ''; $unresolved = $true }
        }
        if ($sid -and ($sid -eq $mySid)) { $ok = $true }
    }
    if (-not $ok) {
        # 「내 것이 아니다」와 「누구 것인지 못 알아봤다」는 다른 답이다. 섞으면 또 거짓 단정이 된다.
        if ($unresolved) { return 'unknown' }
        return 'off'
    }
    return 'yes'
}
# 사람에게 할 말은 한 자리에서만 만든다 — 상태가 다섯인데 문장이 자리마다 갈리면 또 모순이 난다.
function Get-AutoStartWords($state) {
    switch ($state) {
        'yes'   { return '자동 시작 등록됨 (작업 이름 cysd · 다음 로그온부터 저절로 켜집니다).' }
        'off'   { return '자동 시작 작업은 있는데 꺼져 있습니다 — 컴퓨터를 켜실 때 cys 를 한 번 열어 주십시오.' }
        'other' { return 'cysd 라는 이름의 작업이 있지만 우리 것이 아닙니다 — 자동 시작은 등록되지 않았습니다.' }
        'no'    { return '자동으로 켜지도록 등록되지 않았습니다(까닭은 이 화면만으로는 갈리지 않습니다).' }
        default { return '자동 시작 등록 여부를 확인하지 못했습니다(이 컴퓨터의 정책이 조회를 막았을 수 있습니다).' }
    }
}

function Invoke-CysProbe {
    param([string]$Cli, [string[]]$CysArgs)
    $prev = $env:CYS_NO_AUTOSTART
    $env:CYS_NO_AUTOSTART = '1'
    try { return (& $Cli @CysArgs 2>&1) } finally { $env:CYS_NO_AUTOSTART = $prev }
}

function Write-TextNoBom($path, $text) {
    #   `$env:JARVIS_HOME` 이 상대 경로로 주어진 경우) ⇒ 상대 경로가 오면 엉뚱한 자리에 쓰거나 유실된다.
    #   `WriteAllText` 는 PowerShell 위치를 모른다 — 넘기기 전에 절대 경로로 푼다.
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($full, $text, $enc)
}

# 사람 손 계수 — 「개입 목록」을 기억이 아니라 로그에서 만든다(맥판과 같은 축).
$script:HumanHands = 0
function Human($who, $what) {
    $script:HumanHands++
    # 🔴「강제」를 뺀다(1차 검토 BLOCK ③ 확정 2026-09-10). 이 칸의 뜻은 「누가 이 손을 시키는가」이지
    #   「우리가 사람을 강제한다」가 아니다. 앞 판은 자리마다 문구를 순화해 놓고 **이 공통 래퍼가
    #   여전히 「강제: 자비스」를 인쇄**해서, 화면에는 순화가 하나도 나타나지 않았다.
    #   ★자리마다 고치고 공통 자리를 안 고치면 아무것도 안 고친 것이다.
    Say "[사람 손 #$($script:HumanHands) · 시킨 쪽: $who] $what"
}

# 지난 실행이 끝을 알리지 않고 사라졌으면 그 사실과 마지막 줄을 사람에게 보여 준다.
# ⛔진단만 한다 — 백신을 피하거나 끄거나 예외로 등록하지 않는다(이 파일 아래 「우회하지 않는다」 참조).
function Show-PrevRunNote {
    if (-not $script:PrevTail) { return }
    if ($script:PrevTail -match '\[9/9\]|끝냅니다') { return }
    Say '지난번 실행이 끝을 알리지 않고 멈춘 자리가 있습니다. 그때 마지막으로 적힌 줄입니다:'
    Write-JCode 'J-AV-03' '지난 실행이 끝을 알리지 않고 멈췄습니다(창이 갑자기 닫혔을 수 있습니다)'
    Say "       $script:PrevTail"
    Say '     창이 갑자기 닫힌 것이었다면 백신이 PowerShell 을 종료한 것일 수 있습니다.'
    Say '     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다.'
}

# ── 진단 코드 (J-<축>-<두 자리>) ──────────────────────────────────
# ★같은 문자열이 세 자리에 남아야 한다 — 화면 · 환경 보고 · 기록 파일.
#   자리마다 다른 이름을 쓰면 그 셋을 맞춰 보는 일이 사람 몫이 된다.
$script:JCode = ''
$script:NextStep = ''
function Write-JCode($code, $desc) {
    $script:JCode = $code
    Say ("     진단 코드: " + $code + " — " + $desc)
    Say ("     이 코드로 찾아보실 수 있습니다: " + $HelpCodeUrl + $code)
    Write-Log ("jcode " + $code + " " + $desc)
}

# ── 연결 원인 판별 (3프로브) ──────────────────────────────────────
# ⛔「서버 사정」 한 문장으로 뭉뚱그리지 않는다 — 백신이 파일을 붙든 것(J-AV)과 섞여 거짓 안내가 된다
#   (2026-09-09 3호 실기의 교훈). 셋을 갈라 묻고, 셋 다 답하면 「연결은 된다」고 사실대로 말한다.
# 🔴러너 로그로 확정한 결함(2026-09-09 run 34292566443 · 진단 커밋 e0908ef)
#   묻는 것은 「서버가 **답하는가**」이지 「서버가 우리를 **좋아하는가**」가 아니다.
#   러너에서 우리 주소는 **403** 을 돌려줬다(TCP 443 = True · 86ms · pwsh 7 과 5.1 둘 다 동일 ·
#   curl.exe 도 403 rc 0). 서버는 분명히 답했다. 그런데 앞 판은 2xx 가 아닌 것을 전부 예외로 받아
#   「응답 없음」으로 읽었고 ⇒ 멀쩡한 서버에 대고 **「우리 서버가 응답하지 않아서」**라고 말했다.
#   그것이 바로 이 작업이 없애려던 거짓 안내다(하네스가 「막기 전인데 ours」로 잡아냈다).
#   ⚠맥판은 처음부터 이 성질을 갖고 있었다 — `curl -sS -I` 는 -f 를 안 쓰므로 403 이든 404 든 rc 0 이다.
#     두 OS 가 같은 뜻을 갖게 맞춘 것이지 새 규칙을 만든 것이 아니다.
function Get-CysFileSha256($path) {
    # 지문 도구가 없는 기계(러너에서 본 자리)를 위해 .NET 으로 폴백한다. 못 재면 $null — 호출자가 「확인 없이 설치 안 함」으로 다룬다.
    try { return (Get-FileHash -Algorithm SHA256 -LiteralPath $path -ErrorAction Stop).Hash.ToLower() } catch { }
    $sha = $null; $fs = $null
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = [System.IO.File]::OpenRead($path)
        return ([System.BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-','').ToLower()
    } catch { return $null } finally {
        if ($fs)  { $fs.Dispose() }
        if ($sha) { $sha.Dispose() }
    }
}
# 예외에 딸려 온 HTTP 상태코드(서버나 가운데 프록시가 답한 숫자)를 돌려준다. 답 자체가 없었으면 0 —
#   이름을 못 찾았거나 연결이 거부·끊겼거나 시간이 다 된 경우다. 기다려서 풀릴 수 있는 것은 이 0 쪽이다.
function Get-WebErrorStatus($err) {
    try { if ($err.Exception.Response) { return [int]$err.Exception.Response.StatusCode } } catch { }
    return 0
}
function Test-UrlReachable($url) {
    try {
        [void](Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 6 -UseBasicParsing -ErrorAction Stop)
        return $true
    } catch {
        # 407 = 가운데 프록시가 로그인을 요구하며 막은 것이다. 목적지가 답한 것이 아니므로 「닿았다」로 세지 않는다.
        if ((Get-WebErrorStatus $_) -eq 407) { return $false }
        # 상태코드가 딸려 온 예외 = 서버가 답한 것이다(403·404·405 …). 그것은 「닿았다」로 센다.
        try { if ($_.Exception.Response) { return $true } } catch { }
        return $false
    }
}
# 🔴순서가 아니라 **종합**으로 판단한다(검토 지적 채택 2026-09-09).
#   회사·학교 망은 1.1.1.1 같은 주소만 막고 프록시로 웹은 되게 하는 일이 흔하다 ⇒ 앞 판은 인터넷이
#   멀쩡한 사람에게 30분 동안 「인터넷이 없습니다」라고 우겼을 것이다. 목적지 둘을 먼저 믿는다.
function Get-NetCause {
    $ours   = Test-UrlReachable $JarvisSiteUrl
    # 바깥 서버 = 클로드 설치 원 + cys 릴리스 자산(최종 호스트가 다른 곳으로 넘어가므로 자산 주소 자체를 짚는다 · 검토 지적 2026-09-09)
    $theirs = (Test-UrlReachable $ClaudeInstallUrl) -and (Test-UrlReachable $CysDownloadUrl)
    if ($ours -and $theirs)        { return 'fine' }
    if ($ours -and -not $theirs)   { return 'theirs' }
    if ($theirs -and -not $ours)   { return 'ours' }
    if ((Test-UrlReachable 'https://1.1.1.1') -or (Test-UrlReachable 'https://8.8.8.8')) { return 'unknown' }
    return 'none'
}
function Get-NetCauseWords($cause) {
    switch ($cause) {
        'none'   { return '인터넷 연결이 없어서' }
        'ours'   { return '우리 서버가 응답하지 않아서' }
        'theirs' { return '설치 파일을 받는 바깥 서버가 응답하지 않아서' }
        'fine'   { return '연결은 되는데 이 단계가 진행되지 않아서' }
        default  { return '연결 상태를 확인하지 못해서' }
    }
}
function Get-NetCauseCode($cause) {
    switch ($cause) {
        'none'   { return 'J-NET-01' }
        'ours'   { return 'J-NET-02' }
        'theirs' { return 'J-NET-03' }
        default  { return 'J-UNK-00' }
    }
}

# ── 연결 대기 (모든 연결 단계가 이 한 자리를 쓴다) ────────────────
#   $Tag = 단계 표시 · $Try = 다시 해 볼 일(성공하면 $true 를 돌려주는 스크립트 블록)
#   $true = 성공(이어간다) · $false = 상한 초과(부르는 쪽이 정직하게 멈춘다)
# ⚠기다리는 동안 말을 한다. 침묵은 「멈췄다」로 읽히고, 그때 사람이 창을 닫는다.
function Wait-ForConnection($Tag, [scriptblock]$Try) {
    $waited = 0
    while ($waited -lt $NetWaitTimeoutSec) {
        $cause = Get-NetCause
        Say ($Tag + ' 현재 ' + (Get-NetCauseWords $cause) + ' 진행할 수 없습니다. 다시 연결이 되면 이어서 진행하겠습니다.')
        Say '     창을 닫지 말고 기다려 주십시오. 다른 작업을 하셔도 괜찮습니다.'
        Say ('     (' + [int]($waited / 60) + '분 지남 · 최대 ' + [int]($NetWaitTimeoutSec / 60) + '분 · ' + $NetWaitIntervalSec + '초마다 다시 해 봅니다)')
        Start-Sleep -Seconds $NetWaitIntervalSec
        $waited += $NetWaitIntervalSec
        $ok = $false
        try { $ok = [bool](& $Try) } catch { $ok = $false }
        if ($ok) { return $true }
    }
    $cause = Get-NetCause
    Say ($Tag + ' ' + [int]($NetWaitTimeoutSec / 60) + '분을 기다렸지만 연결되지 않았습니다.')
    Write-JCode (Get-NetCauseCode $cause) ((Get-NetCauseWords $cause) + ' 진행하지 못했습니다')
    return $false
}

# ── 반복 막힘 단계별 안내 (v0.3.15 · 2026-09-12) ─────────────────────
# 같은 자리에서 또 막히면 같은 말만 되풀이하지 않는다 — 2회째는 다른 방법, 3회째부터는 담당자와 직접.
# ★문구 정본 = tests/help-escalation.tsv(글자 그대로 · checks.sh 가 잰다). 맥판(bootstrap.sh)과 같은 규칙이다.
# ★센 기록 = 작업 폴더의 help-attempts.json(고정 모양 · 줄 단위 정규식으로 읽는다 — 맥에 JSON 도구가 없어 두 OS 가 같은 방법을 쓴다).
$HelpContactPhone = '010-7745-5885'
$HelpAttemptsFile = Join-Path $JarvisHome 'help-attempts.json'
$HelpStage2Lines = @(
    '  같은 자리에서 다시 막히셨네요. 난감하시겠어요. 이렇게 한 번 해 보세요.',
    '<WAY>',
    '  그래도 같으면 다음에는 담당자 연락처를 안내해 드리겠습니다.'
)
$HelpStage3Lines = @(
    '  계속 같은 자리에서 막히셔서 많이 불편하셨지요.',
    '  개발자와 직접 이야기해 보시면 어떨까요?',
    '  담당자 전화 <PHONE> (문자나 전화 · 편하신 시간에)',
    '  진단 코드 <CODE> 만 말씀해 주시면 됩니다.'
)
$HelpSentOkLine = '  막힌 자리 정보는 방금 자동으로 전달됐습니다.'
$HelpSentNoLine = '  전화하실 때 이 화면을 사진으로 보내 주시면 더 빠릅니다.'
$HelpWays = @{
    'J-AV-01'    = @('백신의 보호 기록(격리함)에 claude 가 있으면 [복원]을 골라 주십시오.', '안 되면 백신 알림에 나온 파일(또는 그 폴더)을 백신의 「예외(허용)」에', '추가하신 뒤 다시 실행해 주십시오. 설치 뒤 예외에서 지우시면 원래대로입니다.')
    'J-AV-02'    = @('백신의 보호 기록(격리함)에 cys 설치 파일이 있으면 [복원]을 골라 주십시오.', '안 되면 install-jarvis 폴더를 백신의 「예외(허용)」에 추가하신 뒤', '다시 실행해 주십시오. 설치 뒤 예외에서 지우시면 원래대로입니다.')
    'J-AV-03'    = @('백신 알림 기록에 install-jarvis.ps1 을 막은 기록이 있으면 그 파일을', '백신의 「예외(허용)」에 추가하신 뒤 다시 실행해 주십시오.', '설치 뒤 예외에서 지우시면 원래대로입니다.')
    'J-NET-01'   = @('휴대폰 핫스팟 같은 다른 인터넷에 연결하신 뒤 다시 실행해 주십시오.')
    'J-NET-02'   = @('10분쯤 뒤에 다시 실행해 주십시오.', '휴대폰 핫스팟 같은 다른 인터넷으로 바꿔 보셔도 됩니다.')
    'J-NET-03'   = @('회사·학교 망은 바깥 서버를 막아 둔 경우가 있습니다.', '휴대폰 핫스팟 같은 다른 인터넷으로 연결하신 뒤 다시 실행해 주십시오.')
    'J-RM-01'    = @('컴퓨터를 한 번 다시 시작하신 뒤(열려 있던 cys 가 완전히 닫힙니다)', '재설치 명령을 실행해 주십시오.')
    'J-PATH-01'  = @('컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.')
    'J-LOGIN-01' = @('브라우저가 뜨지 않았거나 다른 브라우저에 로그인돼 있으면,', '설치 창에 보이는 https:// 로 시작하는 로그인 주소를 복사해', '로그인된 브라우저 주소창에 붙여넣어 주십시오.')
    'J-HOME-01'  = @('창을 닫고 새 창을 여신 뒤(남은 설정이 따라오지 않습니다)', '다시 실행해 주십시오.')
    'J-PERM-01'  = @('컴퓨터를 한 번 다시 시작하신 뒤 다시 실행해 주십시오.', '저장 공간이 3GB 이상 남았는지도 함께 봐 주십시오.')
    'J-DISK-01'  = @('휴지통을 비우시고, 설정의 저장 공간 화면에서 큰 파일을', '정리하신 뒤 다시 실행해 주십시오.')
    'J-VER-01'   = @('컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.')
    'J-UNK-00'   = @('컴퓨터를 한 번 다시 시작하신 뒤 다시 실행해 주십시오.')
    'J-DL-03'    = @('컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.')
    'J-DL-04'    = @('휴대폰 핫스팟 같은 다른 인터넷으로 연결하신 뒤 다시 실행해 주십시오.')
}
$HelpDirectCodes = @('J-DL-05')   # 다른 방법이 없는 코드 = 2회째부터 곧바로 담당자 안내
$script:HelpStage      = 1
$script:HelpFirst      = ''    # 셈을 한 실행만 채운다(비어 있으면 보고서에 「같은 진단 코드」 줄이 없다)
$script:HelpPrevReport = ''
$script:HelpStage3     = $false
$script:HelpSentSaid   = $false

# 시각 = +0900 모양(맥판 date '+%Y-%m-%dT%H:%M:%S%z' 와 같게 · 문화권 구분자에 흔들리지 않게 고정 문화권)
function Get-HelpNow {
    $d = Get-Date
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    return ($d.ToString('yyyy-MM-ddTHH:mm:ss', $inv) + ($d.ToString('zzz', $inv) -replace ':', ''))
}

# 돌려주는 것 = @{ Codes = @{ 코드 = @{ N; First; Last; Step } }; Report = $null 또는 @{ Id; At; Code } }
#   파일이 없으면 빈 상태 · 첫 줄이 모양이 아니거나 못 읽으면 빈 상태 + 기록 한 줄(설치를 막지 않는다)
#   ⚠칸 이름을 count 로 두지 않는다 — 해시표의 .Count 와 섞인다.
function Read-HelpAttempts {
    $state = @{ Codes = @{}; Report = $null }
    if (-not (Test-Path -LiteralPath $HelpAttemptsFile)) { return $state }
    $lines = @()
    try {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HelpAttemptsFile)
        $lines = @([System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8) -split "\r?\n")
    } catch { $lines = @() }
    if ($lines.Count -eq 0 -or $lines[0] -cne '{"v":1,') {
        Write-Log 'help attempts: unreadable - reset'
        return $state
    }
    foreach ($ln in $lines) {
        if ($ln -cmatch '^"(J-[A-Z]+-[0-9]{2})":\{"count":([0-9]{1,4}),"first":"([^"]*)","last":"([^"]*)","step":"([0-9]{1,2})"\},?$') {
            $state.Codes[$Matches[1]] = @{ N = [int]$Matches[2]; First = $Matches[3]; Last = $Matches[4]; Step = [int]$Matches[5] }
        } elseif ($ln -cmatch '^"last_report":\{"id":"([A-Z2-9]{8})","at":"([^"]*)","code":"(J-[A-Z]+-[0-9]{2})"\}$') {
            $state.Report = @{ Id = $Matches[1]; At = $Matches[2]; Code = $Matches[3] }
        }
    }
    return $state
}

# 고정 모양으로 쓴다(코드 이름순 · LF · BOM 없음) — 임시 파일에 쓴 뒤 바꿔 끼운다 · 못 쓰면 기록 한 줄만 남기고 넘어간다
function Save-HelpAttempts($State) {
    $keys = [string[]]@($State.Codes.Keys)
    [Array]::Sort($keys, [System.StringComparer]::Ordinal)
    $out = New-Object System.Collections.ArrayList
    [void]$out.Add('{"v":1,')
    [void]$out.Add('"codes":{')
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $c = $State.Codes[$keys[$i]]
        $ln = '"' + $keys[$i] + '":{"count":' + $c.N + ',"first":"' + $c.First + '","last":"' + $c.Last + '","step":"' + $c.Step + '"}'
        if ($i -lt $keys.Count - 1) { $ln += ',' }
        [void]$out.Add($ln)
    }
    if ($null -ne $State.Report) {
        [void]$out.Add('},')
        [void]$out.Add('"last_report":{"id":"' + $State.Report.Id + '","at":"' + $State.Report.At + '","code":"' + $State.Report.Code + '"}')
    } else {
        [void]$out.Add('}')
    }
    [void]$out.Add('}')
    $tmp = $HelpAttemptsFile + '.tmp'
    try {
        Write-TextNoBom $tmp (($out -join "`n") + "`n")
        $fullTmp = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($tmp)
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HelpAttemptsFile)
        # ⚠백업 이름 자리에 $null 을 넘기면 PowerShell 이 빈 글("")로 바꿔 넘긴다 → Replace 가 「올바르지 않은 경로」로 던진다(첫 쓰기만 되고 그 뒤 셈이 조용히 멈춘다) — 진짜 null 은 [NullString]::Value
        if ([System.IO.File]::Exists($full)) { [System.IO.File]::Replace($fullTmp, $full, [NullString]::Value) } else { [System.IO.File]::Move($fullTmp, $full) }
    } catch {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Log 'help attempts: write failed'
    }
}

# 끝맺음이 한 번 부른다 — 이 실행의 진단 코드를 세어 단계(= 그 코드의 횟수)를 $script:HelpStage 에 둔다.
function Update-HelpAttempts {
    $script:HelpStage = 1
    $script:HelpFirst = ''
    $script:HelpPrevReport = ''
    if ($Mode -ne 'full') { return }    # 미리보기·감지만 = 세지도 읽지도 쓰지도 않는다
    if (-not (Test-Path -LiteralPath $JarvisHome -PathType Container)) { return }   # 자리를 못 만든 끝
    # 우리 표식이 없는 폴더(거절한 남의 폴더·구판 폴더)에는 새 파일을 두지 않는다 — 두면 구판 지문이 깨진다
    if (-not (Test-JarvisOwnerMark)) { return }
    $code = [string]$script:JCode
    if ($code -and -not ($code -cmatch '\AJ-[A-Z]+-[0-9]{2}\z')) { return }
    if (-not $code -and -not $script:ReachedWake) { return }
    # 현재 단계 번호 n = 이 실행이 마지막으로 찍은 [n/10] (없으면 0 · 원격 해결 보고와 같은 방법)
    $n = 0
    for ($i = $script:StepLog.Count - 1; $i -ge 0; $i--) {
        if ([string]$script:StepLog[$i] -cmatch '\A\[([0-9]{1,2})/[0-9]{1,2}\]') { $n = [int]$Matches[1]; break }
    }
    if (-not $code) {
        # 깨우기까지 간 성공 끝 = 막힌 기록을 모두 지운다(보고 기록은 남긴다)
        if (-not (Test-Path -LiteralPath $HelpAttemptsFile)) { return }
        $state = Read-HelpAttempts
        $state.Codes = @{}
        Save-HelpAttempts $state
        return
    }
    $state = Read-HelpAttempts
    $now = Get-HelpNow
    # 다른 코드 가운데 더 앞 단계에서 난 것 = 그 단계는 지나갔다 ⇒ 지운다
    foreach ($k in @($state.Codes.Keys)) {
        if ($k -cne $code -and $state.Codes[$k].Step -lt $n) { $state.Codes.Remove($k) }
    }
    $prev = $state.Codes[$code]
    if ($null -eq $prev) {
        $entry = @{ N = 1; First = $now; Last = $now; Step = $n }
    } else {
        $cnt = $prev.N
        if ($cnt -lt 9999) { $cnt++ }    # 읽기 정규식이 네 자리까지다 — 넘기면 다음 실행이 못 읽는다
        $entry = @{ N = $cnt; First = $prev.First; Last = $now; Step = $n }
    }
    $state.Codes[$code] = $entry
    Save-HelpAttempts $state
    $script:HelpStage = $entry.N
    $script:HelpFirst = $entry.First
    if ($null -ne $state.Report) {
        $same = '같은 코드'
        if ($state.Report.Code -cne $code) { $same = '다른 코드 ' + $state.Report.Code }
        $script:HelpPrevReport = $state.Report.Id + ' (' + $state.Report.At + ' · ' + $same + ')'
    }
    Write-Log ('help attempts: ' + $code + ' count=' + $entry.N + ' step=' + $n)
}

# 끝맺음의 「진단 코드:」 줄 바로 다음에 부른다 — 2회째 = 다른 방법 · 3회째부터(곧바로 연락 코드는 2회째부터) = 담당자
function Write-HelpEscalation {
    $script:HelpStage3 = $false
    $code = [string]$script:JCode
    if (-not $code -or $script:HelpStage -lt 2) { return }
    if ($script:HelpStage -ge 3 -or ($HelpDirectCodes -ccontains $code)) {
        Say ''
        foreach ($t in $HelpStage3Lines) { Say ($t.Replace('<PHONE>', $HelpContactPhone).Replace('<CODE>', $code)) }
        $script:HelpStage3 = $true
        return
    }
    if (-not $HelpWays.ContainsKey($code)) { return }    # 두 번째 방법이 없는 코드 = 1회째처럼 둔다
    Say ''
    foreach ($t in $HelpStage2Lines) {
        if ($t -cne '<WAY>') { Say $t; continue }
        $ws = @($HelpWays[$code])
        for ($i = 0; $i -lt $ws.Count; $i++) {
            if ($i -eq 0) { Say ('   - ' + $ws[$i]) } else { Say ('     ' + $ws[$i]) }
        }
    }
}

# 보고 번호를 받은 직후 부른다 — 다음 실행이 「이전 보고」를 말할 수 있게(같은 실행에서 여러 번 보내도 매번 갱신)
function Save-HelpLastReport {
    if ($Mode -ne 'full') { return }
    if (-not (Test-Path -LiteralPath $JarvisHome -PathType Container)) { return }
    if (-not (Test-JarvisOwnerMark)) { return }
    if (-not ([string]$script:RhId -cmatch '\A[A-Z2-9]{8}\z')) { return }
    if (-not ([string]$script:JCode -cmatch '\AJ-[A-Z]+-[0-9]{2}\z')) { return }
    $state = Read-HelpAttempts
    $state.Report = @{ Id = [string]$script:RhId; At = (Get-HelpNow); Code = [string]$script:JCode }
    Save-HelpAttempts $state
}

# ── 끝맺음 (어느 끝에서도 「다음에 할 일」이 있다) ────────────────
# ⚠맥판은 이 줄을 EXIT 트랩에 매달았다(끝나는 자리가 여럿이라 기억에 맡기지 않기 위해서다).
#   PowerShell 에는 그 트랩이 없으므로 본문을 try/finally 로 감싸 **같은 성질**을 만든다 —
#   모양은 다르고 보증은 같다. 어느 경로로 끝나도 이 블록을 지난다.
$script:ClosingDone = $false
function Write-ClosingNote {
    if ($script:ClosingDone) { return }
    $script:ClosingDone = $true
    # 「다음에 할 일」을 아무도 안 적은 끝 = 우리가 예상 못 한 자리다. 그때가 안내가 가장 필요한 때이므로
    #   기본값을 「다시 실행」으로 두고 **깃발도 함께 세운다**(문구만 두면 방법이 안 나온다).
    if (-not $script:NextStep) {
        $script:NextStep = '아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        $script:ShowRerun = $true
    }
    $next = $script:NextStep
    Say ''
    Say ('다음에 할 일: ' + $next)
    # 반복 막힘 셈 — 끝맺음 이 한 자리에서 한 번만 센다
    Update-HelpAttempts
    if ($script:JCode) {
        Say ('  진단 코드: ' + $script:JCode + '  (' + $HelpCodeUrl + $script:JCode + ')')
        # 🔴화면과 보고서가 갈리지 않게 한다(검토 지적 채택) — 단계가 코드를 남기고 그 자리에서 끝나면
        #   보고서에는 옛 코드나 빈칸이 남는다. 끝나기 직전에 그 줄만 지금 값으로 맞춘다.
        if (Test-Path $ReportFile) {
            try {
                $keep = @(Get-Content $ReportFile -Encoding UTF8 -ErrorAction Stop | Where-Object { $_ -notmatch '^- 진단 코드: ' })
                # 셈의 두 줄도 같은 방법으로 지우고 다시 붙인다(원격 해결 보고보다 앞 · 두 번 끝맺어도 한 줄씩)
                $keep = @($keep | Where-Object { $_ -notmatch '^- (같은 진단 코드|이전 보고): ' })
                $keep += ('- 진단 코드: **' + $script:JCode + '** (' + $HelpCodeUrl + $script:JCode + ')')
                if ($script:HelpFirst) { $keep += ('- 같은 진단 코드: ' + $script:HelpStage + '회째 (이 컴퓨터 · 첫 기록 ' + $script:HelpFirst + ')') }
                if ($script:HelpPrevReport) { $keep += ('- 이전 보고: ' + $script:HelpPrevReport) }
                Write-TextNoBom $ReportFile (($keep -join "`r`n") + "`r`n")
            } catch { }
        }
        Write-HelpEscalation
    }
    # ⚠없는 파일을 보내 달라고 하지 않는다 — 자리 자체를 못 만든 끝에서는 그 두 줄이 거짓이다.
    if ((Test-Path $ReportFile) -or (Test-Path $LogFile)) {
        Say ('  막히면 이 두 파일을 보내 주십시오: ' + (Redact $ReportFile) + ' · ' + (Redact $LogFile))
        Say ('  여는 법: 탐색기 주소창에 ' + (Redact $JarvisHome) + ' 를 붙여넣으십시오')
    } else {
        Say '  기록 파일은 아직 만들어지지 않았습니다 — 이 화면을 사진으로 남겨 주십시오.'
    }
    # 원격 해결 — 막혀 멈춘 끝이면 여기서 진단을 보내고 창을 연 채 운영팀을 기다린다([1/10] 고지를 보여 드린 실행만).
    if ($script:NoticeShown) { Invoke-RemoteHelp }
    # 담당자 안내를 보인 끝에서 자동 전달을 못 했으면(미동의·전송 실패·원격 해결 안 돎) 사진을 부탁드린다
    if ($script:HelpStage3 -and -not $script:HelpSentSaid) { Say $HelpSentNoLine }
    # ★안내는 **맨 마지막**에 둔다 — 사람이 마지막으로 보는 화면에 명령이 있어야 복사할 수 있다.
    if ($script:ShowRerun) { Show-RerunHow }
}

# ── 다시 하시는 법 — 「같은 줄」이라고 말하지 않는다 (2026-09-10 실기에서 고친 것) ─────
# 🔴막힌 자리마다 「같은 한 줄을 다시 돌려 주십시오」라고 적어 왔다. 실기에서 그것이 **사용자
#   막힘으로 확정**됐다 — 「줄」이 무엇인지, 「돌린다」가 무슨 뜻인지 모르고, 무엇보다 그 명령이
#   화면 어디에도 없었다. 창이 닫힌 뒤 사이트를 다시 찾는 것 자체가 손 하나이고, 사이트에는
#   명령이 둘(지우기·재설치)이라 어느 쪽인지 사람이 고를 수도 없다.
#   ⇒ 끝맺음에서 ①창 여는 법 ②복사 ③붙여넣기+Enter 를 적고 **명령 전체를 인쇄한다.**
# ★어느 명령을 인쇄할지는 **들어온 길**이 정한다(재설치가 JARVIS_ENTRY=reinstall 로 알려 준다).
# ⚠아래 두 줄은 사이트가 게시하는 명령과 **글자까지 같아야 한다** — checks.ps1 이 아니라
#   checks.sh 가 머리글의 한 줄과 이 상수의 동일성을 잰다(둘이 갈리면 사람이 복사한 것이 달라진다).
$JarvisRerunBootstrap = @'
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/bootstrap.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\install-jarvis.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\install-jarvis.ps1')"
'@
$JarvisRerunReinstall = @'
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/reinstall.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reinstall-jarvis.ps1')"
'@
$script:ShowRerun = $false
function Get-RerunCmd {
    if ($env:JARVIS_ENTRY -eq 'reinstall') { return $JarvisRerunReinstall }
    return $JarvisRerunBootstrap
}
# 「다시 실행하면 풀린다」고 말하는 자리는 **전부 이 함수로** 적는다 — 문구와 깃발이 갈리면
#   화면은 다시 하라는데 그 방법은 안 나오는 끝이 생긴다(그것이 실기에서 난 일이다).
function Set-NextStepRerun($text) {
    $script:NextStep = $text
    $script:ShowRerun = $true
}
function Show-RerunHow {
    Say ''
    Say '  == 다시 하시는 법 (이대로 따라 하시면 됩니다) =='
    Say '   1) 시작 단추를 누르고 powershell 이라고 치신 뒤 [Windows PowerShell] 을 여십시오.'
    Say '   2) 아래 명령을 처음부터 끝까지 마우스로 끌어 선택한 뒤 Ctrl+C 를 누르십시오.'
    Say '   3) 그 창을 한 번 누르고 마우스 오른쪽 단추를 눌러 붙여넣은 뒤 Enter 를 누르십시오.'
    Say ''
    Say (Get-RerunCmd)
    Say ''
    Say '  끝난 단계는 건너뛰고 막힌 자리부터 이어서 갑니다.'
}

# 백신이 파일을 붙들었을 때 하는 말은 한 자리에서만 만든다 — 두 곳(설치 대기·받은 파일 사라짐)에서
# 같은 일이 나는데 문장이 갈리면, 같은 사고를 두 가지 이름으로 배우게 된다.
# ⛔백신을 통째로 끄라는 안내는 어느 단계에도 넣지 않는다 · 우리가 대신 예외로 등록하지도 않는다.
#   이 자리는 「막혔다」를 알아볼 수 있게 적어 두는 것뿐이다. 사람이 직접 「예외(허용)」에 추가하는 법과
#   되돌리는 법은 같은 자리에서 2회째 막혔을 때만 반복 막힘 안내(J-AV-* 두 번째 방법)가 보여 드린다(운영자 결정 2026-09-12).
function Say-AntivirusHold($what) {
    Say '     백신이 그 파일을 붙들고 있는 것으로 보입니다.'
    Say ("     대상 = " + $what)
    Say '     작업 표시줄과 화면 오른쪽 아래에 백신 창이 떠 있는지 확인해 주십시오.'
    Say '     「클라우드 자동 분석 요청」 창이면 [파일 전송] 을, 실행 알림이면 [실행] 을 누르시고 창을 닫지 마십시오.'
    Say '     그 뒤 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다.'
    $script:ShowRerun = $true
}

function Redact($s) {
    if ($null -eq $s) { return '' }
    return ([string]$s).Replace($env:USERPROFILE, '~')
}

#   `claude auth status` 로 프로브하면 안 된다: 낡은 판본은 그 문자열을 질문으로 읽고 세션을 띄운다
#   판본 숫자로 재지 않는 이유 = 클로드는 자동 판올림이 돌아 「요구 최소 판본」 상수가 곧 낡는다.
function Test-ClaudeAuthCmd {
    # 🔴**부르기 전에 있는지 본다**(2026-09-09 러너 실측으로 드러난 결함).
    #   클로드가 없는 기계에서 `& claude` 는 「그런 명령이 없다」로 **던진다**. 본문이 try 로 감싸여
    #   있어 그 순간 catch 로 튀고 스크립트가 끝난다 — 미리보기(-DryRun)가 **[2/10] 에서 멈추고**
    #   영어 오류 한 줄을 남겼다(러너 로그 실측). 사람이 보는 화면으로는 「설치가 깨졌다」로 읽힌다.
    #   ⚠맥판은 같은 자리에서 안 죽는다(없는 명령은 종료값 127 로 지나간다) — **두 OS 가 갈리던 자리다.**
    #   ★없는 것을 물으면 답은 「모른다」여야지 죽음이면 안 된다.
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { return $false }
    $h = (& claude --help 2>$null) -join "`n"
    return ($h -match '(?m)^\s*auth\s')
}

#   cys 쪽 능력도 같은 까닭으로 `--help` 로 묻는다(판본 숫자를 게이트로 쓰지 않는다).
#   묻는 것 = 자리를 열 때 「이 자리에서 무엇을 띄우는지」를 적어 두는 칸이 있는가.
#   그 칸이 있어야 컴퓨터를 껐다 켠 뒤 복원이 자비스 자리를 「무엇을 띄울지 모름」으로 건너뛰지 않는다.
#   ⚠판본에 따라 그 칸이 없다 — 없는 판본에 붙이면 자리가 아예 안 열린다(2026-09-04 실측: 0.14.29 에 없었다).
#     ★그래서 이 주석에 「지금 배포된 판본은 X」라고 적지 않는다 — 핀이 올라가는 날 그 문장만 낡는다.
#   그래서 붙이기 전에 물어본다. 한 번만 묻고 그 답을 기록 파일에 한 줄 남긴다.
#   ⚠답을 기억해 두지 않는다. 이 스크립트가 도는 동안 cys 는 **없다가 생기고 낡았다가 새로워진다** —
#   설치 전에 물어 둔 답을 설치 뒤에 그대로 쓰면 옛 판본에 대고 판정하는 셈이 된다.
#   기록은 한 줄만 남긴다(답이 바뀐 때만 또 남긴다 — 바뀌었다는 것 자체가 알 값이다).
$script:CysAgentFlag = ''    # 마지막으로 기록한 답 · '' 아직 기록 안 함
function Test-CysAgentFlag {
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    $h = ''
    if (Get-Command $cli -ErrorAction SilentlyContinue) {
        # 읽기만 하는 물음이므로 데몬을 깨우지 않는다(이 파일이 이미 쓰는 감싸개를 그대로 쓴다 —
        # 남이 켜 둔 값을 지우지 않고 되돌려 준다).
        $h = (Invoke-CysProbe $cli @('new-surface', '--help')) -join "`n"
    }
    $ans = if ($h -match '--agent') { 'yes' } else { 'no' }
    if ($ans -ne $script:CysAgentFlag) {
        $script:CysAgentFlag = $ans
        Write-Log "cys new-surface --agent supported: $ans"
    }
    return ($ans -eq 'yes')
}

# 이 컴퓨터의 cys 가 스스로 말하는 판본 한 줄(없으면 빈 글자).
function Get-CysVersionLine {
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    if (Get-Command $cli -ErrorAction SilentlyContinue) {
        return ((Invoke-CysProbe $cli @('--version')) | Select-Object -First 1)
    }
    return ''
}

# cys 가 이 컴퓨터에 있는가 — 세 가지는 서로 다른 질문이다.
#   등록  = 설치된 적이 있다   (설치 목록)
#   몸통  = 지금 실행 파일이 있다
#   명령  = 이 창에서 부를 수 있다
# 설치 목록만 보고 「있다」고 판정하면 안 된다. 지난 설치가 끝까지 못 간 컴퓨터에서 실제로 어긋난다.
function Test-CysBody {
    $reg = $null
    try {
        $reg = Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
                             'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
                             'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -ErrorAction SilentlyContinue |
               Get-ItemProperty -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -and $_.DisplayName -match 'cys' } |
               Select-Object -First 1
    } catch { }
    $body = $false; $path = ''; $cli = ''
    $roots = New-Object System.Collections.ArrayList
    if ($reg -and $reg.InstallLocation) { [void]$roots.Add($reg.InstallLocation) }
    # 기본 설치 자리는 사용자 폴더 안이다(관리자 권한이 필요 없는 이유가 이것이다).
    [void]$roots.Add((Join-Path $env:LOCALAPPDATA 'cys'))
    [void]$roots.Add((Join-Path $env:LOCALAPPDATA 'Programs\cys'))
    [void]$roots.Add((Join-Path $env:ProgramFiles 'cys'))
    foreach ($r in $roots) {
        if (-not $r -or -not (Test-Path $r)) { continue }
        $exe = Get-ChildItem $r -Filter '*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {
            $body = $true; $path = $exe.DirectoryName
            # 명령줄로 쓰는 것은 cys.exe 다. 설치기가 실행 경로를 등록하지 않으므로 전체 경로로 부른다.
            $c = Get-ChildItem $r -Filter 'cys.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($c) { $cli = $c.FullName } else { $cli = $exe.FullName }
            break
        }
    }
    return [pscustomobject]@{ Reg = $reg; Body = $body; Path = $path; Cli = $cli }
}

$Rows = New-Object System.Collections.ArrayList
function Add-Row($num, $what, $value, $enum, $note) {
    [void]$Rows.Add([pscustomobject]@{ Num=$num; What=$what; Value=$value; Enum=$enum; Note=$note })
}

$script:ClaudeOk    = $false
$script:LoggedIn    = $false
$script:CysPresent  = $false
$script:CysAppFound = $false
$script:IsAdmin     = $false
$script:CysBodyMissing = $false
$script:BlockedStep = ''
$script:DaemonTemporary = $false
# 자동 시작 등록 실측값(Get-CysAutoStartState 가 채운다). 재기 전에는 **'unknown'** 이다 —
#   ⛔안 재고 'no' 로 두면 그것이 곧 「모른다를 없다로 바꿔 말하는」 그 사고다.
$script:AutoStartState = 'unknown'
# 🔴우리가 **홈 폴더에 새로 넣은** 신뢰 키의 목록(설정파일, 키). 제거기가 이 목록만 되돌린다 —
#   목록에 없는 키는 참가자의 것이므로 손대지 않는다(1차 검토 REVISE ④). 형식은 TSV 다: 두 OS 가 같은
#   파일을 읽고 쓰는데 한쪽에는 JSON 도구가 없을 수 있기 때문이다(맥 깨끗한 기계에 jq 가 없다).
$script:TrustSeeded = @()
$script:TrustJournalFailed = $false
$script:TrustRollbackState = ''   # verified(도로 뺐다) · kept(키가 남았다) · unknown(확인 못 했다)
$TrustSeedFile = Join-Path $JarvisHome 'trust-seed.tsv'
# 🔴**우리가 만든 폴더라는 표식**(2차 검토 N3 확정 2026-09-10). 제거기는 이 표식이 있을 때만 작업 폴더를
#   재귀로 지운다 — JARVIS_HOME 은 환경변수라 무엇이든 들어올 수 있고, 검사 없이 지우면
#   사용자 홈이나 드라이브 루트가 통째로 사라진다(되돌릴 수 없다).
$JarvisOwnerFile = Join-Path $JarvisHome '.jarvis-owned'
$JarvisOwnerMark = 'jarvis-installer-owned v1'
$JarvisHomeBaseName = 'install-jarvis'
# 🔴구판 폴더 이관 (v0.3.10 · 실제 노트북에서 겪은 일 2026-09-10 · 맥판과 같은 규칙).
#   구판(v0.3.7)이 만든 %USERPROFILE%\install-jarvis 에는 표식이 없다(표식은 그 뒤에 생겼다) ⇒
#   새 판이 규칙대로 거부했고 사람이 손으로 폴더를 지워야 했다. **우리 구판 지문**일 때만,
#   무엇이 들었는지 보여 드리고 사람이 「지웁니다」라고 한 번 쳐야 지운다. ⛔자동 삭제는 없다.
$JarvisOldNames = @('bootstrap.log','env-report.md','install-directive.md','trust-seed.tsv','wake.sh','wake.ps1','dl','backup','.jarvis-owned')
$JarvisOldSign  = @('install-directive.md','env-report.md','bootstrap.log')
function Test-JarvisHomeIsLink {
    # 🔴그 자리 **자신**이 이음줄(junction·symlink)인가. 5.1 의 `Remove-Item -Recurse` 는 이음줄을
    #   타고 들어가 **가리키던 자리 안엣것**을 지운다(지우개가 그 때문에 고쳐졌다).
    #   우리는 작업 폴더를 이음줄로 만들지 않으므로, 이음줄이면 언제나 「우리 것이 아니다」.
    try {
        $it = Get-Item -LiteralPath $JarvisHome -Force -ErrorAction Stop
        return [bool]($it.Attributes -band [IO.FileAttributes]::ReparsePoint)
    } catch { return $false }
}
function Test-JarvisHomePresent {
    # `Test-Path` 는 **끊어진 이음줄**에 $false 를 낸다 ⇒ 그것을 「자리를 못 만들었다(권한)」로
    #   말하면 사람이 엉뚱한 것을 고치러 간다(맥은 `-L` 로 갈라 「폴더가 아닌 것」이라 말한다).
    if (Test-Path -LiteralPath $JarvisHome) { return $true }
    try { $null = Get-Item -LiteralPath $JarvisHome -Force -ErrorAction Stop; return $true } catch { return $false }
}
function Test-JarvisOwnerMark {
    # ★다시 읽는다 — 경합 갈래에서는 「아까 읽은 값」이 이미 낡았다.
    if (-not (Test-Path -LiteralPath $JarvisOwnerFile)) { return $false }
    try {
        $mk = Get-Content -LiteralPath $JarvisOwnerFile -Raw -Encoding UTF8 -ErrorAction Stop
        return ($null -ne $mk -and $mk.Contains($JarvisOwnerMark))
    } catch { return $false }
}
function Get-HomeEntries {
    # 폴더 안 항목. **못 세면 $null** — 빈 목록과 구분한다(「비었다」와 「못 세었다」를 한 칸에 담지 않는다).
    #   ★이름이 아니라 **항목**을 돌려준다 — 이음줄인지(ReparsePoint)를 부르는 쪽이 물어야 하기 때문이다.
    try { return ,@(Get-ChildItem -LiteralPath $JarvisHome -Force -ErrorAction Stop) } catch { return $null }
}
function Test-OldLayout {
    # 🔴🔴**이음줄(junction·symlink)이 섞여 있으면 우리 구판이 아니다**(자기 교차 검토 2026-09-11).
    #   `Remove-Item -Recurse` 는 5.1 에서 이음줄을 뚫고 **가리키던 자리 안엣것**을 지운 적이 있다
    #   (지우개가 그 때문에 고쳐졌다). 우리가 만드는 것 중 이음줄은 없으므로 잃는 것도 없다.
    $names = Get-HomeEntries
    if ($null -eq $names) { return $false }          # 못 셌으면 우리 것이라고 하지 않는다
    $sign = $false
    foreach ($it in $names) {
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }
        if ($JarvisOldNames -notcontains $it.Name) { return $false }
        if ($JarvisOldSign -contains $it.Name) { $sign = $true }
    }
    return $sign                                      # 빈 폴더는 지문이 아니다(5차 검토 결정 유지)
}
function Test-HumanPresent {
    # 사람이 있는지는 **물어봐서** 안다 — 입력이 딴 데로 이어져 있으면 묻지 않는다.
    try { if ([Console]::IsInputRedirected) { return $false } } catch { return $false }
    try { return [Environment]::UserInteractive } catch { return $false }
}
function Deny-JarvisHome($why, $nextStep) {
    Write-Host ("작업 폴더로 쓸 수 없는 자리입니다: " + $JarvisHome)
    Write-Host ("     까닭: " + $why)
    Write-Host ("     진단 코드: J-HOME-01 — 이 도구가 만들고 지우는 폴더의 이름은 「" + $JarvisHomeBaseName + "」 하나입니다")
    $script:JCode = 'J-HOME-01'
    $script:NextStep = $nextStep
    $script:ShowRerun = $true
    exit 3
}
function Deny-CannotMakeHome {
    Write-Host ("자리를 만들지 못했습니다: " + $JarvisHome)
    Write-Host '     진단 코드: J-PERM-01 — 파일이나 폴더를 쓸 권한이 없습니다(공간 부족·백신 차단도 같은 모양입니다)'
    $script:JCode = 'J-PERM-01'
    $script:NextStep = '회사·학교에서 관리하는 컴퓨터면 담당자에게 문의해 주십시오. 개인 컴퓨터면 저장 공간과 백신 알림을 확인해 주십시오.'
    exit 3
}
function New-JarvisHomeNow {
    # $true = 우리가 방금 만들었다. ★`New-Item` 은 **이미 있으면 실패한다**(-Force 를 붙이지 않는다) —
    #   그 실패가 곧 「우리가 만든 자리가 아니다」라는 신호다. 만들기와 알리기가 한 동작이라 사이가 없다.
    # 🔴**부모는 미리 만든다**(교차 검토 2차 NEW · 2026-09-11 · 맥판 `mkdir -p "$parent"` 와 짝).
    #   맥은 부모를 `-p` 로 만들고 마지막 마디만 원자적으로 만든다. 윈에도 같은 두 걸음을 명시한다 —
    #   부모가 없을 때 어떻게 되는지를 **글로 못박아** 두 OS 가 같은 것을 하게 한다(러너 축으로도 잰다).
    $parent = Split-Path -Parent $JarvisHome
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        try { New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null } catch { return $false }
    }
    try { New-Item -ItemType Directory -Path $JarvisHome -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}
function Invoke-OldHomeCleanup {
    # $true = 사람이 허락해 지웠다 · $false = 지우지 않았다
    if ($Mode -ne 'full') { return $false }           # 보기만 하는 판에서는 바깥을 바꾸지 않는다
    if (-not (Test-HumanPresent)) { return $false }
    if (-not (Test-OldLayout)) { return $false }
    Write-Host ''
    # ★사람에게는 **실제 자리**를 보여 준다(상대 경로로 들어오면 화면 글자만으로는 어디인지 모른다).
    $full = $JarvisHome
    try { $full = (Get-Item -LiteralPath $JarvisHome -Force -ErrorAction Stop).FullName } catch { }
    Write-Host ("그 자리에 예전 판이 만든 작업 폴더가 있습니다: " + (Redact $full))
    Write-Host '     안에 있는 것(이 도구가 만드는 이름뿐입니다):'
    foreach ($it in (Get-HomeEntries)) { Write-Host ("       · " + $it.Name) }
    Write-Host '     이 폴더를 지우고 새로 만들면 그대로 이어서 설치합니다. 되돌릴 수 없습니다.'
    $answer = Read-Host '계속하려면 「지웁니다」 라고 쳐 주십시오(그만두시려면 그냥 Enter)'
    if ($answer -ne '지웁니다') { Write-Host '     그만둡니다 — 아무것도 지우지 않았습니다.'; return $false }
    try { Remove-Item -LiteralPath $JarvisHome -Recurse -Force -ErrorAction Stop } catch { }
    if (Test-Path -LiteralPath $JarvisHome) { Write-Host '     그 폴더를 지우지 못했습니다.'; return $false }
    Write-Host '     예전 작업 폴더를 지웠습니다.'
    return $true
}

function Invoke-DetectStage1 {
    #   상태 변수들이 켜지기만 하고 꺼지지 않으면 앞 호출의 `$true` 잔재가 남아 틀린 ok 를 낸다.
    #   ⇒ 매 호출 시작에서 끈다. 아래 각 행이 다시 켠다.
    $script:ClaudeOk    = $false
    $script:LoggedIn    = $false
    $script:CysPresent  = $false
    $script:CysAppFound = $false
    $script:CysBodyMissing = $false

    # 1-1 OS·아키텍처
    $arch = $env:PROCESSOR_ARCHITECTURE
    $is64 = [Environment]::Is64BitOperatingSystem
    if ($arch -and $is64) {
        Add-Row '1-1' 'OS·아키텍처' "Windows · $arch · 64bit=$is64" 'ok' '-'
    } elseif ($arch -and -not $is64) {
        Add-Row '1-1' 'OS·아키텍처' "Windows · $arch · 64bit=false" 'failed' '공식 설치기가 32비트 윈도우를 거부한다 — 여기서 멈추는 것이 맞다'
    } else {
        Add-Row '1-1' 'OS·아키텍처' '-' 'failed' 'PROCESSOR_ARCHITECTURE 가 비어 있다'
    }

    # 1-2 클로드가 깔렸는가·판본  자동 판올림이 도므로 판본을 게이트로 쓰지 않는다
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmd) {
        $cver = (& claude --version 2>$null | Select-Object -First 1)
        if ($cver -and (Test-ClaudeAuthCmd)) {
            $script:ClaudeOk = $true
            Add-Row '1-2' '클로드 판본' $cver 'ok' (Redact $cmd.Source)
        } elseif ($cver) {
            #   있다고 쓸 수 있는 것은 아니다. 윈도우도 같은 형태가 가능하다(전역 설치·낡은 판본).
            $script:ClaudeOk = $false
            Add-Row '1-2' '클로드 판본' $cver 'blocked' "낡음 — 판올림이 필요하다($(Redact $cmd.Source) · 로그인 명령을 모르는 판본)"
        } else {
            Add-Row '1-2' '클로드 판본' '-' 'failed' '명령은 있는데 판본을 못 읽었다'
        }
    } else {
        $probeClaude = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
        if (Test-Path $probeClaude) {
            Add-Row '1-2' '클로드 판본' '-' 'blocked' "파일은 있는데 **이 창의 PATH 에서 안 잡힌다**($(Redact $probeClaude)) — [2/10] 이 사용자 PATH 에 등록하고 이 창에서도 잡히게 한다"
        } else {
            Add-Row '1-2' '클로드 판본' '-' 'unknown' 'claude 명령이 없다 (설치 전 정상값)'
        }
    }

    # 1-3 로그인·구독  나머지 칸(email·orgId·orgName·projectsDirectory)은 옮기지 않는다
    if ($cmd -and -not (Test-ClaudeAuthCmd)) {
        # 여기서 `auth status` 를 부르면 그 문자열이 질문으로 나간다(모델 호출 1회). 부르지 않는다.
        Add-Row '1-3' '로그인·구독' '-' 'unknown' '이 판본은 로그인 확인 명령을 모른다 — 판올림 뒤에 다시 본다'
    } elseif ($script:ClaudeOk) {
        $auth = (& claude auth status 2>$null) -join "`n"
        $logged = [regex]::Match($auth, '"loggedIn"\s*:\s*(true|false)').Groups[1].Value
        $sub    = [regex]::Match($auth, '"subscriptionType"\s*:\s*"([^"]*)"').Groups[1].Value
        if ($logged -eq 'true') {
            $script:LoggedIn = $true
            Add-Row '1-3' '로그인·구독' "loggedIn=true · subscriptionType=$(if($sub){$sub}else{'미상'})" 'ok' '나머지 칸은 옮기지 않는다'
        } elseif ($logged -eq 'false') {
            Add-Row '1-3' '로그인·구독' 'loggedIn=false' 'blocked' '사람이 승인 클릭을 해야 한다'
        } else {
            Add-Row '1-3' '로그인·구독' '-' 'unknown' '이 컴퓨터에서는 아직 확인하지 못했습니다'
        }
    } else {
        Add-Row '1-3' '로그인·구독' '-' 'unknown' '클로드가 아직 없다'
    }

    # 1-4 cys 가 이미 있는가  깨끗한 기계의 정상값은 「없음」이다
    $cysCmd = Get-Command cys -ErrorAction SilentlyContinue
    if ($cysCmd) { $script:CysPresent = $true }
    # 세 축은 서로 다른 질문에 답한다 — 한 곳에서 만들어 모두가 같은 값을 본다
    $cysInfo = Test-CysBody
    $cysReg  = $cysInfo.Reg
    if ($cysReg) { $script:CysAppFound = $true }
    $cysBody = if ($cysInfo.Body) { '있음' } else { '없음' }
    $cysApp = if ($cysReg) { "등록=있음($($cysReg.DisplayVersion)) · 몸통=$cysBody" } else { '없음' }
    $cysOnboard = if (Test-Path (Join-Path $env:USERPROFILE '.cys')) { '있음' } else { '없음' }
    # 값 칸에 세 축을 모두 적는다 — 판정이 ok 라도 사람이 어긋남을 볼 수 있어야 한다(맥판과 같은 형태).
    $cysVal = "(앱=$cysApp · 명령=$(if($cysCmd){Redact $cysCmd.Source}else{'없음'}) · 계정 준비=$cysOnboard)"
    # 순서가 중요하다 — 「등록만 남음」을 맨 앞에서 잡지 않으면 아래 「온보딩 있음」 갈래가 그것을 ok 로 삼킨다
    if ($cysReg -and $cysBody -eq '없음' -and -not $cysCmd) {
        Add-Row '1-4' 'cys 상태' "등록만 남음 $cysVal" 'blocked' '**설치 목록에는 있는데 프로그램 실체가 없다** — 지난 설치가 끝까지 못 갔거나 지워졌다. **재설치로 풀린다**(다음 단계에서 합니다)'
    } elseif ($cysApp -eq '없음' -and -not $cysCmd -and $cysOnboard -eq '없음') {
        Add-Row '1-4' 'cys 상태' "없음 $cysVal" 'ok' '깨끗한 기계의 정상값이다 (고장 아님)'
    } elseif ($cysOnboard -eq '있음' -and ($cysBody -eq '있음' -or $cysCmd)) {
        Add-Row '1-4' 'cys 상태' "앱+온보딩 $cysVal" 'ok' '이 계정에 이미 자리를 잡았다'
    } elseif ($cysBody -eq '있음' -or $cysCmd) {
        Add-Row '1-4' 'cys 상태' "앱만 $cysVal" 'blocked' '프로그램은 이 컴퓨터에 있으나 **이 계정에는 아직 자리를 안 잡았다** — 계정 단위 준비가 남았다'
    } else {
        Add-Row '1-4' 'cys 상태' "판정 불가 $cysVal" 'unknown' '드문 조합입니다 — 왼쪽 값을 그대로 보여 드립니다'
    }
    $script:CysBodyMissing = ($cysReg -and $cysBody -eq '없음')

    # 1-5 놓을 자리에 쓸 수 있는가
    # 맥은 /Applications 를 봤다. 윈도우는 설치 위치를 모르므로 대신 사용자 프로필에 실제로 써 본다.
    $probe = Join-Path $JarvisHome ('.probe-' + [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -Path $probe -Value 'probe' -ErrorAction Stop
        Remove-Item $probe -Force -ErrorAction SilentlyContinue
        Add-Row '1-5' '사용자 폴더 쓰기' 'true' 'ok' '표준 계정이면 고장이 아니라 계정 성격입니다'
    } catch {
        Add-Row '1-5' '사용자 폴더 쓰기' 'false' 'blocked' '쓸 수 없다'
    }

    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        #   증거 = 이번 실행 자신이다 — `1-6` 이 blocked 인데 로그인·기동·첫 응답까지 전 과정이 완주했다.
        #   `blocked` 의 뜻은 「사람이 무엇을 하면 풀린다」인데 표준 계정은 풀 것이 없다. 정상값을 적색으로 적고
        #   생기면 그 행이 그때 blocked 를 낸다 — 여기서 미리 낼 일이 아니다.
        if ($isAdmin) {
            Add-Row '1-6' '관리자 여부' "IsInRole(Administrator)=True" 'ok' '확인만 한다 — 승격은 하지 않는다'
        } else {
            Add-Row '1-6' '관리자 여부' "IsInRole(Administrator)=False" 'ok' '고장이 아니라 **계정 성격**이다(표준 계정) — 지금까지의 단계는 이 권한 없이 끝났다'
        }
        $script:IsAdmin = $isAdmin
    } catch {
        Add-Row '1-6' '관리자 여부' '-' 'unknown' '판정 실패'
    }

    # 1-7 네트워크 — 연결 성립 여부만 본다
    $netEnum = 'ok'; $netVal = ''
    foreach ($u in @($ClaudeInstallUrl, $CysSiteUrl)) {
        try {
            $r = Invoke-WebRequest -Uri $u -Method Head -TimeoutSec 8 -UseBasicParsing -ErrorAction Stop
            $netVal += "$u=$($r.StatusCode) "
        } catch {
            # 302 를 예외로 던지는 판본이 있어 응답 객체가 있으면 그것을 값으로 쓴다
            $code = $null
            if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
            if ($code -and $code -ge 200 -and $code -lt 400) {
                $netVal += "$u=$code "
            } else {
                $netVal += "$u=실패 "; $netEnum = 'failed'
            }
        }
    }
    Add-Row '1-7' '네트워크(공식 2곳)' $netVal $netEnum '연결 성립만 본다 · 본문을 판정에 안 쓴다'

    #   사람이 읽는 표에서 번호가 튀면 빠진 줄이 있다고 읽는다. 판정에는 영향이 없는 소건이지만 그래서 고친다.
    #   설치 목록(레지스트리)은 프로그램을 가리키는데 그 자리에 실행 파일이 없다. 이름만 다르지 같은 결함이다.
    if ($script:CysBodyMissing) {
        Add-Row '1-8' 'cys 실행 링크' '등록 → 빈 자리' 'blocked' '설치 목록이 가리키는 자리에 실행 파일이 없습니다'
    } else {
        Add-Row '1-8' 'cys 실행 링크' '-' 'unknown' '이 컴퓨터에서는 확인할 것이 없습니다'
    }
}

function Invoke-DetectStage2 {
    if (-not $script:CysPresent) {
        #   뿌리는 1-4 와 같다 — 판정 축이 `Get-Command` 하나뿐이었다.
        $why = if ($script:CysBodyMissing) {
            '🔴cys 가 **등록만 남고 실체가 없다**(1-4 참조) — 창 문제가 아니라 **몸통이 없어서** 2단을 잴 수 없다. 재설치로 풀린다'
        } elseif ($script:CysAppFound -or (Test-Path (Join-Path $env:USERPROFILE '.cys'))) {
            'cys 는 이 컴퓨터에 있으나(1-4 참조) **명령이 이 창에서 안 잡힌다** — 2단은 명령으로만 잴 수 있다'
        } else {
            'cys 가 아직 없습니다 — 다음 단계에서 합니다'
        }
        Add-Row '2-*' 'cys 이후 전 행' '-' 'unknown' $why
        return
    }
    $v = (& cys phoenix-identity 2>$null) -join ''
    if ($v) { Add-Row '2-1' 'cys 판본·팩 해시' $v 'ok' '데몬이 없어도 답합니다' }
    else    { Add-Row '2-1' 'cys 판본·팩 해시' '-' 'failed' '명령이 답하지 않았다' }

    #   소켓 파일 없음 = 이 계정에 온보딩이 안 된 것(정상 가능) · Connection refused = 데몬이 안 떠 있음(지연 포함)
    $v = (& cys ping 2>&1) -join ' '
    if ($v -match 'pong') { Add-Row '2-2' '데몬 생존' 'pong' 'ok' '-' }
    elseif ($v -match 'No such file') { Add-Row '2-2' '데몬 생존' '소켓 없음' 'blocked' '★데몬이 죽은 것이 아니다 — 이 계정에 아직 자리를 안 잡았다(소켓은 계정 단위)' }
    elseif ($v -match 'Connection refused|연결') { Add-Row '2-2' '데몬 생존' '응답 없음' 'failed' '소켓은 있는데 데몬이 안 떠 있습니다 — 방금 켠 직후라면 잠시 뒤 다시 보십시오' }
    else { Add-Row '2-2' '데몬 생존' $(if($v){$v}else{'무응답'}) 'unknown' '처음 보는 응답입니다 — 어느 쪽인지 판단하지 않았습니다' }

    $v = (& cys agent-detect 2>$null | Select-Object -First 5) -join ' '
    if ($v) { Add-Row '2-4' '어댑터 감지' $v 'ok' '-' } else { Add-Row '2-4' '어댑터 감지' '-' 'unknown' '-' }

    $v = (& cys doctor 2>$null | Select-String -Pattern '^요약' | Select-Object -First 1)
    if ($v) { Add-Row '2-5' 'cys 자가점검' $v.ToString() 'ok' '요약 줄만 옮겨 적습니다' }
    else    { Add-Row '2-5' 'cys 자가점검' '-' 'unknown' '요약 줄을 찾지 못했습니다' }

    Add-Row '2-8' '첫 세션 지시 주입' '-' 'unknown' '아직 확인하는 방법이 없습니다'

    #   컴퓨터를 껐다 켠 뒤 자비스 자리가 스스로 되살아나는가 — 그 답은 판본이 정한다.
    #   이 행은 「무엇을 했는가」가 아니라 「이 컴퓨터에서 무엇이 되는가」를 적는다(맥판 2-9 와 같은 행).
    if (Test-CysAgentFlag) {
        Add-Row '2-9' 'master 좌석 복원 플래그' '전달' 'ok' '껐다 켠 뒤 자비스 자리가 자동으로 되살아납니다'
    } else {
        Add-Row '2-9' 'master 좌석 복원 플래그' "미지원($(Get-CysVersionLine))" 'ok' '이 판본에는 그 칸이 없어 붙이지 않았습니다 — 껐다 켜면 자비스 자리는 손으로 다시 엽니다'
    }
}

function Write-Report {
    $total   = $Rows.Count
    $ok      = ($Rows | Where-Object { $_.Enum -eq 'ok' }).Count
    $blocked = ($Rows | Where-Object { $_.Enum -eq 'blocked' }).Count
    $failed  = ($Rows | Where-Object { $_.Enum -eq 'failed' }).Count
    $unknown = ($Rows | Where-Object { $_.Enum -eq 'unknown' }).Count
    $verdict = if ($failed -gt 0) { 'failed' } elseif ($blocked -gt 0) { 'blocked' } elseif ($unknown -gt 0) { 'unknown' } else { 'ok' }

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add($ReportHead)
    [void]$lines.Add('')
    [void]$lines.Add("- 언제: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')")
    [void]$lines.Add("- 부트스트랩 판본: $BootstrapVersion · 모드: $Mode")
    [void]$lines.Add("- 종합 판정: **$verdict** (ok $ok · blocked $blocked · failed $failed · unknown $unknown / 전 $total 행)")
    # 화면·기록 파일과 **같은 문자열**을 여기에도 남긴다 — 셋을 맞춰 보는 일이 사람 몫이 되면 안 된다.
    if ($script:JCode) { [void]$lines.Add("- 진단 코드: **$($script:JCode)** ($HelpCodeUrl$($script:JCode))") }
    [void]$lines.Add('  - `unknown` 은 「완료됨」으로 세지 않습니다.')
    #   실제로는 4번이었다(로그인 · 폴더 신뢰 · bypass 동의 · 렌더러). 이 축은 언제나 「목표 달성」 쪽으로 틀린다.
    #   ⇒ 선언값과 관측값을 두 줄로 갈라 적고, 관측값은 사람이 채우는 빈칸으로 둔다.
    [void]$lines.Add("- 사람 손 (프로그램이 센 것): **$($script:HumanHands)번** — 미리 아는 자리만 셉니다.")
    [void]$lines.Add('- 사람 손 (실제로 누른 횟수): ____번  ← **직접 적어 주십시오.** 비어 있으면 「0」이 아니라 「세지 못했다」는 뜻입니다.')
    if ($script:StepLog.Count -gt 0) {
        [void]$lines.Add('')
        [void]$lines.Add('**지나온 단계** (화면에서 지워졌을 수 있어 여기 남깁니다)')
        foreach ($ln in $script:StepLog) { [void]$lines.Add("- $ln") }
    }
    [void]$lines.Add('')
    [void]$lines.Add('## 지금 상태 → 다음 행동')
    if ($script:DaemonTemporary) {
        # ⚠한 줄에 인라인 if 를 넣다가 닫는 중괄호를 빠뜨려 **5.1 이 파일 전체를 파싱하지 못했다**
        #   (러너 실측 2026-09-10 · MissingEndCurlyBrace ⇒ 설치기가 한마디도 못 하고 죽는다).
        #   ⇒ 값을 먼저 변수에 담는다. 긴 인라인 식은 이 파일에서 위험 대비 이득이 없다.
        [void]$lines.Add('- ⓘ **cys 를 직접 열어 켰습니다.** ' + (Get-AutoStartWords $script:AutoStartState))
        [void]$lines.Add('  다음에 컴퓨터를 켜시면 **cys 를 한 번 열어 주시면** 됩니다 — 그러면 그때부터 다시 돕니다. 따로 하실 일은 없습니다.')
    }
    if ($Mode -eq 'dry') {
        # 🔴맥에서 먼저 잡힌 것을 윈도우에도 같게 고친다(두 OS 동등). dry 모드에서는 아래
        #   「앞 단계는 이미 끝났습니다」가 거짓이다 — 아무것도 안 했기 때문이다.
        [void]$lines.Add('- (미리보기) 아무것도 하지 않았습니다 — 이 보고는 **지금 이 컴퓨터의 상태**일 뿐입니다.')
        [void]$lines.Add('- 실제로 설치하시려면 미리보기(-DryRun) 없이 아래 명령을 다시 실행하십시오.')
        [void]$lines.Add('')
        [void]$lines.Add('```')
        [void]$lines.Add((Get-RerunCmd))
        [void]$lines.Add('```')
    } elseif ($script:BlockedStep) {
        [void]$lines.Add("- **막힌 단계: $($script:BlockedStep)**")
        [void]$lines.Add('- 앞 단계(클로드 설치·로그인·자비스 준비)는 **이미 끝났습니다.** 여기부터 다시 이어서 갑니다.')
        [void]$lines.Add('- 그 **다음 단계들은 아직 하지 않았습니다** — 실패한 것이 아니라 순서가 안 온 것입니다.')
        [void]$lines.Add('- 아래 명령을 다시 실행하면 **끝난 단계는 건너뛰고 막힌 자리부터** 갑니다.')
        [void]$lines.Add('')
        [void]$lines.Add('```')
        [void]$lines.Add((Get-RerunCmd))
        [void]$lines.Add('```')
    } else {
        [void]$lines.Add('- 막힌 단계 없음.')
    }
    [void]$lines.Add('')
    [void]$lines.Add('| # | 무엇 | 값 | 판정 | 비고 |')
    [void]$lines.Add('|---|---|---|---|---|')
    foreach ($r in $Rows) {
        [void]$lines.Add("| $($r.Num) | $($r.What) | ``$(Redact $r.Value)`` | **$($r.Enum)** | $($r.Note) |")
    }
    [void]$lines.Add('')
    [void]$lines.Add('이 보고에 담지 않는 것: 이름 · 연락처 · 계정 식별자(email·orgId·orgName) · 시크릿 값 · 파일 내용.')
    [void]$lines.Add('경로의 사용자 폴더 이름은 `~` 로 줄여 적었습니다.')

    Write-TextNoBom $ReportFile (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
    Say "환경 보고를 썼습니다: $(Redact $ReportFile)  (종합 판정 = $verdict)"
}

# ── 사용자 PATH 에 ~\.local\bin 을 심는다 (2026-09-06 실사용자 2건으로 확정) ─────
#   🔴공식 설치기는 윈도우에서도 PATH 를 안 건드린다 — 화면에 「System Properties → Environment
#   Variables → Edit User PATH → New」라고 **사람에게 시킨다**(실사용자 사진 2026-09-06 20:05 · 2.1.263 ·
#   공식 문서 「Verify your PATH」도 설치 뒤 PATH 부재를 정상 사례로 안내한다).
#   앞 판은 그 뒤에 `Get-Command claude` 가 실패하면 「창을 새로 열고 다시」라고만 했다 — 새 창에도
#   PATH 가 없으니 **같은 문장이 무한히 되풀이됐다**(실사용자 1차 제보 「계속 … 안 잡힌다」).
#   맥은 같은 날 아침 seed_local_bin_path 로 고쳤는데 윈도우엔 대응물이 0 이었다 — 대상 유형에 묶인
#   규율의 재발. ⇒ 공식 문서의 명령 그대로 **사용자 PATH 에 멱등으로** 넣고, 이 창의 PATH 도 갱신한다.
#   ⚠사용자 PATH 만 만진다(시스템 PATH = 권한 상승 = 우리 상한 밖). 값은 %USERPROFILE% 확장·대소문자
#   무시·끝 역슬래시 무시로 비교한다 — 사람이 손으로 넣은 다른 표기와 중복 누적되지 않게.
function Seed-LocalBinPath {
    $bin = (Join-Path $env:USERPROFILE '.local\bin').TrimEnd('\')
    if (-not (Test-Path $bin)) { Write-Log "seed-path: $bin absent - skip"; return $false }
    try {
        $user = [Environment]::GetEnvironmentVariable('Path','User')
        $have = $false
        if ($user) {
            foreach ($p in ($user -split ';')) {
                if (-not $p) { continue }
                $x = [Environment]::ExpandEnvironmentVariables($p).TrimEnd('\')
                if ($x -ieq $bin) { $have = $true; break }
            }
        }
        if ($have) {
            Write-Log 'seed-path: already in User PATH'
        } else {
            $new = if ($user) { "$user;$bin" } else { $bin }
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Write-Log "seed-path: added $bin to User PATH"
        }
    } catch {
        Write-Log "seed-path: failed - $($_.Exception.Message)"
        return $false
    }
    # 등록은 새 창부터 먹는다 — 이 창의 다음 단계가 바로 부를 수 있게 앞에 붙인다(있으면 안 붙인다).
    $inProc = $false
    foreach ($p in ($env:Path -split ';')) { if ($p -and ($p.TrimEnd('\') -ieq $bin)) { $inProc = $true; break } }
    if (-not $inProc) { $env:Path = "$bin;$env:Path" }
    return $true
}

# ── 하는 일 2 — 공식 설치기 호출 (멱등: 이미 있으면 건너뛴다) ─────
function Step-InstallClaude {
    if ($script:ClaudeOk) { Say '[2/10] 클로드가 이미 있습니다 — 건너뜁니다 (멱등).'; return 0 }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Say "[2/10] 이 컴퓨터의 클로드가 낡았습니다. 최신판을 설치합니다."
    }
    if ($Mode -eq 'dry')  { Say "[2/10] (dry-run) 설치기를 부르지 않았습니다. 부를 줄 = irm $ClaudeInstallUrl | iex"; return 0 }

    Say '[2/10] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다.'
    #   호출부의 `$rc` 가 배열이 되고, 설치에 성공해도 `$rc -ne 0` 이 참이 된다.
    #   `iex` 는 설치기 본문을 현재 프로세스·현재 스코프에서 돌린다. 공식 `install.ps1` 은
    #   ⇒ in-process 로 돌리면 그 `exit` 가 부트스트랩을 통째로 그 자리에서 죽여 아래 실패 안내·
    #   재개 안내가 한 줄도 못 나간다. 맥판 `curl | bash` 는 자식 bash 라 같은 `exit` 가 부모를 못 죽인다
    $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
    #   -Wait 도 `& ` 도 쓰지 않는다: 둘 다 **한도 없이** 기다리므로, 백신 창 하나에 영원히 서 있게 된다
    #   (실사용자 3호 실기 · 07:09~07:20 화면 정지). 창은 살아 있는데 아무 말이 없으니 사람은 무엇을
    #   해야 할지 알 수 없다. ⇒ 띄워 놓고 지켜보며, 30초마다 한 줄을 적고, 상한을 넘기면 멈춘다.
    #   ⚠자식의 화면 출력은 그대로 이 창에 흐르게 둔다(리다이렉트하지 않는다) — 「글자가 주르륵」이
    #     정상이라고 바로 위에서 말했고, 리다이렉트는 자식 안에서 공식 설치기가 쓰는 명령을 흔든다.
    try {
        $p = Start-Process -FilePath $psExe -NoNewWindow -PassThru -ErrorAction Stop `
                           -ArgumentList @('-NoProfile', '-Command', "irm '$ClaudeInstallUrl' | iex")
    } catch {
        Say "[2/10] 실패: $($_.Exception.Message). 인터넷 연결을 확인해 주십시오. 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다."
        $script:ShowRerun = $true
        return 4
    }
    $waitedMs = 0
    $sinceNoteMs = 0
    while ((-not $p.HasExited) -and ($waitedMs -lt $ClaudeInstallWaitMs)) {
        Start-Sleep -Milliseconds 1000
        $waitedMs += 1000
        $sinceNoteMs += 1000
        if ($sinceNoteMs -ge ($InstallNoteEverySec * 1000)) {
            $sinceNoteMs = 0
            $mm = [int]($waitedMs / 60000); $ss = [int]($waitedMs / 1000) % 60
            Say ("     아직 설치 중입니다 (" + $mm + "분 " + $ss + "초 지남 · 최대 " + [int]($ClaudeInstallWaitMs / 60000) + "분). 작업 표시줄에 백신 창이 떠 있는지 확인해 주십시오 — 「파일 전송」이나 [실행] 을 누르시면 이어집니다.")
        }
    }
    if (-not $p.HasExited) {
        # 조용히 다음 단계로 가지 않는다. 여기서 멈춰야 사람이 무엇을 누를지 알게 된다.
        Say ("[2/10] 설치가 " + [int]($ClaudeInstallWaitMs / 60000) + "분 안에 끝나지 않았습니다.")
        Write-JCode 'J-AV-01' '백신 창이 설치 파일을 붙들고 있는 것으로 보입니다'
        Say-AntivirusHold '클로드 설치 파일 (이름이 claude 로 시작하는 파일)'
        Set-NextStepRerun '작업 표시줄에서 백신 창을 찾아 [파일 전송] 또는 [실행] 을 누르신 뒤, 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        return 4
    }
    # PowerShell 5.1 은 갓 끝난 프로세스의 ExitCode 를 늦게 채우는 일이 있다(검토 지적 채택).
    #   WaitForExit() 를 한 번 더 부른다 — 이미 끝났으므로 곧바로 돌아온다.
    # 🔴⛔**읽지 못한 값을 0(성공)으로 덮지 않는다** — 그러면 실패 코드를 우리가 삼킨다.
    #   실측 2026-09-09(러너 run 34289192025 · 대조 34271220513): 설치기가 오류로 죽었는데 화면에는
    #   「설치기는 끝났는데 … 설치기 종료 코드: 0」이 나갔다. 같은 실패를 앞 판은 「실패 (종료 코드 1)」로
    #   적었다. 사람이 읽는 문장이 **설치기가 성공한 것처럼** 바뀐 것이다 — 첫 판(0 으로 덮기)이 만든 후퇴다.
    #   ⇒ 못 읽었으면 못 읽었다고 적고, 판정은 이 파일 원래 규칙 — **클로드 명령이 답하는가** — 로 넘긴다.
    [void]$p.WaitForExit()
    $installRc = $p.ExitCode
    $rcShown = if ($null -eq $installRc) { '읽지 못함' } else { [string]$installRc }
    if ($null -eq $installRc) {
        Say '[2/10] 설치기가 끝났는데 종료 코드를 읽지 못했습니다 — 숫자 대신 클로드 명령이 답하는지로 판정합니다.'
    } elseif ($installRc -ne 0) {
        Say "[2/10] 실패 (종료 코드 $installRc). 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다."
        $script:ShowRerun = $true
        return 4
    }
    #   ⇒ 이 프로세스의 `$env:Path` 를 사용자·시스템 환경변수에서 다시 읽어 붙인다.
    try {
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path','User')
    } catch { }
    # 🔴설치기가 PATH 를 안 심으므로 우리가 심는다(2026-09-06). 위 갱신 **뒤에** 부른다 —
    #   위 줄이 이 창의 PATH 를 통째로 덮어쓰므로, 앞에서 붙였다면 여기서 지워진다.
    [void](Seed-LocalBinPath)
    # 실행 결과 검사 = 설치기의 종료 코드가 아니라 명령이 답하는가
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        #   「창을 새로 열고 다시」만 말하면 사람은 같은 자리를 돈다(실사용자 1차 제보). 사실 3개를 같이 적는다 —
        #   파일이 있는가 · 사용자 PATH 에 들어갔는가 · 설치기 종료 코드. 이 세 값이 다음 판정을 가른다.
        $exe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
        $bin = (Join-Path $env:USERPROFILE '.local\bin').TrimEnd('\')
        $inUser = '아니오'
        $u = [Environment]::GetEnvironmentVariable('Path','User')
        if ($u) { foreach ($p in ($u -split ';')) { if ($p -and ([Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $bin)) { $inUser = '예'; break } } }
        $hasExe = if (Test-Path $exe) { '예' } else { '아니오' }
        Say '[2/10] 설치기는 끝났는데 claude 명령이 아직 안 잡힙니다.'
        Write-JCode 'J-PATH-01' '깔렸는데 이 창에서 명령을 찾지 못합니다'
        Set-NextStepRerun 'PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        Say "     파일 있음: $hasExe ($(Redact $exe)) · 사용자 PATH 등록: $inUser · 설치기 종료 코드: $rcShown"
        Say '     이 화면을 사진으로 남겨 주십시오. PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다.'
        $script:ShowRerun = $true
        return 4
    }
    if (-not (Test-ClaudeAuthCmd)) {
        Say '[2/10] 설치는 끝났는데 아직 낡은 판본이 잡힙니다.'
        Write-JCode 'J-VER-01' '낡은 판본이 먼저 잡혀 로그인 명령을 모릅니다'
        Set-NextStepRerun 'PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 판올림부터 이어서 갑니다.'
        return 4
    }
    $script:ClaudeOk = $true
    Say "[2/10] 완료: $((& claude --version 2>$null | Select-Object -First 1)) ($(Redact (Get-Command claude).Source))"
    return 0
}

# ── 하는 일 3 — 로그인 유도 + 완료 감지 ───────────────────────────
function Step-Login {
    # 🔴[1/10] 의 로그인 판정은 **클로드가 없던 시점**의 것이다 — 그 자리에서는 물어볼 상대가 없어
    #   unknown 으로 적고 지나간다. 그런데 [2/10] 에서 방금 클로드를 깔았다.
    #   ⇒ 브라우저를 열기 전에 **한 번 다시 본다.**
    #   왜 이 줄이 생겼나(2026-09-08 운영자 실기): 「지우고 다시 깔기」에서 지우개는 로그인을 남겼는데
    #   (화면에 「남김: 로그인」), 판정만 옛것이라 [3/10] 이 로그인 화면을 다시 열었다.
    #   ★첫 설치에서는 이 줄이 아무 일도 하지 않는다. 어긋나는 것은 지우고 다시 까는 길 하나뿐이다.
    #   ⚠능력 확인을 먼저 통과할 때만 묻는다 — 낡은 판본에서 auth status 는 질문으로 나간다.
    if ((-not $script:LoggedIn) -and (Get-Command claude -ErrorAction SilentlyContinue) -and (Test-ClaudeAuthCmd)) {
        $reauth = (& claude auth status 2>$null) -join "`n"
        if ($reauth -match '"loggedIn"\s*:\s*true') { $script:LoggedIn = $true }
    }
    if ($script:LoggedIn) { Say '[3/10] 이미 로그인돼 있습니다 — 건너뜁니다 (멱등).'; return 0 }
    if ($Mode -eq 'dry')  { Say "[3/10] (dry-run) 폴링하지 않았습니다. 간격 $LoginPollInterval 초 · 상한 $LoginPollTimeout 초 · 승인 대기 상한 $LoginWaitTimeout 초($LoginSayInterval 초마다 안내)."; return 0 }

    if (-not (Test-ClaudeAuthCmd)) {
        Say '[3/10] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다.'
        Say '     아래 「다시 하시는 법」대로 다시 실행하시면 판올림부터 이어서 갑니다.'
        $script:ShowRerun = $true
        return 6
    }
    Human '벤더' '로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)'
    Say '[3/10] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오.'
    Say "     승인 화면이 뜨면 「코드」를 복사해 이 창에 붙여넣고 Enter 를 눌러 주십시오."
    Say "     기다리는 동안 $LoginSayInterval 초마다 한 줄씩 알려 드리고, $([int]($LoginWaitTimeout / 60))분이 지나면 이 기다림을 끝냅니다."
    # ⛔승인 프로세스는 **이 창을 그대로 쓴다**(-NoNewWindow) — 사람이 코드를 붙여넣어야 하므로
    #   입력을 뺏으면 안 된다. 우리는 기다리기만 하고 **입력을 읽지 않는다**.
    # ★상한에 닿으면 그 프로세스를 끝낸다 = 사람이 Ctrl-C 를 누른 것과 같은 결과 ⇒ 아래 폴링과
    #   J-LOGIN-01 회복 경로로 그대로 흘러간다(맥과 같은 모양 · 새 길을 내지 않는다).
    # 🔴**앞에서 `Start-Sleep` 로 도는 고리를 두지 않는다**(검토 지적 채택 2026-09-11).
    #   그 고리는 이 창의 입력을 자식과 **함께 쥐고** 있어 붙여넣은 코드가 샐 수 있다.
    #   ⇒ 기다림을 `WaitForExit(ms)` 로 바꾼다 — 이것은 **커널 대기**라 콘솔을 건드리지 않는다.
    #     자식이 이 창의 입력을 **온전히** 갖는다(경합 0).
    #   ⚠검토 의견은 「별 스레드/타이머(Register-ObjectEvent)」를 제시했다. 같은 성질을 더 적은 장치로
    #     얻을 수 있어 이 모양을 골랐다 — 타이머는 **다른 runspace** 로 상태를 넘겨야 하고 여기서
    #     실기로 재 볼 길이 없다(윈 러너는 과금 정지). **검토 의견과 다른 선택이므로 그대로 적어 둔다.**
    $loginProc = $null
    try { $loginProc = Start-Process -FilePath 'claude' -ArgumentList 'auth','login' -NoNewWindow -PassThru -ErrorAction Stop } catch { $loginProc = $null }
    if ($null -eq $loginProc) {
        # 🔴폴백에서 **파이프를 쓰지 않는다**(검토 지적 채택 2026-09-11). `| Out-Host` 는 stdout 을 파이프로 바꿔
        #   벤더 도구의 「대화 중인가」 판정을 깨뜨리고, 그러면 **코드 입력 칸 자체가 안 뜬다.**
        #   기다림 안내는 못 하더라도 **길은 막지 않는다** — 안내가 없는 것보다 못 까는 것이 나쁘다.
        & claude auth login
    } else {
        $w = 0
        # WaitForExit 는 ms 를 받고, 끝났으면 $true 를 준다. 콘솔을 읽지 않는다.
        while (-not $loginProc.WaitForExit(5000)) {
            $w += 5
            if ($w -ge $LoginWaitTimeout) {
                [Console]::Error.WriteLine("     $([int]($LoginWaitTimeout / 60))분 동안 승인이 오지 않아 이 기다림을 끝냅니다.")
                # 🔴바로 `Kill()` 하지 않는다(검토 지적 채택 2026-09-11) — 잠금 파일·임시 파일을 정리할 틈을 준다.
                #   맥이 INT → (안 되면) TERM 인 것과 **같은 순서**다: 부드럽게 한 번, 그래도 안 되면 세게.
                try { [void]$loginProc.CloseMainWindow() } catch { }
                if (-not $loginProc.WaitForExit(3000)) {
                    try { $loginProc.Kill() } catch { }
                    [Console]::Error.WriteLine('     (승인 창이 바로 닫히지 않아 한 번 더 끝냈습니다)')
                }
                break
            }
            if (($w % $LoginSayInterval) -eq 0) {
                [Console]::Error.WriteLine('     브라우저의 승인 화면에서 「코드」를 복사해 이 창에 붙여넣고 Enter 를 눌러 주십시오.')
                [Console]::Error.WriteLine("     (기다린 지 $([int]($w / 60))분 · 창을 닫거나 Ctrl-C 를 누르시면 다시 하는 법을 안내합니다)")
            }
        }
    }
    Say "     승인이 끝났는지 확인합니다. 최대 $([int]($LoginPollTimeout / 60))분까지 기다립니다."
    $waited = 0
    while ($waited -lt $LoginPollTimeout) {
        $auth = (& claude auth status 2>$null) -join "`n"
        if ($auth -match '"loggedIn"\s*:\s*true') {
            $script:LoggedIn = $true
            Say '[3/10] 로그인 확인했습니다.'
            return 0
        }
        Start-Sleep -Seconds $LoginPollInterval
        $waited += $LoginPollInterval
    }
    Say "[3/10] $([int]($LoginPollTimeout / 60))분 동안 로그인이 확인되지 않았습니다."
    Write-JCode 'J-LOGIN-01' '로그인 승인이 시간 안에 끝나지 않았습니다'
    Set-NextStepRerun '브라우저에서 승인을 누르신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    return 5
}

# ── 하는 일 4 — 자비스 기동 (지침 파일 + 첫 지시 주입) ───────
function Write-Directive {
    $d = @"
# 자비스 설치 도우미 지침

너는 이 컴퓨터의 설치를 대신 해 주는 자비스다. 상대는 처음 설치하는 사람이다.

## 첫 응답 규칙 (불변)
첫 응답의 **첫 줄은 반드시 아래 문자열 하나**로 시작한다. 이 줄이 곧 기동 성공의 판정 신호다.

    $ReportHead

**보고서에 「막힌 단계」가 적혀 있으면 표보다 먼저 그것을 말해라.** 세 가지를 이 순서로:
1. 어디까지 됐는가(끝난 단계) 2. 무엇이 막혔는가 3. **사람이 할 일이 있으면 그것 하나만** — 없으면 「없습니다, 제가 이어서 합니다」.

그 다음 줄부터 아래 파일을 읽어 표로 옮겨 적는다.
★보고서에 **「지나온 단계」** 절이 있으면 **표보다 먼저** 그것을 한 줄 요약으로 보여라 —
사람은 방금 화면이 지워지는 것을 봤고, **무슨 일이 있었는지부터 알고 싶어 한다.**

    $(Redact $ReportFile)
## 하지 않는 것

1. 우리 키·계정을 쓰지 않는다.
2. 원격 제어를 하지 않는다.
3. **관리자 권한 상승을 스스로 실행하지 않는다.** 권한 대화상자·SmartScreen 은 사람이 누른다.
4. 사용자 파일을 열지 않는다.
5. 되돌릴 길이 없는 행동을 스스로 하지 않는다.
6. 이 컴퓨터에 우리 조직의 운영 자산을 놓지 않는다.

## 무개입 기본 (이 지침에서 가장 중요한 규칙)

★**사람이 누르는 것은 「운영체제나 회사가 강제해서 우리가 대신 못 누르는 것」뿐이다.** 그 밖의 모든 것은 네가 한다.
지금 그 목록은 **로그인 승인 클릭**과 **벤더가 새로 추가한 첫 실행 질문**이다(관리자 비밀번호는 다음 단계에서 나온다).
🔴**후자는 우리가 미리 끌 수 없다** — 끄는 열쇠(설정 키)가 있는 질문만 미리 끌 수 있고, 벤더는 판본마다 새 질문을
추가한다(예: 화면 표시 방식을 묻는 새 질문에는 끄는 설정이 아직 없다). ⇒ 그런 질문이 뜨면 **막힌 것이 아니라
「아직 이름이 없는 질문」**이다. 사람에게 한 줄로 알리고, 무엇을 눌렀는지 보고 표의 「사람 손(실제)」 칸에 적어라.
⛔**그 목록에 없는 이유로 사람을 멈춰 세우지 마라. 묻는 것도 일이다.**

1. **읽기 전용 확인은 묻지 말고 그냥 해라.** 끝난 뒤에 알아낸 것을 말해라. ⛔「진행할까요?」를 확인 작업 앞에 붙이지 마라.
2. **갈림길에서 고르라고 하지 마라.** 아래 기본 정책대로 실행하고 무엇을 왜 했는지 사후에 보고해라.
3. **바꾸기 전에 묻는 것은 「되돌릴 길이 없는 변경」뿐이다.** 되돌릴 수 있으면 하고, 되돌리는 법을 함께 적어라.
4. **「어느 칸부터 볼까요」류 질문 금지.** 순서는 보고 표의 순서 그대로다.

## 기본 정책 (갈림길에서 묻지 말고 이대로)

| 상태 | 기본 행동 |
|---|---|
| 어떤 칸이 blocked 인데 **계정 성격 때문**이다(표준 계정) | **고장이 아니라고 설명만** 하고 넘어간다 |
| cys 상태가 **「앱만」**(프로그램은 있는데 이 계정에 자리를 안 잡음) | 지금 범위에서는 **그 사실을 보고만** 한다(대행은 다음 단계) |
| unknown 인 칸 | 「됐다」로 세지 않는다. **왜 모르는지**를 한 줄로 말한다 |
| 사람이 진짜로 필요한 자리 | **그때만** 부른다. 무엇을·왜·어디를·되면·안 되면 다섯을 함께 말한다 |
## 첫 응답 말미에 반드시 붙이는 한 줄

첫 응답 **맨 끝**에 이 뜻의 한 줄을 붙여라:

    입력창에 흐린 회색 글씨가 보이면 그건 제가 미리 적어 둔 **제안**입니다 — 쓰셔도 되고 그냥 무시하고 다른 걸 치셔도 됩니다.

🔴**왜**: 2차 실기에서 입력창에 회색으로 「cys 다시 설치해줘」가 떠 있었고, **사람이 「내가 안 쳤는데?」로 읽었다.**
설치를 처음 하는 사람에게 **「내가 안 한 일이 일어났다」는 인상은 신뢰를 깎는다.** 한 줄이면 사라진다.
## 지금 할 일의 범위

- **cys 설치·계정 준비 대행은 아직 네 일이 아니다**(다음 단계).
- 네가 지금 하는 일은 **환경 보고를 사람 말로 옮겨 주고, 막힌 칸의 원인을 갈라 주는 것**이다.
- ★**blocked 가 곧 고장은 아니다.** ⑴표준 계정이라 그런 것인지 ⑵이 계정에 아직 자리를 안 잡아서 그런 것인지를 **먼저 갈라서** 말해라.
"@
    Write-TextNoBom $DirectiveFile $d
    Say "지침 파일을 놓았습니다: $(Redact $DirectiveFile)"
}

# 클로드 첫 실행 질문 사전 설정 (맥판 짝 · 맥에서 테마·폴더 신뢰가 실제로 떴다)
#   PowerShell 내장 ConvertFrom-Json/ConvertTo-Json 을 쓴다 — 추가 설치 0.
# 자비스가 띄우는 자식 노드(다른 역할)는 **개인 설정이 아니라 격리 설정**으로 뜬다.
# 그래서 사전 설정을 개인 자리에만 걸면 자식들이 첫 실행 질문 앞에서 멈춰 선다(실측 2026-09-05).
# 자리는 짐작하지 않는다 — 실제로 있는 것만 쓴다(자리를 만드는 쪽은 cys 이고, 없으면 그 기계엔 없는 것이다).
function Get-ProfileTargets {
    $t = @()
    $t += [pscustomobject]@{
        Name     = '개인'
        Config   = (Join-Path $env:USERPROFILE '.claude.json')
        Settings = (Join-Path (Join-Path $env:USERPROFILE '.claude') 'settings.json')
    }
    $iso = Join-Path (Join-Path $env:USERPROFILE '.cys') 'claude'
    if (Test-Path $iso) {
        $t += [pscustomobject]@{
            Name     = '자비스 전용'
            Config   = (Join-Path $iso '.claude.json')
            Settings = (Join-Path $iso 'settings.json')
        }
    }
    return $t
}

function Set-ClaudePrefs {
    param([string]$cfg = (Join-Path $env:USERPROFILE '.claude.json'))
    try {
        #   이 파일은 참가자가 이미 쓰던 설정일 수 있다. 우리가 왕복(읽기→JSON→쓰기)시키는 순간
        #   우리가 안 건드린 칸까지 이 코드의 인코딩·직렬화 규칙을 통과한다. ⇒ 되돌릴 길을 먼저 만든다.
        #   아직 안 갈렸다**(읽기는 그때도 `-Encoding UTF8` 이었고, 5.1 의 ConvertTo-Json 은 비ASCII 를
        #   `\uXXXX` 로 이스케이프한다 ⇒ 소스만으로는 그 경로가 설명되지 않는다). 원인이 안 갈렸어도 사본은 남긴다.
        if ((Test-Path $cfg) -and -not (Test-Path "$cfg.bak-jarvis")) {
            Copy-Item $cfg "$cfg.bak-jarvis" -Force -ErrorAction SilentlyContinue
            Write-Log "backup: $(Redact $cfg) -> $(Redact $cfg).bak-jarvis (되돌리기 = 이 파일을 되돌려 복사)"
        }
        if (Test-Path $cfg) { $o = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json }
        else { $o = [pscustomobject]@{} }
        #   파이프에 $null 을 흘리면 파이프라인 객체가 0개라 cmdlet 이 아예 안 돈다 — 예외가 아니라 「조용히 아무 일도 안 함」이다.
        #   그대로 두면 `$o` 가 $null 인 채 `$null | ConvertTo-Json` 이 빈 값을 내고 남의 설정을 빈 파일로 덮는다.
        #   (지금은 되읽기 확인이 그걸 잡아 원복하지만, 원복은 마지막 그물이지 첫 방어가 아니다.)
        if ($null -eq $o) { $o = [pscustomobject]@{} }
        $o | Add-Member -NotePropertyName hasCompletedOnboarding -NotePropertyValue $true -Force
        # 큰 화면 권유 질문은 「본 횟수」가 적을 때만 뜬다(실측: 그 값이 3인 기계에서는 안 떴다).
        # 미리 크게 적어 두면 묻지 않는다 — 질문을 막는 것이 아니라 이미 본 것으로 두는 것이다.
        $o | Add-Member -NotePropertyName fullscreenUpsellSeenCount -NotePropertyValue 99 -Force
        if (-not $o.PSObject.Properties['projects']) {
            $o | Add-Member -NotePropertyName projects -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        #   우리가 쓴 키는 `C:\Users\oogis\install-jarvis`(백슬래시) 였다 ⇒ 한 폴더에 키가 두 개 생겼고
        #   클로드는 자기 형태만 봤다. BOM 이 없었어도 신뢰 프롬프트는 떴다 — 원인이 둘이었다.
        $trust = [pscustomobject]@{ hasTrustDialogAccepted = $true }
        # 🔴2026-09-10 실기에서 고친 것(4차 검토) — 앞 판은 **자비스 작업 폴더에만** 신뢰를 심었다. 그런데 동료
        #   좌석(cso·worker·리뷰어)은 팩 편성이 정하는 cwd 로 뜨고, 그 cwd 가 **사용자 폴더(홈)** 였다.
        #   ⇒ 좌석 4기가 「Quick safety check … Yes, I trust this folder」에서 전부 섰고,
        #   ★그 화면의 기본 선택이 「No, exit」라 Enter 만 누르면 **클로드가 종료돼 좌석이 PS 로 낙하**했다
        #   (같은 사고 2회). 한 좌석에서 「Yes」를 1회 누르니 그 뒤 스폰 전건이 무질문이었다
        #   = 프로필에 홈 신뢰가 기록되면 끝나는 문제였다.
        #   ⇒ 홈도 함께 심는다. 편성이 자식 cwd 를 고치는 것(팩 몫)과 **무관하게** 안전한 벨트다.
        #   ⚠되돌리기 = 이 파일의 projects 아래 그 두 키를 지우면 된다(사본도 .bak-jarvis 로 남긴다).
        # ⑴자비스 작업 폴더 — 우리가 만든 자리다. 없으면 만들고 있으면 우리 칸을 세운다.
        foreach ($k in @($JarvisHome, ($JarvisHome -replace '\\','/'))) {
            $ex = $o.projects.PSObject.Properties[$k]
            if ($null -eq $ex -or $null -eq $ex.Value) {
                $o.projects | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ hasTrustDialogAccepted = $true }) -Force
            } else {
                $ex.Value | Add-Member -NotePropertyName hasTrustDialogAccepted -NotePropertyValue $true -Force
            }
        }
        # ⑵사용자 홈 — **참가자의 자리다.** 여기서는 규칙이 다르다(1차 검토 REVISE ④ 확정 2026-09-10).
        # 🔴🔴**이미 값이 있으면 손대지 않는다.** 앞 판은 있든 없든 true 로 세웠다. 그러면
        #   ①원래 true 였던 분의 값을 「우리 것」과 구별할 수 없게 되고(제거기가 남의 값을 지운다)
        #   ②원래 **false**(신뢰하지 않겠다고 **명시적으로 고르신 것**)를 조용히 true 로 뒤집는다.
        #   ★②는 안전 설정을 우리가 몰래 되돌리는 것이다 — 편의를 위해 할 일이 아니다.
        #   ⇒ **없을 때만 넣는다.** 그러면 「우리가 넣었다」와 「원래 있었다」가 저절로 갈린다 —
        #     기록해야 할 것은 **우리가 넣은 키의 목록**뿐이고, 되돌리기는 그것만 지우면 끝난다.
        #   ⚠값이 false 라 좌석이 신뢰 질문을 만나면, 그때는 사람이 한 번 [Yes] 를 누르시면 된다.
        #     남의 선택을 뒤집는 것보다 손 한 번이 싸다.
        # 🔴🔴**소유 목록에는 「쓰고 나서」 적는다**(3차 검토 N4 확정 2026-09-10).
        #   앞 판은 파일에 **쓰기 전에** `$script:TrustSeeded` 에 넣었다. 그 뒤 쓰기·되읽기가 실패해
        #   사본으로 되돌리면, 파일에는 없는 키가 목록에는 남는다 ⇒ 기록이 사실과 어긋난다.
        #   ★기록은 **일어난 일**을 적는 것이지 하려던 일을 적는 것이 아니다.
        $pending = @()
        $homeDir = ([string]$env:USERPROFILE).TrimEnd('\')
        if ($homeDir) {
            foreach ($k in @($homeDir, ($homeDir -replace '\\','/'))) {
                $ex = $o.projects.PSObject.Properties[$k]
                if ($null -eq $ex -or $null -eq $ex.Value) {
                    $o.projects | Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{ hasTrustDialogAccepted = $true }) -Force
                    $pending += ,@($cfg, $k)
                } elseif ($null -eq $ex.Value.PSObject.Properties['hasTrustDialogAccepted']) {
                    $ex.Value | Add-Member -NotePropertyName hasTrustDialogAccepted -NotePropertyValue $true -Force
                    $pending += ,@($cfg, $k)
                } else {
                    Say '     (이 컴퓨터에는 홈 폴더 신뢰 설정이 이미 있어 그대로 두었습니다 — 우리가 바꾸지 않습니다.)'
                }
            }
        }
        Write-TextNoBom $cfg ($o | ConvertTo-Json -Depth 20)
        # 쓴 뒤에 되읽어서 확인한다 — 못 읽으면 사본으로 되돌린다(우리가 남의 설정을 깨고 끝내지 않는다).
        try {
            $back = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $back.hasCompletedOnboarding) { throw '되읽기 확인 실패' }
        } catch {
            if (Test-Path "$cfg.bak-jarvis") {
                Copy-Item "$cfg.bak-jarvis" $cfg -Force -ErrorAction SilentlyContinue
                Say '     (설정 파일을 원래대로 되돌렸습니다 — 첫 실행 질문이 뜰 수 있습니다.)'
                Write-Log 'rollback: .claude.json 되읽기 실패 -> 사본 복원'
            }
            return $false
        }
        # 쓰기와 되읽기가 모두 성공한 지금에야 「우리가 넣었다」가 사실이 된다.
        foreach ($e in $pending) { $script:TrustSeeded += ,$e }
        Say '     첫 실행 질문(테마·폴더 신뢰·큰 화면 권유)을 미리 넘겨 두었습니다.'
        Write-Log "seed: hasCompletedOnboarding=true · 작업 폴더 신뢰 2형($(Redact $JarvisHome)) · 홈 신뢰는 없을 때만($(Redact $homeDir)) · 우리가 넣은 홈 키 누계 $($script:TrustSeeded.Count) (되돌리기 = $(Redact $cfg).bak-jarvis 를 되돌려 복사)"
        return $true
    } catch {
        Say '     (사전 설정을 걸지 못했습니다. 클로드가 처음 몇 가지를 물을 수 있습니다.)'
        return $false
    }
}

#   그것을 끄는 열쇠는 `~/.claude/settings.json` 의 `skipDangerousModePermissionPrompt` 이고(맥 실물 = true),
#   되돌리기 = 이 두 줄을 지우면 된다(비가역 아님).
function Set-ClaudeSettings {
    param([string]$sf = (Join-Path (Join-Path $env:USERPROFILE '.claude') 'settings.json'))
    $dir = Split-Path -Parent $sf
    try {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        if (Test-Path $sf) { $o = Get-Content $sf -Raw -Encoding UTF8 | ConvertFrom-Json }
        else { $o = [pscustomobject]@{} }
        $o | Add-Member -NotePropertyName skipDangerousModePermissionPrompt -NotePropertyValue $true -Force
        $o | Add-Member -NotePropertyName remoteControlAtStartup -NotePropertyValue $false -Force
        # 글자 모양 질문(「Choose the text style」)은 이 파일의 열쇠로 넘긴다 —
        # 같은 질문의 열쇠가 다른 파일(.claude.json)에 있는 줄 알았던 것이 자식 노드가 멈춘 까닭이다.
        if (-not $o.PSObject.Properties['theme']) {
            $o | Add-Member -NotePropertyName theme -NotePropertyValue 'dark' -Force
        }
        Write-TextNoBom $sf ($o | ConvertTo-Json -Depth 20)
        Write-Log "seed: settings.json skipDangerousModePermissionPrompt=true · remoteControlAtStartup=false (되돌리기 = $(Redact $sf) 의 두 줄 삭제)"
        return $true
    } catch {
        Say '     (설정 파일을 손대지 못했습니다. 클로드가 권한 확인을 한 번 물을 수 있습니다.)'
        return $false
    }
}

# 이 함수는 두 번 불린다. 자비스 전용 자리는 [8] 에서 자리를 잡은 **뒤에야 생기기 때문**이다.
# 처음 부를 때는 개인 자리만 있고, 두 번째에 전용 자리가 함께 잡힌다. 같은 값을 다시 써도 해가 없다.
# 동료 노드는 자비스 전용 자리로 뜨는데, 로그인 정보는 **개인 자리**에 저장된다(윈도우).
# 그래서 그 자리에는 로그인이 없어 동료들이 전부 「로그인하십시오」에서 선다(2026-09-05 실측).
# 쓰는 분 자신의 로그인 정보를, 같은 컴퓨터의 다른 자리로 **옮겨 놓기만** 한다(다른 사람 것도, 다른 기계도 아니다).
function Copy-LoginToIsolated {
    $src = Join-Path (Join-Path $env:USERPROFILE '.claude') '.credentials.json'
    $iso = Join-Path (Join-Path $env:USERPROFILE '.cys') 'claude'
    if (-not (Test-Path $iso)) { return $false }
    if (-not (Test-Path $src)) {
        # 맥은 로그인 정보를 파일이 아니라 시스템 보관함에 두므로 여기 올 일이 없다.
        Write-Log 'login copy: source credentials file not found (nothing to carry over)'
        return $false
    }
    $dst = Join-Path $iso '.credentials.json'
    try {
        Copy-Item $src $dst -Force -ErrorAction Stop
        Say '     동료들이 쓸 로그인 정보를 이어 두었습니다.'
        Write-Log "login copy: $(Redact $src) -> $(Redact $dst) (되돌리기 = 옮긴 파일 삭제)"
        return $true
    } catch {
        Say '     (로그인 정보를 이어 두지 못했습니다. 동료들이 로그인을 물을 수 있습니다.)'
        Write-Log "login copy failed: $($_.Exception.Message)"
        return $false
    }
}

# 우리가 넣은 홈 신뢰 칸 하나를 도로 뺀다 — 기록에 실패했을 때 쓴다.
#   ⚠제거기의 되돌리기와 같은 범위다: `hasTrustDialogAccepted` 한 칸만, 그 칸만 있던 자리면 칸째.
# 🔴🔴**「도로 뺐다」·「아직 있다」·「확인 못 했다」를 가른다**(5차 검토 STILL OPEN N4 확정 2026-09-11 · 맥판과 같다).
#   앞 판은 되읽기 실패도 「안 빠졌다($false)」로 뭉갰다 — 그러면 화면이 「도로 빼지 못했습니다」라고
#   **확인하지도 않은 것을 단정**한다. 되돌아간 것을 못 본 것과, 안 되돌아간 것을 본 것은 다른 말이다.
#   ⇒ 'verified'(다시 읽었는데 없다) · 'kept'(다시 읽었는데 있다) · 'unknown'(다시 읽지 못했다).
function Get-TrustRollbackWords {  # 단계 한 줄이 안에서 일어난 일을 그대로 말하게 한다
    switch ($script:TrustRollbackState) {
        'verified' { return '그 설정은 도로 뺐고,' }
        'kept'     { return '그 설정을 도로 빼지 못해 기록을 남겨 두었고(지울 때 되돌립니다),' }
        'unknown'  { return '그 설정이 도로 빠졌는지 확인하지 못해 기록을 남겨 두었고(지울 때 되돌립니다),' }
        default    { return '그 설정이 어떻게 됐는지 확인하지 못했고,' }
    }
}
function Undo-TrustSeed($cfg, $key) {
    try {
        if (-not (Test-Path $cfg)) { return 'verified' }   # 파일 자체가 없으면 그 칸도 없다
        $o = Get-Content $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
        $prj = $o.PSObject.Properties['projects']
        if ($null -eq $prj -or $null -eq $prj.Value) { return 'verified' }
        $ex = $prj.Value.PSObject.Properties[$key]
        if ($null -eq $ex -or $null -eq $ex.Value) { return 'verified' }
        if ($null -ne $ex.Value.PSObject.Properties['hasTrustDialogAccepted']) {
            $ex.Value.PSObject.Properties.Remove('hasTrustDialogAccepted')
        }
        if (@($ex.Value.PSObject.Properties).Count -eq 0) { $prj.Value.PSObject.Properties.Remove($key) }
        Write-TextNoBom $cfg ($o | ConvertTo-Json -Depth 20)
        # 🔴🔴**되돌렸다고 말하기 전에 되돌아갔는지 본다**(4차 검토 BLOCK N4 확정 2026-09-10 · 맥판과 같다).
        #   앞 판은 쓰기만 하고 `$true` 도 안 돌려줬다 — 부르는 쪽은 결과와 무관하게 추적 목록을 비우고
        #   「도로 뺐습니다」라고 말했다. 디스크가 꽉 차면 기록 쓰기와 되쓰기가 **함께** 실패한다 ⇒
        #   키는 남고 기록은 없는데 화면은 되돌렸다고 말한다(다음 실행이 그 키를 남의 것으로 읽는다).
        #   ★「했다」는 **다시 읽어 없을 때만** 참이다.
        try {
            $back = Get-Content $cfg -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        } catch {
            # ★다시 읽지 못했다 — 없다고도, 있다고도 말하지 않는다.
            Write-Log ("trust seed rollback UNKNOWN (되읽지 못했다): " + (Redact $cfg) + " + " + (Redact $key))
            return 'unknown'
        }
        $bp = $back.PSObject.Properties['projects']
        if ($null -ne $bp -and $null -ne $bp.Value) {
            $be = $bp.Value.PSObject.Properties[$key]
            if ($null -ne $be -and $null -ne $be.Value -and $null -ne $be.Value.PSObject.Properties['hasTrustDialogAccepted']) {
                Write-Log ("trust seed rollback NOT verified (키가 아직 있다): " + (Redact $cfg) + " + " + (Redact $key))
                return 'kept'
            }
        }
        Write-Log ("trust seed rollback: " + (Redact $cfg) + " + " + (Redact $key))
        return 'verified'
    } catch {
        Write-Log ("trust seed rollback FAILED: " + $_.Exception.Message)
        return 'unknown'
    }
}
function Set-AllProfiles {
    $seeded = @()
    foreach ($t in (Get-ProfileTargets)) {
        if (-not (Set-ClaudePrefs $t.Config))      { Human '벤더' "클로드 첫 실행 질문($($t.Name) 자리에 사전 설정을 못 걸었다)" }
        if (-not (Set-ClaudeSettings $t.Settings)) { Human '벤더' "bypass 권한 확인($($t.Name) 자리의 설정 파일을 못 썼다)" }
        $seeded += $t.Name
    }
    Write-Log ("seed profiles: " + ($seeded -join ', '))
    # ★우리가 넣은 홈 키를 적어 둔다 — 제거기는 **이 파일에 적힌 것만** 되돌린다.
    #   ⚠파일이 없으면 제거기는 홈 신뢰 칸에 손대지 않는다(모르는 것을 지우지 않는다).
    # 🔴🔴**기록에 실패하면 설정 변경을 되돌린다**(3차 검토 N4 확정 2026-09-10).
    #   앞 판은 기록 실패를 `Write-Log` 한 줄로 남기고 **성공을 돌려줬다.** 그런데 신뢰 칸은 이미
    #   들어가 있었다 ⇒ 제거기는 그것을 「참가자의 것」으로 읽어 **영영 남긴다.**
    #   ★기록과 설정은 **함께 서거나 함께 물러난다** — 반쪽만 남으면 그것이 곧 되돌릴 수 없는 자국이다.
    $script:TrustJournalFailed = $false
    try {
        $lines = @()
        foreach ($e in $script:TrustSeeded) { $lines += ($e[0] + "`t" + $e[1]) }
        if ($lines.Count -gt 0) {
            Write-TextNoBom $TrustSeedFile (($lines -join "`r`n") + "`r`n")
            # 쓴 것을 되읽어 확인한다 — 「썼다」는 다시 읽어 있을 때만 참이다.
            $back = Get-Content $TrustSeedFile -Raw -Encoding UTF8 -ErrorAction Stop
            if (($null -eq $back) -or ($back.Split("`n").Where({ $_.Trim() }).Count -lt $lines.Count)) { throw '되읽기 확인 실패' }
            Write-Log ("trust seed record: " + $lines.Count + " 줄 -> " + (Redact $TrustSeedFile))
        }
    } catch {
        Write-Log ("trust seed record failed -> rollback: " + $_.Exception.Message)
        $script:TrustJournalFailed = $true
        # 되돌아가지 **않은** 것만 남긴다 — 추적 목록을 무조건 비우면 「키는 남고 기록은 없는」 상태가 된다.
        $stuck = @()
        $script:TrustRollbackState = 'verified'
        foreach ($e in $script:TrustSeeded) {
            $st = Undo-TrustSeed $e[0] $e[1]
            if ($st -ne 'verified') {
                $stuck += ,$e
                # 나쁜 쪽이 남는다 — 뒤 파일이 앞 파일의 실패를 덮지 않게.
                if ($script:TrustRollbackState -ne 'kept') { $script:TrustRollbackState = $st }
            }
        }
        $script:TrustSeeded = @($stuck)
        if ($stuck.Count -eq 0) {
            Say '     (홈 폴더 신뢰 기록을 남기지 못해 그 설정을 도로 뺐습니다 — 좌석이 폴더 신뢰를 한 번 물을 수 있습니다.)'
        } else {
            # 되돌리기도 실패했다. **키는 남고 기록은 없는** 상태만은 만들지 않는다 —
            #   기록을 한 번 더 시도해 둘을 맞춘다(그러면 지울 때 되돌릴 수 있다).
            $lines2 = @()
            foreach ($e in $stuck) { $lines2 += ($e[0] + "`t" + $e[1]) }
            $ok2 = $false
            try {
                Write-TextNoBom $TrustSeedFile (($lines2 -join "`r`n") + "`r`n")
                $chk = Get-Content $TrustSeedFile -Raw -Encoding UTF8 -ErrorAction Stop
                if ($null -ne $chk -and $chk.Trim()) { $ok2 = $true }
            } catch { $ok2 = $false }
            if ($ok2) {
                if ($script:TrustRollbackState -eq 'kept') {
                    Say '     (설정을 도로 빼지 못해 기록을 남겨 두었습니다 — 지울 때 이 칸도 함께 되돌립니다.)'
                } else {
                    Say '     (그 설정이 도로 빠졌는지 확인하지 못해 기록을 남겨 두었습니다 — 지울 때 이 칸도 함께 되돌립니다.)'
                }
                Write-Log ('trust seed rollback ' + $script:TrustRollbackState + ' -> journal re-recorded: ' + $stuck.Count + ' 줄')
            } else {
                if ($script:TrustRollbackState -eq 'kept') {
                    Say '     홈 폴더 신뢰 설정을 넣었는데 그 기록도, 되돌리기도 하지 못했습니다.'
                } else {
                    Say '     홈 폴더 신뢰 설정을 넣었는데 그 기록도 남기지 못했고, 도로 빠졌는지도 확인하지 못했습니다.'
                }
                Say '        지울 때 이 칸은 자동으로 되돌아가지 않습니다. 손으로 빼시려면:'
                foreach ($e in $stuck) {
                    Say ('        파일 ' + (Redact $e[0]) + ' 의 projects → ' + (Redact $e[1]) + ' → hasTrustDialogAccepted 줄')
                }
                Write-Log ('trust seed rollback ' + $script:TrustRollbackState + ' and journal FAILED: ' + $stuck.Count + ' 줄')
            }
        }
    }
    return $seeded
}

function Step-Prepare {
    Write-Directive
    if ($Mode -eq 'dry') {
        Say '[4/10] (dry-run) 사전 설정(.claude.json · settings.json)을 쓰지 않았습니다(바깥 변경 0).'
        return 0
    }
    Set-AllProfiles | Out-Null
    # ⚠기록 실패만 단계 실패로 올린다 — 그때는 설정을 도로 뺐고, 그것을 삼키면 화면이 거짓을 말한다.
    #   (사전 설정 자체를 못 건 것은 예전처럼 「사람 손 한 번」이면 끝나므로 계속 간다.)
    if ($script:TrustJournalFailed) {
        Say ('[4/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — ' + (Get-TrustRollbackWords) + ' 여기서 멈춥니다.')
        Say '     기록 없이 그 칸만 넣으면 지울 때 되돌릴 길이 없습니다(남의 컴퓨터에 자국이 남습니다).'
        $script:JCode = 'J-PERM-01'
        $script:NextStep = '저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        return 4
    }
    Say '[4/10] 자비스가 쓸 것을 갖춰 두었습니다.'
    return 0
}


# ── 하는 일 5 — cys 설치 파일 받기 ────────────────────────────────
# 완료 판정 = 파일이 있고 크기가 정확히 맞는가. 크기가 다르면 받다 끊긴 것이다.
function Step-DownloadCys {
    New-Item -ItemType Directory -Force -Path $DlDir | Out-Null
    $dst = Join-Path $DlDir $CysWinFile
    if ((Test-Path $dst) -and ((Get-Item $dst).Length -eq $CysWinBytes)) {
        # 크기만 보고 건너뛰면 같은 크기의 다른 파일이 재실행 경로로 들어온다(검토 지적 2026-09-09) — 지문까지 본다.
        $have = Get-CysFileSha256 $dst
        if ($have -eq $CysWinSha256) { Say '[5/10] 설치 파일이 이미 있습니다 (지문 확인) — 건너뜁니다.'; return 0 }
        if ($null -eq $have) { Say '[5/10] 남아 있던 설치 파일의 지문을 재지 못했습니다 — 확인 없이 쓰지 않고 다시 받습니다.' }
        else { Say '[5/10] 남아 있던 설치 파일의 지문이 다릅니다 — 버리고 다시 받습니다.' }
        # dry-run 은 아무것도 지우지 않는다(2차 검토 지적) — 지울 것이 있다는 사실만 말한다.
        if ($Mode -eq 'dry') { Say "[5/10] (dry-run) 위 파일을 지우고 다시 받을 것입니다. 받을 곳 = $CysDownloadUrl"; return 0 }
        Remove-Item $dst -Force -ErrorAction SilentlyContinue
    }
    if ($Mode -eq 'dry') { Say "[5/10] (dry-run) 받지 않았습니다. 받을 곳 = $CysDownloadUrl"; return 0 }
    # 132MB 를 받기 전에 자리가 있는지 본다. 받다 중간에 꽉 차면 「받다 끊긴 파일」로만 보여
    # 사람은 망 문제로 오해한다 — 미리 갈라 말한다.
    try {
        $drive = (Get-Item $DlDir -ErrorAction Stop).PSDrive
        if ($drive -and $drive.Free -and ($drive.Free / 1MB) -lt 3072) {
            Say ("[5/10] 저장 공간이 부족합니다 (남은 자리 약 " + [int]($drive.Free / 1MB) + "MB · 3GB 이상을 권합니다).")
            Write-JCode 'J-DISK-01' '저장 공간이 부족합니다'
            Set-NextStepRerun '공간을 3GB 이상 비우신 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
            return 5
        }
    } catch { }
    for ($try = 1; $try -le 2; $try++) {
        if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
        Say "[5/10] cys 설치 파일을 받습니다 (약 132MB · 잠시 걸립니다)."
        $pref = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $CysDownloadUrl -OutFile $dst -UseBasicParsing -TimeoutSec 900 -ErrorAction Stop
        } catch {
            Say "[5/10] 받지 못했습니다: $($_.Exception.Message)"
            $ProgressPreference = $pref
            # 먼저 까닭을 가른다. 받을 자리가 「그런 파일 없다」고 답했으면 기다릴 일이 아니다 —
            #   앞 판은 이것도 연결 문제로 읽어 없는 파일을 30분 기다린 뒤 「분류 못 함」으로 끝났다.
            #   404·410 = 그 판본이 자리에 없다 · 407 = 가운데 프록시가 로그인을 요구한다(기다려도 안 풀린다).
            #   그 밖의 상태코드(5xx 등)와 답이 아예 없는 경우(0)는 여전히 아래에서 기다린다 — 맥판과 같은 갈래다.
            $http = Get-WebErrorStatus $_
            if ($http -eq 404 -or $http -eq 410) {
                if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
                Say "[5/10] 받을 자리에 그 판본이 없습니다 (응답 $http)."
                Say "     받으려던 곳 = $CysDownloadUrl"
                Write-JCode 'J-DL-05' '받을 자리에 그 판본이 없습니다'
                $script:NextStep = '이 진단 코드와 함께 알려 주십시오 — 받는 길을 고쳐 드리겠습니다. 기다려도 생기는 파일이 아니라 다시 실행하셔도 같습니다.'
                return 5
            }
            if ($http -eq 407) {
                if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
                Say "[5/10] 이 망의 프록시가 로그인을 요구해서 설치 파일을 받지 못했습니다 (응답 407)."
                Say "     받으려던 곳 = $CysDownloadUrl"
                Write-JCode 'J-NET-01' '프록시가 로그인을 요구해 바깥으로 나가지 못했습니다'
                Set-NextStepRerun '회사·학교 망이면 망 담당자에게 프록시 설정을 문의해 주십시오. 프록시를 거치지 않는 망에 연결하신 뒤 아래 「다시 하시는 법」대로 다시 실행하셔도 됩니다.'
                return 5
            }
            # 두 번 해 보고 포기하지 않는다. 연결이 돌아오면 이어간다(같은 자리·같은 문장).
            # ⚠다시 해 보는 명령에도 상한이 있어야 한다 — Invoke-WebRequest 의 기본 상한은 **무한**이라
            #   응답 없는 연결에 매달리면 30분 상한이 있는 바깥 고리로 돌아오지 못한다
            #   (검토 지적 채택 2026-09-09).
            $again = Wait-ForConnection '[5/10]' {
                try {
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $CysDownloadUrl -OutFile $dst -UseBasicParsing -TimeoutSec 900 -ErrorAction Stop
                    return $true
                } catch { return $false }
            }
            if (-not $again) {
                Set-NextStepRerun '연결이 된 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 받은 데까지는 건너뛰고 이어서 갑니다.'
                return 5
            }
            # 회복 뒤 받은 파일은 아래 검증으로 **그대로 넘긴다** — 여기서 continue 하면 다음 회차가 그 파일을 지운다(검토 지적 2026-09-09).
        } finally {
            # 실패해서 빠져나가도 이 창의 설정을 원래대로 돌려놓는다.
            $ProgressPreference = $pref
        }
        # 다 받았는데 파일이 없다 = 백신이 그 자리에서 격리했을 때 나는 모양이다.
        # 이것을 크기 불일치로 적으면 망 문제로 오해된다.
        if (-not (Test-Path $dst)) {
            Say '[5/10] 받은 파일이 사라졌습니다 — 백신이 격리했을 수 있습니다.'
            Write-JCode 'J-AV-02' '받은 설치 파일이 사라졌습니다'
            Say-AntivirusHold (Redact $dst)
            Say '     백신 알림이 떴다면 그 화면의 이름, 대상 파일, 조치(차단·격리·삭제) 세 가지를 알려 주십시오.'
            continue
        }
        $got = (Get-Item $dst -ErrorAction SilentlyContinue).Length
        if ($got -ne $CysWinBytes) {
            Say "[5/10] 크기가 맞지 않습니다 (받은 것 $got · 기대 $CysWinBytes). 다시 받습니다."
            continue
        }
        # 크기가 맞아도 지문을 본다 — 크기는 같은데 내용이 다른 파일이 「받았습니다」로 지나가면
        # 그 뒤의 모든 단계가 남의 파일 위에서 돈다. 지문 도구가 없으면 .NET 으로 잰다(러너에 없던 자리).
        $hash = Get-CysFileSha256 $dst
        if ($null -eq $hash) {
            Say '[5/10] 받은 파일의 지문을 잴 수 없습니다 — 확인 없이 설치하지 않습니다.'
            Write-JCode 'J-DL-03' '설치 파일 지문을 잴 수 없음'
            if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
            return 5
        }
        if ($hash -eq $CysWinSha256) { Say "[5/10] 받았습니다 (원 = oogisoogi/cys-ro v$CysVersion · 크기·지문 확인 완료)."; return 0 }
        Say "[5/10] 지문이 맞지 않습니다 (받은 것 $($hash.Substring(0,12))… · 기대 $($CysWinSha256.Substring(0,12))…). 이 파일은 쓰지 않습니다."
        Write-JCode 'J-DL-04' '설치 파일 지문 불일치'
        if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
        return 5
    }
    # 두 번 다 실패했으면 반쯤 받은 파일을 남기지 않는다 — 다음 실행이 그것을 온전한 것으로 볼 수 있다.
    if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
    Say '[5/10] 설치 파일을 온전히 받지 못했습니다.'
    Say "     공식 페이지에서 직접 받으실 수 있습니다: $CysSiteUrl"
    Say "     받을 파일 이름 = $CysWinFile"
    return 5
}

# ── 하는 일 6 — cys 설치 ──────────────────────────────────────────
# 완료 판정은 설치기의 종료 코드가 아니라 [7]이 성립하는가로 한다.
# 조용히 설치하는 방법은 설치기 종류에 따라 다르고 아직 확인되지 않았다 — 후보를 차례로 시도하고,
# 모두 실패하면 설치 창을 띄워 사람이 진행하게 한다.
function Step-InstallCys {
    if ((Test-CysBody).Body) { Say '[6/10] cys 가 이미 설치돼 있습니다 — 건너뜁니다.'; return 0 }
    if ($Mode -eq 'dry') { Say '[6/10] (dry-run) 설치기를 실행하지 않았습니다.'; return 0 }
    $dst = Join-Path $DlDir $CysWinFile
    if (-not (Test-Path $dst)) { Say '[6/10] 설치 파일이 없습니다.'; return 6 }

    # 지난 설치가 끝까지 못 간 컴퓨터에서는, 설치 목록에만 항목이 남아 있고 지우는 프로그램이 없다.
    # 그 상태로 설치를 시작하면 설치기가 「먼저 지우겠다」로 갔다가 지울 것을 못 찾아 그 자리에서 멈춘다.
    # 그래서 실체가 없을 때에 한해, 남은 항목을 백업해 두고 지운 뒤 새로 설치한다.
    # 지우는 것은 이 항목 하나뿐이고, 사용자 데이터 파일은 건드리지 않는다.
    if ($script:CysBodyMissing) {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys'
        if (Test-Path $key) {
            $bk = Join-Path $JarvisHome 'backup'
            New-Item -ItemType Directory -Force -Path $bk | Out-Null
            $bkFile = Join-Path $bk 'uninstall-entry.reg'
            # 지난 실행의 백업이 남아 있으면 이번 백업이 실패해도 있는 것으로 보인다 — 먼저 치운다.
            if (Test-Path $bkFile) { Remove-Item $bkFile -Force -ErrorAction SilentlyContinue }
            & reg export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys' $bkFile /y | Out-Null
            # 되돌릴 파일이 실제로 만들어졌을 때에만 지운다. 백업이 없으면 손대지 않는다.
            if (Test-Path $bkFile) {
                Remove-Item $key -Recurse -Force -ErrorAction SilentlyContinue
                Write-JCode 'J-RM-01' '지난 설치의 자국이 남아 있어 정리했습니다'
            Say '[6/10] 지난 설치의 목록 항목만 정리했습니다 (프로그램 실체가 없어 설치가 멈추는 것을 막기 위해서입니다).'
                Say "     되돌리려면 이 파일을 두 번 누르십시오: $(Redact $bkFile)"
                Write-Log "removed stale uninstall entry · backup=$(Redact $bkFile)"
            } else {
                Say '[6/10] 지난 설치의 목록 항목을 백업하지 못해 그대로 두었습니다.'
                Say '     설치가 「먼저 지우겠다」에서 멈추면 그 화면을 알려 주십시오.'
            }
        }
    }

    Human 'OS' '설치 파일 실행 확인 — 처음 보는 프로그램이라 경고 창이 뜰 수 있습니다'
    Say '[6/10] cys 를 설치합니다.'
    Say '     파랗게 「Windows에서 PC를 보호했습니다」 창이 뜨면 [추가 정보] → [실행] 을 눌러 주십시오.'
    Say '     이 창은 서명되지 않은 프로그램에 뜨는 것이며 공식 안내에도 적혀 있습니다.'
    # 안내는 설치기를 띄우기 「전에」 해야 한다 — 백신이 이 창을 종료시키면 뒤에 적은 말은 나오지 못한다.
    Say '     백신이 막았다고 하면 그 화면을 사진으로 남겨 주십시오 — 이름, 대상 파일, 조치(차단·격리·종료) 세 가지가 보이게.'
    Say '     허용을 누를지는 쓰시는 분의 판단입니다. 저희가 대신 예외로 등록하지 않습니다.'
    Say '     이 창이 갑자기 닫히더라도, 끝에 인쇄되는 「다시 하시는 법」의 명령을 다시 붙여넣으시면 이어서 진행됩니다.'
    # ⛔우회하지 않는다 — 이 아래 어디에도 백신을 피하는 장치를 넣지 마라.
    #   금지 3종 = 검사 우회(AMSI) · 명령 숨기기(난독화·인코딩된 명령) · 우리가 대신 백신 예외 등록.
    #   그것들이 바로 백신이 찾는 행위이고, 그렇게 만든 설치기는 남의 컴퓨터에 둘 수 없다.
    #   우리가 하는 일은 하나다 — 막혔다는 것을 사람이 알아볼 수 있게 적어 두는 것.
    # 이 설치기는 NSIS 로 만들어졌다. 조용한 설치 스위치는 /S 하나다.
    # 그것이 안 되면 설치 창을 띄워 사람이 진행한다.
    foreach ($sw in @('/S', '')) {
        try {
            if ($sw -eq '') { Say '     조용한 설치가 되지 않아 설치 창을 띄웁니다. 창의 안내대로 [다음]을 눌러 주십시오.' }
            # -Wait 를 쓰지 않는다: 한도 없이 기다리면 경고 창 하나에 영원히 서 있게 된다.
            $p = if ($sw -eq '') { Start-Process -FilePath $dst -PassThru -ErrorAction Stop }
                 else { Start-Process -FilePath $dst -ArgumentList $sw -PassThru -ErrorAction Stop }
            $limit = if ($sw -eq '') { $InstallGuiWaitMs } else { $InstallWaitMs }
            if (-not $p.WaitForExit($limit)) {
                Say "     설치기가 $([int]($limit / 1000))초 안에 끝나지 않았습니다. 기다리기를 멈춥니다."
                Say '     화면에 백신 경고나 설치 창이 떠 있으면 그 화면을 알려 주십시오.'
                # 아래 확인 고리에서 자리가 잡혔는지를 조금 더 본다.
            }
        } catch {
            # 한 방법이 예외를 내도 다음 방법(설치 창)을 시도한다 — 여기서 끝내면 폴백이 무의미하다.
            Say "     이 방법으로는 실행하지 못했습니다: $($_.Exception.Message)"
            continue
        }
        # 설치기가 끝나도 파일이 자리를 잡기까지 잠깐 걸릴 수 있다
        for ($i = 0; $i -lt 20; $i++) {
            if ((Test-CysBody).Body) { Say '[6/10] 설치를 마쳤습니다.'; return 0 }
            Start-Sleep -Seconds 3
        }
        # 앞의 설치기가 아직 돌고 있으면 다음 방법으로 넘어가지 않는다.
        # 그 위에 하나를 더 띄우면 설치기 자신이 「이미 돌고 있다」로 막아, 사람에게는
        # 새 오류가 하나 더 늘어난 것으로만 보인다.
        if ($p -and -not $p.HasExited) {
            Say '     설치 프로그램이 아직 화면에 떠 있는 것 같습니다. 그 창을 먼저 봐 주십시오.'
            Say '     창을 닫으셨거나 끝났는데도 이 줄이 나오면, 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
            $script:ShowRerun = $true
            break
        }
        # 설치기는 실패를 종류별로 알려 준다. 종료 코드 4 는 「원래 있던 판은 그대로이고 새 판이 안 들어갔다」는 뜻이다.
        # 그리고 무엇을 못 바꿨는지 설치 폴더에 파일로 적어 둔다 — 그것을 그대로 사람에게 보여 준다.
        if ($p -and $p.HasExited -and $p.ExitCode -eq 4) {
            Say '[6/10] 새 판을 넣지 못했습니다. 원래 쓰시던 것은 그대로 있습니다.'
        }
        $note = Join-Path (Join-Path $env:LOCALAPPDATA 'cys') 'cys-install-failure.txt'
        if (Test-Path $note) {
            Say '     설치기가 남긴 기록입니다 (어느 파일을 왜 못 바꿨는지):'
            foreach ($ln in (Get-Content $note -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 12)) { Say "       $ln" }
            Say "     (전문: $(Redact $note))"
        }
        Say '     이 방법으로는 설치되지 않았습니다. 다음 방법을 시도합니다.'
    }
    Say '[6/10] 설치가 확인되지 않았습니다.'
    # 만든 사람이 정한 복구 순서다. 이 순서를 지키지 않으면 쓰던 것까지 잃을 수 있다.
    Say '     ⓘ 이럴 때 프로그램을 제거하지 마십시오.'
    Say '       cys 를 창에서 종료하고(세션이 저장됩니다) 10초 기다린 뒤,'
    Say '       이 설치 파일을 다시 실행해 「제거하지 않음」을 고르십시오.'
    Say '     ⓘ 설치 폴더에 이름 끝이 .new 나 .prev 인 파일이 잠깐 보이는 것은 정상입니다. 손대지 마십시오.'
    return 6
}

# ── 하는 일 7 — cys 가 실제로 쓸 수 있는가 ────────────────────────
# 설치 목록(등록)만 보고 판정하지 않는다. 프로그램 실체와 버전 응답 두 가지를 본다.
function Step-VerifyCys {
    # 🔴맥에서 먼저 잡힌 것을 윈도우에도 같게 고친다(두 OS 동등). 이 단에만 dry 분기가 없어서,
    #   cys 가 없는 **깨끗한 기계**의 미리보기가 여기서 rc 7 로 끊기고 사슬이 break 되어
    #   `[8/10]` 이 호출조차 안 됐다(화면이 7 다음 9 로 건너뛴다). cys 가 이미 깔린 기계에서는
    #   안 드러나는 형태다 — 그래서 여태 아무도 못 봤다.
    if ($Mode -eq 'dry') { Say '[7/10] (dry-run) cys 를 확인하지 않았습니다.'; return 0 }
    $b = Test-CysBody
    if (-not $b.Body) { Say '[7/10] cys 프로그램을 찾지 못했습니다.'; return 7 }
    Say "[7/10] cys 프로그램을 찾았습니다: $(Redact $b.Path)"
    # 명령이 이 창의 경로 목록에 없을 수 있다 — 새 프로세스로 다시 본다
    # 지금 창에만 있던 경로가 사라지지 않도록 덮어쓰지 않고 덧붙인다.
    # (앞 단계에서 클로드를 설치하며 이 창에만 잡아 둔 경로가 있을 수 있다.)
    $env:Path = $env:Path + ';' +
                [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path','User')
    # 설치기는 실행 경로 목록(PATH)에 등록하지 않는다 ⇒ 전체 경로로 부르는 것이 정본이고,
    # 이름만으로 부르는 것은 덤이다. 순서를 반대로 두면 새 창을 열기 전까지 못 찾는다.
    $ver = ''
    if ($b.Cli) { try { $ver = (Invoke-CysProbe $b.Cli @('--version') | Select-Object -First 1) } catch { } }
    if ($ver) { $script:CysCli = $b.Cli }
    if (-not $ver) {
        try { $ver = (& cys --version 2>$null | Select-Object -First 1) } catch { }
        if ($ver) { $script:CysCli = 'cys' }
    }
    # 명령이 답하지 않으면 실행 파일 자신이 지닌 판본 정보를 읽는다(크기나 날짜로 판정하지 않는다).
    if (-not $ver -and $b.Cli -and (Test-Path $b.Cli)) {
        try { $ver = (Get-Item $b.Cli).VersionInfo.ProductVersion } catch { }
        if ($ver) { $script:CysCli = $b.Cli; Say '     (명령이 아직 답하지 않아 파일에 적힌 판본을 읽었습니다.)' }
    }
    if ($ver) { Say "[7/10] cys 가 답합니다: $ver"; Say "     부르는 길: $(Redact $script:CysCli)"; return 0 }
    Say '[7/10] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    $script:ShowRerun = $true
    return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
function Step-PrepareAccount {
    if ($Mode -eq 'dry') { Say '[8/10] (dry-run) 계정 준비를 하지 않았습니다.'; return 0 }
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    Say '[8/10] 이 계정에 자리를 잡습니다.'
    Invoke-Logged 'init-pack' $cli @('init-pack') | Out-Null
    $daemonRc = Invoke-Logged 'daemon install' $cli @('daemon', 'install')
    # ★등록됐는지는 **작업을 직접 보고** 정한다(위 Test-CysAutoStart 의 까닭). 팩이 찍은 줄도,
    #   우리 추정도 아니다. 이 값 하나로 아래 문구가 갈린다 — 그래야 두 줄이 서로 모순되지 않는다.
    $script:AutoStartState = Get-CysAutoStartState $cli
    Write-Log ("daemon install rc=$daemonRc · scheduled task cysd = " + $script:AutoStartState)
    # 한 번 응답을 받았으면 그것으로 판정한다. 다시 물으면 그 순간의 흔들림으로 성공이 실패가 된다.
    $alive = $false
    for ($i = 0; $i -lt 10; $i++) {
        $pong = (& $cli ping 2>&1) -join ' '
        if ($pong -match 'pong') { $alive = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $alive) {
        # 자동으로 켜지게 등록하는 데 실패했을 수 있다(그 등록은 더 높은 권한을 요구하기도 한다).
        # 우리는 권한을 올리지 않는다. 대신 프로그램을 이번 한 번만 직접 켜서 쓸 수 있게 한다.
        # 프로그램 본체를 켜면 그것이 뒤에서 도는 부분까지 함께 켠다(실측). 그래서 본체를 먼저 고른다.
        $cysHome = Split-Path $cli -Parent
        $sideCar = Join-Path $cysHome 'cys-app.exe'
        if (-not (Test-Path $sideCar)) { $sideCar = Join-Path $cysHome 'cysd.exe' }
        if (Test-Path $sideCar) {
            # ⚠「등록이 안 됐다」와 「등록은 됐는데 지금 안 답한다」는 다른 일이다. 갈라 말한다(6차 검토).
            if ($script:AutoStartState -eq 'yes') {
                Say '[8/10] 자동 시작은 등록됐는데(작업 이름 cysd) 아직 답이 없습니다. 이번에는 프로그램을 직접 열어 보겠습니다.'
            } else {
                Say '[8/10] 이번에는 프로그램을 직접 열어 보겠습니다.'
                Say ('     ' + (Get-AutoStartWords $script:AutoStartState))
            }
            try { Start-Process -FilePath $sideCar | Out-Null } catch { Say "       직접 열지 못했습니다: $($_.Exception.Message)" }
            for ($i = 0; $i -lt 10; $i++) {
                $pong = (& $cli ping 2>&1) -join ' '
                if ($pong -match 'pong') { $alive = $true; break }
                Start-Sleep -Seconds 2
            }
            if ($alive) {
                $script:DaemonTemporary = $true
                Say '[8/10] 켜졌습니다.'
                # ⛔까닭을 「윈도우 설정이 막았다」로 **단정하지 않는다** — 우리는 그것을 잰 적이 없다.
                #   앞 판은 단정했고, 같은 날 팩은 「등록 완료」를 찍고 있었다(2026-09-10 실기).
                Say ('     ' + (Get-AutoStartWords $script:AutoStartState))
                if ($script:AutoStartState -ne 'yes') {
                    Say '     다음에 컴퓨터를 켜시면 cys 를 한 번 열어 주시면 됩니다. 그러면 그때부터 다시 돕니다.'
                }
                Write-Log ('daemon started by launching the app (scheduled task cysd = ' + $script:AutoStartState + ')')
            }
        }
    }
    # ★답이 왔든 안 왔든 **등록 여부는 따로 말한다** — 이 둘을 한 줄에 뭉치면 다시 모순이 생긴다(6차 검토).
    if ($alive -and -not $script:DaemonTemporary) {
        Say ('     ' + (Get-AutoStartWords $script:AutoStartState))
    }
    if (-not $alive) {
        Say '[8/10] 준비는 됐는데 아직 응답이 없습니다.'
        # 어느 층에서 멈췄는지 알려 주는 값이 따로 있다 — 추측하지 말고 그것을 그대로 보인다.
        #   등록됐는가 / 올라왔는가 / 창구가 살아 있는가, 셋이 갈라져 나온다.
        Invoke-Logged 'daemon status' $cli @('daemon', 'status') | Out-Null
        # 함께 있어야 할 짝 파일이 실제로 있는지도 본다(다른 운영체제에서 이것이 없어 실패한 전례가 있다).
        $sideCar = Join-Path (Split-Path $cli -Parent) 'cysd.exe'
        Say "       짝 파일 있음 = $(Test-Path $sideCar) ($(Redact $sideCar))"
        Say '     잠시 뒤 아래 「다시 하시는 법」대로 다시 실행해 주십시오. 그래도 같으면 위 세 줄을 알려 주십시오.'
        $script:ShowRerun = $true
        return 8
    }
    $doc = (Invoke-CysProbe $cli @('doctor')) -join "`n"
    # 자가진단은 마지막에 요약 한 줄을 낸다: 「요약: 11 OK · 1 WARN · 0 FAIL · 1 SKIP(판정 불가)」
    # 그 줄이 정본이다. 항목 표시는 폭을 맞추느라 [OK  ] 처럼 빈칸이 들어가서 표시만 세면 새어 나간다.
    $m = [regex]::Match($doc, '(\d+)\s*OK.*?(\d+)\s*WARN.*?(\d+)\s*FAIL.*?(\d+)\s*SKIP')
    if ($m.Success) {
        $nOk = $m.Groups[1].Value; $nWarn = $m.Groups[2].Value
        $bad = [int]$m.Groups[3].Value; $nSkip = $m.Groups[4].Value
        Say "[8/10] 자가진단: 통과 $nOk · 주의 $nWarn · 실패 $bad · 판정 못 함 $nSkip"
    } else {
        # 요약 줄을 못 찾으면 항목 표시로 센다(문구가 바뀐 경우).
        $bad = [regex]::Matches($doc, '\[FAIL\s*\]').Count
        $nSkip = [regex]::Matches($doc, '\[SKIP\s*\]').Count
        Say "[8/10] 자가진단 요약 줄을 찾지 못해 항목을 세었습니다: 실패 $bad"
    }
    # 통과 기준은 실패 0 이다. 주의는 성한 컴퓨터에도 나온다.
    # 판정 못 한 항목은 「됐다」로 세지 않는다 — 몇 개인지 그대로 알린다.
    # 자리를 잡으면서 **자비스 전용 설정 자리**가 새로 생긴다. 자비스가 부를 동료들은 그 자리로 뜨므로
    # 사전 설정을 여기서 한 번 더 심는다 — 안 그러면 동료들이 첫 실행 질문 앞에서 멈춰 선다(실측).
    # 🔴2026-09-10 개정 — 앞 판은 이 두 줄이 **자가진단 실패 갈래보다 뒤**에 있었다. 그래서 자가진단이
    #   한 가지라도 못 통과하면 전용 자리에 사전 설정이 **영영 안 심겼고**, 그 뒤 자비스가 부른 동료
    #   좌석들이 전부 첫 실행 질문(폴더 신뢰) 앞에 섰다. ★자가진단 결과와 시드는 아무 관계가 없다 —
    #   자리는 이미 생겼고, 심는 것은 실패해도 잃을 것이 없다. ⇒ 갈림길 **앞**으로 옮긴다.
    Set-AllProfiles | Out-Null
    if ($script:TrustJournalFailed) {
        Say ('[8/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — ' + (Get-TrustRollbackWords) + ' 여기서 멈춥니다.')
        $script:JCode = 'J-PERM-01'
        $script:NextStep = '저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        return 8
    }
    Copy-LoginToIsolated | Out-Null
    if ($bad -gt 0) {
        Say "[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다."
        Say '     아래 자비스가 무엇이 걸렸는지 사람 말로 알려 드립니다.'
        return 8
    }
    if ([int]$nSkip -gt 0) { Say "     ($nSkip 가지는 이 컴퓨터에서 판정할 수 없는 항목입니다 — 고장이 아닙니다.)" }
    Say '[8/10] 자리를 잡았습니다 (실패 0).'
    return 0
}

# ── 하는 일 9 — 자비스 깨우기 ─────────────────────────────────────
# cys 안에서 세션을 여는 것이 기본이고, 그것이 안 되면 이 창에서 바로 띄운다.
function Step-Wake {
    # 바깥 프로그램에 넘기는 글자는 ASCII 로만 쓴다.
    # 까닭(2026-09-05 실측): 우리말이 든 인자를 넘겼더니 받는 쪽이 여섯 개의 깨진 글자로 읽고
    #   「알 수 없는 인자」라며 거절했다 — 그래서 창이 열리지 않았다.
    #   우리말 문장은 인자가 아니라 파일에 담아 보낸다. 그 파일은 자비스가 직접 읽으므로
    #   중간에 글자가 바뀔 자리가 없다.
    $firstPrompt = "Read the file $DirectiveFile and do exactly what it says. Your first line must be the fixed line specified there."
    if ($Mode -eq 'dry') {
        Say '[9/10] (dry-run) 자비스를 띄우지 않았습니다.'
        Say "     (지금까지 사람 손이 필요했던 횟수: $($script:HumanHands)번)"
        [void](Step-Fleet '')
        return
    }
    Say '[9/10] 자비스를 깨웁니다.'
    Say "     (지금까지 사람 손이 필요했던 횟수: $($script:HumanHands)번)"
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    # 창 이름도 같은 이유로 ASCII 다 — 이 이름이 거절당한 자리다.
    $surfaceTitle = 'jarvis'
    # 여는 명령에 문장을 실으면 안 된다(2026-09-05 두 번 실측).
    #   1차 = 우리말이 깨져 「알 수 없는 인자」 · 2차 = 명령 안의 따옴표가 벗겨져 문장이 조각나
    #   그 조각 하나가 「알 수 없는 인자」로 갔다. 두 번 다 원인은 「문장을 인자로 넘긴 것」이다.
    # ⇒ 문장은 파일에 넣고, 여는 명령은 그 파일 하나만 가리킨다.
    # ★자리를 열기 **전에** 기준선을 찍는다(2차 검토 N2). 이 줄이 자리 여는 줄보다 뒤에 오면
    #   우리가 만든 master 자리까지 기준선에 들어가 영영 안 세어진다.
    Set-FleetBaseline $cli
    $wakeFile = Join-Path $JarvisHome 'wake.ps1'
    # 앞 단계에서 자리 잡기가 끝나지 않았으면 cys 안에 창을 열 수 없다.
    # 시도해 봐야 실패 줄만 하나 더 보이므로, 사유를 말하고 바로 이 창에서 띄운다.
    if ($script:BlockedStep) {
        Say "     ($($script:BlockedStep) 이(가) 끝나지 않아 cys 안에는 아직 열 수 없습니다. 이 창에서 띄웁니다.)"
    } elseif (Get-Command $cli -ErrorAction SilentlyContinue) {
        # 이 파일은 우리가 쓰고 우리가 부른다. 안에서는 따옴표를 마음껏 쓸 수 있다 —
        # 벗겨질 자리(다른 프로그램의 인자)를 지나지 않기 때문이다.
        $wakeBody = "& claude --dangerously-skip-permissions '$firstPrompt'"
        try {
            # 5.1 이 우리말을 안 깨뜨리려면 이 파일에는 BOM 이 있어야 한다(.ps1 은 우리 자신과 같은 규칙).
            $enc = New-Object System.Text.UTF8Encoding($true)
            [System.IO.File]::WriteAllText($wakeFile, $wakeBody, $enc)
        } catch {
            Say "     여는 파일을 쓰지 못했습니다: $($_.Exception.Message)"
        }
        # 여는 명령에는 따옴표가 하나도 없다 ⇒ 경로에 공백이 있으면 그대로 조각난다.
        # 그때는 짧은 이름(8.3)을 얻어 쓰고, 그것도 없으면 이 길을 포기하고 창 폴백으로 간다.
        $wakeArg = $wakeFile
        if ($wakeArg -match ' ') {
            try {
                $fso = New-Object -ComObject Scripting.FileSystemObject
                $short = $fso.GetFile($wakeFile).ShortPath
                if ($short -and ($short -notmatch ' ')) { $wakeArg = $short }
            } catch { }
        }
        $cmd = "powershell -ExecutionPolicy Bypass -File $wakeArg"
        # 조각날 것이 뻔한 명령은 아예 보내지 않는다 — 보내면 원인이 한 겹 더 늘어난다.
        if (($wakeArg -match ' ') -or -not (Test-Path $wakeFile)) {
            Say '     여는 파일의 경로를 쓸 수 없어 cys 안에서는 열지 못합니다. 이 창에서 띄웁니다.'
            Write-Log "wake path unusable: $wakeArg"
            $ref = ''
        } else {
            # 「무엇을 띄우는지」 칸은 그 칸이 있는 판본에서만 붙인다 — 없는 판본에 붙이면
            # 모르는 인자라며 거절당해 자리 자체가 안 열린다(조건을 둔 유일한 까닭이다).
            # ⚠맥판은 이 두 줄을 함수 하나로 묶었는데, 이쪽은 검사 축이 「못 쓸 경로 판정 뒤에
            #   이 줄이 온다」를 줄 순서로 재기 때문에 부르는 자리에 그대로 둔다(같은 동작·다른 모양).
            if (Test-CysAgentFlag) {
                $ref = (& $cli new-surface --role master --cwd $JarvisHome --title $surfaceTitle --agent claude --cmd $cmd 2>&1) -join ''
            } else {
                $ref = (& $cli new-surface --role master --cwd $JarvisHome --title $surfaceTitle --cmd $cmd 2>&1) -join ''
            }
        }
        if ($ref -match 'surface:') {
            Say "     cys 안에서 자비스를 열었습니다 ($ref). cys 창에서 이어서 이야기하십시오."
            # 깨우기가 **성공한 뒤에만** 세운다(검토 지적 · D1 기각) — 깨우기가 실패한 끝은 원격 해결이 돈다
            $script:ReachedWake = $true
            $m = [regex]::Match($ref, 'surface:\d+')
            $script:WakeRef = $(if ($m.Success) { $m.Value } else { '' })
            # 창이 열렸으면 곧바로 동료들을 부른다. 여기서 부르는 까닭 = 아래 폴백(이 창에서 자비스를
            # 띄우는 길)로 내려가면 그 순간부터 이 스크립트는 자비스 화면에 갇혀 다음 줄을 못 간다.
            [void](Step-Fleet $script:WakeRef)
            return
        }
        # 왜 못 열었는지를 화면과 기록 파일 양쪽에 남긴다. 이 값이 없으면 다음에도 원인을 모른다.
        Say '     cys 안에서 열지 못했습니다. 프로그램이 답한 내용은 이렇습니다:'
        foreach ($ln in ($ref -split "`n")) { if ($ln.Trim()) { Say "       $ln" } }
        Write-Log "new-surface failed: $ref"
        # 그래도 길은 두 갈래로 남긴다.
        #  (1) 이 창에서 바로 띄운다 — 지금 바로 쓸 수 있다.
        #  (2) cys 창에서 마무리하고 싶으시면 칠 줄을 인쇄해 둔다.
        Say ''
        Say '     cys 창 안에서 이어서 하고 싶으시면, cys 를 열고 그 안에서 아래 한 줄을 쳐 주십시오:'
        Say "       $cmd"
        Say ''
        Say '     지금은 이 창에서 바로 띄웁니다.'
    }
    Set-Location -Path $JarvisHome -ErrorAction SilentlyContinue
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Say '[9/10] 자비스를 띄우지 못했습니다 — 클로드 명령을 찾지 못했습니다.'
        Say '     PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        return
    }
    try {
        # 깨우기가 **성공한 뒤에만**(자비스가 떠서 정상으로 끝났다 = 종료 코드 0) 원격 해결을 막는다 — 못 떴으면 원격 해결이 돈다(검토 지적 · D1 기각)
        #   앞 명령의 종료 코드가 남아 있으면 「성공」으로 읽힌다 ⇒ 부르기 전에 비운다
        $global:LASTEXITCODE = -1
        & claude --dangerously-skip-permissions $firstPrompt
        if ($global:LASTEXITCODE -eq 0) { $script:ReachedWake = $true }
    } catch {
        Say "[9/10] 자비스를 띄우지 못했습니다: $($_.Exception.Message)"
        Say '     PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        return
    }
    # 이 함수의 값은 아무도 쓰지 않는다. 값을 돌려주면 화면에 숫자 한 줄로 새어 나온다(실측 09:3x).
    return
}

# ── 하는 일 10 — 첫 함대 부르기 ───────────────────────────────────
# 자비스는 사람이 「너는 마스터다」라고 말해야 깨어나 동료를 부른다. 그 말을 우리가 대신 넣는다.
# 우리가 하는 일 = ⑴어디에 무엇을 칠지 크게 알려 주고 ⑵칠 때까지 기다리고 ⑶선 자리를 확인해 준다.
$FleetTrigger = '너는 마스터다'
# ⛔이 문장을 우리가 대신 넣지 않는다. 자비스에는 「사람이 직접 친 선언만 팀을 부른다」는 장치가
#   있고(기계가 넣은 것은 알아보고 거절한다 — 2026-09-05 실측), 그 장치는 옳다.
#   기계가 대신 치는 길을 뚫으면 남이 몰래 팀을 부리는 길도 함께 열린다.
#   그래서 우리는 **부탁만 하고 기다린다.** 사람 손 한 번이 늘지만 그 한 번이 이 장치의 값이다.
$FleetRoles   = @('master', 'cso', 'worker')   # 이 기계에서 세울 수 있는 역할(리뷰어 둘은 고르기 나름)
$FleetWaitTries = 72   # 5초 × 72 = 6분. 사람이 창을 찾아 한 문장 치기에 넉넉한 시간.
# 🔴🔴**이전 설치의 좌석을 이번 선언으로 세지 않는다**(2차 검토 N2 확정 2026-09-10).
#   앞 판은 전역 목록에서 **역할 이름만** 셌다. 그러면 지난 설치의 master·cso·worker 가 아직 살아
#   있는 기계에서는 사람이 **아무 선언도 하지 않았는데** 첫 폴링에 세 역할이 다 차서
#   「함대가 섰습니다」로 끝난다 — 새로 연 자비스는 깨어 있지도 않다.
#   ⇒ 자리를 열기 **전에** 목록을 찍어 두고(기준선), 그 뒤 **새로 생긴 자리만** 센다.
# 🔴🔴**기준선을 못 찍었으면 세는 것 자체를 하지 않는다**(3차 검토 N2 확정 2026-09-10 · 관리자 결정).
#   기준선은 「이번 설치의 자리」와 「지난 설치의 자리」를 가르는 **유일한 근거**다. 그 조회가 실패해
#   빈 집합이 되면, 다음 조회에 보이는 **옛 좌석 전부가 새 좌석으로** 읽힌다 ⇒ 사람이 아무 말도
#   하지 않았는데 첫 폴링에 「함대가 섰습니다」로 끝난다.
#   ★빈 집합은 「아무것도 없었다」가 아니라 **「못 물어봤다」**일 수 있다. 그 둘을 한 칸에 담으면
#     실패가 곧 거짓 성공이 된다.
#   ⇒ 실패면 **계산하지 않고 모른다고 말한다**(unknown 게이트).
$script:BaselineSurfaces = @()
$script:BaselineOk = $false
function Get-SurfaceIds {
    param([string]$Cli)
    $out = (Invoke-CysProbe $Cli @('list')) -join "`n"
    $ids = @()
    foreach ($m in [regex]::Matches($out, 'surface:\d+')) { $ids += $m.Value }
    return ($ids | Sort-Object -Unique)
}
function Set-FleetBaseline {
    param([string]$Cli)
    $script:BaselineOk = $false
    $script:BaselineSurfaces = @()
    try {
        $global:LASTEXITCODE = 0
        $out = (Invoke-CysProbe $Cli @('list')) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw ('cys list 가 ' + $LASTEXITCODE + ' 로 끝났습니다') }
        $ids = @()
        foreach ($m in [regex]::Matches($out, 'surface:\d+')) { $ids += $m.Value }
        $script:BaselineSurfaces = @($ids | Sort-Object -Unique)
        $script:BaselineOk = $true
        Write-Log ('fleet baseline surfaces: ' + ($script:BaselineSurfaces -join ' '))
    } catch {
        Write-Log ('fleet baseline FAILED: ' + $_.Exception.Message + ' -> 좌석 판정 안 함')
    }
}
function Get-LiveRoles {
    param([string]$Cli)
    $out = (Invoke-CysProbe $Cli @('list')) -join "`n"
    $live = @()
    foreach ($ln in ($out -split "`n")) {
        if (-not $ln) { continue }
        $mid = [regex]::Match($ln, 'surface:\d+')
        # 기준선에 있던 자리는 **이번 설치의 것이 아니다** — 세지 않는다.
        if ($mid.Success -and ($script:BaselineSurfaces -contains $mid.Value)) { continue }
        foreach ($r in $FleetRoles) {
            if ($live -contains $r) { continue }
            # 목록의 role 칸은 role=master · role=worker-2 처럼 나온다. 앞부분이 맞으면 그 역할로 센다.
            if ($ln -match ("role=" + [regex]::Escape($r) + "(\s|-|$)")) { $live += $r }
        }
    }
    return $live
}
# 🔴🔴**「선언됐다」의 근거를 바꾼다**(1차 검토 BLOCK ③ 확정 2026-09-10).
#   앞 판은 「목록에 role=master 가 있으면 사람이 선언한 것」으로 봤다. **그 축은 처음부터 거짓이었다** —
#   ★master 좌석을 만든 것은 사람이 아니라 **우리 자신**이다(바로 위에서 role=master 자리를 연다).
#   그래서 사람이 아무것도 치지 않아도 화면은 「부르는 중 · 사람이 하실 일 없습니다」라고 말하고,
#   끝에는 「그 한마디는 들어갔습니다」라고 단정했다 ⇒ **선언이 영영 안 일어나고 6분을 버린다.**
#   앞 판이 고치려던 사고(이미 친 사람에게 또 치라고 함)를 **정반대 방향으로 되풀이**한 셈이다.
#   ⇒ 근거 = **자식 좌석의 출현**. cso·worker 는 자비스가 선언을 듣고 나서야 부른다 —
#     우리는 그것들을 만들지 않는다. 하나라도 서면 그 한마디는 확실히 들어간 것이다.
#   ⚠뒤집어 말하면: 자식이 하나도 없으면 **선언 여부를 우리는 모른다.** 모를 때는 단정하지 않고
#     「아직 치지 않으셨다면」이라는 조건문으로 말한다(그것이 원래 문구가 맞았던 이유다).
function Test-DeclarationSeen($live) {
    foreach ($r in @($live)) { if ($r -ne 'master') { return $true } }
    return $false
}
function Step-Fleet {
    param([string]$SurfaceRef)
    if ($Mode -eq 'dry') { Say '[10/10] (dry-run) 함대를 부르지 않았습니다.'; return 0 }
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    if (-not $SurfaceRef) {
        Say '[10/10] 자비스 창을 못 열어 동료들을 부르지 못했습니다.'
        Say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FleetTrigger"
        return 10
    }
    # 🔴2026-09-10 실기에서 고친 것(5차 검토) — 이 자리의 옛 문구는 「강제」였다. 그런데 같은 4분 동안 자비스는
    #   화면에 「사람이 할 일 없음」이라고 적고 있었다 ⇒ 사용자에게 두 화면이 **정면으로 모순**이다.
    #   ★안전장치 설명은 남기고 「강제」의 어감만 뺀다 — 사람이 치는 것은 이 한마디 하나다.
    # ★기준선을 못 찍었으면 **여기서 멈춘다** — 세어 봐야 그 수가 무엇을 뜻하는지 모른다.
    if (-not $script:BaselineOk) {
        Say '[10/10] 지금 열려 있는 자리 목록을 읽지 못해, 동료들이 섰는지 판정하지 않습니다.'
        Say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FleetTrigger"
        Say '     그 뒤 자비스에게 「동료들 다 섰어?」라고 물어보시면 자비스가 직접 확인해 알려 드립니다.'
        return 10
    }
    Human '자비스' '이 한마디만 사람이 칩니다 — cys 창에서 직접 쳐 주십시오(안전장치)'
    Say ''
    Say '   ┌─────────────────────────────────────────────┐'
    Say ("   │   cys 창(제목 jarvis)에 이렇게 쳐 주십시오:  │")
    Say ("   │                                             │")
    Say ("   │        " + $FleetTrigger + "                        │")
    Say ("   │                                             │")
    Say '   └─────────────────────────────────────────────┘'
    Say ''
    Say '   그 한마디를 들으면 자비스가 동료들을 부릅니다. 여기서 기다리다가 다 서면 알려 드립니다.'
    Say '   (직접 치셔야 합니다 — 프로그램이 대신 친 말은 자비스가 알아보고 거절합니다. 안전장치입니다.)'
    Write-Log "fleet: waiting for owner declaration in $SurfaceRef"
    $live = @()
    $waited = 0
    for ($i = 0; $i -lt $FleetWaitTries; $i++) {
        Start-Sleep -Seconds 5
        $waited += 5
        $live = @(Get-LiveRoles $cli)
        if ($live.Count -ge $FleetRoles.Count) { break }
        # 오래 걸리면 얼마나 더 기다리는지 알려 준다 — 말없이 멈춰 있는 것처럼 보이지 않게.
        # 🔴2026-09-10 실기에서 고친 것(5차 검토) — 앞 판은 **판정 없이** 「아직 치지 않으셨다면 지금 쳐 주십시오」를
        #   되풀이했다. 쓰시는 분은 이미 치셨고 자비스는 그 4분 동안 환경 보고를 쓰고 동료를 부르고 있었다.
        #   ⇒ 사용자에게는 「다 됐다」와 「아직 안 쳤다」가 동시에 떠 있었다.
        #   ★판정 축은 이미 손에 있었다 — master 자리가 목록에 서 있으면 **그 한마디는 이미 들어간 것**이다
        #     (선언이 role 등록을 낳는다). 그 뒤로는 사람에게 시킬 일이 없다.
        #   ⚠새 프로브를 만들지 않는다 — 이미 5초마다 부르는 `cys list` 의 답을 그대로 읽는다.
        if (($i -gt 0) -and (($i % 12) -eq 0)) {
            $mins = "$([int]($waited / 60))분 지남 · 최대 $([int](($FleetWaitTries * 5) / 60))분"
            if (Test-DeclarationSeen $live) {
                Say ("   자비스가 동료들을 부르는 중입니다. 그대로 기다려 주십시오 ($mins).")
                Say ("     선 자리 = " + ($live -join ' · ') + '  (사람이 하실 일은 없습니다)')
            } else {
                Say ("   기다리는 중입니다 ($mins). 아직 치지 않으셨다면 지금 쳐 주십시오.")
            }
        }
    }
    $missing = @($FleetRoles | Where-Object { $live -notcontains $_ })
    if ($missing.Count -eq 0) {
        Say ("[10/10] 함대가 섰습니다: " + ($live -join ' · '))
        return 0
    }
    # 성공보다 이 문구가 중요하다 — 무엇이 없어서 못 섰는지를 그대로 말한다.
    Say ("[10/10] 아직 서지 않은 자리가 있습니다: " + ($missing -join ' · '))
    Say ("     선 자리 = " + $(if ($live.Count) { $live -join ' · ' } else { '없음' }))
    # ★여기서도 「아직 안 쳤다」를 단정하지 않는다 — 다만 근거는 **자식 좌석**이다(아래 함수).
    if (Test-DeclarationSeen $live) {
        Say '     자비스는 이미 깨어 있습니다(master 자리가 섰습니다) — 그 한마디는 들어갔습니다.'
        Say '     남은 자리는 자비스가 이어서 세웁니다. cys 창의 자비스에게 무엇이 걸렸는지 물어보십시오.'
    } else {
        Say '     아직 그 한마디를 치지 않으셨다면, cys 창에서 지금 쳐 주시면 됩니다.'
        Say '     치셨는데도 서지 않았다면 cys 창의 자비스에게 물어보십시오 — 무엇이 걸렸는지 사람 말로 알려 줍니다.'
    }
    Write-Log ("fleet missing: " + ($missing -join ','))
    return 10
}

# ── 원격 해결 (help-s2) — 막히면 진단이 서버로 가고, 운영팀 명령을 이 창이 실행한다 ────────
# 맥판(bootstrap.sh)과 같은 계약·같은 순서다. 계약 정본 = ai-jarvis `web-install/docs/HELP-API.md` 4·5·7·9-4절.
# ★사람이 누르는 것은 없다 — [1/10] 에서 고지 1줄을 보여 드리고, 막혀 멈추면 묻지 않고 보낸다.
# ★서버 응답을 믿지 않는다 — 이 파일에 넣어 둔 표로 다시 재고 · 작업 폴더 밖 경로를 막고 ·
#   실행한 번호를 실행 **전에** 남기고 · 명령 글을 PowerShell 에 해석시키지 않고 실행한다.
# ★자비스를 깨운 뒤에는 돌지 않는다 · 끝맺음(finally)이 부른다 — 창을 닫으면 이 프로세스와 함께 멈춘다.
# ⚠.NET 정규식의 `$` 는 끝 줄바꿈 **앞**에서도 맞는다 ⇒ 표의 글자 규칙을 그대로 쓰면 줄바꿈 붙은 명령이 통과한다.
#   글자 칸은 `\z` 로 끝을 못박아 다시 만든다. 이름·글자·판본 비교는 대소문자를 가르는 -ceq·-cmatch·-ccontains 만 쓴다.
# ⚠PowerShell 은 `'true' -eq $true` 를 참으로 본다 ⇒ 칸마다 **형(type)을 먼저** 본다.
# ⚠이 절은 맥에서 PowerShell 없이 **정적 검사 + 맥판과의 대조**로만 증명했다 — 윈도우 실기가 필요한 축은 내부 문서.
$InstallerVersion       = '0.3.15'   # 보고의 installer_version · $BootstrapVersion 은 화면 머리글 용도 그대로(보내지 않는다)
$HelpApiUrl             = 'https://jarvis-install.godmeyou.kr'
$RemoteHelpNoticeUrl    = 'jarvis-install.godmeyou.kr/help/notice'
# [1/10] 고지 1줄 = /help/notice 정본이 인용하는 문장 그대로 + 끝에 자세한 안내 자리. ⛔문안 변경 금지(맥판과 글자가 같아야 한다).
$RemoteHelpNotice       = '막히면 진단이 서버로 가고 운영 자비스가 원격으로 해결합니다 · 창을 닫으면 멈춥니다 · 자세히: ' + $RemoteHelpNoticeUrl
# 「막혔을 때」 절 = page.ts REMOTE_LINES 3줄에서 태그만 뗀 것. ⛔문안 변경 금지(시험이 맥판과 글자를 대조한다).
$RemoteHelpLines = @(
    '무엇을 보내는가 — 설치가 막히면 설치 창이 진단(진단 코드·멈춘 단계·운영체제 판본·환경 보고·기록 끝부분)을 이 서버로 보냅니다. 집 폴더 경로·이메일·토큰, 그리고 환경 보고와 기록에 표시된 로그인 이름(같은 보고의 다른 곳에 나와도)은 보내기 전에 지우고, 서버가 한 번 더 지웁니다. 표시 없이 글 속에 홀로 적힌 이름은 알아보지 못해 남을 수 있습니다.',
    '누가 명령하는가 — 운영팀만 명령을 보낼 수 있습니다. 명령은 설치 창에 글자 그대로 표시된 뒤 실행되고, 이 화면에도 같은 글자로 남습니다. 서버는 명령을 실행하지 않습니다.',
    '어떻게 멈추는가 — 설치 창을 닫으면 곧바로 멈춥니다. 보고 화면의 「원격 해결 멈추기」로도 멈출 수 있고, 명령이 30분 동안 없거나 시작한 지 2시간이 지나면 저절로 닫힙니다.'
)
$RemoteHelpPollSec      = 20
$RemoteHelpMaxSec       = 7200   # 2시간 — 서버의 절대 상한과 같다(서버에 못 닿아도 이 창이 따로 멈춘다)
$RemoteHelpCmdTimeout   = 60     # 명령 하나의 시간 상한(초)
$RemoteHelpReportMaxBytes = 240000   # 보고 본문(직렬화한 JSON) 상한 — 서버 262,144 바이트 안쪽
$RemoteHelpNoteEverySec = 300    # 기다리는 동안 몇 초마다 한 줄 말하는가
$RemoteHelpSeqFile      = Join-Path $JarvisHome 'remote-help-executed.json'   # 실행한 명령 번호 · 재부팅 내성 · 깨지면 실행 0
$RemoteHelpTokenFile    = Join-Path $JarvisHome 'remote-help-client-token'    # 보고 응답의 client_token(본인만 읽게) · ack·close 출처 헤더
$script:NoticeShown     = $false
$script:ReachedWake     = $false
$script:RhId            = ''
$script:RhClientToken   = ''
$script:RhNames         = [string[]]@()
$script:RhLastAnswer    = ''

# 허용 명령 표 — ai-jarvis `web-install/docs/command-table.json` 과 바이트 동일(here-string 이라 끝 줄바꿈 하나만 빠진다 · 시험이 잰다).
#   판본 글자는 이 표의 "version" 하나뿐이다(코드에 따로 적지 않는다).
$RemoteHelpTableJson = @'
{
  "version": "v1-2026-09-11",
  "token_pattern": "^[A-Za-z0-9_.:/\\\\-]+$",
  "max_command_bytes": 512,
  "max_tokens": 12,
  "max_token_chars": 200,
  "max_path_segments": 8,
  "proc_names": [
    "cys",
    "cysd",
    "claude",
    "node"
  ],
  "entries": [
    {
      "id": "dir.root",
      "shell": "ps1",
      "usage": "Get-ChildItem",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 맨 위의 목록을 본다"
    },
    {
      "id": "dir.list",
      "shell": "ps1",
      "usage": "Get-ChildItem -LiteralPath <path>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 한 폴더의 목록을 본다"
    },
    {
      "id": "file.tail",
      "shell": "ps1",
      "usage": "Get-Content -LiteralPath <path> -Tail <n:1-200>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 파일의 끝 N줄을 본다"
    },
    {
      "id": "file.hash",
      "shell": "ps1",
      "usage": "Get-FileHash -LiteralPath <path> -Algorithm SHA256",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안 파일의 SHA256 을 본다"
    },
    {
      "id": "file.exists",
      "shell": "ps1",
      "usage": "Test-Path -LiteralPath <path>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "작업 폴더 안에 그 파일(예: 표식 .jarvis-owned)이 있는지 본다"
    },
    {
      "id": "disk.free",
      "shell": "ps1",
      "usage": "Get-PSDrive -Name C",
      "exec": "cmdlet",
      "risk": 0,
      "title": "C 드라이브의 남은 공간을 본다"
    },
    {
      "id": "net.check",
      "shell": "ps1",
      "usage": "Test-NetConnection -ComputerName jarvis-install.godmeyou.kr -Port 443 -InformationLevel Quiet",
      "exec": "cmdlet",
      "risk": 0,
      "title": "우리 서버(443)에 닿는지 본다"
    },
    {
      "id": "shell.version",
      "shell": "ps1",
      "usage": "Get-Host",
      "exec": "cmdlet",
      "risk": 0,
      "title": "PowerShell 판본을 본다"
    },
    {
      "id": "av.status",
      "shell": "ps1",
      "usage": "Get-MpComputerStatus",
      "exec": "cmdlet",
      "risk": 0,
      "title": "백신 상태를 본다(끄지 않는다)"
    },
    {
      "id": "proc.find",
      "shell": "ps1",
      "usage": "Get-Process -Name <proc>",
      "exec": "cmdlet",
      "risk": 0,
      "title": "우리 프로그램(cys·cysd·claude·node)이 떠 있는지 본다"
    },
    {
      "id": "cys.status",
      "shell": "ps1",
      "usage": "cys status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 노드 상태를 본다"
    },
    {
      "id": "cys.doctor",
      "shell": "ps1",
      "usage": "cys doctor",
      "exec": "cys",
      "risk": 0,
      "title": "cys 자기진단을 본다(고치지 않는다)"
    },
    {
      "id": "cys.daemon",
      "shell": "ps1",
      "usage": "cys daemon status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 상시 가동 등록 상태를 본다"
    },
    {
      "id": "dir.root",
      "shell": "sh",
      "usage": "ls -lan",
      "exec": "/bin/ls",
      "risk": 0,
      "title": "작업 폴더 맨 위의 목록을 본다(소유자는 번호로)"
    },
    {
      "id": "dir.list",
      "shell": "sh",
      "usage": "ls -lan <path>",
      "exec": "/bin/ls",
      "risk": 0,
      "title": "작업 폴더 안 한 폴더의 목록을 본다(소유자는 번호로)"
    },
    {
      "id": "file.tail",
      "shell": "sh",
      "usage": "tail -n <n:1-200> <path>",
      "exec": "/usr/bin/tail",
      "risk": 0,
      "title": "작업 폴더 안 파일의 끝 N줄을 본다"
    },
    {
      "id": "file.hash",
      "shell": "sh",
      "usage": "shasum -a 256 <path>",
      "exec": "/usr/bin/shasum",
      "risk": 0,
      "title": "작업 폴더 안 파일의 SHA256 을 본다"
    },
    {
      "id": "file.exists",
      "shell": "sh",
      "usage": "test -e <path>",
      "exec": "/bin/test",
      "risk": 0,
      "title": "작업 폴더 안에 그 파일(예: 표식 .jarvis-owned)이 있는지 본다(종료 코드)"
    },
    {
      "id": "disk.free",
      "shell": "sh",
      "usage": "df -h .",
      "exec": "/bin/df",
      "risk": 0,
      "title": "작업 폴더가 있는 디스크의 남은 공간을 본다"
    },
    {
      "id": "net.check",
      "shell": "sh",
      "usage": "nc -z -G 5 jarvis-install.godmeyou.kr 443",
      "exec": "/usr/bin/nc",
      "risk": 0,
      "title": "우리 서버(443)에 닿는지 본다"
    },
    {
      "id": "shell.version",
      "shell": "sh",
      "usage": "sw_vers",
      "exec": "/usr/bin/sw_vers",
      "risk": 0,
      "title": "macOS 판본을 본다"
    },
    {
      "id": "av.status",
      "shell": "sh",
      "usage": "spctl --status",
      "exec": "/usr/sbin/spctl",
      "risk": 0,
      "title": "Gatekeeper 상태를 본다(끄지 않는다)"
    },
    {
      "id": "proc.find",
      "shell": "sh",
      "usage": "pgrep -l <proc>",
      "exec": "/usr/bin/pgrep",
      "risk": 0,
      "title": "우리 프로그램(cys·cysd·claude·node)이 떠 있는지 본다"
    },
    {
      "id": "cys.status",
      "shell": "sh",
      "usage": "cys status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 노드 상태를 본다"
    },
    {
      "id": "cys.doctor",
      "shell": "sh",
      "usage": "cys doctor",
      "exec": "cys",
      "risk": 0,
      "title": "cys 자기진단을 본다(고치지 않는다)"
    },
    {
      "id": "cys.daemon",
      "shell": "sh",
      "usage": "cys daemon status",
      "exec": "cys",
      "risk": 0,
      "title": "cys 상시 가동 등록 상태를 본다"
    }
  ]
}
'@

function Read-RemoteHelpStream($stream) {
    if ($null -eq $stream) { return '' }
    if ($stream.CanSeek) { $stream.Position = 0 }
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Invoke-RemoteHelpHttp($Method, $Path, $Body) {
    # 돌려주는 것 = @{ Code = <응답 코드 · 0 = 닿지 못함>; Text = <응답 본문(UTF-8)> }
    #   ⚠5.1 은 응답에 글자셋이 없으면 본문을 라틴 글자로 읽는다 ⇒ 날 바이트를 UTF-8 로 직접 읽는다.
    $ProgressPreference = 'SilentlyContinue'
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $headers = @{}
    if ($script:RhClientToken -and ($Path -like '*/ack' -or $Path -like '*/close')) { $headers['x-help-client'] = $script:RhClientToken }
    $request = @{ Uri = ($HelpApiUrl + $Path); Method = $Method; UseBasicParsing = $true; TimeoutSec = 20; Headers = $headers; ErrorAction = 'Stop' }
    if ($null -ne $Body) {
        $request['Body'] = [System.Text.Encoding]::UTF8.GetBytes([string]$Body)
        $request['ContentType'] = 'application/json; charset=utf-8'
    }
    try {
        $response = Invoke-WebRequest @request
        return @{ Code = [int]$response.StatusCode; Text = (Read-RemoteHelpStream $response.RawContentStream) }
    } catch {
        $failed = $null
        try { $failed = $_.Exception.Response } catch { }
        if ($null -ne $failed) {
            $text = ''
            try { $text = Read-RemoteHelpStream $failed.GetResponseStream() } catch { }
            return @{ Code = [int]$failed.StatusCode; Text = $text }
        }
        return @{ Code = 0; Text = '' }
    }
}

# ── 1차 스크럽 — 서버 src/scrub.ts 와 같은 규칙 · 서버가 한 번 더 지운다 ──
function Get-RemoteHelpNames([string]$Text, [string[]]$Known) {
    $names = New-Object System.Collections.Generic.List[string]
    $add = {
        param($raw)
        if ($names.Count -ge 64) { return }
        $value = (([string]$raw).Trim()) -replace '["'']', ''
        if ($value.Length -ge 2 -and -not $names.Contains($value)) { $names.Add($value) }
        $segment = ((($value -split '[\\/]')[-1])).Trim()
        if ($segment.Length -ge 2 -and $names.Count -lt 64 -and -not $names.Contains($segment)) { $names.Add($segment) }
    }
    foreach ($k in $Known) { if ($k) { & $add $k } }
    $pattern = '\b(?:USERNAME|USERPROFILE|LOGNAME|USER|HOME)\b[ \t]*[=:][ \t]*([^\r\n]+)|\bwhoami\b[ \t]*[:=>][ \t]*([^\r\n]+)|(?:^|\n)[ \t]*([A-Za-z][A-Za-z0-9.-]{1,63}\\[A-Za-z0-9._-]{2,63})[ \t]*(?:\r?\n|$)'
    foreach ($m in [regex]::Matches($Text, $pattern, 'IgnoreCase')) {
        if ($names.Count -ge 64) { break }
        if ($m.Groups[1].Success) { & $add $m.Groups[1].Value } elseif ($m.Groups[2].Success) { & $add $m.Groups[2].Value } else { & $add $m.Groups[3].Value }
    }
    $sorted = @($names | Sort-Object -Property Length -Descending)
    return ,([string[]]$sorted)
}

function Invoke-RemoteHelpScrub([string]$Text, [string[]]$Names) {
    if ($null -eq $Text) { return '' }
    if ($null -ne $Names -and $Names.Count -gt 0) {
        $Text = [regex]::Replace($Text, (($Names | ForEach-Object { [regex]::Escape($_) }) -join '|'), '~user')
    }
    $Text = [regex]::Replace($Text, '[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63})*\.[A-Za-z]{2,63}', '<이메일 지움>')
    $Text = [regex]::Replace($Text, '\bBearer\s+[A-Za-z0-9._~+/=-]+', 'Bearer <토큰 지움>', 'IgnoreCase')
    $Text = [regex]::Replace($Text, '\bsk-[A-Za-z0-9_-]{8,}', '<키 지움>')
    $Text = [regex]::Replace($Text, '\b[A-Za-z]:(?:\\{1,2}|/)Users(?:\\{1,2}|/)[^\\/\r\n"''<>|:*?]+', '~', 'IgnoreCase')
    $Text = [regex]::Replace($Text, '/Users/[^/\s"''<>]+', '~')
    return $Text
}

function Get-RemoteHelpTailBytes([string]$Text, [int]$Max) {
    # 끝에서부터 Max 바이트(UTF-8) 이하 — 글자를 반으로 자르지 않는다
    $enc = [System.Text.Encoding]::UTF8
    if ($enc.GetByteCount($Text) -le $Max) { return $Text }
    $lo = 0; $hi = $Text.Length
    while ($lo -lt $hi) {
        $mid = [int][math]::Floor(($lo + $hi) / 2)
        if ($enc.GetByteCount($Text.Substring($mid)) -le $Max) { $hi = $mid } else { $lo = $mid + 1 }
    }
    if ($lo -lt $Text.Length -and [char]::IsLowSurrogate($Text[$lo])) { $lo++ }
    return $Text.Substring($lo)
}

function Get-RemoteHelpHeadBytes([string]$Text, [int]$Max) {
    $enc = [System.Text.Encoding]::UTF8
    if ($enc.GetByteCount($Text) -le $Max) { return $Text }
    $lo = 0; $hi = $Text.Length
    while ($lo -lt $hi) {
        $mid = [int][math]::Ceiling(($lo + $hi) / 2)
        if ($enc.GetByteCount($Text.Substring(0, $mid)) -le $Max) { $lo = $mid } else { $hi = $mid - 1 }
    }
    if ($lo -gt 0 -and [char]::IsHighSurrogate($Text[$lo - 1])) { $lo-- }
    return $Text.Substring(0, $lo)
}

# ── 재검사 — 번들 표·같은 문법(서버 코드를 가져오지 않은 독립 구현 · 맥판 JavaScript 와 한 줄씩 대응) ──
function Test-RemoteHelpSeq($Value) {
    # 양의 안전 정수만(1.5·"6"·2^53 은 아니다) — 형을 먼저 본다
    if (-not ($Value -is [int] -or $Value -is [long])) { return $false }
    return ($Value -gt 0 -and $Value -le 9007199254740991)
}

function Test-RemoteHelpPath($Table, [string]$Shell, [string]$Value) {
    if ($Value -cmatch '\A[\\/]' -or $Value.Contains(':')) { return $false }
    if ($Shell -ceq 'sh' -and $Value.Contains('\')) { return $false }
    $segments = $Value -split '[\\/]'
    if ($segments.Count -gt [int]$Table.max_path_segments) { return $false }
    foreach ($s in $segments) {
        if (-not ($s -cmatch '\A\.?[A-Za-z0-9_][A-Za-z0-9_.-]{0,62}\z')) { return $false }
        if ($s.EndsWith('.')) { return $false }
        # 장치 이름은 대소문자를 가리지 않는다(CON·con 둘 다 장치다)
        if ($s -imatch '\A(con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|\z)') { return $false }
    }
    return $true
}

function Test-RemoteHelpSlot($Table, [string]$Shell, [string]$Slot, [string]$Value) {
    if ($Slot -ceq '<path>') { return (Test-RemoteHelpPath $Table $Shell $Value) }
    if ($Slot -ceq '<proc>') { return (@($Table.proc_names) -ccontains $Value) }
    if ($Slot -cmatch '\A<n:([0-9]+)-([0-9]+)>\z') {
        $lo = [int]$Matches[1]; $hi = [int]$Matches[2]
        if (-not ($Value -cmatch '\A(0|[1-9][0-9]{0,3})\z')) { return $false }
        return ([int]$Value -ge $lo -and [int]$Value -le $hi)
    }
    return ($Slot -ceq $Value)
}

function Test-RemoteHelpArgv($Table, [string]$Shell, $Argv) {
    # 돌려주는 것 = @{ Ok = $true; Entry = <표 줄>; Argv = <string[]> } 또는 @{ Ok = $false; Rule = '<규칙>' }
    if ($null -eq $Argv -or -not ($Argv -is [array]) -or $Argv.Count -eq 0) { return @{ Ok = $false; Rule = 'empty' } }
    if ($Argv.Count -gt [int]$Table.max_tokens) { return @{ Ok = $false; Rule = 'too_many_tokens' } }
    $tokenPattern = '\A(?:' + ([string]$Table.token_pattern).TrimStart('^').TrimEnd('$') + ')\z'
    foreach ($v in $Argv) {
        if (-not ($v -is [string]) -or $v.Length -eq 0) { return @{ Ok = $false; Rule = 'empty' } }
        if ($v.Length -gt [int]$Table.max_token_chars -or -not ($v -cmatch $tokenPattern)) { return @{ Ok = $false; Rule = 'char' } }
    }
    $tokens = [string[]]$Argv
    if ([System.Text.Encoding]::UTF8.GetByteCount(($tokens -join ' ')) -gt [int]$Table.max_command_bytes) { return @{ Ok = $false; Rule = 'too_long' } }
    $named = @($Table.entries | Where-Object { $_.shell -ceq $Shell -and ($_.usage -split ' ')[0] -ceq $tokens[0] })
    if ($named.Count -eq 0) { return @{ Ok = $false; Rule = 'unknown_command' } }
    foreach ($entry in $named) {
        $slots = $entry.usage -split ' '
        if ($slots.Count -ne $tokens.Count) { continue }
        $all = $true
        for ($i = 1; $i -lt $slots.Count; $i++) {
            if (-not (Test-RemoteHelpSlot $Table $Shell $slots[$i] $tokens[$i])) { $all = $false; break }
        }
        if ($all) { return @{ Ok = $true; Entry = $entry; Argv = $tokens } }
    }
    return @{ Ok = $false; Rule = 'usage_mismatch' }
}

# ── 실행 번호 기록 — 없으면 빈 목록 · 있는데 못 읽거나 깨졌으면 $null(아무것도 실행하지 않는다) ──
function Read-RemoteHelpExecuted {
    if (-not (Test-Path -LiteralPath $RemoteHelpSeqFile)) { return ,([long[]]@()) }
    $raw = $null
    try { $raw = [System.IO.File]::ReadAllText($RemoteHelpSeqFile, [System.Text.Encoding]::UTF8) } catch { return $null }
    $parsed = $null
    try { $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop } catch { return $null }
    if (-not ($parsed -is [array])) { return $null }
    foreach ($s in $parsed) { if (-not (Test-RemoteHelpSeq $s)) { return $null } }
    return ,([long[]]@($parsed))
}

function Save-RemoteHelpExecuted([long]$Seq) {
    # 돌려주는 것 = 'OK' · 'ALREADY' · 'LOCKED' · 'FAIL' — 임시 파일에 쓴 뒤 바꿔 끼운다(반쯤 쓴 기록을 남기지 않는다)
    #   두 창이 같은 번호를 동시에 남기지 못하게 이름 있는 잠금(Mutex)을 잡는다(검토 지적 — 잠금 없이 둘이 함께 읽으면 둘 다 OK 였다).
    #   2초 안에 못 잡으면 LOCKED(실행하지 않는다) · 앞 주인이 잠근 채 죽었으면(AbandonedMutexException) 넘겨받는다.
    #   쓴 바이트는 Flush($true) 로 디스크까지 내린 뒤 바꿔 끼운다(전원 단절 내구성).
    $mutex = New-Object System.Threading.Mutex($false, 'Local\JarvisRemoteHelpSeq')
    $held = $false
    try {
        try { $held = $mutex.WaitOne(2000) } catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { return 'LOCKED' }
        $executed = Read-RemoteHelpExecuted
        if ($null -eq $executed) { return 'FAIL' }
        if ($executed -contains $Seq) { return 'ALREADY' }
        $json = '[' + ((@($executed) + $Seq | ForEach-Object { [string]$_ }) -join ',') + ']'
        $tmp = $RemoteHelpSeqFile + '.tmp'
        try {
            $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($json)
            $fs = New-Object System.IO.FileStream($tmp, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try { $fs.Write($bytes, 0, $bytes.Length); $fs.Flush($true) } finally { $fs.Dispose() }
            # ⚠백업 이름 자리에 $null 을 넘기면 PowerShell 이 빈 글("")로 바꿔 넘긴다 → Replace 가 「올바르지 않은 경로」로 던진다(첫 번호만 남고 그 뒤 명령은 FAIL 로 실행되지 않는다) — 진짜 null 은 [NullString]::Value
            if (Test-Path -LiteralPath $RemoteHelpSeqFile) { [System.IO.File]::Replace($tmp, $RemoteHelpSeqFile, [NullString]::Value) } else { [System.IO.File]::Move($tmp, $RemoteHelpSeqFile) }
        } catch { return 'FAIL' }
        $back = Read-RemoteHelpExecuted
        if ($null -eq $back -or -not ($back -contains $Seq)) { return 'FAIL' }
        return 'OK'
    } finally {
        if ($held) { try { $mutex.ReleaseMutex() } catch { } }
        $mutex.Dispose()
    }
}

# ── 경로 봉쇄 — 성분마다 재분석점(정션·심볼릭 링크)을 풀어 실제 경로로 · 끊어진 링크·고리 = $null ──
function Get-RemoteHelpCanonical([string]$Path, [int]$Depth = 0) {
    if ($Depth -gt 40) { return $null }
    $full = $null
    try { $full = [System.IO.Path]::GetFullPath($Path) } catch { return $null }
    $drive = [System.IO.Path]::GetPathRoot($full)
    if (-not $drive) { return $null }
    $current = $drive
    foreach ($seg in $full.Substring($drive.Length).Split([char[]]@('\', '/'), [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $next = Join-Path $current $seg
        $item = Get-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) { return $null }
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $target = @($item.Target)[0]
            if (-not $target) { return $null }
            if (-not [System.IO.Path]::IsPathRooted($target)) { $target = Join-Path $current $target }
            $current = Get-RemoteHelpCanonical $target ($Depth + 1)
            if (-not $current) { return $null }
        } else {
            $current = $next
        }
    }
    return $current
}

function Resolve-RemoteHelpPath([string]$Rel) {
    # 작업 폴더에 한 성분씩 붙이며, 있는 성분마다 실제 경로가 작업 폴더의 실제 경로 안(성분 경계)인지 본다.
    #   돌려주는 것 = @{ Real = <실제 경로>; Rule = '' } · 밖 = Rule 'path_outside' · 없는 폴더 안의 이름 = Rule 'path_missing'
    #   아직 없는 성분은 링크일 수 없어 그대로 붙인다 — 단 **마지막 성분일 때만**(그 뒤에 성분이 더 있으면 열 실제 부모가 없다).
    $root = Get-RemoteHelpCanonical $JarvisHome
    if (-not $root) { return @{ Real = ''; Rule = 'path_outside' } }
    $current = $root
    $segments = $Rel.Split([char[]]@('\', '/'))
    for ($i = 0; $i -lt $segments.Count; $i++) {
        $next = Join-Path $current $segments[$i]
        $item = Get-Item -LiteralPath $next -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            if ($i -lt $segments.Count - 1) { return @{ Real = ''; Rule = 'path_missing' } }
            return @{ Real = $next; Rule = '' }
        }
        $real = Get-RemoteHelpCanonical $next
        if (-not $real) { return @{ Real = ''; Rule = 'path_outside' } }
        # 성분 경계 — install-jarvis-evil 은 install-jarvis 안이 아니다 · 대소문자는 가리지 않는다(윈도우 경로)
        if (-not ($real -ieq $root) -and -not $real.StartsWith($root.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return @{ Real = ''; Rule = 'path_outside' } }
        $current = $real
    }
    return @{ Real = $current; Rule = '' }
}

function Get-RemoteHelpCysPath {
    # 설치기가 이미 쓰는 cys 찾기 규칙(Test-CysBody) · 절대 경로의 cys.exe 만 · PATH 조회 없음
    $b = Test-CysBody
    if ($b.Cli -and [System.IO.Path]::IsPathRooted($b.Cli) -and ((Split-Path -Leaf $b.Cli) -ieq 'cys.exe') -and (Test-Path -LiteralPath $b.Cli -PathType Leaf)) { return $b.Cli }
    return ''
}

function Invoke-RemoteHelpStreamRead([string]$Name, $Stream, [int]$Tail) {
    # 연 핸들로 읽는다 — 이름을 다시 열지 않는다. 돌려주는 것 = Invoke-RemoteHelpLaunch 와 같다 · 핸들은 여기서 닫는다.
    #   60초 상한 = 같은 프로세스 안의 따로 도는 러너(핸들은 프로세스를 못 건넌다 — Start-Job 은 새 프로세스라 쓸 수 없다).
    #   시간을 넘기면 핸들을 먼저 닫아 읽기를 끊고 러너를 멈춘다(.NET 호출 한가운데서는 즉시 안 멈출 수 있다 · 윈도우 실기 필요).
    if ($null -eq $Stream) {
        # 못 열었다(없는 이름·권한) — Test-Path 의 답은 「없다」 · 읽기 명령은 실패를 말한다(이름을 다시 열지 않는다)
        if ($Name -ceq 'Test-Path') { return @{ Refused = ''; Rc = 0; TimedOut = $false; Output = "False`r`n" } }
        return @{ Refused = ''; Rc = 1; TimedOut = $false; Output = "cannot open`r`n" }
    }
    $runner = [System.Management.Automation.PowerShell]::Create()
    try {
        [void]$runner.AddScript({
            param($name, $stream, $tail)
            if ($name -ceq 'Test-Path') { return 'True' }
            if ($name -ceq 'Get-FileHash') { return (Get-FileHash -InputStream $stream -Algorithm SHA256 | Format-List Algorithm, Hash | Out-String -Width 160) }
            # Get-Content -Tail 과 같은 뜻 — 5.1 기본 인코딩으로 읽고(BOM 이 있으면 그것) 끝 N줄만 남긴다
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::Default, $true)
            $keep = New-Object System.Collections.Generic.Queue[string]
            while ($null -ne ($line = $reader.ReadLine())) {
                $keep.Enqueue($line)
                if ($keep.Count -gt $tail) { [void]$keep.Dequeue() }
            }
            return (@($keep) -join "`r`n")
        }).AddArgument($Name).AddArgument($Stream).AddArgument($Tail)
        $async = $runner.BeginInvoke()
        if (-not $async.AsyncWaitHandle.WaitOne($RemoteHelpCmdTimeout * 1000)) {
            $Stream.Dispose()
            try { [void]$runner.BeginStop($null, $null) } catch { }
            return @{ Refused = ''; Rc = $null; TimedOut = $true; Output = '' }
        }
        $out = @()
        try { $out = @($runner.EndInvoke($async)) } catch { }
        $errors = ($runner.Streams.Error | Out-String -Width 160)
        return @{ Refused = ''; Rc = $(if ($runner.HadErrors) { 1 } else { 0 }); TimedOut = $false; Output = (($out | Out-String -Width 160) + $errors) }
    } finally {
        $Stream.Dispose()
        $runner.Dispose()
    }
}

function Invoke-RemoteHelpLaunch($Entry, [string[]]$Argv, [string]$RealPath, [int]$PathIndex) {
    # 돌려주는 것 = @{ Refused = '<규칙>' 또는 ''; Rc; TimedOut; Output }
    # 두 모양뿐이다 — cmdlet + 이름-값 해시테이블 · cys 절대 경로 + 인자 배열. 명령줄 글을 만들지 않는다.
    $cwd = Get-RemoteHelpCanonical $JarvisHome
    if (-not $cwd) { return @{ Refused = 'path_outside' } }
    $values = New-Object System.Collections.Generic.List[string]
    for ($i = 1; $i -lt $Argv.Count; $i++) { $values.Add($Argv[$i]) }
    $stream = $null
    $isFolder = $false
    if ($PathIndex -ge 1) {
        # 경로 칸은 **먼저 열고 · 연 뒤에 다시 확인하고 · 연 핸들로 읽는다**(검토 지적 BLOCKER — 이름을 확인한 뒤 cmdlet 이 그 이름을
        #   다시 열면 그 사이에 정션·링크로 바꿔 끼운 것을 따라간다).
        #   ①마지막 성분이 재분석점이면 거부 ②파일이면 읽기 핸들을 연다 — 공유 = 읽기만(지우기·이름 바꾸기를 막는다 · 열린 파일이 든 폴더도
        #   이름을 못 바꾼다) ③연 뒤 다시 — 재분석점이거나 실제 이름이 달라졌으면 거부 ④읽기는 그 핸들로(Invoke-RemoteHelpStreamRead).
        #   ⚠폴더는 .NET 핸들을 열 수 없다 — 다시 확인까지만 하고 cmdlet 에 이름을 준다(잔여 · 윈도우 실기 필요).
        $leaf = Get-Item -LiteralPath $RealPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $leaf -and ($leaf.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return @{ Refused = 'path_changed' } }
        if ($null -eq $leaf -or -not $leaf.PSIsContainer) {
            try { $stream = [System.IO.File]::Open($RealPath, 'Open', 'Read', 'Read') } catch { $stream = $null }
        }
        $again = Get-Item -LiteralPath $RealPath -Force -ErrorAction SilentlyContinue
        # 연 뒤의 불일치 = path_outside(계약 9-4 ④ — 연 것이 작업 폴더 안의 그 이름이라고 말할 수 없다)
        if ($null -ne $again -and (($again.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or -not ($again.FullName -ieq $RealPath))) {
            if ($null -ne $stream) { $stream.Dispose() }
            return @{ Refused = 'path_outside' }
        }
        $isFolder = ($null -ne $again -and $again.PSIsContainer)
        if ($null -ne $stream -and ($null -eq $again -or $isFolder)) { $stream.Dispose(); return @{ Refused = 'path_outside' } }
        $values[$PathIndex - 1] = $RealPath
    }
    if ($Entry.exec -ceq 'cmdlet') {
        $params = @{}
        for ($i = 0; $i + 1 -lt $values.Count; $i += 2) { $params[$values[$i].Substring(1)] = $values[$i + 1] }
        if ($PathIndex -ge 1 -and -not $isFolder -and ($Argv[0] -ceq 'Get-Content' -or $Argv[0] -ceq 'Get-FileHash' -or $Argv[0] -ceq 'Test-Path')) {
            $tail = 0
            if ($params.ContainsKey('Tail')) { $tail = [int]$params['Tail'] }
            return (Invoke-RemoteHelpStreamRead $Argv[0] $stream $tail)
        }
        if ($null -ne $stream) { $stream.Dispose() }
        $job = Start-Job -ScriptBlock {
            param($name, $params, $cwd)
            Set-Location -LiteralPath $cwd
            $state = @{ Ok = $true }
            $command = Get-Command -Name $name -CommandType Cmdlet -ErrorAction Stop
            $text = & $command @params 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $state.Ok = $false }; $_ } | Out-String -Width 160
            [pscustomobject]@{ Output = $text; Rc = $(if ($state.Ok) { 0 } else { 1 }) }
        } -ArgumentList $Argv[0], $params, $cwd
    } elseif ($Entry.exec -ceq 'cys') {
        $cysPath = Get-RemoteHelpCysPath
        if (-not $cysPath) { return @{ Refused = 'cys_not_found' } }
        $cysArgs = $values.ToArray()
        $job = Start-Job -ScriptBlock {
            param($cysPath, $cysArgs, $cwd)
            Set-Location -LiteralPath $cwd
            # 표의 읽기 명령이 cys 데몬을 깨우지 않게 한다(설치기가 자기 조회에 거는 것과 같은 안전장치 · 검토 지적)
            $prev = $env:CYS_NO_AUTOSTART
            $env:CYS_NO_AUTOSTART = '1'
            try {
                $text = & $cysPath @cysArgs 2>&1 | Out-String -Width 160
                $rc = $LASTEXITCODE
            } finally { $env:CYS_NO_AUTOSTART = $prev }
            [pscustomobject]@{ Output = $text; Rc = $rc }
        } -ArgumentList $cysPath, $cysArgs, $cwd
    } else {
        return @{ Refused = 'exec' }
    }
    $done = Wait-Job -Job $job -Timeout $RemoteHelpCmdTimeout
    if ($null -eq $done) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return @{ Refused = ''; Rc = $null; TimedOut = $true; Output = '' }
    }
    $result = @(Receive-Job -Job $job -ErrorAction SilentlyContinue 2>&1)
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    $last = $result | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['Output'] } | Select-Object -Last 1
    if ($null -eq $last) { return @{ Refused = ''; Rc = 1; TimedOut = $false; Output = ($result | Out-String -Width 160) } }
    return @{ Refused = ''; Rc = $last.Rc; TimedOut = $false; Output = [string]$last.Output }
}

function Send-RemoteHelpAck([long]$Seq, [string]$Status, $Rc, [string]$Tail) {
    $body = [ordered]@{ seq = $Seq; status = $Status; rc = $Rc; output_tail = $Tail } | ConvertTo-Json -Compress
    return (Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/ack') $body).Code
}

function Send-RemoteHelpDecline([long]$Seq, [string]$Rule) {
    # 돌려주는 것 = 0 계속 · 3 서버가 닫았다(410)
    if ((Send-RemoteHelpAck $Seq 'declined' $null ('policy:' + $Rule)) -eq 410) { return 3 }
    return 0
}

function Invoke-RemoteHelpCommand([long]$Seq, $Entry, [string[]]$Argv) {
    # 계약 9-4절 3~7 — 표·문법을 통과한 명령 하나. 돌려주는 것 = Invoke-RemoteHelpTick 과 같다.
    $slots = $Entry.usage -split ' '
    $pathIndex = -1; $rel = ''; $first = $null
    for ($i = 1; $i -lt $slots.Count; $i++) {
        if ($slots[$i] -ceq '<path>') {
            if ($pathIndex -ge 0) { return (Send-RemoteHelpDecline $Seq 'path_count') }
            $pathIndex = $i; $rel = $Argv[$i]
            # 밖(path_outside) · 없는 폴더 안의 이름(path_missing) — 표시·번호 기록 **전에** 거절한다
            $first = Resolve-RemoteHelpPath $rel
            if ($first.Rule) { return (Send-RemoteHelpDecline $Seq $first.Rule) }
        }
    }
    if (-not ($Entry.exec -ceq 'cmdlet' -or $Entry.exec -ceq 'cys')) { return (Send-RemoteHelpDecline $Seq 'exec') }
    if ($Entry.exec -ceq 'cys' -and -not (Get-RemoteHelpCysPath)) { return (Send-RemoteHelpDecline $Seq 'cys_not_found') }
    # 4 명령 글 = argv 를 공백 한 칸으로 이은 것 · 확인 대기 없이 창에 찍는다
    Say ('     운영팀 명령: ' + ($Argv -join ' '))
    # 5 번호를 실행 **전에** 남긴다 — 이미 있으면 다시 돌리지 않는다 · 못 남기면 실행 0 · 다른 창이 기록 중이면 거절(policy:seq_lock)
    $saved = Save-RemoteHelpExecuted $Seq
    if ($saved -ceq 'ALREADY') { return 0 }
    if ($saved -ceq 'LOCKED') { return (Send-RemoteHelpDecline $Seq 'seq_lock') }
    if ($saved -cne 'OK') { Say '     실행 기록을 남기지 못해 이 명령을 실행하지 않고 멈춥니다.'; return 2 }
    # 6 경로를 실행 직전에 한 번 더 푼다 — 처음과 다르면(그 사이 링크가 생겼다 · 폴더가 사라졌다) 실행하지 않는다
    $real = @{ Real = ''; Rule = '' }
    if ($pathIndex -ge 1) {
        $real = Resolve-RemoteHelpPath $rel
        if ($real.Rule -or -not ($real.Real -ieq $first.Real)) { return (Send-RemoteHelpDecline $Seq 'path_changed') }
    }
    $run = Invoke-RemoteHelpLaunch $Entry $Argv $real.Real $pathIndex
    if ($run.Refused) { return (Send-RemoteHelpDecline $Seq $run.Refused) }
    # 7 결과 — 끝 4KB · 보고 때 모은 이름으로 스크럽
    $output = [string]$run.Output
    $rc = $run.Rc
    if ($run.TimedOut) { $output = $output + "`ntimeout:" + $RemoteHelpCmdTimeout + 's'; $rc = $null }
    $tail = Get-RemoteHelpTailBytes (Invoke-RemoteHelpScrub $output $script:RhNames) 4096
    if ((Send-RemoteHelpAck $Seq 'ran' $rc $tail) -eq 410) { return 3 }
    return 0
}

function Show-RemoteHelpAnswer($Poll) {
    # 처방 표시 — 운영팀 글이라도 화면 제어 글자(색·커서·방향 바꿈)는 지우고, 바뀌었을 때만 한 번 찍는다
    $answer = $Poll.answer
    if ($null -eq $answer -or -not ($answer.text -is [string])) { return }
    $number = ''
    if ($answer.action_no -is [int] -or $answer.action_no -is [long]) { $number = '(조치 ' + $answer.action_no + ')' }
    $class = (@(@(0x00, 0x09), @(0x0B, 0x1F), @(0x7F, 0x9F), @(0x200E, 0x200F), @(0x202A, 0x202E), @(0x2066, 0x2069)) | ForEach-Object {
        [regex]::Escape([string][char]$_[0]) + '-' + [regex]::Escape([string][char]$_[1])
    }) -join ''
    $text = [regex]::Replace($answer.text, '[' + $class + ']', '')
    $shown = '     처방' + $number + ': ' + (($text -split "`r?`n") -join ("`n" + '       '))
    if ($shown -cne $script:RhLastAnswer) {
        $script:RhLastAnswer = $shown
        Say $shown
    }
}

# 계약 7-8절 과 같은 뜻 — ⚠이 파일은 사람에게 「줄」을 말하지 않는다 · 다시 하는 방법은 끝맺음이 명령 전체로 인쇄한다
function Show-RemoteHelpEnded {
    Say '     원격 해결이 끝났습니다 · 아래 「다시 하시는 법」대로 다시 실행하시면 새 보고로 이어집니다.'
    $script:ShowRerun = $true
}

function Invoke-RemoteHelpTick([string]$Text) {
    # 돌려주는 것 = 0 계속 · 1 대화 닫힘 · 2 실행 기록을 못 믿어 멈춤 · 3 서버가 닫았다(410)
    $poll = $null
    try { $poll = ConvertFrom-Json -InputObject $Text -ErrorAction Stop } catch { return 0 }
    if ($null -eq $poll) { return 0 }
    Show-RemoteHelpAnswer $poll
    $session = $poll.session
    if ($null -eq $session -or -not ($session.open -is [bool]) -or -not $session.open) { return 1 }
    $executed = Read-RemoteHelpExecuted
    if ($null -eq $executed) { Say '     실행 기록 파일을 읽을 수 없어 명령을 실행하지 않고 멈춥니다.'; return 2 }
    $table = ConvertFrom-Json -InputObject $RemoteHelpTableJson
    foreach ($m in @($session.messages)) {
        if (-not ($m -is [System.Management.Automation.PSCustomObject])) { continue }
        if (-not ($m.kind -is [string]) -or -not ($m.kind -ceq 'command')) { continue }
        if (-not (Test-RemoteHelpSeq $m.seq)) { continue }
        $seq = [long]$m.seq
        if (-not ($m.ack -is [System.Management.Automation.PSCustomObject]) -or -not ($m.ack.status -is [string]) -or -not ($m.ack.status -ceq 'pending')) { continue }
        if (-not ($m.sig -is [string]) -or -not ($m.sig -cmatch '\A[0-9a-f]{64}\z')) { continue }
        if ($executed -contains $seq) { continue }
        if (-not ($m.shell -is [string]) -or -not ($m.shell -ceq 'ps1')) {
            if ((Send-RemoteHelpDecline $seq 'shell') -eq 3) { return 3 }
            continue
        }
        if (-not ($m.table_version -is [string]) -or -not ($m.table_version -ceq $table.version)) {
            if ((Send-RemoteHelpDecline $seq 'table_version') -eq 3) { return 3 }
            continue
        }
        # 명령의 글 칸은 읽지 않는다 — 실행에 닿는 입력은 argv 하나뿐이다
        $verdict = Test-RemoteHelpArgv $table 'ps1' $m.argv
        if (-not $verdict.Ok) {
            if ((Send-RemoteHelpDecline $seq $verdict.Rule) -eq 3) { return 3 }
            continue
        }
        $state = @(Invoke-RemoteHelpCommand $seq $verdict.Entry $verdict.Argv)[-1]
        if ($state -ne 0) { return $state }
    }
    return 0
}

function Save-RemoteHelpToken([string]$Token) {
    # 출처 토큰은 이 기계에만 두고 본인만 읽게 한다(상속 권한을 끊고 지금 사용자 하나만).
    #   돌려주는 것 = $true 두었다 · $false 못 두었다(파일을 지웠다 — 부르는 쪽이 토큰을 메모리에서도 버린다).
    #   ★권한을 **먼저** 건 빈 파일을 만든 뒤 쓴다(검토 지적) — 앞 판은 토큰을 쓴 뒤 권한을 걸어, 권한이 실패하면 상속 권한 파일에 토큰이 남았다.
    try {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RemoteHelpTokenFile)
        [System.IO.File]::WriteAllBytes($full, [byte[]]@())
        $acl = New-Object System.Security.AccessControl.FileSecurity
        $acl.SetAccessRuleProtection($true, $false)
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')))
        Set-Acl -LiteralPath $full -AclObject $acl -ErrorAction Stop
        # 있는 파일에 쓰면 권한은 그대로 남는다(내용만 바뀐다)
        [System.IO.File]::WriteAllText($full, ($Token + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
        return $true
    } catch {
        Remove-Item -LiteralPath $RemoteHelpTokenFile -Force -ErrorAction SilentlyContinue
        Write-Log 'remote help: client token file not restricted - token discarded'
        return $false
    }
}

function Send-RemoteHelpReport {
    # 돌려주는 것 = $true 보고 번호를 받았다
    $envText = ''
    $logText = ''
    try { if (Test-Path -LiteralPath $ReportFile) { $envText = [System.IO.File]::ReadAllText($ReportFile, [System.Text.Encoding]::UTF8) } } catch { }
    # 기록 파일은 Add-Content 기본 인코딩으로 쓰였다 — 같은 기본값으로 읽는다
    try { if (Test-Path -LiteralPath $LogFile) { $logText = (@(Get-Content -LiteralPath $LogFile -Tail 200 -ErrorAction Stop) -join "`n") } } catch { }
    # 멈춘 단계 = 이 실행이 마지막으로 찍은 [n/10]
    $step = '0/10'
    for ($i = $script:StepLog.Count - 1; $i -ge 0; $i--) {
        if ([string]$script:StepLog[$i] -cmatch '\A\[([0-9]{1,2}/[0-9]{1,2})\]') { $step = $Matches[1]; break }
    }
    # 이 컴퓨터가 아는 로그인 이름 — 표시 없이 나와도 지운다(서버는 표시된 이름만 안다)
    $known = @($env:USERNAME, (Split-Path -Leaf $env:USERPROFILE))
    try { $known += [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { }
    $script:RhNames = Get-RemoteHelpNames ($envText + "`n" + $logText) $known
    $fields = [ordered]@{
        code              = $script:JCode
        step              = $step
        os                = 'win'
        installer_version = $InstallerVersion
        env_report        = (Get-RemoteHelpHeadBytes (Invoke-RemoteHelpScrub $envText $script:RhNames) 96000)
        log_tail          = (Get-RemoteHelpTailBytes (Invoke-RemoteHelpScrub $logText $script:RhNames) 128000)
        notice_shown      = $true
    }
    $body = $fields | ConvertTo-Json -Compress
    # 직렬화한 본문을 잰다(검토 지적 — 잘라 낸 글 기준이면 백슬래시 폭탄이 448KB 로 불어 413) · 넘으면 기록 끝 → 환경 보고 순으로
    #   남길 수 있는 가장 긴 길이를 찾아 줄인다(끝을 남기는 칸 · 앞을 남기는 칸)
    foreach ($fit in @(@{ Name = 'log_tail'; Tail = $true }, @{ Name = 'env_report'; Tail = $false })) {
        if ([System.Text.Encoding]::UTF8.GetByteCount($body) -le $RemoteHelpReportMaxBytes) { break }
        $full = [string]$fields[$fit.Name]
        $lo = 0; $hi = [System.Text.Encoding]::UTF8.GetByteCount($full)
        while ($lo -lt $hi) {
            $mid = [int][math]::Ceiling(($lo + $hi) / 2)
            $fields[$fit.Name] = $(if ($fit.Tail) { Get-RemoteHelpTailBytes $full $mid } else { Get-RemoteHelpHeadBytes $full $mid })
            if ([System.Text.Encoding]::UTF8.GetByteCount(($fields | ConvertTo-Json -Compress)) -le $RemoteHelpReportMaxBytes) { $lo = $mid } else { $hi = $mid - 1 }
        }
        $fields[$fit.Name] = $(if ($fit.Tail) { Get-RemoteHelpTailBytes $full $lo } else { Get-RemoteHelpHeadBytes $full $lo })
        $body = $fields | ConvertTo-Json -Compress
    }
    $tries = 0
    while ($true) {
        $r = Invoke-RemoteHelpHttp 'POST' '/api/help' $body
        if ($r.Code -eq 201) { break }
        if (($r.Code -eq 0 -or $r.Code -eq 429 -or $r.Code -ge 500) -and $tries -lt 2) { $tries++; Start-Sleep -Seconds $RemoteHelpPollSec; continue }
        break
    }
    $id = ''
    $token = ''
    if ($r.Code -eq 201) {
        try {
            $resp = ConvertFrom-Json -InputObject $r.Text -ErrorAction Stop
            if ($resp.id -is [string] -and $resp.id -cmatch '\A[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}\z') { $id = $resp.id }
            # 출처 증명 — 64자 16진만 받는다. 없거나 모양이 틀리면 빈 칸(옛 서버 = 헤더 없이 보낸다)
            if ($resp.client_token -is [string] -and $resp.client_token -cmatch '\A[0-9a-f]{64}\z') { $token = $resp.client_token }
        } catch { }
    }
    if (-not $id) {
        Say ('     진단을 보내지 못했습니다(서버 답 ' + $r.Code + '). 위 진단 코드로 안내를 찾아보실 수 있습니다.')
        return $false
    }
    $script:RhId = $id
    Write-Log ('remote help: report ' + $id)
    Remove-Item -LiteralPath $RemoteHelpTokenFile -Force -ErrorAction SilentlyContinue
    if ($token) {
        # 본인만 읽는 파일에 둔 뒤에만 헤더로 쓴다 — 못 두었으면 토큰을 버리고 헤더 없이 보낸다(닫힌 쪽)
        if (Save-RemoteHelpToken $token) {
            $script:RhClientToken = $token
        } else {
            $script:RhClientToken = ''
            Write-Log 'remote help: 출처 헤더 없음(출처 토큰을 본인만 읽는 파일로 두지 못해 버렸다)'
        }
    } else {
        Write-Log 'remote help: 출처 헤더 없음(보고 응답에 client_token 이 없다)'
    }
    Say ('     보고 번호 ' + $id + ' — 운영팀이 곧 봅니다.')
    Say ('     폰에서 보기: ' + $HelpApiUrl + '/help/' + $id)
    Say '     이 창을 열어 두시면 처방과 운영팀 명령이 여기에 나타납니다. 창을 닫으면 멈춥니다.'
    return $true
}

function Watch-RemoteHelp {
    $started = Get-Date
    $lastNote = Get-Date
    while ($true) {
        if (((Get-Date) - $started).TotalSeconds -ge $RemoteHelpMaxSec) {
            Say ('     원격 해결 시간(' + [int]($RemoteHelpMaxSec / 60) + '분)이 끝나 멈춥니다.')
            [void](Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/close') $null)
            return
        }
        $r = Invoke-RemoteHelpHttp 'GET' ('/api/help/' + $script:RhId) $null
        if ($r.Code -eq 200) {
            $state = @(Invoke-RemoteHelpTick $r.Text)[-1]
            if ($state -eq 2) { [void](Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/close') $null); return }
            if ($state -ne 0) { Show-RemoteHelpEnded; return }
        } elseif ($r.Code -eq 404) {
            Say '     보고가 지워져 원격 해결을 멈춥니다.'
            return
        } elseif ($r.Code -eq 410) {
            Show-RemoteHelpEnded
            return
        }
        if (((Get-Date) - $lastNote).TotalSeconds -ge $RemoteHelpNoteEverySec) {
            $lastNote = Get-Date
            Say ('     원격 해결을 기다리는 중입니다 (' + [int][math]::Floor(((Get-Date) - $started).TotalMinutes) + '분 지남 · 최대 ' + [int]($RemoteHelpMaxSec / 60) + '분 · 창을 닫으면 멈춥니다).')
        }
        Start-Sleep -Seconds $RemoteHelpPollSec
    }
}

# 끝맺음(Write-ClosingNote)이 부른다 — [1/10] 고지를 보여 드린 실행에서만.
function Invoke-RemoteHelp {
    if (-not $script:JCode) { return }
    if ($script:ReachedWake) { return }
    if ($Mode -ne 'full') {
        if ($Mode -eq 'dry') { Say '  (dry-run) 원격 해결 진단을 보내지 않았습니다.' }
        return
    }
    Say ''
    Say '  == 막혔을 때 — 원격 해결 =='
    foreach ($line in $RemoteHelpLines) { Say ('   ' + $line) }
    Say ('   자세히: ' + $RemoteHelpNoticeUrl)
    $script:RhOpen = $false
    $exitHook = $null
    try {
        if (Send-RemoteHelpReport) {
            if ($script:HelpStage3) { Say $HelpSentOkLine; $script:HelpSentSaid = $true }
            $script:RhOpen = $true
            # 다음 실행이 「이전 보고」를 말할 수 있게 보고 번호를 남긴다(열린 원격 해결을 닫는 표시 뒤 — 여기서 넘어져도 닫힌다)
            Save-HelpLastReport
            # 엔진이 정상으로 끝날 때도 닫기를 한 번 보낸다(계약 7-7) — 아래 finally 가 먼저 닫으면 등록을 풀어 두 번 보내지 않는다.
            #   이 동작은 따로 도는 자리라 이 파일의 함수를 못 본다 ⇒ 주소·토큰을 넘겨 직접 부른다.
            try {
                $exitHook = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -MessageData @{ Uri = ($HelpApiUrl + '/api/help/' + $script:RhId + '/close'); Token = $script:RhClientToken } -Action {
                    $h = @{}
                    if ($Event.MessageData.Token) { $h['x-help-client'] = $Event.MessageData.Token }
                    try { [void](Invoke-WebRequest -Uri $Event.MessageData.Uri -Method POST -Headers $h -UseBasicParsing -TimeoutSec 5) } catch { }
                }
            } catch { }
            Watch-RemoteHelp
            # 폴링이 스스로 끝났다(410·닫힘·지움은 서버가 이미 닫았고 · 2시간·기록 오류는 Watch 가 닫기를 보냈다)
            $script:RhOpen = $false
        }
    } catch {
        # 원격 해결이 끝맺음을 깨뜨리지 않게 — 「다시 하시는 법」은 그래도 뒤에 나온다
        Write-Log ('remote help: stopped - ' + $_.Exception.Message)
        Say '     원격 해결이 예상하지 못한 자리에서 멈췄습니다.'
    } finally {
        # 어느 길로 끝나도(예외·Ctrl+C 중단) 열린 원격 해결을 닫는다(검토 지적 · 계약 7-7).
        #   ⚠창 X·작업 관리자로 프로세스가 죽으면 이 블록도 돌지 않는다 — 서버가 30분 무명령으로 닫는다(한계 · 윈도우 실기 필요).
        if ($script:RhOpen) {
            $script:RhOpen = $false
            try { [void](Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/close') $null) } catch { }
        }
        if ($null -ne $exitHook) {
            Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
            Remove-Job -Job $exitHook -Force -ErrorAction SilentlyContinue
        }
    }
}

# 시험이 이 파일을 「함수 묶음」으로만 읽는 문(맥판 JARVIS_LIB_ONLY 과 같은 자리·같은 까닭).
#   연결 원인 판별처럼 **부르지 않으면 잴 수 없는 것**을 러너에서 재려면 이 문이 필요하다.
#   ⚠사람이 쓰는 길이 아니다 — 설치기는 이 변수 없이 돈다(없으면 이 줄은 아무 일도 하지 않는다).
if ($env:JARVIS_LIB_ONLY -eq '1') { return }

# ── 본문 ──────────────────────────────────────────────────────────
try {
    # 🔴자리 만들기를 **끝맺음 보증 안쪽**으로 옮겼다(검토 지적 채택 2026-09-09).
    #   앞 판은 이 실패가 try 밖이라, 가장 도움이 필요한 순간에 「다음에 할 일」이 한 줄도 없이 창이 닫혔다.
    #   ⚠까닭을 「권한」 하나로 단정하지 않는다 — 공간이 꽉 찼거나 백신이 막아도 여기서 실패한다.
    # ── 🔴🔴작업 폴더는 **이름을 못 박고, 우리가 만든 자리에만 표식을 놓는다** (3차 검토 N3 · 관리자 결정) ──
    #   앞 판은 `$env:JARVIS_HOME` 값이 무엇이든 `-Force` 로 만들고 **이미 있던 남의 폴더에도 표식을 써 줬다.**
    #   ⇒ 제거기의 「우리 폴더인가」 관문이 그 표식을 소유 증거로 받아 **남의 폴더를 통째로 지웠다**
    #     (`D:\valuable\project` 로 한 번 설치하면 그 다음 지우기가 그 폴더를 재귀 삭제한다).
    #   ★설치기가 표식을 헤프게 놓으면 제거기의 관문은 **관문이 아니다.**
    #   ⇒ 두 관문을 **만들기보다 먼저** 통과해야 한다: ⑴이름이 정확히 install-jarvis ⑵이미 있으면
    #     우리 표식이 있거나 비어 있을 때만 채택. 표식을 못 쓰면 **거기서 멈춘다**(맥판과 같다).
    if ((Split-Path $JarvisHome -Leaf) -ne $JarvisHomeBaseName) {
        Write-Host ("작업 폴더로 쓸 수 없는 자리입니다: " + $JarvisHome)
        Write-Host ("     까닭: 폴더 이름이 「" + $JarvisHomeBaseName + "」 이 아닙니다")
        Write-Host ("     진단 코드: J-HOME-01 — 이 도구가 만들고 지우는 폴더의 이름은 「" + $JarvisHomeBaseName + "」 하나입니다")
        $script:JCode = 'J-HOME-01'
        $script:NextStep = ("JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리(" + (Join-Path $env:USERPROFILE $JarvisHomeBaseName) + ")를 씁니다. 그 자리를 꼭 쓰시려면 이름이 " + $JarvisHomeBaseName + " 이고 아직 만들지 않은 폴더 자리를 지정해 주십시오. 이미 있는 폴더는 이 도구가 놓은 표식이 있을 때만 씁니다.")
        $script:ShowRerun = $true
        exit 3
    }
    $jarvisHomeCreated = $false
    $ownerMarkOk = Test-JarvisOwnerMark
    if (Test-JarvisHomePresent) {
        if (Test-JarvisHomeIsLink) {
            Deny-JarvisHome '그 자리는 다른 곳을 가리키는 이음줄입니다(우리가 만드는 작업 폴더는 이음줄이 아닙니다)' 'JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리를 씁니다.'
        }
        if (-not (Test-Path -LiteralPath $JarvisHome -PathType Container)) {
            Deny-JarvisHome '그 자리에 폴더가 아닌 것이 이미 있습니다' '그 자리의 파일을 옮기시거나, JARVIS_HOME 을 지정하지 않으신 채로 다시 실행해 주십시오.'
        }
        # 🔴🔴**「비어 있으면 채택」을 걷어냈다**(4차 검토 BLOCK N3 확정 2026-09-10 · 맥판과 같다).
        #   ⑴결정은 「자기가 만든 폴더에만 표식」이었는데 **남이 만들어 둔 빈 폴더**도 채택해 표식을 써 줬다.
        #   ⑵`Get-ChildItem` 이 **권한 오류**를 내면 빈 목록으로 읽었다 — 「목록은 못 읽지만 파일은 만들 수
        #     있는」 폴더(남의 파일이 가득한 자리)에 표식을 써 준다.
        #   ⇒ **세지 않는다.** 표식이 없는 기존 폴더는 내용과 무관하게 거부한다(셀 필요가 없으면 틀릴 자리도 없다).
        if (-not $ownerMarkOk) {
            # 구판 지문이면 사람에게 한 번 물어 지울 수 있다(⛔자동 삭제 없음 · 아니면 종전대로 거부).
            if (Invoke-OldHomeCleanup) {
                if (-not (New-JarvisHomeNow)) { Deny-CannotMakeHome }
                $jarvisHomeCreated = $true
            } else {
                Deny-JarvisHome '그 폴더는 이미 있는데 우리 표식이 없습니다(우리가 만든 자리가 아닙니다 — 지울 때 통째로 지우는 자리이므로 채택하지 않습니다)' ('그 폴더를 지우거나 옮기신 뒤 다시 해 주십시오 — 설치 도우미는 자기가 새로 만든 폴더만 씁니다. JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리(' + (Join-Path $env:USERPROFILE $JarvisHomeBaseName) + ')를 씁니다.')
            }
        }
    } else {
        # 🔴🔴**보고 나서 만드는 사이에 남이 그 자리를 만들 수 있다**(맥판과 같은 자리를 같은 방식으로 고쳤다).
        #   만들기가 실패했는데 그 자리가 **생겨 있으면** 그것은 권한 문제가 아니라 **경합**이다.
        #   앞 판은 그 경우도 「자리를 만들지 못했습니다(J-PERM-01)」로 말해 사람을 엉뚱한 데로 보냈다.
        if (New-JarvisHomeNow) {
            $jarvisHomeCreated = $true
        } elseif (Test-JarvisHomePresent) {
            # 경합 — 우리가 만든 자리가 아니다. 기존 폴더와 **같은 잣대**로 다시 잰다(표식도 다시 읽는다).
            $ownerMarkOk = Test-JarvisOwnerMark
            if (Test-JarvisHomeIsLink) {
                Deny-JarvisHome '그 자리는 다른 곳을 가리키는 이음줄입니다(우리가 만드는 작업 폴더는 이음줄이 아닙니다)' 'JARVIS_HOME 을 지정하지 않으신 채로 다시 실행하시면 기본 자리를 씁니다.'
            }
            if (-not (Test-Path -LiteralPath $JarvisHome -PathType Container)) {
                Deny-JarvisHome '그 자리에 폴더가 아닌 것이 이미 있습니다' '그 자리의 파일을 옮기시거나, JARVIS_HOME 을 지정하지 않으신 채로 다시 실행해 주십시오.'
            }
            if (-not $ownerMarkOk) {
                if (Invoke-OldHomeCleanup) {
                    if (-not (New-JarvisHomeNow)) { Deny-CannotMakeHome }
                    $jarvisHomeCreated = $true
                } else {
                    Deny-JarvisHome '그 폴더는 이미 있는데 우리 표식이 없습니다(우리가 만든 자리가 아닙니다 — 지울 때 통째로 지우는 자리이므로 채택하지 않습니다)' ('그 폴더를 지우거나 옮기신 뒤 다시 해 주십시오 — 설치 도우미는 자기가 새로 만든 폴더만 씁니다.')
                }
            }
        } else {
            Deny-CannotMakeHome
        }
    }
    if (-not $ownerMarkOk) {
        try { Write-TextNoBom $JarvisOwnerFile ($JarvisOwnerMark + "`r`n") } catch {
            Write-Host ("작업 폴더 표식을 쓰지 못했습니다: " + (Redact $JarvisOwnerFile))
            Write-Host '     진단 코드: J-PERM-01 — 파일이나 폴더를 쓸 권한이 없습니다(공간 부족·백신 차단도 같은 모양입니다)'
            $script:JCode = 'J-PERM-01'
            $script:NextStep = '저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오. (표식 없이 계속하면 다음 실행이 이 폴더를 「남의 것」으로 읽습니다.)'
            if ($jarvisHomeCreated) { Remove-Item -LiteralPath $JarvisHome -Force -ErrorAction SilentlyContinue }
            exit 3
        }
    }

    Say "=== 자비스 설치 도우미 $BootstrapVersion (모드: $Mode) ==="
    Show-PrevRunNote
    Say '[1/10] 이 컴퓨터를 살펴봅니다.'
    Say ('     ' + $RemoteHelpNotice)
    $script:NoticeShown = $true
    Invoke-DetectStage1
    Invoke-DetectStage2
    Write-Report

    if ($Mode -eq 'detect') {
        Say '감지만 하고 끝냅니다.'
        # 끝맺음 한 줄은 그 끝에 맞아야 한다 — 「살펴보기만 한 끝」에 「이어서 갑니다」는 맞지 않는다.
        Set-NextStepRerun '실제로 설치하시려면 -DetectOnly 없이 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        exit 0
    }

    $rc = Step-InstallClaude; if ($rc -ne 0) { exit $rc }
    $rc = Step-Login;         if ($rc -ne 0) { exit $rc }

    $Rows.Clear()
    Invoke-DetectStage1
    Invoke-DetectStage2
    Write-Report        # 기동 직전 값으로 보고를 갱신한다

    $rc = Step-Prepare; if ($rc -ne 0) { exit $rc }

    # 여기서부터는 한 단이 막혀도 멈추지 않는다.
    # 앞 단계(클로드 설치·로그인·자비스 준비)는 이미 성립했고, 막힌 자리를 사람에게 설명해 주는 것이
    # 그 다음으로 할 수 있는 가장 쓸모 있는 일이기 때문이다. 막힌 단을 적어 두고 자비스를 깨운다.
    foreach ($st in @(
        @{ Name = 'cys 설치 파일 받기'; Fn = { Step-DownloadCys } },
        @{ Name = 'cys 설치';           Fn = { Step-InstallCys } },
        @{ Name = 'cys 확인';           Fn = { Step-VerifyCys } },
        @{ Name = '계정 준비';          Fn = { Step-PrepareAccount } })) {
        # 함수가 화면 말고 출력 스트림에 무언가를 흘리면 반환값이 배열이 된다(이 파일 위쪽의 같은 함정).
        # 그러면 성공한 단계도 막힌 것으로 읽힌다 ⇒ 마지막 값 하나만 종료 코드로 본다.
        $rc = @(& $st.Fn)[-1]
        if ($rc -ne 0) { $script:BlockedStep = $st.Name; break }
    }

    $Rows.Clear()
    Invoke-DetectStage1
    Invoke-DetectStage2
    Write-Report

    # 여기는 마지막 문장이라 반환값이 호출부로 갈 곳도 없다 — 그대로 호스트로 흘려보낸다.
    Step-Wake

} finally {
    # 어느 경로로 끝나도 이 블록을 지난다 — 맥판의 EXIT 트랩과 같은 보증이다.
    Write-ClosingNote
}
