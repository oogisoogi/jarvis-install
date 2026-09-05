# 자비스 설치 도우미 — 윈도우
#
# 하는 일 4가지
#   1) 이 컴퓨터의 상태를 살펴 환경 보고 1장을 쓴다
#   2) 클로드 코드가 없거나 낡았으면 공식 설치기로 설치한다
#   3) 로그인 화면을 열고 승인이 끝날 때까지 기다린다
#   4) 자비스를 깨워 환경 보고를 사람 말로 옮겨 준다
# 같은 줄을 다시 돌리면 끝난 단계는 건너뛰고 이어서 간다.
#
# 쓰는 법
#   powershell -File bootstrap.ps1                 전 단계
#   powershell -File bootstrap.ps1 -DetectOnly     살펴보기만 하고 환경 보고 1장을 쓴 뒤 끝낸다
#   powershell -File bootstrap.ps1 -DryRun         판정은 다 하되 바깥을 바꾸는 행위는 하지 않는다
#
# 배포 한 줄 (사람이 붙여넣는 것 — cmd 창과 PowerShell 창 어느 쪽에서도 같은 줄이 돈다)
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
$CysSiteUrl       = 'https://www.cysinsight.com/'   # 공식 안내 문서가 쓰는 주소 문자열을 그대로 따른다

# ── 자리 ──────────────────────────────────────────────────────────
$JarvisHome = if ($env:JARVIS_HOME) { $env:JARVIS_HOME } else { Join-Path $env:USERPROFILE 'install-jarvis' }
$LogFile       = Join-Path $JarvisHome 'bootstrap.log'
$ReportFile    = Join-Path $JarvisHome 'env-report.md'
$DirectiveFile = Join-Path $JarvisHome 'install-directive.md'
$DlDir         = Join-Path $JarvisHome 'dl'

# cys 설치 파일 — 판본을 파일 이름에 박아 배포하므로 여기에 핀한다.
# 크기가 안 맞으면 받다 끊긴 것이거나 배포가 바뀐 것이다. 어느 쪽이든 진단하고 멈춘다.
$CysVersion     = '0.14.29'
$CysDownloadDir = 'https://www.cysinsight.com/downloads/'
$CysWinFile     = "cys_${CysVersion}_x64-setup.exe"
$CysWinBytes    = 138676916
$CysDownloadUrl = $CysDownloadDir + $CysWinFile

$LoginPollInterval = 3     # 초
$LoginPollTimeout  = 600   # 초 (10분)

# 설치기를 기다리는 한도. 한도가 없으면 백신 경고 창 같은 것이 떠 있는 동안 영원히 서 있게 된다.
$InstallWaitMs    = 300000   # 조용한 설치 (5분)
$InstallGuiWaitMs = 900000   # 설치 창을 띄웠을 때 (15분 · 사람이 누르는 시간)

$Mode = if ($DetectOnly) { 'detect' } elseif ($DryRun) { 'dry' } else { 'full' }

# 바깥 프로그램이 우리말로 낸 글자가 깨져 보이지 않게 한다.
# 깨지면 보기 흉한 데서 끝나지 않는다 — 막힌 자리의 오류 문구를 읽을 수 없게 된다.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
# 위 한 줄은 「우리가 화면에 쓰는 글자」만 정한다. 바깥 프로그램이 낸 글자를 우리가 받아
# 기록 파일로 옮길 때 쓰는 것은 이쪽이다. 한쪽만 맞추면 화면은 멀쩡한데 기록만 깨진다.
$OutputEncoding = [System.Text.Encoding]::UTF8

New-Item -ItemType Directory -Force -Path $JarvisHome | Out-Null

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
    Say "[사람 손 #$($script:HumanHands) · 강제: $who] $what"
}

# 지난 실행이 끝을 알리지 않고 사라졌으면 그 사실과 마지막 줄을 사람에게 보여 준다.
# ⛔진단만 한다 — 백신을 피하거나 끄거나 예외로 등록하지 않는다(이 파일 아래 「우회하지 않는다」 참조).
function Show-PrevRunNote {
    if (-not $script:PrevTail) { return }
    if ($script:PrevTail -match '\[9/9\]|끝냅니다') { return }
    Say '지난번 실행이 끝을 알리지 않고 멈춘 자리가 있습니다. 그때 마지막으로 적힌 줄입니다:'
    Say "       $script:PrevTail"
    Say '     창이 갑자기 닫힌 것이었다면 백신이 PowerShell 을 종료한 것일 수 있습니다.'
    Say '     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다.'
}

function Redact($s) {
    if ($null -eq $s) { return '' }
    return ([string]$s).Replace($env:USERPROFILE, '~')
}

#   `claude auth status` 로 프로브하면 안 된다: 낡은 판본은 그 문자열을 질문으로 읽고 세션을 띄운다
#   판본 숫자로 재지 않는 이유 = 클로드는 자동 판올림이 돌아 「요구 최소 판본」 상수가 곧 낡는다.
function Test-ClaudeAuthCmd {
    $h = (& claude --help 2>$null) -join "`n"
    return ($h -match '(?m)^\s*auth\s')
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
            Add-Row '1-2' '클로드 판본' '-' 'blocked' "파일은 있는데 **이 창의 PATH 에서 안 잡힌다**($(Redact $probeClaude)) — 창을 새로 열면 잡힌다"
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
        [void]$lines.Add('- ⓘ **cys 를 직접 열어 켰습니다.** 자동으로 켜지도록 등록하는 것은 이 계정에서 막혀 있습니다(윈도우 설정).')
        [void]$lines.Add('  다음에 컴퓨터를 켜시면 **cys 를 한 번 열어 주시면** 됩니다 — 그러면 그때부터 다시 돕니다. 따로 하실 일은 없습니다.')
    }
    if ($script:BlockedStep) {
        [void]$lines.Add("- **막힌 단계: $($script:BlockedStep)**")
        [void]$lines.Add('- 앞 단계(클로드 설치·로그인·자비스 준비)는 **이미 끝났습니다.** 여기부터 다시 이어서 갑니다.')
        [void]$lines.Add('- 그 **다음 단계들은 아직 하지 않았습니다** — 실패한 것이 아니라 순서가 안 온 것입니다.')
        [void]$lines.Add('- 같은 한 줄을 다시 돌리면 **끝난 단계는 건너뛰고 막힌 자리부터** 갑니다.')
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

# ── 하는 일 2 — 공식 설치기 호출 (멱등: 이미 있으면 건너뛴다) ─────
function Step-InstallClaude {
    if ($script:ClaudeOk) { Say '[2/11] 클로드가 이미 있습니다 — 건너뜁니다 (멱등).'; return 0 }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Say "[2/11] 이 컴퓨터의 클로드가 낡았습니다. 최신판을 설치합니다."
    }
    if ($Mode -eq 'dry')  { Say "[2/11] (dry-run) 설치기를 부르지 않았습니다. 부를 줄 = irm $ClaudeInstallUrl | iex"; return 0 }

    Say '[2/11] 클로드 코드를 설치합니다. 글자가 주르륵 올라갑니다 — 정상입니다.'
    #   호출부의 `$rc` 가 배열이 되고, 설치에 성공해도 `$rc -ne 0` 이 참이 된다.
    #   `iex` 는 설치기 본문을 현재 프로세스·현재 스코프에서 돌린다. 공식 `install.ps1` 은
    #   ⇒ in-process 로 돌리면 그 `exit` 가 부트스트랩을 통째로 그 자리에서 죽여 아래 실패 안내·
    #   재개 안내가 한 줄도 못 나간다. 맥판 `curl | bash` 는 자식 bash 라 같은 `exit` 가 부모를 못 죽인다
    $psExe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
    try {
        & $psExe -NoProfile -Command "irm '$ClaudeInstallUrl' | iex" | Out-Host
        $installRc = $LASTEXITCODE
    } catch {
        Say "[2/11] 실패: $($_.Exception.Message). 인터넷 연결을 확인해 주십시오. 같은 한 줄을 다시 돌리면 여기서부터 이어서 갑니다."
        return 4
    }
    if ($installRc -ne 0) {
        Say "[2/11] 실패 (종료 코드 $installRc). 같은 한 줄을 다시 돌리면 여기서부터 이어서 갑니다."
        return 4
    }
    #   ⇒ 이 프로세스의 `$env:Path` 를 사용자·시스템 환경변수에서 다시 읽어 붙인다.
    try {
        $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path','User')
    } catch { }
    # 실행 결과 검사 = 설치기의 종료 코드가 아니라 명령이 답하는가
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Say '[2/11] 설치기는 끝났는데 claude 명령이 아직 안 잡힙니다. 창을 새로 열고 다시 돌려 주십시오.'
        return 4
    }
    if (-not (Test-ClaudeAuthCmd)) {
        Say '[2/11] 설치는 끝났는데 아직 낡은 판본이 잡힙니다. 창을 새로 열고 다시 돌려 주십시오.'
        return 4
    }
    $script:ClaudeOk = $true
    Say "[2/11] 완료: $((& claude --version 2>$null | Select-Object -First 1)) ($(Redact (Get-Command claude).Source))"
    return 0
}

# ── 하는 일 3 — 로그인 유도 + 완료 감지 ───────────────────────────
function Step-Login {
    if ($script:LoggedIn) { Say '[3/11] 이미 로그인돼 있습니다 — 건너뜁니다 (멱등).'; return 0 }
    if ($Mode -eq 'dry')  { Say "[3/11] (dry-run) 폴링하지 않았습니다. 간격 $LoginPollInterval 초 · 상한 $LoginPollTimeout 초."; return 0 }

    if (-not (Test-ClaudeAuthCmd)) {
        Say '[3/11] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다.'
        Say '     같은 한 줄을 다시 돌리면 판올림부터 이어서 갑니다.'
        return 6
    }
    Human '벤더' '로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)'
    Say '[3/11] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오.'
    & claude auth login | Out-Host
    Say "     승인이 끝났는지 확인합니다. 최대 $([int]($LoginPollTimeout / 60))분까지 기다립니다."
    $waited = 0
    while ($waited -lt $LoginPollTimeout) {
        $auth = (& claude auth status 2>$null) -join "`n"
        if ($auth -match '"loggedIn"\s*:\s*true') {
            $script:LoggedIn = $true
            Say '[3/11] 로그인 확인했습니다.'
            return 0
        }
        Start-Sleep -Seconds $LoginPollInterval
        $waited += $LoginPollInterval
    }
    Say "[3/11] $([int]($LoginPollTimeout / 60))분 동안 로그인이 확인되지 않았습니다. 같은 한 줄을 다시 돌리면 여기서부터 이어서 갑니다."
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
        foreach ($k in @($JarvisHome, ($JarvisHome -replace '\\','/'))) {
            $o.projects | Add-Member -NotePropertyName $k -NotePropertyValue $trust -Force
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
        Say '     첫 실행 질문(테마·폴더 신뢰·큰 화면 권유)을 미리 넘겨 두었습니다.'
        Write-Log "seed: hasCompletedOnboarding=true · projects.$JarvisHome.hasTrustDialogAccepted=true (되돌리기 = $(Redact $cfg) 삭제)"
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

function Set-AllProfiles {
    $seeded = @()
    foreach ($t in (Get-ProfileTargets)) {
        if (-not (Set-ClaudePrefs $t.Config))      { Human '벤더' "클로드 첫 실행 질문($($t.Name) 자리에 사전 설정을 못 걸었다)" }
        if (-not (Set-ClaudeSettings $t.Settings)) { Human '벤더' "bypass 권한 확인($($t.Name) 자리의 설정 파일을 못 썼다)" }
        $seeded += $t.Name
    }
    Write-Log ("seed profiles: " + ($seeded -join ', '))
    return $seeded
}

function Step-Prepare {
    Write-Directive
    if ($Mode -eq 'dry') {
        Say '[4/11] (dry-run) 사전 설정(.claude.json · settings.json)을 쓰지 않았습니다(바깥 변경 0).'
        return 0
    }
    Set-AllProfiles | Out-Null
    Say '[4/11] 자비스가 쓸 것을 갖춰 두었습니다.'
    return 0
}


# ── 하는 일 5 — cys 설치 파일 받기 ────────────────────────────────
# 완료 판정 = 파일이 있고 크기가 정확히 맞는가. 크기가 다르면 받다 끊긴 것이다.
function Step-DownloadCys {
    New-Item -ItemType Directory -Force -Path $DlDir | Out-Null
    $dst = Join-Path $DlDir $CysWinFile
    if ((Test-Path $dst) -and ((Get-Item $dst).Length -eq $CysWinBytes)) {
        Say '[5/11] 설치 파일이 이미 있습니다 — 건너뜁니다.'
        return 0
    }
    if ($Mode -eq 'dry') { Say "[5/11] (dry-run) 받지 않았습니다. 받을 곳 = $CysDownloadUrl"; return 0 }
    for ($try = 1; $try -le 2; $try++) {
        if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
        Say "[5/11] cys 설치 파일을 받습니다 (약 132MB · 잠시 걸립니다)."
        $pref = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $CysDownloadUrl -OutFile $dst -UseBasicParsing -ErrorAction Stop
        } catch {
            Say "[5/11] 받지 못했습니다: $($_.Exception.Message)"
            continue
        } finally {
            # 실패해서 빠져나가도 이 창의 설정을 원래대로 돌려놓는다.
            $ProgressPreference = $pref
        }
        # 다 받았는데 파일이 없다 = 백신이 그 자리에서 격리했을 때 나는 모양이다.
        # 이것을 크기 불일치로 적으면 망 문제로 오해된다.
        if (-not (Test-Path $dst)) {
            Say '[5/11] 받은 파일이 사라졌습니다 — 백신이 격리했을 수 있습니다.'
            Say '     백신 알림이 떴다면 그 화면의 이름, 대상 파일, 조치(차단·격리·삭제) 세 가지를 알려 주십시오.'
            continue
        }
        $got = (Get-Item $dst -ErrorAction SilentlyContinue).Length
        if ($got -eq $CysWinBytes) { Say '[5/11] 받았습니다 (크기 확인 완료).'; return 0 }
        Say "[5/11] 크기가 맞지 않습니다 (받은 것 $got · 기대 $CysWinBytes). 다시 받습니다."
    }
    # 두 번 다 실패했으면 반쯤 받은 파일을 남기지 않는다 — 다음 실행이 그것을 온전한 것으로 볼 수 있다.
    if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
    Say '[5/11] 설치 파일을 온전히 받지 못했습니다.'
    Say "     공식 페이지에서 직접 받으실 수 있습니다: $CysSiteUrl"
    Say "     받을 파일 이름 = $CysWinFile"
    return 5
}

# ── 하는 일 6 — cys 설치 ──────────────────────────────────────────
# 완료 판정은 설치기의 종료 코드가 아니라 [7]이 성립하는가로 한다.
# 조용히 설치하는 방법은 설치기 종류에 따라 다르고 아직 확인되지 않았다 — 후보를 차례로 시도하고,
# 모두 실패하면 설치 창을 띄워 사람이 진행하게 한다.
function Step-InstallCys {
    if ((Test-CysBody).Body) { Say '[6/11] cys 가 이미 설치돼 있습니다 — 건너뜁니다.'; return 0 }
    if ($Mode -eq 'dry') { Say '[6/11] (dry-run) 설치기를 실행하지 않았습니다.'; return 0 }
    $dst = Join-Path $DlDir $CysWinFile
    if (-not (Test-Path $dst)) { Say '[6/11] 설치 파일이 없습니다.'; return 6 }

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
                Say '[6/11] 지난 설치의 목록 항목만 정리했습니다 (프로그램 실체가 없어 설치가 멈추는 것을 막기 위해서입니다).'
                Say "     되돌리려면 이 파일을 두 번 누르십시오: $(Redact $bkFile)"
                Write-Log "removed stale uninstall entry · backup=$(Redact $bkFile)"
            } else {
                Say '[6/11] 지난 설치의 목록 항목을 백업하지 못해 그대로 두었습니다.'
                Say '     설치가 「먼저 지우겠다」에서 멈추면 그 화면을 알려 주십시오.'
            }
        }
    }

    Human 'OS' '설치 파일 실행 확인 — 처음 보는 프로그램이라 경고 창이 뜰 수 있습니다'
    Say '[6/11] cys 를 설치합니다.'
    Say '     파랗게 「Windows에서 PC를 보호했습니다」 창이 뜨면 [추가 정보] → [실행] 을 눌러 주십시오.'
    Say '     이 창은 서명되지 않은 프로그램에 뜨는 것이며 공식 안내에도 적혀 있습니다.'
    # 안내는 설치기를 띄우기 「전에」 해야 한다 — 백신이 이 창을 종료시키면 뒤에 적은 말은 나오지 못한다.
    Say '     백신이 막았다고 하면 그 화면을 사진으로 남겨 주십시오 — 이름, 대상 파일, 조치(차단·격리·종료) 세 가지가 보이게.'
    Say '     허용을 누를지는 쓰시는 분의 판단입니다. 저희가 대신 예외로 등록하지 않습니다.'
    Say '     이 창이 갑자기 닫히더라도 같은 한 줄을 다시 돌리시면 이어서 진행됩니다.'
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
            if ((Test-CysBody).Body) { Say '[6/11] 설치를 마쳤습니다.'; return 0 }
            Start-Sleep -Seconds 3
        }
        # 앞의 설치기가 아직 돌고 있으면 다음 방법으로 넘어가지 않는다.
        # 그 위에 하나를 더 띄우면 설치기 자신이 「이미 돌고 있다」로 막아, 사람에게는
        # 새 오류가 하나 더 늘어난 것으로만 보인다.
        if ($p -and -not $p.HasExited) {
            Say '     설치 프로그램이 아직 화면에 떠 있는 것 같습니다. 그 창을 먼저 봐 주십시오.'
            Say '     창을 닫으셨거나 끝났는데도 이 줄이 나오면, 같은 한 줄을 다시 돌려 주십시오.'
            break
        }
        # 설치기는 실패를 종류별로 알려 준다. 종료 코드 4 는 「원래 있던 판은 그대로이고 새 판이 안 들어갔다」는 뜻이다.
        # 그리고 무엇을 못 바꿨는지 설치 폴더에 파일로 적어 둔다 — 그것을 그대로 사람에게 보여 준다.
        if ($p -and $p.HasExited -and $p.ExitCode -eq 4) {
            Say '[6/11] 새 판을 넣지 못했습니다. 원래 쓰시던 것은 그대로 있습니다.'
        }
        $note = Join-Path (Join-Path $env:LOCALAPPDATA 'cys') 'cys-install-failure.txt'
        if (Test-Path $note) {
            Say '     설치기가 남긴 기록입니다 (어느 파일을 왜 못 바꿨는지):'
            foreach ($ln in (Get-Content $note -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 12)) { Say "       $ln" }
            Say "     (전문: $(Redact $note))"
        }
        Say '     이 방법으로는 설치되지 않았습니다. 다음 방법을 시도합니다.'
    }
    Say '[6/11] 설치가 확인되지 않았습니다.'
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
    $b = Test-CysBody
    if (-not $b.Body) { Say '[7/11] cys 프로그램을 찾지 못했습니다.'; return 7 }
    Say "[7/11] cys 프로그램을 찾았습니다: $(Redact $b.Path)"
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
    if ($ver) { Say "[7/11] cys 가 답합니다: $ver"; Say "     부르는 길: $(Redact $script:CysCli)"; return 0 }
    Say '[7/11] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. 창을 새로 열고 같은 줄을 다시 돌려 주십시오.'
    return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
function Step-PrepareAccount {
    if ($Mode -eq 'dry') { Say '[8/11] (dry-run) 계정 준비를 하지 않았습니다.'; return 0 }
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    Say '[8/11] 이 계정에 자리를 잡습니다.'
    Invoke-Logged 'init-pack' $cli @('init-pack') | Out-Null
    Invoke-Logged 'daemon install' $cli @('daemon', 'install') | Out-Null
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
            Say '[8/11] 자동으로 켜지도록 등록하지는 못했습니다. 이번에는 프로그램을 직접 열어 보겠습니다.'
            try { Start-Process -FilePath $sideCar | Out-Null } catch { Say "       직접 열지 못했습니다: $($_.Exception.Message)" }
            for ($i = 0; $i -lt 10; $i++) {
                $pong = (& $cli ping 2>&1) -join ' '
                if ($pong -match 'pong') { $alive = $true; break }
                Start-Sleep -Seconds 2
            }
            if ($alive) {
                $script:DaemonTemporary = $true
                Say '[8/11] 켜졌습니다.'
                Say '     자동으로 켜지도록 등록하는 것은 이 계정에서 막혀 있습니다(윈도우 설정).'
                Say '     다음에 컴퓨터를 켜시면 cys 를 한 번 열어 주시면 됩니다. 그러면 그때부터 다시 돕니다.'
                Write-Log 'daemon started by launching the app (auto-start registration blocked by policy)'
            }
        }
    }
    if (-not $alive) {
        Say '[8/11] 준비는 됐는데 아직 응답이 없습니다.'
        # 어느 층에서 멈췄는지 알려 주는 값이 따로 있다 — 추측하지 말고 그것을 그대로 보인다.
        #   등록됐는가 / 올라왔는가 / 창구가 살아 있는가, 셋이 갈라져 나온다.
        Invoke-Logged 'daemon status' $cli @('daemon', 'status') | Out-Null
        # 함께 있어야 할 짝 파일이 실제로 있는지도 본다(다른 운영체제에서 이것이 없어 실패한 전례가 있다).
        $sideCar = Join-Path (Split-Path $cli -Parent) 'cysd.exe'
        Say "       짝 파일 있음 = $(Test-Path $sideCar) ($(Redact $sideCar))"
        Say '     잠시 뒤 같은 줄을 다시 돌려 주십시오. 그래도 같으면 위 세 줄을 알려 주십시오.'
        return 8
    }
    $doc = (Invoke-CysProbe $cli @('doctor')) -join "`n"
    # 자가진단은 마지막에 요약 한 줄을 낸다: 「요약: 11 OK · 1 WARN · 0 FAIL · 1 SKIP(판정 불가)」
    # 그 줄이 정본이다. 항목 표시는 폭을 맞추느라 [OK  ] 처럼 빈칸이 들어가서 표시만 세면 새어 나간다.
    $m = [regex]::Match($doc, '(\d+)\s*OK.*?(\d+)\s*WARN.*?(\d+)\s*FAIL.*?(\d+)\s*SKIP')
    if ($m.Success) {
        $nOk = $m.Groups[1].Value; $nWarn = $m.Groups[2].Value
        $bad = [int]$m.Groups[3].Value; $nSkip = $m.Groups[4].Value
        Say "[8/11] 자가진단: 통과 $nOk · 주의 $nWarn · 실패 $bad · 판정 못 함 $nSkip"
    } else {
        # 요약 줄을 못 찾으면 항목 표시로 센다(문구가 바뀐 경우).
        $bad = [regex]::Matches($doc, '\[FAIL\s*\]').Count
        $nSkip = [regex]::Matches($doc, '\[SKIP\s*\]').Count
        Say "[8/11] 자가진단 요약 줄을 찾지 못해 항목을 세었습니다: 실패 $bad"
    }
    # 통과 기준은 실패 0 이다. 주의는 성한 컴퓨터에도 나온다.
    # 판정 못 한 항목은 「됐다」로 세지 않는다 — 몇 개인지 그대로 알린다.
    if ($bad -gt 0) {
        Say "[8/11] 자가진단에서 $bad 가지가 통과하지 못했습니다."
        Say '     아래 자비스가 무엇이 걸렸는지 사람 말로 알려 드립니다.'
        return 8
    }
    if ([int]$nSkip -gt 0) { Say "     ($nSkip 가지는 이 컴퓨터에서 판정할 수 없는 항목입니다 — 고장이 아닙니다.)" }
    # 자리를 잡으면서 **자비스 전용 설정 자리**가 새로 생긴다. 자비스가 부를 동료들은 그 자리로 뜨므로
    # 사전 설정을 여기서 한 번 더 심는다 — 안 그러면 동료들이 첫 실행 질문 앞에서 멈춰 선다(실측).
    Set-AllProfiles | Out-Null
    Copy-LoginToIsolated | Out-Null
    Say '[8/11] 자리를 잡았습니다 (실패 0).'
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
        Say '[9/11] (dry-run) 자비스를 띄우지 않았습니다.'
        Say "     (지금까지 사람 손이 필요했던 횟수: $($script:HumanHands)번)"
        [void](Step-Fleet '')
        [void](Step-Agora)
        return
    }
    Say '[9/11] 자비스를 깨웁니다.'
    Say "     (지금까지 사람 손이 필요했던 횟수: $($script:HumanHands)번)"
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    # 창 이름도 같은 이유로 ASCII 다 — 이 이름이 거절당한 자리다.
    $surfaceTitle = 'jarvis'
    # 여는 명령에 문장을 실으면 안 된다(2026-09-05 두 번 실측).
    #   1차 = 우리말이 깨져 「알 수 없는 인자」 · 2차 = 명령 안의 따옴표가 벗겨져 문장이 조각나
    #   그 조각 하나가 「알 수 없는 인자」로 갔다. 두 번 다 원인은 「문장을 인자로 넘긴 것」이다.
    # ⇒ 문장은 파일에 넣고, 여는 명령은 그 파일 하나만 가리킨다.
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
            $ref = (& $cli new-surface --role master --cwd $JarvisHome --title $surfaceTitle --cmd $cmd 2>&1) -join ''
        }
        if ($ref -match 'surface:') {
            Say "     cys 안에서 자비스를 열었습니다 ($ref). cys 창에서 이어서 이야기하십시오."
            $m = [regex]::Match($ref, 'surface:\d+')
            $script:WakeRef = $(if ($m.Success) { $m.Value } else { '' })
            # 창이 열렸으면 곧바로 동료들을 부른다. 여기서 부르는 까닭 = 아래 폴백(이 창에서 자비스를
            # 띄우는 길)로 내려가면 그 순간부터 이 스크립트는 자비스 화면에 갇혀 다음 줄을 못 간다.
            [void](Step-Fleet $script:WakeRef)
            # 아고라 참가는 함대와 의존이 없다. 함대가 못 선 가장 흔한 까닭은 그 한마디를 아직 안 치신 것이고,
            # 그것은 고장이 아니다. 고장이 아닌 까닭으로 기능을 없애지 않는다.
            [void](Step-Agora)
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
        Say '[9/11] 자비스를 띄우지 못했습니다 — 클로드 명령을 찾지 못했습니다.'
        Say '     창을 새로 열고 같은 한 줄을 다시 돌려 주십시오.'
        return
    }
    try {
        & claude --dangerously-skip-permissions $firstPrompt
    } catch {
        Say "[9/11] 자비스를 띄우지 못했습니다: $($_.Exception.Message)"
        Say '     창을 새로 열고 같은 한 줄을 다시 돌려 주십시오.'
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
function Get-LiveRoles {
    param([string]$Cli)
    $out = (Invoke-CysProbe $Cli @('list')) -join "`n"
    $live = @()
    foreach ($r in $FleetRoles) {
        # 목록의 role 칸은 role=master · role=worker-2 처럼 나온다. 앞부분이 맞으면 그 역할로 센다.
        if ($out -match ("role=" + [regex]::Escape($r) + "(\s|-|$)")) { $live += $r }
    }
    return $live
}
function Step-Fleet {
    param([string]$SurfaceRef)
    if ($Mode -eq 'dry') { Say '[10/11] (dry-run) 함대를 부르지 않았습니다.'; return 0 }
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    if (-not $SurfaceRef) {
        Say '[10/11] 자비스 창을 못 열어 동료들을 부르지 못했습니다.'
        Say "     cys 창에서 자비스에게 이렇게 말해 주십시오: $FleetTrigger"
        return 10
    }
    Human '자비스' '동료들을 부르는 한마디 — cys 창에서 직접 쳐 주셔야 합니다'
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
        if (($i -gt 0) -and (($i % 12) -eq 0)) {
            Say ("   기다리는 중입니다 ($([int]($waited / 60))분 지남 · 최대 $([int](($FleetWaitTries * 5) / 60))분). 아직 치지 않으셨다면 지금 쳐 주십시오.")
        }
    }
    $missing = @($FleetRoles | Where-Object { $live -notcontains $_ })
    if ($missing.Count -eq 0) {
        Say ("[10/11] 함대가 섰습니다: " + ($live -join ' · '))
        return 0
    }
    # 성공보다 이 문구가 중요하다 — 무엇이 없어서 못 섰는지를 그대로 말한다.
    Say ("[10/11] 아직 서지 않은 자리가 있습니다: " + ($missing -join ' · '))
    Say ("     선 자리 = " + $(if ($live.Count) { $live -join ' · ' } else { '없음' }))
    Say '     아직 그 한마디를 치지 않으셨다면, cys 창에서 지금 쳐 주시면 됩니다.'
    Say '     치셨는데도 서지 않았다면 cys 창의 자비스에게 물어보십시오 — 무엇이 걸렸는지 사람 말로 알려 줍니다.'
    Write-Log ("fleet missing: " + ($missing -join ','))
    return 10
}

# ── 하는 일 11 — 아고라 참가 ───────────────────────────────────────
# 아고라는 여러 자비스가 한자리에 모여 토론하는 곳이다. 이 단은 이 컴퓨터를 그 명부에 올린다.
# 파이썬을 쓰지 않는다. 필요한 것(열쇠 만들기·지문·소유 증명 서명·주고받기)이 전부
# 윈도우에 이미 들어 있다. 프로그램을 하나도 더 깔지 않는다는 뜻이다.
$AgoraRelayUrl = if ($env:AGORA_RELAY_URL) { $env:AGORA_RELAY_URL } else { 'https://agora.godmeyou.kr' }
$AgoraSignNs   = 'jarvis-agora@godmeyou.kr'
$AgoraHome     = if ($env:AGORA_HOME) { $env:AGORA_HOME } else { Join-Path $env:USERPROFILE '.config\agora' }
$AgoraKey      = Join-Path $AgoraHome 'id_ed25519'
$AgoraConf     = Join-Path $AgoraHome 'participant.json'
# 클라이언트 파일은 설치 사이트 사본에서 받는다. 주소가 비어 있으면 그 부분만 건너뛴다
# (명부 등재는 클라이언트 파일과 아무 의존이 없다).
$AgoraCliUrl   = if ($env:AGORA_CLI_URL) { $env:AGORA_CLI_URL } else { '' }
$AgoraCliSha   = if ($env:AGORA_CLI_SHA) { $env:AGORA_CLI_SHA } else { '' }

# 이름에는 사람에 관한 것을 넣지 않는다.
# 컴퓨터 이름을 쓰지 않는 까닭: 이 컴퓨터의 이름은 대개 계정 이름을 담고 있다.
# 읽지 않으면 심사할 것도 없다.
function New-AgoraId {
    # New-Object System.Random 을 쓰지 않는다 — 시각으로 씨를 뿌리므로 같은 순간에 두 번 부르면
    # 똑같은 이름이 나온다. 이름이 겹쳐서 다시 해 보는 자리에서 하필 그 일이 일어난다.
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
    $buf = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt 10; $i++) { [void]$buf.Append($chars[(Get-Random -Minimum 0 -Maximum $chars.Length)]) }
    return ('jarvis-' + $buf.ToString())
}

# 서명 도구가 이 컴퓨터에서 소유 증명을 실제로 만들 수 있는지 본다.
# 판본이 낮으면 -Y 자체를 모른다 — 한 번 서명해 보는 것이 유일하게 확실한 판정이다.
# 열쇠가 암호로 잠겨 있으면 서명 도구가 암호를 물으며 그 자리에서 멈춘다.
# 물어보기 전에 파일만 보고 판별한다 — 잠기지 않은 열쇠는 둘째 줄이 늘 이 글자로 시작한다(실측).
function Test-AgoraKeyOpen {
    if (-not (Test-Path $AgoraKey)) { return $false }
    $lines = Get-Content -LiteralPath $AgoraKey -TotalCount 2 -ErrorAction SilentlyContinue
    if (-not $lines -or $lines.Count -lt 2) { return $false }
    return ([string]$lines[1]).StartsWith('b3BlbnNzaC1rZXktdjEAAAAABG5vbmU')
}

function Test-AgoraSigner {
    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) { return $false }
    if (-not (Test-AgoraKeyOpen)) { Write-Log 'agora: key is locked - not signing'; return $false }
    $probe = Join-Path $AgoraHome '.signprobe'
    try { Write-TextNoBom $probe 'probe' } catch { return $false }
    $ok = $false
    try {
        # 물어볼 입력을 아예 닫아 둔다. 무언가를 묻게 되면 기다리지 않고 그 자리에서 실패한다.
        $null | & ssh-keygen -Y sign -q -n $AgoraSignNs -f $AgoraKey $probe 2>&1 | Out-Null
        $ok = ($LASTEXITCODE -eq 0) -and (Test-Path ($probe + '.sig'))
    } catch { $ok = $false }
    Remove-Item -LiteralPath $probe, ($probe + '.sig') -Force -ErrorAction SilentlyContinue
    return $ok
}

# cys 가 함께 가져온 파이썬을 경로로 찾는다.
# 이름으로만 부르면 컴퓨터에 원래 있던 것이 잡힐 수 있다.
function Get-BundledPython {
    $roots = @()
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA 'cys') }
    if ($env:PROGRAMFILES) { $roots += (Join-Path $env:PROGRAMFILES 'cys') }
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $hit = Get-ChildItem -Path $root -Filter 'python.exe' -Recurse -Depth 6 -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    # cys 창 안에서 돌고 있으면 PATH 에 이미 번들 것이 잡힌다.
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch 'WindowsApps')) { return $cmd.Source }
    return ''
}

# 릴레이에 말을 거는 자리는 여기 하나뿐이다. 주고받는 형태가 바뀌면 이 함수만 고친다.
# 결과: 0 = 올랐다(새로 또는 이미) · 3 = 이름이 이미 다른 열쇠의 것 · 그 밖 = 못 올렸다
function Invoke-AgoraRegister {
    param([string]$ParticipantId, [string]$PublicKey, [string]$Fingerprint)
    $msg = Join-Path $AgoraHome '.register.json'
    # 서명 대상은 다섯 칸을 이 순서로 이어 붙인 것 하나다.
    # 끝에 줄바꿈이나 표시 바이트가 붙으면 다른 것을 서명한 셈이 되므로 그 둘이 없는 쓰기만 쓴다.
    $canon = '{"display_name":"' + $ParticipantId + '","fingerprint":"' + $Fingerprint +
             '","participant_id":"' + $ParticipantId + '","public_key":"' + $PublicKey +
             '","purpose":"agora-register-v1"}'
    Write-TextNoBom $msg $canon
    Remove-Item -LiteralPath ($msg + '.sig') -Force -ErrorAction SilentlyContinue
    $null | & ssh-keygen -Y sign -q -n $AgoraSignNs -f $AgoraKey $msg 2>&1 | Out-Null
    if (($LASTEXITCODE -ne 0) -or -not (Test-Path ($msg + '.sig'))) {
        Write-Log 'agora: sign failed'
        Remove-Item -LiteralPath $msg -Force -ErrorAction SilentlyContinue
        return 1
    }
    $sigLines = Get-Content -LiteralPath ($msg + '.sig')
    $sig = ($sigLines -join '\n') + '\n'
    $body = '{"participant_id":"' + $ParticipantId + '","display_name":"' + $ParticipantId +
            '","public_key":"' + $PublicKey + '","fingerprint":"' + $Fingerprint +
            '","signature":"' + $sig + '"}'
    Remove-Item -LiteralPath $msg, ($msg + '.sig') -Force -ErrorAction SilentlyContinue
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $code = 0
    try {
        $resp = Invoke-WebRequest -Uri ($AgoraRelayUrl + '/register') -Method Post `
                    -ContentType 'application/json' -Body $bytes -TimeoutSec 30 `
                    -UseBasicParsing -ErrorAction Stop
        $code = [int]$resp.StatusCode
        Write-TextNoBom (Join-Path $AgoraHome '.register.resp.json') ([string]$resp.Content)
    } catch {
        # 실패해도 답의 내용이 중요하다 — 무엇이 걸렸는지는 본문에 적혀 있다.
        $r = $_.Exception.Response
        if ($r) {
            try { $code = [int]$r.StatusCode } catch { $code = 0 }
            try {
                $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
                Write-TextNoBom (Join-Path $AgoraHome '.register.resp.json') $sr.ReadToEnd()
                $sr.Close()
            } catch { }
        }
        Write-Log ("agora: register error " + $_.Exception.Message)
    }
    # 응답 코드를 한 줄로 남긴다(맥판과 같은 자리·같은 이름).
    Write-TextNoBom (Join-Path $AgoraHome '.register.http') ([string]$code)
    Write-Log "agora: register http=$code"
    if (($code -eq 201) -or ($code -eq 200)) { return 0 }
    if ($code -eq 409) { return 3 }
    return 4
}

# 명부 사본을 내려받는다. 없어도 등재 자체는 이미 끝난 것이므로 실패로 세지 않는다.
function Sync-AgoraRoster {
    $got = 0
    foreach ($n in @('allowed_signers', 'revoked_keys', 'operators')) {
        try {
            Invoke-WebRequest -Uri ($AgoraRelayUrl + '/participants/' + $n) `
                -OutFile (Join-Path $AgoraHome $n) -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
            $got++
        } catch { Write-Log ("agora: roster $n failed") }
    }
    Write-Log "agora: roster files=$got"
    return ($got -gt 0)
}

# 클라이언트 파일을 받아 놓고, cys 가 가져온 파이썬으로 도는 실행 파일을 하나 만든다.
function Set-AgoraClient {
    if (-not $AgoraCliUrl) { Write-Log 'agora: client url empty - skip'; return $false }
    $py = Get-BundledPython
    if (-not $py) { Write-Log 'agora: bundled python not found'; return $false }
    $zip = Join-Path $AgoraHome '.client.zip'
    try {
        Invoke-WebRequest -Uri $AgoraCliUrl -OutFile $zip -TimeoutSec 120 -UseBasicParsing -ErrorAction Stop
    } catch { Write-Log 'agora: client download failed'; return $false }
    if ($AgoraCliSha) {
        $h = Get-FileHash -LiteralPath $zip -Algorithm SHA256 -ErrorAction SilentlyContinue
        $got = if ($h -and $h.Hash) { ([string]$h.Hash).ToLower() } else { '' }
        # 지문을 못 얻었으면 「맞는지 모른다」이지 「맞다」가 아니다 - 빈 값은 아래 대조에서 반드시 어긋난다.
        if ($got -ne $AgoraCliSha.ToLower()) {
            Write-Log "agora: client sha mismatch got=$got"
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    $lib = Join-Path $AgoraHome 'lib'
    $bin = Join-Path $AgoraHome 'bin'
    [void](New-Item -ItemType Directory -Path $lib -Force -ErrorAction SilentlyContinue)
    [void](New-Item -ItemType Directory -Path $bin -Force -ErrorAction SilentlyContinue)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        # 이 방법은 같은 이름이 이미 있으면 그 자리에서 던진다 — 다시 돌릴 때가 바로 그 자리다.
        # 우리가 만든 폴더이므로 통째로 비우고 새로 푼다(남의 파일은 이 아래에 없다).
        Remove-Item -LiteralPath $lib -Recurse -Force -ErrorAction SilentlyContinue
        [void](New-Item -ItemType Directory -Path $lib -Force -ErrorAction SilentlyContinue)
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $lib)
    } catch {
        Write-Log ('agora: client unzip failed ' + $_.Exception.Message)
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        return $false
    }
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $shim = '@echo off' + "`r`n" + '"' + $py + '" "' + (Join-Path $lib 'bin\agora') + '" %*' + "`r`n"
    Write-TextNoBom (Join-Path $bin 'agora.cmd') $shim
    Write-Log "agora: client placed with $py"
    return $true
}

function Step-Agora {
    if ($Mode -eq 'dry') {
        Say "[11/11] (dry-run) 아고라에 등재하지 않았습니다. 등재할 곳 = $AgoraRelayUrl"
        return
    }
    [void](New-Item -ItemType Directory -Path $AgoraHome -Force -ErrorAction SilentlyContinue)
    # 이름을 정한다. 이미 있으면 그대로 쓴다(다시 돌려도 사고가 되지 않게).
    $participantId = ''
    if (Test-Path $AgoraConf) {
        # 있는지 본 것과 읽히는 것은 다르다(그 사이에 잠길 수 있다). 읽은 값이 빌 수 있다고 보고 다룬다.
        $confRaw = Get-Content -LiteralPath $AgoraConf -Raw -ErrorAction SilentlyContinue
        if ($confRaw) {
            $m = [regex]::Match([string]$confRaw, '"id"\s*:\s*"([^"]*)"')
            if ($m.Success) { $participantId = $m.Groups[1].Value }
        }
    }
    if (-not $participantId) { $participantId = New-AgoraId }
    # 열쇠를 만든다. 이미 있으면 덮어쓰지 않는다 —
    # 덮어쓰면 그 열쇠로 서명한 지난 글을 아무도 확인할 수 없다.
    $madeKey = $false
    if (-not (Test-Path $AgoraKey)) {
        # 빈 암호를 넘기는 자리다. 윈도우에서는 따옴표 두 개를 그대로 넘겨야 받는 쪽이 빈 값으로 읽는다.
        # 그래도 잠긴 열쇠가 만들어질 여지가 있으므로, 바로 아래에서 파일을 보고 다시 확인한다.
        $null | & ssh-keygen -t ed25519 -N '""' -C ('agora:' + $participantId) -f $AgoraKey -q 2>&1 | Out-Null
        if (-not (Test-Path $AgoraKey)) {
            Say '[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠를 만들지 못했습니다).'
            Say '     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다.'
                return
        }
        $madeKey = $true
    }
    # 원인을 하나로 단정하지 않는다. 「열쇠가 잠겼다」와 「도구가 낡았다」는 다른 일이고
    # 사람이 해야 할 일도 다르다 — 앞의 것은 열쇠를 치우면 되고 뒤의 것은 그렇지 않다.
    if (-not (Test-AgoraKeyOpen)) {
        Say '[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠에 암호가 걸려 있습니다).'
        Say ("     " + (Redact $AgoraKey) + " 를 다른 이름으로 옮겨 두시고 같은 줄을 다시 돌리면 새로 만듭니다.")
        Write-Log 'agora: key is locked'
        return
    }
    if (-not (Test-AgoraSigner)) {
        Say '[11/11] 아고라 참가는 지금 하지 못했습니다 (이 컴퓨터의 서명 도구가 낡았습니다).'
        Say '     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다.'
        Write-Log 'agora: signer too old'
        return
    }
    # 값이 비어 있을 수 있는 자리에 바로 점을 찍지 않는다 —
    # 파일이 없거나 못 읽으면 값이 비고, 그때 점을 찍으면 그 자리에서 오류가 뜬다.
    $pubRaw = Get-Content -LiteralPath ($AgoraKey + '.pub') -Raw -ErrorAction SilentlyContinue
    $publicKey = if ($pubRaw) { ([string]$pubRaw).Trim() } else { '' }
    $fingerprint = ''
    $fpOut = ($null | & ssh-keygen -l -f ($AgoraKey + '.pub') 2>&1) -join ' '
    $fm = [regex]::Match($fpOut, 'SHA256:[A-Za-z0-9+/=]+')
    if ($fm.Success) { $fingerprint = $fm.Value }
    if ((-not $publicKey) -or (-not $fingerprint)) {
        Say '[11/11] 아고라 참가는 지금 하지 못했습니다 (참가 열쇠를 읽지 못했습니다).'
        return
    }
    $rc = Invoke-AgoraRegister $participantId $publicKey $fingerprint
    # 이름이 이미 다른 열쇠의 것일 때, 이번에 열쇠를 새로 만들었다면 다른 이름으로 한 번만 다시 해 본다.
    # 열쇠가 원래 있었다면 다시 해도 같은 이유로 막힌다(한 열쇠는 한 이름만 가진다) — 그래서 하지 않는다.
    if (($rc -eq 3) -and $madeKey) {
        $participantId = New-AgoraId
        $rc = Invoke-AgoraRegister $participantId $publicKey $fingerprint
    }
    if ($rc -ne 0) {
        Say '[11/11] 아고라 참가는 지금 하지 못했습니다.'
        Say '     나중에 자비스에게 아고라에 참가해 달라고 말하면 됩니다.'
        return
    }
    $conf = '{' + "`n" + '  "id": "' + $participantId + '",' + "`n" +
            '  "display_name": "' + $participantId + '",' + "`n" +
            '  "key_fingerprint": "' + $fingerprint + '",' + "`n" +
            '  "namespace": "' + $AgoraSignNs + '",' + "`n" +
            '  "operator": false,' + "`n" +
            '  "relay": "' + $AgoraRelayUrl + '"' + "`n" + '}' + "`n"
    Write-TextNoBom $AgoraConf $conf
    if (-not (Sync-AgoraRoster)) { Say '     (참가자 명부 사본은 나중에 받아도 됩니다.)' }
    [void](Set-AgoraClient)
    Say "[11/11] 아고라에 참가했습니다. 이 컴퓨터의 참가 이름은 $participantId 입니다."
    Say ("     이 이름과 열쇠는 " + (Redact $AgoraHome) + " 에 있습니다.")
    # 이 함수의 값은 아무도 쓰지 않는다. 값을 돌려주면 화면에 숫자 한 줄로 새어 나온다.
    return
}

# ── 본문 ──────────────────────────────────────────────────────────
Say "=== 자비스 설치 도우미 $BootstrapVersion (모드: $Mode) ==="
Show-PrevRunNote
Say '[1/11] 이 컴퓨터를 살펴봅니다.'
Invoke-DetectStage1
Invoke-DetectStage2
Write-Report

if ($Mode -eq 'detect') { Say '감지만 하고 끝냅니다.'; exit 0 }

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
