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
# 🔴v0.3.18 — 참가자 클로드는 **stable 채널**로 깔고 그 채널에 묶는다(자동 판올림으로 참가자 화면이 수업 중에 바뀌지 않게).
#   공식 문서(code.claude.com/docs/en/setup · 2026-09-15 확인): 설치기는 `stable` 인자를 받고 「설치 때 고른 채널이 자동 판올림의 기본값이 된다」 ·
#   설정 열쇠 = settings.json 의 "autoUpdatesChannel": "stable"(약 1주 늦고 큰 퇴행 판을 건너뜀). ⇒ 설치 인자 + 설정 열쇠 둘 다.
$ClaudeChannel    = 'stable'
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
# ★★릴리스 핀 자리(v0.3.18) — 다음 판(cysr 1.0.0 · 앱+팩 단일 판번)으로 올릴 때 고치는 곳은 **이 블록뿐**이다:
#   $CysDisplayName · $CysVersion · $CysWinFile(자산 이름이 바뀌면) · $CysWinBytes · $CysWinSha256 — 값은 발행 뒤 SHA256SUMS.txt 와 대조(tests/win-pin-release.sh).
#   화면 머리글은 이 값으로 「<이름> <판> · 설치 도우미 <설치기 판>」 을 찍는다(설치기 판 = $InstallerVersion · 별도 semver).
$CysDisplayName = 'cysr'
$CysVersion     = '1.0.1'
$CysDownloadDir = "https://github.com/oogisoogi/cys-ro/releases/download/v${CysVersion}/"
# ✅아래 세 값 = v1.0.1 발행(2026-09-16 10:56 · Latest) 뒤 **실측으로 채웠다**(installer-0321-pin · 앞 판 자리표 TBD-1.0.1 을 대신한다).
#   출처 = 릴리스 SHA256SUMS.txt(그 파일 자신의 sha256 = c7b93b67bc17cd7f5cc88706eb6350c5dd7bc5c5cefb79dd7ea234c808c1f16e) · 크기는 릴리스 자산 목록과 내려받은 파일 양쪽에서 쟀다.
#   ⚠판을 올릴 때 이 세 값을 그대로 두면 받기가 반드시 실패한다 — 대조는 tests/win-pin-release.sh 가 릴리스를 때려서 진다.
# ⚠파일 이름 줄은 **선언 한 줄·뒤에 아무것도 없어야** 한다(tests/win-pin-release.sh 가 줄 끝까지 맞춰 읽는다).
#   `${CysVersion}` 를 그대로 두는 것이 정본이다 — 판을 올릴 때 이름이 함께 따라 오르고, 뮤턴트 M508 이 그 따라오름을 잰다.
#   지금 값은 풀면 cysr_1.0.1_x64-setup.exe = 릴리스 자산 이름과 글자 그대로 같다.
$CysWinFile     = "cysr_${CysVersion}_x64-setup.exe"
$CysWinBytes    = 139989480
$CysWinSha256   = 'f33cb82e0cd96cd67827cb05b9139064bcad20103ede743b7fe7efad41e2564d'   # 릴리스 SHA256SUMS.txt 의 줄
$CysDownloadUrl = $CysDownloadDir + $CysWinFile

$LoginPollInterval = 2     # 초 — 승인 프로세스가 끝난 뒤 로그인을 다시 확인하는 간격
$LoginConfirmTries = 3     # 승인 프로세스가 끝난 뒤 몇 번 확인하고 곧바로 갈래를 정하는가(v0.3.17 · 예전 10분 폴링을 대신한다)
# 🔴★승인 대기 구간에는 **상한이 없었다**(2026-09-11 맥 Tart 실기 · 두 OS 같은 구조).
#   벤더의 `claude auth login` 이 코드 입력을 기다리며 **2시간 32분 동안 화면에 0바이트**를 찍고 섰다.
#   ⇒ 20분이면 이 기다림을 끝낸다(그 뒤는 이미 있는 J-LOGIN-01 회복 경로).
#   v0.3.17: 로그인은 새로 뜬 창에서 한다 — 기다리는 동안 이 설치 창에는 찍지 않고 경과는 창 제목에만 적는다.
$LoginSayInterval  = 60    # 초 — 기다리는 동안 설치 창 제목의 경과(분)를 고치는 간격
$LoginWaitTimeout  = 1200  # 초 (20분) — 승인 대기 자체의 상한 · 벽시계로 잰다 (그 뒤 질문 1분 + 확인 3회 ⇒ 최악 약 21분으로 닫힌다)
$LoginCheckpointSec  = 300 # 초 (5분) — 브라우저에 로그인 화면이 떴는지 한 번 묻는 자리
$LoginStatusEverySec = 30  # 초 — 로그인 창이 살아 있는 동안 확인 명령을 부르는 간격(로그인 파일은 5초마다 본다)
$LoginAskWaitSec     = 60  # 초 — 상한에 닿았을 때 숫자 하나를 기다리는 상한
$LoginStatusWaitMs   = 20000 # ms — 확인 명령 한 번의 상한(벤더 도구가 멈춰도 20분 상한이 살아 있게)
$LoginTickMs         = 2000  # ms — 로그인을 기다리는 한 바퀴(이 사이에 복사된 코드·설치 창에 붙여넣은 코드·로그인 파일을 본다)
$LoginClipMaxSends   = 3     # 한 번 연 로그인에서 복사된 코드를 넣는 최대 횟수(같은 코드는 한 번만 · 서로 다른 코드만 센다)
$LoginTypedMaxSends  = 3     # 한 번 연 로그인에서 설치 창에 붙여넣은 코드를 넣는 최대 횟수
# 🔴로그인 카드(2026-09-14 워크숍 · 로그인 막힘 9건) — 승인을 두 번 누르거나 주소창 주소를 붙여넣어 코드가 무효가 됐다(사진 · 400).
#   「코드를 복사해 붙여넣으라」 한 줄로는 어느 코드·어느 단추인지 몰랐다 ⇒ 로그인 화면을 열기 전에 한 번.
# 🔴v0.3.17(2026-09-15): ①첫 줄 = 유료 구독 조건(사이트와 같은 말 · 무료 계정은 승인이 끝나지 않아 20분을 그대로 섰다)
#   ②붙여넣을 곳 = 새로 뜬 로그인 창 ③브라우저가 완료를 보이면 붙여넣지 않는다 ④브라우저가 안 열리면 그 창의 주소
#   ⑤「Ctrl-C 를 누르시면」 대신 「기다리셔도 됩니다」 — 기다리는 동안 이 창에 되풀이하지 않는다(화면이 밀리지 않게).
$LoginCardLines = @(
    '     Claude 유료 구독 계정(Pro 이상)이어야 합니다 — 무료 계정으로는 로그인 승인이 끝나지 않습니다.',
    '     로그인은 이렇게 해 주십시오 (3가지만):',
    '     1) 열려 있는 Claude 탭을 모두 닫고, 브라우저에서 「승인」은 한 번만 누르십시오 (두 번 누르면 앞 코드가 무효가 됩니다).',
    '     2) 「Authentication code」 화면이 뜨면 복사 단추로 코드를 복사만 하십시오 — 붙여넣지 않으셔도 이 설치 창이 몇 초 안에 알아서 넣습니다 (주소창의 주소는 안 됩니다).',
    '     3) 「코드를 로그인에 넣었습니다」가 안 나오면: 이 설치 창을 한 번 누르고 마우스 오른쪽 단추로 붙여넣은 뒤 Enter 를 누르십시오 — 5분 안에.',
    '     브라우저가 안 열리면: 이 설치 창에 보이는 https:// 주소를 복사해 브라우저 주소창에 붙여넣으십시오.',
    '     주소를 마우스로 긁을 수 없으면: 이 설치 창에서 Alt+Space → E → K 를 누른 뒤 주소를 끌어 선택하고 Enter 를 누르십시오(복사됩니다).',
    '     이 설치 창은 닫지 마십시오. 기다리셔도 됩니다 — 20분 뒤 저절로 다음 안내가 나옵니다.'
)
# 로그인이 끝내 안 됐을 때 사람이 스스로 푸는 길(윈도우 · 2026-09-15 샌드박스에서 이 길로 로그인이 됐다)
$LoginSelfFixLines = @(
    '     스스로 푸는 법: 새 PowerShell 창을 열고 claude 를 입력해 Enter 를 누른 뒤, 그 창에서 로그인을 끝내 주십시오.',
    '     로그인이 끝나면 그 창은 닫으셔도 됩니다. 그다음 아래 「다시 하시는 법」대로 다시 실행하시면 로그인은 건너뛰고 이어서 갑니다.'
)

# 설치기를 기다리는 한도. 한도가 없으면 백신 경고 창 같은 것이 떠 있는 동안 영원히 서 있게 된다.
$InstallWaitMs    = 300000   # 조용한 설치 (5분)
$InstallGuiWaitMs = 900000   # 설치 창을 띄웠을 때 (15분 · 사람이 누르는 시간)
# 🔴2026-09-09 실사용자 3호 실기 — 클로드 설치기가 백신 창에 붙들려 **아무 말 없이** 멈췄다.
#   그 자리에는 상한도 안내도 없었다(설치기를 부르고 그냥 기다렸다). 사람은 화면이 멈춘 것만 보고,
#   정작 눌러야 할 창은 다른 곳에 떠 있었다. ⇒ 기다리는 동안 말을 하고, 끝이 있는 기다림으로 바꾼다.
$ClaudeInstallWaitMs  = 600000   # 클로드 설치 상한 (10분 · 넘으면 조용히 다음으로 가지 않는다)
$InstallNoteEverySec  = 30       # 기다리는 동안 몇 초마다 한 줄을 적는가
# 🔴2026-09-14 워크숍 — 한 기기에서 공식 설치기가 30분 동안 3회 모두 10분 상한에 닿아 끝내 설치하지 못했다.
#   ⇒ 같은 자리(J-AV-01)에서 이미 막혔던 컴퓨터는 상한을 5분으로 줄이고, 상한에 닿으면 멈추기 전에 같은 공식 파일을 직접 받아 끝까지 간다.
$ClaudeInstallRetryWaitMs  = 300000   # 같은 자리에서 다시 막힌 실행의 상한 (5분)
$ClaudeDirectBaseUrl       = 'https://downloads.claude.ai/claude-code-releases'   # 공식 설치기(install.ps1)가 받는 자리 그대로
$ClaudeDirectInstallWaitMs = 180000   # 받은 파일로 공식 설치(install 하위명령)를 한 번 더 해 볼 때의 상한 (3분)
$ClaudeVersionWaitMs       = 90000    # 제자리에 둔 파일이 판본을 답하기까지의 상한
# 떠 있는 창 제목 가운데 백신 창으로 보이는 것(읽기만 · 짐작이다 — 틀릴 수 있다)
$AvWindowPattern = '\bV3\b|AhnLab|안랩|알약|ALYac|이스트시큐리티|ESTsecurity|Avast|\bAVG\b|Norton|McAfee|Kaspersky|카스퍼스키|Bitdefender|\bESET\b|Defender|백신|보안 알림|실행 알림|분석 요청'
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
$script:PrevRunState = ''   # 지난 실행이 어디까지 갔나 — '' 모름 · closed 끝맺음까지 · wait 원격 해결 대기 중 · answer 처방을 받은 뒤 · ended 원격 해결이 스스로 끝남
if (Test-Path $LogFile) {
    # 기록은 UTF-8 로 쓴다(Write-Log · v0.3.18) — 같은 글자표로 읽는다
    $prevLines = @(Get-Content $LogFile -ErrorAction SilentlyContinue -Encoding UTF8 | Where-Object { $_ -ne '' })
    if ($prevLines.Count -gt 0) {
        $script:PrevTail = $prevLines[-1]
        # 🔴2026-09-14 워크숍 — 처방을 받고 창을 닫은 실행에도 「창이 갑자기 닫혔다(J-AV-03)」가 붙었고, 처방 500자가 첫 화면을 덮었다.
        #   ⇒ 마지막 실행(마지막 머리글 줄 뒤)이 어디까지 갔는지 본다. 뒤에 적힌 줄이 앞의 것을 이긴다.
        $from = 0
        for ($i = $prevLines.Count - 1; $i -ge 0; $i--) { if ($prevLines[$i] -match '=== 자비스 설치 도우미 ') { $from = $i; break } }
        for ($i = $from; $i -lt $prevLines.Count; $i++) {
            $ln = $prevLines[$i]
            if ($ln -match '^\S+\s+다음에 할 일: ') { $script:PrevRunState = 'closed' }
            elseif ($ln -match '^\S+\s+remote help: report [A-Z2-9]{8}') { $script:PrevRunState = 'wait' }
            elseif ($ln -match '^\S+\s+처방(\(조치 [0-9]+\))?: ') { $script:PrevRunState = 'answer' }
            elseif ($ln -match '^\S+\s+(원격 해결 시간\([0-9]+분\)이 끝나 멈춥니다|원격 해결이 끝났습니다)') { $script:PrevRunState = 'ended' }
        }
    }
}

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    # 🔴v0.3.18 — 글자표를 박아 적는다. Add-Content 의 기본 글자표는 Windows PowerShell 5.1 에서 시스템 ANSI(한국어 윈도우 = CP949)라
    #   UTF-8 로 읽는 자리(첨부 전송 · 사람이 연 편집기)에서 「→」가 「��」로 깨졌다(2026-09-15 윈 실기 bootstrap.log · 두 바이트 = 두 글자).
    #   ⇒ BOM 없는 UTF-8 로 덧붙이고, 이 파일을 읽는 두 자리(지난 실행 꼬리 · 원격 해결 보고)도 UTF-8 로 읽는다.
    #   ⚠앞 판이 ANSI 로 적어 둔 기록은 첫 실행 한 번만 한글 줄이 깨져 읽힌다(지난 실행 상태를 「모름」으로 본다).
    #   줄 끝은 Add-Content 와 같게 운영체제의 줄바꿈이다(윈도우 CRLF) — 이 파일을 읽는 흉내·도구의 줄 모양을 바꾸지 않는다.
    try { [System.IO.File]::AppendAllText($LogFile, "$ts $msg" + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding $false)) } catch { }
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
    # ⓕ③ v0.3.20 — 창에 오류 글이 뜨면 그 자리에서 찍는다(이유 × 단계마다 한 번 · fail-open).
    #   ⚠$script:CaptureReady 를 보는 까닭: 이 함수는 파일 위쪽(196줄)인데 캡처 블록은 아래쪽에서 값을 잡는다.
    #     그 전에 Say 가 불리면 아직 없는 변수를 보게 된다 — 그래서 **다 읽힌 뒤에만** 이 줄이 산다.
    #   ⚠$script:CaptureInSay 를 보는 까닭: 증거를 보내는 쪽이 다시 Say 를 부르면 끝없이 돈다.
    if ($script:CaptureReady -and (-not $script:CaptureInSay) -and ([string]$msg -imatch $CaptureErrorTextPattern)) {
        $script:CaptureInSay = $true
        try { Send-CaptureEvidence 'error-text' ([string]$msg) } finally { $script:CaptureInSay = $false }
    }
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
    # 끝맺음까지 간 실행 · 원격 해결이 스스로 끝난 실행 = 「갑자기 닫힘」이 아니다(끝맺음이 이미 다음에 할 일을 알렸다)
    if (($script:PrevRunState -eq 'closed') -or ($script:PrevRunState -eq 'ended')) { Write-Log ('prevrun ' + $script:PrevRunState + ' - no J-AV-03'); return }
    # 원격 해결을 기다리던 중에 닫힌 창 = 사람이 처방을 보고 새로 실행한 것이다 — J-AV-03 을 붙이지 않고 한 줄로 알린다
    if (($script:PrevRunState -eq 'answer') -or ($script:PrevRunState -eq 'wait')) {
        if ($script:PrevRunState -eq 'answer') { Say '지난번 실행 기록: (운영팀 처방을 받은 뒤 창이 닫혔습니다)' }
        else { Say '지난번 실행 기록: (원격 해결을 기다리던 중에 창이 닫혔습니다)' }
        Write-Log ('prevrun ' + $script:PrevRunState + ' - no J-AV-03')
        Say '     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다.'
        return
    }
    Say '지난번 실행이 끝을 알리지 않고 멈춘 자리가 있습니다. 그때 마지막으로 적힌 줄입니다:'
    # 🔴Write-JCode 를 쓰지 않는다(2026-09-14 도움 채널 3건) — $script:JCode 에 넣으면 이번 실행이 다른 까닭으로 끝나도
    #   끝맺음 보고에 이 코드가 실려 「백신이 창을 닫았다」는 엉뚱한 안내가 나갔다. 지난 실행 표시는 별도 칸이다.
    $script:PrevRunCode = 'J-AV-03'
    Say '     지난 실행의 진단 코드: J-AV-03 — 지난 실행이 끝을 알리지 않고 멈췄습니다(창이 갑자기 닫혔을 수 있습니다)'
    Say ('     이 코드로 찾아보실 수 있습니다: ' + $HelpCodeUrl + 'J-AV-03')
    Write-Log 'prevrun J-AV-03'
    # 마지막 줄이 길면 새 실행의 첫 화면이 덮인다(2026-09-14 · 처방 500자가 통째로 찍혔다) — 120자에서 자른다
    $tail = [string]$script:PrevTail
    if ($tail.Length -gt 120) { $tail = $tail.Substring(0, 120) + '…' }
    Say "       $tail"
    Say '     창이 갑자기 닫힌 것이었다면 백신이 PowerShell 을 종료한 것일 수 있습니다.'
    Say '     이어서 진행합니다 — 이미 끝난 단계는 다시 하지 않습니다.'
}

# ── 진단 코드 (J-<축>-<두 자리>) ──────────────────────────────────
# ★같은 문자열이 세 자리에 남아야 한다 — 화면 · 환경 보고 · 기록 파일.
#   자리마다 다른 이름을 쓰면 그 셋을 맞춰 보는 일이 사람 몫이 된다.
$script:JCode = ''
$script:NextStep = ''
$script:PrevRunCode = ''    # 지난 실행 표시(Show-PrevRunNote) — 이번 실행의 코드와 섞지 않는다
function Write-JCode($code, $desc) {
    $script:JCode = $code
    Say ("     진단 코드: " + $code + " — " + $desc)
    Say ("     이 코드로 찾아보실 수 있습니다: " + $HelpCodeUrl + $code)
    Write-Log ("jcode " + $code + " " + $desc)
    Send-Progress (Get-CurrentStep) 'fail' $null $code $null   # 막힌 자리를 자동으로 알린다(fail-open)
    Send-EvidenceOnce 'fail'   # v0.3.18 — 실패 증거(설치 창 끝부분 · 마스킹 뒤)
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
    'J-RM-01'    = @('재설치 명령을 한 번 더 실행해 주십시오.', '열려 있는 cys 는 재설치가 스스로 닫습니다.')
    'J-PATH-01'  = @('컴퓨터를 한 번 다시 시작하신 뒤 새 창에서 다시 실행해 주십시오.')
    'J-LOGIN-01' = @('브라우저가 뜨지 않았거나 다른 브라우저에 로그인돼 있으면,', '화면에 보이는 https:// 로 시작하는 로그인 주소를 복사해', '로그인된 브라우저 주소창에 붙여넣어 주십시오.')
    'J-LOGIN-02' = @('브라우저 창을 모두 닫으신 뒤 다시 실행해 주십시오.', '승인은 한 번만 누르시고 코드를 복사하면 설치가 이어집니다.', '안 이어지면 설치 창을 한 번 클릭한 뒤 Ctrl+V 로 붙여넣어 주십시오.')
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
# 🔴v0.3.18 — 조용히 넘긴 확인에서 난 오류인가를 **글자가 아니라 구문으로** 가른다.
#   v0.3.17 은 오류가 난 줄의 글자에서 「-ErrorAction SilentlyContinue」를 찾았다. 실측(pwsh 7.6 · 2026-09-15)으로 그 필터를 빠져나간 형태 =
#   ⑴-EA 0 ⑵-ErrorAction:SilentlyContinue ⑶여러 줄에 걸친 명령(오류의 줄 글자는 명령의 첫 줄뿐이다 · Test-CysBody 의 목록 읽기가 이 모양)
#   ⑷2>$null · 2>&1 로 받아 둔 바깥 명령(& cys … 2>$null — cys 가 아직 없으면 「명령을 찾지 못함」이 쌓인다).
#   ⇒ 오류가 난 자리(스크립트 · 줄 · 칸)를 감싸는 가장 작은 명령을 구문 트리에서 찾아, 그 명령의 ErrorAction 값과 오류 흐름 돌리기를 본다.
#   ⚠구문 트리를 못 얻거나 자리를 못 찾으면 「조용하지 않음」이다 — 앞 판처럼 참고로 적는다(모르는 것을 지우지 않는다).
$script:QuietAstCache = @{}
function Test-QuietErrorRecord($e) {
    $ii = $null
    try { $ii = $e.InvocationInfo } catch { }
    if (-not $ii) { return $false }
    # 줄 글자 필터는 구문 트리를 못 쓸 때만 쓴다 — 한 줄에 명령이 여럿이면 다른 명령의 -EA 로 거짓 통과한다(교차 검토 1R F3).
    $lineQuiet = ([string]$ii.Line -match '-(ErrorAction|EA)\s+(SilentlyContinue|Ignore)')
    $file = [string]$ii.ScriptName; $ln = [int]$ii.ScriptLineNumber; $col = [int]$ii.OffsetInLine
    if (-not $file -or $ln -le 0 -or $col -le 0) { return $lineQuiet }
    if (-not $script:QuietAstCache.ContainsKey($file)) {
        $ast = $null
        try { $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null) } catch { }
        $script:QuietAstCache[$file] = $ast
    }
    $ast = $script:QuietAstCache[$file]
    if (-not $ast) { return $lineQuiet }
    $hit = $null
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $x = $c.Extent
        $afterStart = ($ln -gt $x.StartLineNumber) -or ($ln -eq $x.StartLineNumber -and $col -ge $x.StartColumnNumber)
        $beforeEnd  = ($ln -lt $x.EndLineNumber) -or ($ln -eq $x.EndLineNumber -and $col -le $x.EndColumnNumber)
        if ($afterStart -and $beforeEnd -and ((-not $hit) -or ($x.Text.Length -lt $hit.Extent.Text.Length))) { $hit = $c }
    }
    if (-not $hit) { return $lineQuiet }
    # 감싸는 명령을 바깥으로 올라가며 본다 — `& { … } 2>$null` 처럼 바깥 명령에서 막은 경우도 조용한 확인이다(교차 검토 1R F4).
    for ($node = $hit; $node; $node = $node.Parent) {
        if ($node -isnot [System.Management.Automation.Language.CommandAst]) { continue }
        # 2>$null · *>$null · 2>&1 — 오류 흐름을 버리거나 받아 둔 명령이다
        foreach ($r in $node.Redirections) { if ([string]$r.FromStream -in @('Error', 'All')) { return $true } }
        $els = $node.CommandElements
        for ($i = 0; $i -lt $els.Count; $i++) {
            $pa = $els[$i]
            if ($pa -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
            $pn = [string]$pa.ParameterName
            if (-not (($pn -ieq 'EA') -or ($pn.Length -ge 6 -and 'ErrorAction'.StartsWith($pn, [System.StringComparison]::OrdinalIgnoreCase)))) { continue }
            $arg = if ($pa.Argument) { $pa.Argument } elseif ($i + 1 -lt $els.Count) { $els[$i + 1] } else { $null }
            $v = if ($arg) { ([string]$arg.Extent.Text).Trim().Trim("'", '"') } else { '' }
            if ($v -match '^(SilentlyContinue|Ignore|0|4)$') { return $true }
        }
    }
    return $false
}
function Write-ClosingNote {
    if ($script:ClosingDone) { return }
    $script:ClosingDone = $true
    # 「다음에 할 일」을 아무도 안 적은 끝 = 우리가 예상 못 한 자리다. 그때가 안내가 가장 필요한 때이므로
    #   기본값을 「다시 실행」으로 두고 **깃발도 함께 세운다**(문구만 두면 방법이 안 나온다).
    if (-not $script:NextStep) {
        $script:NextStep = '아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        # 🔴본문 try/finally 에 catch 가 없어 오류 문구는 화면에만 나가고 기록 파일엔 한 줄도 안 남았다(2026-09-14 3건).
        #   마지막 오류를 적는다 — 끝난 원인이 아닐 수 있고, Ctrl-C 중단은 여기에 안 잡힌다.
        # 🔴v0.3.17 — 조용히 넘긴 확인(-ErrorAction SilentlyContinue)의 오류도 여기에 쌓인다. 그 줄을 원인처럼 적어 오진을 불렀다
        #   (2026-09-15 · 로그인 확인 중에 끝난 실행에 「cys 를 찾지 못했다」가 적혔다 — 그것은 [1/10] 의 정상 확인이었다).
        #   ⇒ 그런 줄은 빼고 적는다. 남은 것이 없으면 「오류 기록 없음」이라고 적는다 — Ctrl-C 중단 같은 끝일 수 있다. 원인은 단정하지 않는다.
        #   ⚠try/catch 로 잡아 넘긴 오류는 여기서 가를 수 없어 남는다(교차 검토 지적) — 그래서 이름표가 「참고 · 끝난 원인이 아닐 수 있음」이다.
        #   🔴v0.3.18 — 가르는 일은 Test-QuietErrorRecord 가 한다(글자 필터가 놓친 네 형태 · 그 함수 머리 주석).
        $quietErr = @($Error | Where-Object { Test-QuietErrorRecord $_ })
        $loudErr  = @($Error | Where-Object { -not (Test-QuietErrorRecord $_) })
        if ($loudErr.Count -gt 0) {
            $e0 = $loudErr[0]
            $why = (($e0 | Out-String) -replace '\s+', ' ').Trim()
            $etype = if ($e0.Exception) { $e0.Exception.GetType().FullName } else { $e0.GetType().FullName }
            Write-Log ('unexpected end: last error (참고 · 끝난 원인이 아닐 수 있음) = ' + $etype + ' - ' + $why.Substring(0, [Math]::Min(300, $why.Length)))
        } else {
            Write-Log 'unexpected end: no error recorded (Ctrl-C 중단 같은 끝일 수 있음)'
        }
        if ($quietErr.Count -gt 0) { Write-Log ('unexpected end: skipped ' + $quietErr.Count + ' quietly handled check error(s)') }
        if ($script:LoginStage) { Write-Log ('unexpected end: last login stage = ' + $script:LoginStage) }
        # 코드가 비면 원격 해결(Invoke-RemoteHelp)이 보고를 보내지 않는다 ⇒ 설치 모드·깨우기 전의 끝만 「분류 못 함」으로 채운다.
        if ((-not $script:JCode) -and ($Mode -eq 'full') -and (-not $script:ReachedWake)) { $script:JCode = 'J-UNK-00'; Write-Log 'jcode J-UNK-00 unexpected end' }
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
                $keep = @($keep | Where-Object { $_ -notmatch '^- (같은 진단 코드|이전 보고|지난 실행 진단 코드)' })
                $keep += ('- 진단 코드: **' + $script:JCode + '** (' + $HelpCodeUrl + $script:JCode + ')')
                if ($script:PrevRunCode) { $keep += ('- 지난 실행 진단 코드(참고 · 이번 끝의 코드가 아님): ' + $script:PrevRunCode) }
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
    # 🔴v0.3.17 — 원격 해결은 창을 최대 2시간 붙든다. 그 **앞에도** 「다시 하시는 법」을 한 번 보여 준다 — 기다리지 않고 바로 다시 해 볼 수 있게.
    #   맨 끝의 한 번은 그대로 둔다(사람이 마지막으로 보는 화면에 명령이 있어야 복사할 수 있다). 조건은 원격 해결이 실제로 도는 관문과 같다.
    if ($script:NoticeShown -and $script:ShowRerun -and $script:JCode -and ($Mode -eq 'full') -and (-not $script:ReachedWake)) { Show-RerunHow }
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
    Say '   1) ⊞ 윈도우 키(키보드 왼쪽 아래, Ctrl과 Alt 사이)를 누르고 powershell 이라고 치신 뒤 [Windows PowerShell] 을 여십시오.'
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
# ── 옛 판 안내 (TICKET=installer-speed-pin-0320 · 2026-09-16) ─────────
#   0.14.x 로 깔린 cys 는 앱 안 업데이트가 안 된다(서명 열쇠가 바뀌었다) — 설치기가 새 판으로 다시 깐다.
#   ★묻지 않는다 · 막지 않는다 — 한 줄 알리고 그대로 간다(사람 손 0). 판본을 못 읽으면 아무 말도 하지 않는다.
function Show-OldCysNote {
    try {
        $v = Get-CysInstalledVersion (Test-CysBody)
        if ($v -match '^0\.14\.') {
            Say ("     깔려 있는 cys $v 는 앱 안에서 업데이트할 수 없는 옛 판입니다 — 이번 설치에서 새 판($CysDisplayName $CysVersion)으로 다시 설치합니다(하실 일은 없습니다).")
            Write-Log ("old cys: $v -> reinstall $CysVersion")
        }
    } catch { }
}
# 설치된 cys 의 판본 (v0.3.18) — 설치 목록의 판본 칸이 먼저, 없으면 실행 파일에 적힌 판본. 명령은 부르지 않는다(데몬을 깨울 수 있다).
#   돌려주는 것 = '0.14.36' 모양 · 못 읽으면 ''.
function Get-CysInstalledVersion($b) {
    $raw = ''
    try { if ($b.Reg -and $b.Reg.DisplayVersion) { $raw = [string]$b.Reg.DisplayVersion } } catch { }
    if (-not $raw -and $b.Cli) { try { $raw = [string](Get-Item -LiteralPath $b.Cli -ErrorAction Stop).VersionInfo.ProductVersion } catch { } }
    $m = [regex]::Match($raw, '\d+\.\d+\.\d+')
    if ($m.Success) { return $m.Value }
    return ''
}

# 🔴v0.3.18 (결정 2026-09-15 19:4x) — 「판번이 같아도 실제 내용이 바뀌었으면 업데이트해야 한다」.
#   판번 대조만으로 건너뛰면 같은 판번으로 다시 발행한 파일(내용이 다른 빌드)이 그 기기에 영영 안 닿는다.
#   ⇒ 건너뜀 = 「같은 판 AND 핀 지문 일치」일 때만. 설치 도우미가 cys 를 깔고 나면 설치 자리에 표지 한 장을 둔다:
#      { 이번 핀의 설치 파일 지문 · 그때 깔린 cys.exe 의 실측 지문 }. 다음 실행은 ⑴표지의 핀 지문 = 지금 핀 ⑵지금 cys.exe 실측 지문 = 표지 값
#      둘 다일 때만 「같은 내용」으로 본다. 표지가 없거나(다른 경로로 깐 cys · v0.3.17 이전) 못 재면 「같다고 확인 못 함」 → 다시 받아 덮어 깐다.
#   ⚠표지는 설치 자리(프로그램 폴더)에 둔다 — 작업 폴더에 두면 재설치(-KeepApp)가 작업 폴더를 지워 매번 다시 받는다(② 건너뜀이 죽는다).
#   돌려주는 것 = 'match' · 'no-stamp' · 'stamp-unreadable' · 'pin-changed' · 'exe-unmeasured' · 'exe-changed'
function Get-CysPinStampPath($b) {
    if ($b -and $b.Path) { return (Join-Path $b.Path 'jarvis-cys-pin.json') }
    return ''
}
function Get-CysContentState($b) {
    $sp = Get-CysPinStampPath $b
    if (-not $sp -or -not (Test-Path -LiteralPath $sp)) { return 'no-stamp' }
    $st = $null
    try { $st = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { $st = $null }
    if ($null -eq $st) { return 'stamp-unreadable' }
    if ([string]$st.setup_sha256 -cne [string]$CysWinSha256) { return 'pin-changed' }
    $exeSha = $null
    if ($b.Cli) { $exeSha = Get-CysFileSha256 $b.Cli }
    if ($null -eq $exeSha) { return 'exe-unmeasured' }
    if ($exeSha -cne ([string]$st.exe_sha256).ToLower()) { return 'exe-changed' }
    return 'match'
}
function Save-CysPinStamp($b) {
    # 설치를 확인한 뒤에만 부른다 · 못 적어도 설치는 막지 않는다(다음 실행이 한 번 더 받을 뿐)
    if ($Mode -eq 'dry') { return $false }
    $sp = Get-CysPinStampPath $b
    $exeSha = $null
    if ($b -and $b.Cli) { $exeSha = Get-CysFileSha256 $b.Cli }
    if (-not $sp -or ($null -eq $exeSha)) { Write-Log 'cys pin stamp: not written (cys.exe 지문을 못 쟀다)'; return $false }
    $o = [ordered]@{ version = $CysVersion; setup_sha256 = $CysWinSha256; exe_sha256 = $exeSha; installer_version = $InstallerVersion; at = (Get-Date -Format o) }
    try { Write-TextNoBom $sp ($o | ConvertTo-Json); Write-Log ('cys pin stamp: written v' + $CysVersion + ' exe=' + $exeSha.Substring(0, 12)); return $true }
    catch { Write-Log ('cys pin stamp: write failed - ' + $_.Exception.Message); return $false }
}

# 🔴v0.3.18 — SmartScreen 손 1(「추가 정보 → 실행」)을 없애는 자리. 채택(2026-09-15) = 웹 표식(Zone.Identifier) 제거 · **지문 대조 통과 뒤에만**.
#   ⛔이 함수는 지문이 핀과 같다고 확인한 줄 바로 뒤에서만 부른다 — 확인 전에 표식을 지우면 모르는 파일의 경고까지 지운다(보안 경계 = 검증이 먼저).
#   ⚠받은 방식에 따라 표식이 아예 없을 수 있다(브라우저가 아닌 받기) — 그때는 지울 것이 없다고 기록만 한다(실기 기록으로 손 1 의 원인을 가른다).
function Test-WebMark($path) {
    try { return [bool](Get-Item -LiteralPath $path -Stream 'Zone.Identifier' -ErrorAction Stop) } catch { return $false }
}
function Clear-WebMark($path, $what) {
    if ($Mode -eq 'dry') { return 'dry' }
    $leaf = Split-Path -Leaf $path
    if (-not (Test-WebMark $path)) { Write-Log ('motw: none on ' + $leaf + ' (' + $what + ')'); return 'none' }
    try {
        Unblock-File -LiteralPath $path -ErrorAction Stop
        Write-Log ('motw: removed after sha256 match - ' + $leaf + ' (' + $what + ')')
        return 'removed'
    } catch {
        Write-Log ('motw: remove failed - ' + $leaf + ' - ' + $_.Exception.Message)
        return 'failed'
    }
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

    # (installer-speed-pin-0320) [8/10] 이 방금 돌린 자가진단이 있으면 그 출력을 쓴다 — 같은 명령을 한 실행에 두 번 부르지 않는다.
    $v = if ($script:DoctorText) { ($script:DoctorText -split "`n" | Select-String -Pattern '^요약' | Select-Object -First 1) }
         else { (& cys doctor 2>$null | Select-String -Pattern '^요약' | Select-Object -First 1) }
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

# ── 사용자 PATH 에 cys 자리를 심는다 (v0.3.18 · 2026-09-15 윈 실기) ─────
#   🔴cys 설치기도 PATH 를 안 건드린다([7/10] 머리 주석). 설치 도우미 안에서는 전체 경로로 불러 드러나지 않았고,
#   설치가 끝난 뒤 새 창의 자비스가 「cys」를 찾지 못했다 ⇒ Seed-LocalBinPath 와 같은 규칙으로 **사용자** PATH 에만 멱등으로 넣는다(관리자 권한 0).
#   ⚠읽기·쓰기를 두 함수로 뺀 까닭 = 맥 흉내에는 사용자 환경변수 자리가 없다(.NET 이 무시한다) — 흉내가 이 둘만 바꿔 끼워 규칙을 잰다.
#   ⚠지우는 쪽 = reset-clean.ps1 Remove-UserPathSeed(프로그램까지 지울 때만 · -KeepApp 이면 남긴다).
function Get-UserPathValue { return [Environment]::GetEnvironmentVariable('Path', 'User') }
function Set-UserPathValue($value) { [Environment]::SetEnvironmentVariable('Path', $value, 'User') }
function Seed-CysPath($dir) {
    if (-not $dir) { return $false }
    $want = ([string]$dir).TrimEnd('\')
    try {
        $user = Get-UserPathValue
        $have = $false
        if ($user) {
            foreach ($p in ($user -split ';')) {
                if (-not $p) { continue }
                if ([Environment]::ExpandEnvironmentVariables($p).TrimEnd('\') -ieq $want) { $have = $true; break }
            }
        }
        if ($have) {
            Write-Log 'seed-cys-path: already in User PATH'
        } else {
            $new = if ($user) { $user.TrimEnd(';') + ';' + $want } else { $want }
            Set-UserPathValue $new
            Write-Log ('seed-cys-path: added ' + (Redact $want) + ' to User PATH')
        }
    } catch {
        Write-Log ('seed-cys-path: failed - ' + $_.Exception.Message)
        return $false
    }
    $inProc = $false
    foreach ($p in ($env:Path -split ';')) { if ($p -and ($p.TrimEnd('\') -ieq $want)) { $inProc = $true; break } }
    if (-not $inProc) { $env:Path = ([string]$env:Path).TrimEnd(';') + ';' + $want }
    return $true
}

# ── [2/10] 공식 설치기가 상한에 닿았을 때 (v0.3.16 · 2026-09-14 워크숍) ─────────────
# 🔴그날 한 기기가 30분 동안 3회 모두 10분 상한에 닿았고 끝내 설치하지 못했다. 기록에는 「백신으로 보입니다」 한 문장만
#   남아 무엇이 멈췄는지 갈리지 않았다 ⇒ ⑴무엇이 살아 있었는지 적고(읽기만) ⑵같은 공식 파일을 직접 받아 끝까지 간다.
# ★공식 설치기(https://claude.ai/install.ps1 · 2026-09-14 실물)가 하는 일 = ①{BASE}/latest 로 판본 ②{BASE}/<판본>/manifest.json 의
#   해시 ③claude.exe 받기 ④해시 대조 ⑤받은 파일로 `install latest` ⑥받은 파일 삭제. 멈춘 자리는 ③ 또는 ⑤다.
#   ⇒ ①~④를 같은 주소·같은 해시 대조로 우리가 하고, ⑤를 짧은 상한(3분)으로 한 번 해 본다(되면 셸 연동·자동 판올림 준비까지
#     공식 그대로 깔린다). 그것도 상한이면 받은 파일을 ~\.local\bin\claude.exe 에 두고 판본을 답하는지로 판정한다.
#   ★기록 파일에 「공식 설치기가 받던 파일」(③ 진행)과 「install hold diag (⑤ 받은 파일로 설치)」(⑤ 멈춤)가 따로 남아 다음 보고에서 원인이 갈린다.
# ⛔백신을 끄거나 피하거나 예외로 등록하지 않는다 — 같은 공식 파일을 받고, 백신 검사는 그대로 받는다.
function Get-ProcTree($rootId) {
    # 돌려주는 것 = 자식·손자 목록(Id · Name · Start · Parent · Depth) · 못 읽으면 빈 목록(설치를 막지 않는다)
    $all = $null
    try {
        $all = @(Get-CimInstance Win32_Process -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{ Id = [int]$_.ProcessId; Parent = [int]$_.ParentProcessId; Name = [string]$_.Name; Start = $_.CreationDate }
        })
    } catch { $all = $null }
    if ($null -eq $all) {
        # CIM 이 없는 자리 — PowerShell 7 의 Parent 칸으로 대신 잰다(5.1 에는 없는 칸이다)
        try {
            $all = @(Get-Process -ErrorAction Stop | ForEach-Object {
                $pp = 0; try { if ($_.Parent) { $pp = [int]$_.Parent.Id } } catch { $pp = 0 }
                $st = $null; try { $st = $_.StartTime } catch { $st = $null }
                [pscustomobject]@{ Id = [int]$_.Id; Parent = $pp; Name = [string]$_.ProcessName; Start = $st }
            })
        } catch { return @() }
    }
    $out = @()
    $frontier = @([int]$rootId)
    $depth = 0
    while (($frontier.Count -gt 0) -and ($depth -lt 6)) {
        $depth++
        $next = @()
        foreach ($c in $all) {
            if (($frontier -contains $c.Parent) -and ($c.Id -ne $c.Parent)) {
                $out += [pscustomobject]@{ Id = $c.Id; Name = $c.Name; Start = $c.Start; Parent = $c.Parent; Depth = $depth }
                $next += $c.Id
            }
        }
        $frontier = $next
    }
    return $out
}
function Get-AvWindowTitles {
    $t = @()
    foreach ($pr in @(Get-Process -ErrorAction SilentlyContinue)) {
        $w = ''
        try { $w = [string]$pr.MainWindowTitle } catch { $w = '' }
        if ($w -and ($w -match $AvWindowPattern)) { $t += ($w + ' (' + $pr.ProcessName + ')') }
    }
    return @($t | Select-Object -Unique)
}
function Get-FileStateWords($path) {
    # 있음 · 크기 · 잠김(다른 프로그램이 쥐고 있어 열리지 않는가) — 읽기만 한다
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
    if (-not [System.IO.File]::Exists($full)) { return '없음' }
    $size = '?'
    try { $size = [string]([System.IO.FileInfo]$full).Length } catch { $size = '?' }
    $lock = '아니오'
    $fs = $null
    try { $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None) }
    catch { $lock = '예(' + $_.Exception.GetType().Name + ')' }
    finally { if ($fs) { $fs.Dispose() } }
    return ('있음 · ' + $size + '바이트 · 잠김 ' + $lock)
}
function Add-ReportLines($lines) {
    # 환경 보고(원격 해결이 보내는 본문)에 줄을 덧붙인다 — 보고서를 쓰는 방식과 같게 BOM 없는 UTF-8
    try {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportFile)
        [System.IO.File]::AppendAllText($full, ((@($lines) -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
    } catch { Write-Log 'report append failed' }
}
function Write-ClaudeInstallDiag($p, $where) {
    # 돌려주는 것 = 그때 본 자식 목록(끄는 데 쓴다)
    $tree = @(Get-ProcTree $p.Id)
    $procWords = '없음(또는 읽지 못함)'
    if ($tree.Count -gt 0) {
        $procWords = (@($tree | ForEach-Object {
            $s = ''
            try { if ($_.Start) { $s = ([datetime]$_.Start).ToString('HH:mm:ss') } } catch { $s = '' }
            $_.Name + '(번호 ' + $_.Id + ' · 부모 ' + $_.Parent + ' · 시작 ' + $s + ')'
        })) -join ' · '
    }
    $av = @(Get-AvWindowTitles)
    $avWords = if ($av.Count -gt 0) { $av -join ' · ' } else { '없음' }
    $exe = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    $dls = @()
    try { $dls = @(Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.claude\downloads') -Filter 'claude-*.exe' -Force -ErrorAction Stop | ForEach-Object { $_.Name + ' ' + $_.Length + '바이트' }) } catch { $dls = @() }
    $dlWords = if ($dls.Count -gt 0) { $dls -join ' · ' } else { '없음' }
    $lines = @(
        ('설치기 프로세스 번호 ' + $p.Id + ' · 자식: ' + $procWords),
        ('백신으로 보이는 창 제목: ' + $avWords),
        ('~\.local\bin\claude.exe: ' + (Get-FileStateWords $exe)),
        ('공식 설치기가 받던 파일(~\.claude\downloads): ' + $dlWords)
    )
    foreach ($l in $lines) { Write-Log ('install hold diag (' + $where + '): ' + (Redact $l)) }
    Add-ReportLines (@('', ('## [2/10] 설치가 상한에 닿았을 때 본 것 (' + $where + ')')) + @($lines | ForEach-Object { '- ' + (Redact $_) }))
    if ($av.Count -gt 0) {
        Say ('     지금 떠 있는 창 가운데 백신 창으로 보이는 것: 『' + $av[0] + '』 — 그 창에서 [실행] 또는 [파일 전송] 을 눌러 주십시오.')
    }
    return $tree
}
function Stop-ProcTree($p, $tree) {
    # 깊은 자식부터 끄고 마지막에 본인 — 우리가 띄운 설치기와 그 자식만 겨눈다
    foreach ($t in @(@($tree) | Sort-Object Depth -Descending)) {
        try { Stop-Process -Id $t.Id -Force -ErrorAction Stop } catch { }
    }
    try { if (-not $p.HasExited) { $p.Kill() } } catch { }
    try { [void]$p.WaitForExit(5000) } catch { }
    Write-Log ('install hold: stopped installer ' + $p.Id + ' and ' + @($tree).Count + ' child process(es) - exited=' + $p.HasExited)
}
function Wait-ProcBounded($proc, $capMs, $label) {
    # 돌려주는 것 = $true 상한 안에 끝났다 · $false 상한에 닿았다(그 사이 몇 초마다 한 줄 · 콘솔을 건드리지 않는 대기)
    $w = 0; $since = 0
    while (-not $proc.WaitForExit(1000)) {
        $w += 1000; $since += 1000
        if ($w -ge $capMs) { return $false }
        if ($since -ge ($InstallNoteEverySec * 1000)) {
            $since = 0
            Say ('     ' + $label + ' (' + [int][math]::Floor($w / 60000) + '분 ' + ([int][math]::Floor($w / 1000) % 60) + '초 지남 · 최대 ' + [int][math]::Floor($capMs / 60000) + '분)')
        }
    }
    return $true
}
function Install-ClaudeDirect {
    # 돌려주는 것 = $true 클로드가 ~\.local\bin 에서 판본을 답했다 · $false 못 했다(까닭은 화면·기록에)
    $platform = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'win32-arm64' } else { 'win32-x64' }
    $saved = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # 5.1 은 진행 막대를 그리느라 큰 파일 받기가 몇 배 느려진다
    try {
        # ① 판본
        $ver = ''
        try { $ver = ([string](Invoke-RestMethod -Uri ($ClaudeDirectBaseUrl + '/' + $ClaudeChannel) -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop)).Trim() } catch { $ver = '' }
        if (-not ($ver -cmatch '\A[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?\z')) {
            Say '     공식 자리에서 판본 번호를 읽지 못했습니다.'
            Write-Log ('install direct: step1 latest unreadable (' + $ver.Length + ' chars)')
            return $false
        }
        # ② 해시
        $sum = ''; $size = 0
        try {
            $m = Invoke-RestMethod -Uri ($ClaudeDirectBaseUrl + '/' + $ver + '/manifest.json') -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            $sum = ([string]$m.platforms.$platform.checksum).ToLower()
            try { $size = [long]$m.platforms.$platform.size } catch { $size = 0 }
        } catch { $sum = '' }
        if (-not ($sum -cmatch '\A[0-9a-f]{64}\z')) {
            Say '     공식 자리에서 파일 확인값(해시)을 읽지 못했습니다 — 확인 없이 설치하지 않습니다.'
            Write-Log ('install direct: step2 manifest checksum unreadable for ' + $ver + ' ' + $platform)
            return $false
        }
        # ③ 받기
        New-Item -ItemType Directory -Force -Path $DlDir | Out-Null
        $dl = Join-Path $DlDir ('claude-' + $ver + '-' + $platform + '.exe')
        Remove-Item -LiteralPath $dl -Force -ErrorAction SilentlyContinue
        Say ('     공식 자리에서 클로드 ' + $ver + ' 파일을 받습니다 (약 ' + [int][math]::Floor($size / 1MB) + 'MB · 보통 1~3분).')
        $t0 = Get-Date
        try {
            Invoke-WebRequest -Uri ($ClaudeDirectBaseUrl + '/' + $ver + '/' + $platform + '/claude.exe') -OutFile $dl -UseBasicParsing -TimeoutSec 900 -ErrorAction Stop
        } catch {
            Remove-Item -LiteralPath $dl -Force -ErrorAction SilentlyContinue
            Say ('     파일을 받지 못했습니다: ' + $_.Exception.Message)
            Write-Log ('install direct: step3 download failed - ' + $_.Exception.Message)
            return $false
        }
        Write-Log ('install direct: step3 download ok ' + $ver + ' in ' + [int][math]::Floor(((Get-Date) - $t0).TotalSeconds) + 's')
        # ④ 해시 대조 — 못 재면 쓰지 않는다
        $got = Get-CysFileSha256 $dl
        if ($null -eq $got) {
            Remove-Item -LiteralPath $dl -Force -ErrorAction SilentlyContinue
            Say '     받은 파일의 확인값(해시)을 잴 수 없어 그 파일은 쓰지 않았습니다.'
            Write-Log 'install direct: step4 checksum unmeasurable'
            return $false
        }
        if ($got -cne $sum) {
            Remove-Item -LiteralPath $dl -Force -ErrorAction SilentlyContinue
            Say '     받은 파일의 확인값(해시)이 공식 값과 다릅니다 — 그 파일은 쓰지 않았습니다.'
            Write-Log ('install direct: step4 checksum mismatch got=' + $got + ' want=' + $sum)
            return $false
        }
        Write-Log 'install direct: step4 checksum ok'
        # ⑤ 받은 파일로 공식 설치를 짧은 상한으로 한 번 해 본다 — 되면 셸 연동·자동 판올림 준비까지 공식 그대로 깔린다
        $exe = Join-Path (Join-Path $env:USERPROFILE '.local\bin') 'claude.exe'
        $step5 = 'not-run'
        $ip = $null
        try { $ip = Start-Process -FilePath $dl -ArgumentList 'install',$ClaudeChannel -NoNewWindow -PassThru -ErrorAction Stop } catch { $ip = $null; $step5 = 'start-failed' }
        if ($null -ne $ip) {
            if (Wait-ProcBounded $ip $ClaudeDirectInstallWaitMs '받은 파일로 설치하는 중입니다') {
                [void]$ip.WaitForExit()
                $step5 = 'rc=' + $(if ($null -eq $ip.ExitCode) { 'unread' } else { [string]$ip.ExitCode })
            } else {
                $step5 = 'timeout ' + [int][math]::Floor($ClaudeDirectInstallWaitMs / 60000) + 'min'
                $t5 = @(Write-ClaudeInstallDiag $ip '⑤ 받은 파일로 설치')
                Stop-ProcTree $ip $t5
            }
        }
        Write-Log ('install direct: step5 install ' + $ClaudeChannel + ' ' + $step5)
        # ⑤가 끝나고 파일이 제자리에 있으면 그대로 쓴다 · 아니면 받은 파일을 제자리에 둔다(옮기는 동안만 .jarvis-new)
        if (-not (($step5 -eq 'rc=0') -and (Test-Path -LiteralPath $exe))) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $exe) | Out-Null
            $tmp = $exe + '.jarvis-new'
            $placed = $false
            for ($try = 1; ($try -le 2) -and (-not $placed); $try++) {
                try {
                    Copy-Item -LiteralPath $dl -Destination $tmp -Force -ErrorAction Stop
                    Move-Item -LiteralPath $tmp -Destination $exe -Force -ErrorAction Stop
                    $placed = $true
                } catch {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    Write-Log ('install direct: place try ' + $try + ' failed - ' + $_.Exception.Message)
                    if ($try -lt 2) { Start-Sleep -Seconds 3 }
                }
            }
            if (-not $placed) {
                Say ('     받은 파일을 제자리(' + (Redact $exe) + ')에 두지 못했습니다 — ' + (Get-FileStateWords $exe))
                return $false
            }
            Write-Log ('install direct: placed ' + (Redact $exe))
        }
        Remove-Item -LiteralPath $dl -Force -ErrorAction SilentlyContinue
        # 판정 = 제자리 파일이 판본을 답하는가(상한 있음)
        $vout = Join-Path $DlDir 'claude-version.txt'
        Remove-Item -LiteralPath $vout -Force -ErrorAction SilentlyContinue
        $vp = $null
        try { $vp = Start-Process -FilePath $exe -ArgumentList '--version' -NoNewWindow -PassThru -RedirectStandardOutput $vout -ErrorAction Stop } catch { $vp = $null }
        $vtext = ''
        if ($null -ne $vp) {
            if ($vp.WaitForExit($ClaudeVersionWaitMs)) {
                $vtext = [string](@(Get-Content -LiteralPath $vout -ErrorAction SilentlyContinue) | Select-Object -First 1)
            } else {
                try { $vp.Kill() } catch { }
                Write-Log 'install direct: --version timeout'
            }
        }
        Remove-Item -LiteralPath $vout -Force -ErrorAction SilentlyContinue
        if (-not ($vtext -match '[0-9]+\.[0-9]+\.[0-9]+')) {
            Say '     제자리에 둔 클로드가 판본을 답하지 않았습니다.'
            Write-Log ('install direct: --version no answer (' + $vtext + ')')
            return $false
        }
        Say ('     직접 받은 클로드가 판본을 답했습니다: ' + $vtext.Trim())
        Write-Log ('install direct: ok ' + $vtext.Trim() + ' - step5 ' + $step5)
        return $true
    } finally {
        $ProgressPreference = $saved
    }
}

# ── 하는 일 2 — 공식 설치기 호출 (멱등: 이미 있으면 건너뛴다) ─────
function Step-InstallClaude {
    if ($script:ClaudeOk) { Say '[2/10] 클로드가 이미 있습니다 — 건너뜁니다.'; return 0 }
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
                           -ArgumentList @('-NoProfile', '-Command', "& ([scriptblock]::Create((irm '$ClaudeInstallUrl' -UseBasicParsing))) $ClaudeChannel")
    } catch {
        Say "[2/10] 실패: $($_.Exception.Message). 인터넷 연결을 확인해 주십시오. 아래 「다시 하시는 법」대로 다시 실행하시면 여기서부터 이어서 갑니다."
        $script:ShowRerun = $true
        return 4
    }
    # 같은 자리(J-AV-01)에서 이미 막혔던 컴퓨터는 상한을 5분으로 줄인다 — 한 기기가 10분 × 3회 = 30분을 썼다(2026-09-14).
    $prevHold = 0
    try { $ph = (Read-HelpAttempts).Codes['J-AV-01']; if ($ph) { $prevHold = [int]$ph.N } } catch { $prevHold = 0 }
    $waitCap = if ($prevHold -ge 1) { $ClaudeInstallRetryWaitMs } else { $ClaudeInstallWaitMs }
    Write-Log ('install wait cap ' + $waitCap + 'ms (J-AV-01 before: ' + $prevHold + ')')
    $waitedMs = 0
    $sinceNoteMs = 0
    $avShown = ''
    while ((-not $p.HasExited) -and ($waitedMs -lt $waitCap)) {
        Start-Sleep -Milliseconds 1000
        $waitedMs += 1000
        $sinceNoteMs += 1000
        if ($sinceNoteMs -ge ($InstallNoteEverySec * 1000)) {
            $sinceNoteMs = 0
            # 🔴[int] 는 반올림이다 — 1분 30초가 「2분 30초」로 찍혀 시간이 뒤죽박죽이었다(2026-09-14 사진). 버림으로 센다.
            $mm = [int][math]::Floor($waitedMs / 60000); $ss = [int][math]::Floor($waitedMs / 1000) % 60
            Say ("     아직 설치 중입니다 (" + $mm + "분 " + $ss + "초 지남 · 최대 " + [int]($waitCap / 60000) + "분). 작업 표시줄에 백신 창이 떠 있는지 확인해 주십시오 — 「파일 전송」이나 [실행] 을 누르시면 이어집니다.")
            Send-Progress '2/10' 'wait' ([int]($waitedMs / 1000)) $null $null
            if ($waitedMs -ge 180000) { Send-EvidenceOnce 'stall' }   # v0.3.18 — 대기 3분 이상 = 정체 증거
            # 백신 창으로 보이는 창 제목이 떠 있으면 그 이름을 그대로 적는다(읽기만 · 바뀌었을 때만)
            $av = @(Get-AvWindowTitles)
            if (($av.Count -gt 0) -and ($av[0] -cne $avShown)) {
                $avShown = $av[0]
                Say ('     지금 떠 있는 창 가운데 백신 창으로 보이는 것: 『' + $av[0] + '』 — 그 창에서 [실행] 또는 [파일 전송] 을 눌러 주십시오.')
            }
        }
    }
    $held = $false
    $direct = $false
    if (-not $p.HasExited) {
        $held = $true
        Say ("[2/10] 설치가 " + [int]($waitCap / 60000) + "분 안에 끝나지 않았습니다.")
        # ⑴무엇이 살아 있었는지 적는다 ⑵공식 설치기를 멈추고 같은 공식 파일을 직접 받아 이어 간다(위 「상한에 닿았을 때」)
        $tree = @(Write-ClaudeInstallDiag $p '공식 설치기')
        Stop-ProcTree $p $tree
        Say '     공식 설치기를 멈추고, 같은 공식 자리에서 클로드 파일을 직접 받아 설치를 이어 갑니다(백신 검사는 그대로 받습니다).'
        $direct = (@(Install-ClaudeDirect)[-1] -eq $true)
    }
    if ($held -and (-not $direct)) {
        # 조용히 다음 단계로 가지 않는다. 여기서 멈춰야 사람이 무엇을 누를지 알게 된다.
        Write-JCode 'J-AV-01' '백신 창이 설치 파일을 붙들고 있는 것으로 보입니다'
        if ($prevHold -ge 1) {
            # 같은 자리 2회째부터 — 현장에서 통한 처방(공식 설치기를 도우미 밖에서 직접)을 설치기가 먼저 알린다
            Say '     클로드 공식 설치기를 이 도우미 밖에서 직접 돌려 보실 수도 있습니다 — 새 PowerShell 창에 아래 한 줄을 붙여넣고 Enter:'
            Say ('     & ([scriptblock]::Create((irm ' + $ClaudeInstallUrl + '))) ' + $ClaudeChannel)
            Say '     「Installation complete」 가 보이면 그 창을 닫고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        }
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
    if ($direct) {
        # 직접 받은 파일이 판본을 답했다 — 멈춘 공식 설치기는 우리가 껐으므로 그 종료 코드는 판정에 쓰지 않는다
        $rcShown = '공식 설치기는 멈춤 · 직접 받은 파일'
    } elseif ($null -eq $installRc) {
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
# 🔴v0.3.17(2026-09-15) — 로그인은 **새로 뜬 창**에서 한다. 설치 창은 그 창을 지켜보기만 한다.
#   왜: 벤더 로그인 화면(주소·코드 입력 칸)이 우리 안내문과 같은 창에 섞였다 — 60초마다 끼어드는 안내가 코드 칸을 밀어 올렸을 수 있다(추론 · 실측 아님).
#   붙여넣을 창도 「이 창」이라고만 적혀 있었다. 워크숍 로그인 막힘 9건(2026-09-14)에서 현장에 통한 처방은 「클로드를 따로 실행해 로그인」이었다.
#   ⚠옛 방식의 표준입출력 가로채기는 원인이 아니었다(동료 판정 2026-09-15 · 표본 3건 모두 벤더 도구가 20분 내내 살아 있었다) — 새 창의 근거는 화면 분리와 붙여넣을 창 하나다.
#   ⇒ 벤더 화면을 온전히 보이게 떼어 내고, 붙여넣을 창을 하나(새로 뜬 로그인 창)로 정한다. 설치 창은 조용히 기다리고 경과는 창 제목에만 적는다.
#   완료 판정 = 로그인 확인 명령(auth status)의 답 + 로그인 파일(.credentials.json)이 이번에 생겼거나 고쳐졌는가.
#   ⚠새 창이 실제로 어떻게 보이는지(주소가 찍히는가 · 창이 저절로 닫히는가)는 윈도우 실기로만 잰다 — 흉내 시험은 판정·상한·기록만 잰다.
$script:LoginRc = 0
$script:LoginStage = ''
function Set-LoginStage([string]$s) {
    # 어디서 끝났는지를 기록 끝부분(원격 보고에 실린다)에서 바로 가를 수 있게 단계 표지를 남긴다
    $script:LoginStage = $s
    Write-Log ('login stage: ' + $s)
}
# 로그인 파일 — 옮기기 단계(아래 · 같은 자리)와 같은 경로. 내용은 읽지 않는다(시각·크기만).
function Get-LoginCredStamp {
    $fi = New-Object System.IO.FileInfo ([System.IO.Path]::Combine($env:USERPROFILE, '.claude', '.credentials.json'))
    if (-not $fi.Exists) { return @{ Exists = $false; Ticks = [long]0; Length = [long]0 } }
    return @{ Exists = $true; Ticks = [long]$fi.LastWriteTimeUtc.Ticks; Length = [long]$fi.Length }
}
# 「있다」가 아니라 「이번에 생겼거나 고쳐졌다」로 본다 — 예전 로그인이 남긴 파일로 성공을 선언하지 않는다.
#   ⚠크기 하한 100바이트 = 토큰이 든 파일은 수백 바이트다. 빈 껍데기(「{}」)가 쓰였을 때 성공으로 읽지 않기 위한 선이다.
function Test-LoginCredFresh($before) {
    $now = Get-LoginCredStamp
    if ((-not $now.Exists) -or ($now.Length -lt 100)) { return $false }
    if (-not $before.Exists) { return $true }
    return ($now.Ticks -ne $before.Ticks)
}
# 판정 — 확인 명령이 답하면 그 답이 이긴다(「아니다」라고 답하면 파일이 새로 생겨도 아니다).
#   답을 받지 못했을 때(명령이 없어졌거나 답의 모양이 바뀌었을 때)만 파일로 판정한다 — 확인 명령은 벤더 문서에 없어 언제든 바뀔 수 있다.
function Resolve-LoginDone([string]$authText, $credBefore) {
    if ($authText -match '"loggedIn"\s*:\s*true') { return 'status' }
    if ($authText -match '"loggedIn"\s*:\s*false') { return '' }
    if (Test-LoginCredFresh $credBefore) { return 'file' }
    return ''
}
# 🔴확인 명령 한 번에도 상한을 건다(교차 검토 지적 채택 2026-09-15) — 상한 없이 부르면 벤더 도구가 멈추는 순간
#   이 창의 20분 상한까지 함께 멈춘다(창이 살아 있는 동안에도 부르게 되면서 생긴 자리다).
#   ⇒ 따로 띄워 출력은 임시 파일로 받고 상한에 닿으면 끈다. 못 띄우면 던진다(부르는 쪽이 「실행 실패」로 센다) · 상한이면 빈 답(= 답 없음).
function Get-LoginStatusText($exe) {
    $out = [System.IO.Path]::GetTempFileName()
    $err = [System.IO.Path]::GetTempFileName()
    $p = $null
    try {
        $p = Start-Process -FilePath $exe -ArgumentList 'auth','status' -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err -ErrorAction Stop
        if (-not $p.WaitForExit($LoginStatusWaitMs)) {
            try { $p.Kill() } catch { }
            # 끈 뒤 끝나기를 잠깐 기다린다 — 출력 파일을 쥔 채 지우러 가지 않게(교차 검토 두 번째 지적).
            #   ⚠상한 없는 WaitForExit() 로 기다리면 끄기가 안 먹힌 경우 이 자리가 다시 상한 없는 대기가 된다 ⇒ 2초로 묶는다.
            try { [void]$p.WaitForExit(2000) } catch { }
            Write-Log ('login status timeout ' + [int]($LoginStatusWaitMs / 1000) + 's: killed')
            return ''
        }
        return [System.IO.File]::ReadAllText($out)
    } finally {
        if ($p) { try { $p.Dispose() } catch { } }
        Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
    }
}
# 구독 종류만 떼어 적는다(다음 워크숍 준비 자료) — 같은 답에 든 이메일·조직 이름은 적지 않는다.
function Get-LoginSubscription([string]$authText) {
    if ($authText -match '"subscriptionType"\s*:\s*"([A-Za-z0-9_-]{1,32})"') { return $Matches[1] }
    return 'unknown'
}
# 승인 프로세스가 끝나면(스스로든 상한이든) 몇 초 간격으로 몇 번만 묻고 곧바로 갈래를 정한다.
#   🔴예전에는 여기서 10분을 더 기다렸다 — 승인 프로세스가 이미 끝났으면 그 뒤에 로그인이 될 길이 없어 헛 대기였다(2026-09-15 표본 · 실제 11분).
function Confirm-LoginAfterExit($exe, $credBefore) {
    $fails = 0
    for ($i = 1; $i -le $LoginConfirmTries; $i++) {
        $auth = ''
        try { $auth = Get-LoginStatusText $exe } catch {
            $auth = ''
            $fails++
            $why = (($_ | Out-String) -replace '\s+', ' ').Trim()
            Write-Log ('login poll failed ' + $fails + ': ' + $_.Exception.GetType().FullName + ' - ' + $why.Substring(0, [Math]::Min(300, $why.Length)))
        }
        $by = Resolve-LoginDone $auth $credBefore
        if ($by) { return @{ By = $by; Auth = $auth; Fails = $fails; Note = ('로그인 됨 · ' + $i + '번째 확인 · 판정 ' + $by) } }
        if ($i -lt $LoginConfirmTries) { Start-Sleep -Seconds $LoginPollInterval }
    }
    return @{ By = ''; Auth = ''; Fails = $fails; Note = ('로그인 안 됨 · 확인 ' + $LoginConfirmTries + '회 · 그 가운데 실행 실패 ' + $fails + '회') }
}
# 상한에 닿은 실패에서만 묻는다 — 성공한 사람에게는 손이 하나도 늘지 않는다. 답은 분류 표지로만 적는다(개인정보 아님).
$LoginAnswerTags = @{ '1' = 'browser-not-opened'; '2' = 'no-approval-screen'; '3' = 'approved-code-rejected'; 'enter' = 'unknown'; 'timeout' = 'no-answer'; 'no-input' = 'no-console-input' }
# 질문 전에 이 설치 창에 쌓여 있던 글자 수 — 코드를 로그인 창이 아니라 이 창에 붙여넣었는지 가르는 표지(글자 자체는 읽고 버린다 · 적지 않는다)
function Get-LoginStrayKeyCount {
    $n = 0
    try { while ([Console]::KeyAvailable -and ($n -lt 10000)) { [void][Console]::ReadKey($true); $n++ } } catch { return -1 }
    return $n
}
# ── 코드 넣기 (2026-09-15 윈도우 샌드박스 첫 실제 로그인) ─────────
# 🔴설치기가 띄운 로그인 창이 붙여넣기도 타이핑도 받지 못했다(오른쪽 단추·Ctrl+Shift+V·창 메뉴 전부 · 브라우저 주소창 타이핑은 정상).
#   벤더 도구(2.1.272 바이너리 실측)는 코드를 화면 입력 칸이 아니라 **표준 입력의 한 줄**로 읽는다 — 「코드#state」로 갈라 둘 다 있어야 받는다.
#   ⇒ 로그인 프로세스의 입력을 설치기가 쥐고, 사람이 브라우저에서 복사한 코드를 설치기가 그 입력에 한 줄로 넣는다(사람 손 = 승인 + 복사).
#   ★복사된 내용은 코드 모양일 때만 쓴다 — 모양이 아닌 내용은 읽고 버린다(기록·해시 0). 코드 자체도 기록에 안 남긴다(횟수만).
#   ★로그인을 연 순간 이미 복사돼 있던 코드(예전 시도의 코드)는 넣지 않는다 · 같은 코드는 한 번만 넣는다 · 한 번 연 로그인에서 최대 $LoginClipMaxSends 회.
#   ★폴백 — 복사된 내용을 못 읽는 기기: 이 설치 창에 붙여넣고 Enter 를 누르면 설치기가 같은 입력으로 넘긴다(이 창의 읽기는 PowerShell 자신이 한다).
# 문자 = 주소에 그대로 실리는 문자(영문·숫자·- . _ ~) · 「#」 은 정확히 하나. 1100자가 넘는 내용은 다듬지도 맞춰 보지도 않고 버린다(큰 복사 내용을 2초마다 다루지 않게).
function Test-LoginCodeShape([string]$s) {
    if (($null -eq $s) -or ($s.Length -gt 1100)) { return $false }
    return ($s.Trim() -cmatch '^[A-Za-z0-9._~-]{16,512}#[A-Za-z0-9._~-]{16,512}$')
}
function Get-LoginClipText {
    try { return [string](Get-Clipboard -Raw -ErrorAction Stop) } catch { return $null }
}
function Get-LoginTextHash([string]$s) {
    if (-not $s) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) } finally { $sha.Dispose() }
}
# 로그인 프로세스를 입력을 설치기가 쥔 채로 띄운다 — 출력은 이 설치 창에 그대로 찍힌다(주소가 보인다). 못 띄우면 던진다.
function Start-LoginPipeProc {
    param([string]$FilePath, [string[]]$ArgumentList)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = ($ArgumentList -join ' ')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    return [System.Diagnostics.Process]::Start($psi)
}
function Send-LoginCode($proc, [string]$code) {
    try {
        if ($proc.HasExited) { return $false }
        $proc.StandardInput.WriteLine($code.Trim())
        $proc.StandardInput.Flush()
        return $true
    } catch { return $false }
}
# 설치 창에 쌓인 글자를 기다리지 않고 읽어, 한 줄이 끝났으면 돌려준다(아니면 $null). 글자는 화면에 * 로만 보이고 기록에 안 남는다.
$script:LoginTypedBuf = ''
$script:LoginTypedKeys = 0   # 설치 창에서 읽은 글자 수(보고용 · 글자 자체는 적지 않는다)
function Read-LoginTypedLine {
    try {
        while ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            $script:LoginTypedKeys++
            if ($k.Key -eq [ConsoleKey]::Enter) {
                $line = $script:LoginTypedBuf
                $script:LoginTypedBuf = ''
                [Console]::WriteLine()
                return $line
            }
            if ($k.Key -eq [ConsoleKey]::Backspace) {
                if ($script:LoginTypedBuf.Length -gt 0) { $script:LoginTypedBuf = $script:LoginTypedBuf.Substring(0, $script:LoginTypedBuf.Length - 1); [Console]::Write("`b `b") }
                continue
            }
            if (([int]$k.KeyChar -ge 32) -and ($script:LoginTypedBuf.Length -lt 1100)) { $script:LoginTypedBuf += [string]$k.KeyChar; [Console]::Write('*') }
        }
    } catch { }
    return $null
}
function Read-LoginFailKey([int]$waitSec) {
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $waitSec) {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ([string]$k.KeyChar -match '^[123]$') { return [string]$k.KeyChar }
                if ($k.Key -eq [ConsoleKey]::Enter) { return 'enter' }
            } else {
                Start-Sleep -Milliseconds 200
            }
        }
        return 'timeout'
    } catch { return 'no-input' }
}
function Invoke-LoginFailQuestion {
    $stray = Get-LoginStrayKeyCount
    Say '     로그인이 시간 안에 끝나지 않았습니다. 어땠는지 숫자 하나만 눌러 주십시오 (안 누르셔도 1분 뒤 다음으로 갑니다):'
    Say '       1 = 브라우저가 열리지 않았다'
    Say '       2 = 브라우저는 열렸지만 승인 화면이 안 나왔다 (구독 안내가 나왔다)'
    Say '       3 = 승인하고 코드도 붙여넣었는데 안 됐다'
    Say '       Enter = 잘 모르겠다'
    $key = Read-LoginFailKey $LoginAskWaitSec
    $tag = [string]$LoginAnswerTags[$key]
    if (-not $tag) { $tag = 'unknown' }
    Write-Log ('login fail answer: ' + $tag + ' (key=' + $key + ') · stray keys before question=' + $stray)
    if ($key -match '^[123]$') { Say ('     ' + $key + ' 번으로 적었습니다.') }
    return @{ Answer = $tag; Keys = $stray }
}
# 로그인 성공 — 두 자리(창이 살아 있을 때 · 창이 끝난 뒤)가 같은 일을 하게 한 자리에서 한다.
function Complete-LoginSuccess([string]$by, [string]$authText, [string]$where) {
    Set-LoginStage ('done by ' + $by + ' ' + $where)
    Write-Log ('login subscription: ' + (Get-LoginSubscription $authText))
    # 🔴코드를 로그인 창이 아니라 이 설치 창에 붙여넣었으면 그 글자가 입력 버퍼에 남아 다음 단계(자비스 첫 화면)로 흘러간다
    #   (교차 검토 지적에서 파생 · 2026-09-15) ⇒ 여기서 비우고 글자 수만 적는다(글자 자체는 적지 않는다).
    $stray = Get-LoginStrayKeyCount
    if ($stray -gt 0) { Write-Log ('login stray keys in installer window cleared=' + $stray) }
    $script:LoggedIn = $true
    Say '[3/10] 로그인 확인했습니다.'
}
# 로그인 단계에서 본 것 — 기록 파일과 환경 보고(원격 해결이 보내는 본문)에 같은 줄을 남긴다. 코드·주소·계정 원문은 없다.
function Add-LoginReport($info) {
    $lines = @(
        ('로그인 창: ' + $info.Win),
        ('승인 프로세스: ' + $info.Proc),
        ('다시 열기: ' + $info.Reopen),
        ('코드 넣기: ' + $info.Send),
        ('끝난 뒤 확인: ' + $info.Confirm),
        ('상한에서 받은 답: ' + $info.Answer),
        ('질문 전 설치 창에 쌓인 글자 수: ' + $info.Keys)
    )
    foreach ($l in $lines) { Write-Log ('login report: ' + $l) }
    Add-ReportLines (@('', '## [3/10] 로그인 단계에서 본 것') + @($lines | ForEach-Object { '- ' + $_ }))
}

# ⚠이 함수는 값을 돌려주지 않는다 — 결과는 $script:LoginRc 에 둔다(부르는 쪽이 반환값을 받으면 안 된다).
#   🔴받으면 이 함수 안에서 실행한 벤더 명령의 출력이 화면이 아니라 그 변수로 빨려 들어가, 이 창에서 로그인할 때 코드 입력 칸이 안 뜬다(about_Return · 2026-09-15 규명).
function Step-Login {
    $script:LoginRc = 0
    # 🔴[1/10] 의 로그인 판정은 **클로드가 없던 시점**의 것이다 — 그 자리에서는 물어볼 상대가 없어
    #   unknown 으로 적고 지나간다. 그런데 [2/10] 에서 방금 클로드를 깔았다.
    #   ⇒ 브라우저를 열기 전에 **한 번 다시 본다.**
    #   왜 이 줄이 생겼나(2026-09-08 운영자 실기): 「지우고 다시 깔기」에서 지우개는 로그인을 남겼는데
    #   (화면에 「남김: 로그인」), 판정만 옛것이라 [3/10] 이 로그인 화면을 다시 열었다.
    #   ★첫 설치에서는 이 줄이 아무 일도 하지 않는다. 어긋나는 것은 지우고 다시 까는 길 하나뿐이다.
    #   ⚠능력 확인을 먼저 통과할 때만 묻는다 — 낡은 판본에서 auth status 는 질문으로 나간다.
    # 🔴이름이 아니라 [2/10] 이 확정한 전체 경로로 부른다(2026-09-14) — 승인과 확인이 같은 파일을 묻게. 못 찾으면 종전대로 이름.
    #   (2026-09-15 · 아래 재판정도 같은 경로·같은 상한으로 묻게 되어 여기로 올렸다)
    $claudeExe = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)[0].Source
    if (-not $claudeExe) { $claudeExe = 'claude' }
    if ((-not $script:LoggedIn) -and (Get-Command claude -ErrorAction SilentlyContinue) -and (Test-ClaudeAuthCmd)) {
        # 🔴이 재판정에도 확인 명령 한 번의 상한을 건다(2026-09-15 · 흉내 status-hang 적색 규명) — 여기서 상한 없이 부르면
        #   확인 명령이 멈추는 순간 로그인 카드도 20분 상한도 오기 전에 설치 창이 선다(기록 한 줄 없이).
        #   못 띄우거나 상한이면 답 없음 = 종전의 「로그인 안 됨」 갈래로 그대로 간다.
        $reauth = ''
        try { $reauth = Get-LoginStatusText $claudeExe } catch { $reauth = '' }
        if ($reauth -match '"loggedIn"\s*:\s*true') { $script:LoggedIn = $true }
    }
    if ($script:LoggedIn) { Say '[3/10] 이미 로그인돼 있습니다 — 건너뜁니다.'; return }
    if ($Mode -eq 'dry')  { Say "[3/10] (dry-run) 로그인 창을 열지 않았습니다. 승인 대기 상한 $LoginWaitTimeout 초(벽시계) · 끝난 뒤 확인 $LoginConfirmTries 회($LoginPollInterval 초 간격) · $LoginCheckpointSec 초에 한 번 점검."; return }

    if (-not (Test-ClaudeAuthCmd)) {
        Say '[3/10] 이 판본의 클로드는 로그인 확인 명령을 모릅니다. 판올림이 먼저 필요합니다.'
        Say '     아래 「다시 하시는 법」대로 다시 실행하시면 판올림부터 이어서 갑니다.'
        $script:ShowRerun = $true
        $script:LoginRc = 6
        return
    }
    Human '벤더' '로그인 승인 클릭 — 클로드 회사 화면에서만 할 수 있다(우리가 대신 못 누른다)'
    Say '[3/10] 지금 로그인 화면을 엽니다. 브라우저가 뜨면 승인을 눌러 주십시오.'
    foreach ($ln in $LoginCardLines) { Say $ln }
    # ★기다림은 `WaitForExit(ms)` 로 한다 — 커널 대기라 이 창의 입력을 건드리지 않는다(검토 지적 채택 2026-09-11 · 새 창에서도 그대로 둔다).
    # ★상한에 닿으면 그 창을 끝낸다 = 사람이 창을 닫은 것과 같은 결과 ⇒ 아래 확인과 J-LOGIN-01 회복 경로로 그대로 흘러간다.
    # ★$claudeExe(전체 경로)는 이 함수 첫머리에서 정했다 — 재판정·승인·확인이 같은 파일을 묻는다.
    $info = @{ Win = '설치 창(코드는 설치기가 넣는다)'; Proc = '-'; Reopen = '안 했다'; Send = '-'; Confirm = '-'; Answer = '묻지 않음(상한에 닿지 않았다)'; Keys = '-' }
    $c = @{ By = ''; Auth = ''; Fails = 0; Note = '-' }
    $oldTitle = $null
    try { $oldTitle = $Host.UI.RawUI.WindowTitle } catch { $oldTitle = $null }
    try {
        # ★승인 창이 상한 전에 스스로 끝났는데 로그인이 안 됐으면 = 코드가 받아들여지지 않은 것(J-LOGIN-02 · 2026-09-14 워크숍 4건)
        #   ⇒ 로그인 화면을 **한 번만** 더 연다(현장에서 통한 처방 「claude 를 다시 실행해 로그인」을 안에 둔 것). 두 번째도 같으면 J-LOGIN-01 로 간다.
        $reopened = $false
        while ($true) {
            $credBefore = Get-LoginCredStamp
            $loginProc = $null
            $timedOut = $false
            $w = 0
            # ★입력을 설치기가 쥔 자식으로 띄운다(위 「코드 넣기」) — 새로 뜬 창은 키 입력을 받지 못했다(2026-09-15 샌드박스). 사람은 복사만 한다.
            try { $loginProc = Start-LoginPipeProc -FilePath $claudeExe -ArgumentList 'auth','login' } catch { $loginProc = $null }
            $script:LoginProc = $loginProc   # v0.3.20 — 정체 증거가 「살아 있는 로그인 창」을 찾는 자리(여기 말고는 안 쓴다)
            if ($null -eq $loginProc) {
                # 다시 여는 자리에서 못 띄웠으면 확인으로 넘어간다(없는 명령을 앞에서 부르면 설치가 통째로 끝난다)
                if ($reopened) { Write-Log 'login reopen: could not start - go to confirm'; break }
                # 🔴로그인 프로세스를 못 띄우면 이 창에서 벤더 로그인을 부르지 않는다(이종 검토 2회차 채택 2026-09-15).
                #   그 길은 벤더가 윈도우 콘솔에서 코드를 읽는 경로라 샌드박스에서 입력을 못 받았고, 동기 호출이라 20분 상한도 걸리지 않았다.
                #   ⇒ 곧바로 확인 → 실패 끝맺음(스스로 푸는 법: 새 PowerShell 창에서 claude 직접 로그인 → 다시 실행)으로 간다.
                $info.Win = '띄우지 못했다'
                $info.Proc = '띄우지 못했다'
                Set-LoginStage 'start-failed'
                Write-Log 'login proc: could not start'
                Say '[3/10] 로그인 프로그램을 띄우지 못했습니다.'
            } else {
                # 핸들을 먼저 한 번 잡아 둔다 — 윈도우 PowerShell 5.1 에서 핸들을 안 잡은 채 끝난 프로세스는 종료 코드가 비어 읽히는 사례가 보고돼 있다(커뮤니티 보고 · 실기 확인 항목).
                try { [void]$loginProc.Handle } catch { }
                Set-LoginStage ('wait (installer-fed · pid ' + $loginProc.Id + ')')
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $checkpointSaid = $false
                $nextStatus = $LoginStatusEverySec
                $nextTitle = 0
                $nextProgress = 0
                # 로그인을 연 순간 이미 복사돼 있던 코드는 기준으로만 둔다(넣지 않는다) — 코드 모양일 때만 해시를 만든다.
                $clipBase = ''
                $clip0 = Get-LoginClipText
                if (Test-LoginCodeShape $clip0) { $clipBase = Get-LoginTextHash $clip0.Trim() }
                $clip0 = $null
                $lastSent = ''
                $clipSends = 0
                $typedSends = 0
                # WaitForExit 는 ms 를 받고, 끝났으면 $true 를 준다. 콘솔을 읽지 않는다.
                while (-not $loginProc.WaitForExit($LoginTickMs)) {
                    # 🔴상한은 **벽시계**로 잰다 — 쉰 초를 더해 가면 확인 명령에 든 시간이 빠져 「최대 20분」이 거짓이 된다(2026-09-15 표본 · 10분 표시가 실제 11분).
                    $w = [int]$sw.Elapsed.TotalSeconds
                    # 코드 넣기 — 복사된 내용에 「코드#state」 모양이 새로 나타나면 그 한 줄을 로그인 프로세스 입력에 넣는다(위 「코드 넣기」 머리 주석).
                    if ($clipSends -lt $LoginClipMaxSends) {
                        $clip = Get-LoginClipText
                        if (Test-LoginCodeShape $clip) {
                            $clipHash = Get-LoginTextHash $clip.Trim()
                            if (($clipHash -ne $clipBase) -and ($clipHash -ne $lastSent)) {
                                $lastSent = $clipHash
                                if (Send-LoginCode $loginProc $clip) {
                                    $clipSends++
                                    Write-Log ('login code sent from clipboard ' + $clipSends + ' after ' + $w + 's')
                                    Say '     복사하신 코드를 로그인에 넣었습니다 — 확인을 기다립니다.'
                                } else { Write-Log 'login code send failed (clipboard)' }
                            }
                        }
                        $clip = $null
                    }
                    $typed = Read-LoginTypedLine
                    if ($null -ne $typed) {
                        if (($typedSends -lt $LoginTypedMaxSends) -and (Test-LoginCodeShape $typed)) {
                            $lastSent = Get-LoginTextHash $typed.Trim()
                            if (Send-LoginCode $loginProc $typed) {
                                $typedSends++
                                Write-Log ('login code sent from installer window ' + $typedSends + ' after ' + $w + 's')
                                Say '     붙여넣으신 코드를 로그인에 넣었습니다 — 확인을 기다립니다.'
                            } else { Write-Log 'login code send failed (installer window)' }
                        } elseif ($typed.Trim()) {
                            Write-Log 'login typed line not used (not code shape or over limit)'
                            Say '     코드 모양이 아닙니다 — 브라우저 「Authentication code」 화면의 복사 단추로 복사한 코드만 넣어 주십시오.'
                        }
                        $typed = $null
                    }
                    $info.Send = ('복사된 코드 ' + $clipSends + '회 · 설치 창 붙여넣기 ' + $typedSends + '회 · 설치 창에서 읽은 글자 ' + $script:LoginTypedKeys)
                    # 창이 살아 있는 동안에도 로그인이 끝났는지 본다 — 파일은 5초마다(싸다) · 확인 명령은 파일이 새로 생겼을 때와 30초마다.
                    #   확인 명령은 이 설치 창에서 돈다 — 로그인 창의 입력에는 닿지 않는다.
                    $authNow = ''
                    $doneBy = ''
                    if ((Test-LoginCredFresh $credBefore) -or ($w -ge $nextStatus)) {
                        $nextStatus = $w + $LoginStatusEverySec
                        try { $authNow = Get-LoginStatusText $claudeExe } catch { $authNow = '' }
                        $doneBy = Resolve-LoginDone $authNow $credBefore
                    }
                    if ($doneBy) {
                        # 로그인은 끝났는데 창이 남아 있다 — 우리가 닫아 준다(부드럽게 한 번, 안 되면 끝낸다).
                        # 🔴창 닫기 신호는 자기 창이 있을 때만 보낸다(이종 검토 지적 채택 2026-09-15) — 로그인 프로세스는 설치 창을 함께 쓰므로 자기 창이 없다.
                        #   공유 콘솔 창에 닫기 신호가 가면 설치 창까지 닫힐 수 있다 ⇒ 창이 없으면 곧바로 3초 기다렸다 끝낸다.
                        if ($loginProc.MainWindowHandle -ne [IntPtr]::Zero) { try { [void]$loginProc.CloseMainWindow() } catch { } }
                        # 끝내기 전에 입력을 닫아 스스로 끝날 틈을 준다(이종 검토 2회차 · 벤더가 입력 끝을 따로 받지 않으면 3초 뒤 끝낸다).
                        try { $loginProc.StandardInput.Close() } catch { }
                        if (-not $loginProc.WaitForExit(3000)) { try { $loginProc.Kill() } catch { } }
                        Write-Log ('login window closed after login - exited=' + $loginProc.HasExited)
                        Complete-LoginSuccess $doneBy $authNow ('while window open after ' + $w + 's')
                        return
                    }
                    if ($w -ge $LoginWaitTimeout) {
                        $timedOut = $true
                        [Console]::Error.WriteLine("     $([int]($LoginWaitTimeout / 60))분 동안 승인이 오지 않아 이 기다림을 끝냅니다.")
                        # 🔴위 안내는 화면(stderr)에만 가서 기록 파일에 한 줄도 안 남았다 — 20분 상한이 작동했는지 기록으로 못 갈랐다(2026-09-14 57분·26분 대기 2건).
                        Write-Log ('login wait timeout ' + [int]($LoginWaitTimeout / 60) + 'min: CloseMainWindow')
                        # 🔴바로 `Kill()` 하지 않는다(검토 지적 채택 2026-09-11) — 잠금 파일·임시 파일을 정리할 틈을 준다.
                        #   맥이 INT → (안 되면) TERM 인 것과 **같은 순서**다: 부드럽게 한 번, 그래도 안 되면 세게.
                        if ($loginProc.MainWindowHandle -ne [IntPtr]::Zero) { try { [void]$loginProc.CloseMainWindow() } catch { } }
                        try { $loginProc.StandardInput.Close() } catch { }
                        if (-not $loginProc.WaitForExit(3000)) {
                            try { $loginProc.Kill() } catch { }
                            [Console]::Error.WriteLine('     (승인 창이 바로 닫히지 않아 한 번 더 끝냈습니다)')
                            Write-Log ('login wait timeout: Kill - exited=' + $loginProc.HasExited)
                        } else {
                            Write-Log 'login wait timeout: closed without Kill'
                        }
                        break
                    }
                    # 한 번만 묻는다 — 브라우저가 안 열린 사람은 여기서 스스로 풀 수 있다(주소는 로그인 창에 있다).
                    if ((-not $checkpointSaid) -and ($w -ge $LoginCheckpointSec)) {
                        $checkpointSaid = $true
                        Say '     [5분 점검] 브라우저에 로그인 화면이 떴습니까? 안 떴으면 이 설치 창에 보이는 https:// 주소를 복사해 브라우저 주소창에 붙여넣으십시오.'
                        Write-Log 'login checkpoint shown'
                    }
                    # 기다리는 동안 이 창에는 찍지 않는다 — 경과는 창 제목에만(60초마다).
                    if ($w -ge $nextTitle) {
                        $nextTitle = $w + $LoginSayInterval
                        try { $Host.UI.RawUI.WindowTitle = ('자비스 설치 — 로그인을 기다리는 중 ' + [int]($w / 60) + '분 · 코드는 복사만 하시면 됩니다') } catch { }
                    }
                    # 60초마다 대기 진행을 알린다(계약 3절 · 서버 쪽이 정체를 알아본다).
                    if ($w -ge $nextProgress) {
                        $nextProgress = $w + 60
                        Send-Progress '3/10' 'wait' $w $null $null
                        if ($w -ge 180) { Send-EvidenceOnce 'stall' }   # v0.3.18 — 로그인 대기 3분 이상 = 정체 증거
                    }
                    # 5분마다 로그인 창을 한 장 찍어 둔다(최대 4 · 계약 3절 · 원인 분류용 · 보고가 열리면 첨부).
                    if (($script:LoginCapCount -lt 4) -and ($w -ge (($script:LoginCapCount + 1) * $LoginCheckpointSec))) {
                        $script:LoginCapCount++
                        $jpg = Get-LoginWindowJpeg $loginProc
                        if ($jpg) {
                            $capf = Join-Path $JarvisHome ('login-cap-' + $script:LoginCapCount + '.jpg')
                            try { [System.IO.File]::WriteAllBytes($capf, $jpg); $script:LoginCapFiles += $capf; Write-Log ('login window capture ' + $script:LoginCapCount + ' saved') } catch { }
                        } else { Write-Log ('login window capture ' + $script:LoginCapCount + ' skipped (창을 못 찍음)') }
                    }
                }
                $w = [int]$sw.Elapsed.TotalSeconds
                $ec = '?'
                try { $ec = [string]$loginProc.ExitCode } catch { $ec = '?' }
                if ($timedOut) { $info.Proc = ('상한 ' + [int]($LoginWaitTimeout / 60) + '분에 닿아 끝냈다 · 종료 코드 ' + $ec + ' · ' + $w + '초') }
                else { $info.Proc = ('스스로 끝났다 · 종료 코드 ' + $ec + ' · ' + $w + '초') }
                Write-Log ('login proc exit=' + $ec + ' after ' + $w + 's' + $(if ($timedOut) { ' (cap)' } else { ' (self)' }))
                if ($timedOut) {
                    Set-LoginStage 'question'
                    $ans = Invoke-LoginFailQuestion
                    $info.Answer = $ans.Answer
                    $info.Keys = $ans.Keys
                }
            }
            Set-LoginStage 'confirm'
            $c = Confirm-LoginAfterExit $claudeExe $credBefore
            $info.Confirm = $c.Note
            if ($c.By) {
                Complete-LoginSuccess $c.By $c.Auth 'after window ended'
                return
            }
            if ($null -ne $loginProc) {
                if ((-not $timedOut) -and (-not $reopened)) {
                    Write-Log ('login ended early after ' + $w + 's without login')
                    Set-LoginStage 'reopen'
                    Say '[3/10] 로그인 코드가 받아들여지지 않은 것으로 보입니다 — 로그인 화면을 한 번 더 엽니다.'
                    Write-JCode 'J-LOGIN-02' '로그인 코드 입력이 받아들여지지 않았습니다(로그인 화면을 한 번 더 엽니다)'
                    # 이 코드는 끝의 코드가 아니다 — 다시 연 로그인이 되면 성공 끝이다. 화면·기록에만 남기고 칸은 비운다.
                    $script:JCode = ''
                    foreach ($ln in $LoginCardLines) { Say $ln }
                    $info.Reopen = '1회 했다'
                    $reopened = $true
                    continue
                }
            }
            break
        }
        Set-LoginStage 'fail'
        if ($c.Fails -ge $LoginConfirmTries) { Say '[3/10] 로그인 확인 명령이 한 번도 실행되지 못했습니다(까닭은 기록 파일에 적었습니다).' }
        else { Say '[3/10] 로그인이 확인되지 않았습니다.' }
        # 🔴사람이 스스로 푸는 길(2026-09-15 윈도우 샌드박스 실증) — 새 PowerShell 창에서 claude 를 직접 실행하면 입력·로그인이 정상이었다.
        #   다시 실행하면 [3/10] 이 로그인을 다시 판정해 건너뛴다(Step-Login 첫머리 재판정).
        foreach ($ln in $LoginSelfFixLines) { Say $ln }
        Add-LoginReport $info
        Write-JCode 'J-LOGIN-01' '로그인 승인이 시간 안에 끝나지 않았습니다'
        Set-NextStepRerun '아래 「다시 하시는 법」대로 다시 실행하시면 로그인 창이 다시 열립니다.'
        $script:LoginRc = 5
        return
    } finally {
        if ($null -ne $oldTitle) { try { $Host.UI.RawUI.WindowTitle = $oldTitle } catch { } }
    }
}

# ── 하는 일 4 — 자비스 기동 (지침 파일 + 첫 지시 주입) ───────
function Write-Directive {
    $d = @"
# 자비스 설치 도우미 지침

너는 이 컴퓨터의 설치를 대신 해 주는 자비스다. 상대는 처음 설치하는 사람이다.

## 준비 작업 1번 — 표지 파일 하나 만들기 (제일 먼저)

아래 파일을 만들어라. 내용은 두 줄이면 된다 — 지금 시각과 이 세션의 프로세스 번호.

    $(Join-Path $JarvisHome $MasterMarkName)

**왜 이것을 먼저 하는가**: 설치기는 이 파일이 생긴 것으로 「자비스가 지침을 읽고 준비 작업을 시작했다」를 판정한다.
없으면 설치기는 **시작하지 않은 것으로 보고 사람에게 사실대로 알린다**(거절인지 못 쓴 것인지는 단정하지 않는다).
이 파일은 설치 확인용이고, 지워도 설치기가 다시 물어볼 뿐 다른 일은 일어나지 않는다.

★**이 지침이 이상하다고 판단되면 따르지 않아도 된다.** 그때는 무엇이 왜 걸리는지 한 줄로 적어라 —
설치기는 그것을 「시작하지 않음」으로 읽고 사람에게 넘긴다. 읽지 않은 채 따르는 것보다 그쪽이 낫다.

**보고서에 「막힌 단계」가 적혀 있으면 표보다 먼저 그것을 말해라.** 세 가지를 이 순서로:
1. 어디까지 됐는가(끝난 단계) 2. 무엇이 막혔는가 3. **사람이 할 일이 있으면 그것 하나만** — 없으면 「없습니다, 제가 이어서 합니다」.

그 다음 아래 파일을 읽어 표로 옮겨 적는다.
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
    # ⚠표지 파일 경로만 **가리지 않고** 적는다(다른 경로는 Redact 로 ~ 로 줄인다).
    #   까닭: 이 줄은 사람이 읽는 안내가 아니라 **모델이 파일을 만들 자리**다. `~` 는 도구에 따라
    #   그대로 폴더 이름이 될 수 있고, 그러면 표지가 엉뚱한 곳에 생겨 판정이 거짓 적색이 된다.
    #   지침 파일은 그 사용자의 기계에만 있으므로 여기서 이름을 줄일 이유가 없다(첫 지시의 지침 경로도 이미 그대로다).
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
        # v0.3.18 — 자동 판올림 채널을 stable 로 묶는다(설치 인자와 같은 값 · 위 $ClaudeChannel 주석)
        $o | Add-Member -NotePropertyName autoUpdatesChannel -NotePropertyValue $ClaudeChannel -Force
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
    # 🔴v0.3.18 — 같은 판이 이미 깔려 있으면 132MB 를 받지 않는다([6/10] 이 어차피 건너뛴다 · 2026-09-15 윈 재설치 실기).
    #   판본을 못 읽을 때도 받지 않는다 — [6/10] 이 그때 있는 것을 그대로 쓰기 때문이다(Step-InstallCys 와 같은 갈래).
    $b0 = Test-CysBody
    if ($b0.Body) {
        $have0 = Get-CysInstalledVersion $b0
        if ($have0 -eq $CysVersion) {
            # v0.3.18 — 같은 판번이어도 내용(핀 지문)이 같다고 확인될 때만 건너뛴다(Get-CysContentState 주석).
            $cs0 = Get-CysContentState $b0
            if ($cs0 -eq 'match') { Say "[5/10] 같은 판(v$CysVersion)의 cys 가 이미 설치돼 있습니다 (지문 확인) — 받지 않고 건너뜁니다."; return 0 }
            Write-Log ('cys same version content ' + $cs0 + ' - download again')
            Say "[5/10] 같은 판(v$CysVersion)이지만 깔린 파일이 이번 판 파일과 같은지 확인되지 않습니다 — 다시 받아 덮어 설치합니다."
        } elseif (-not $have0) { Say '[5/10] 설치된 cys 의 판본을 읽지 못해 있는 것을 그대로 씁니다 — 받지 않고 건너뜁니다.'; return 0 } else { Say "[5/10] 설치된 cys 는 v$have0 입니다 — v$CysVersion 을 받아 덮어 설치합니다." }
    }
    New-Item -ItemType Directory -Force -Path $DlDir | Out-Null
    $dst = Join-Path $DlDir $CysWinFile
    if ((Test-Path $dst) -and ((Get-Item $dst).Length -eq $CysWinBytes)) {
        # 크기만 보고 건너뛰면 같은 크기의 다른 파일이 재실행 경로로 들어온다(검토 지적 2026-09-09) — 지문까지 본다.
        $have = Get-CysFileSha256 $dst
        if ($have -eq $CysWinSha256) { [void](Clear-WebMark $dst 'cys setup'); Say '[5/10] 설치 파일이 이미 있습니다 (지문 확인) — 건너뜁니다.'; return 0 }
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
        if ($hash -eq $CysWinSha256) { [void](Clear-WebMark $dst 'cys setup'); Say "[5/10] 받았습니다 (원 = oogisoogi/cys-ro v$CysVersion · 크기·지문 확인 완료)."; return 0 }
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
    # 🔴v0.3.18 — 「몸통이 있다」만 보고 건너뛰지 않는다. 판본을 견줘 다르면 조용한 설치(/S)로 덮어 깐다(2026-09-15 · 재설치가 옛 판을 남긴 결함).
    #   ⚠판본을 못 읽으면 있는 것을 그대로 쓴다(앞 판과 같은 동작) — 모르는 채 덮어 깔다 멀쩡한 설치를 흔들지 않는다.
    #   ⚠덮어 깔기가 안 되면 쓰시던 판으로 이어 간다 — 옛 판이 남는 것이 설치 전체가 멈추는 것보다 낫다(설치 창을 사람에게 띄우지도 않는다).
    $upgradeFrom = ''
    $refresh = ''   # v0.3.18 — 같은 판번을 핀 파일로 덮어 까는 까닭(Get-CysContentState 값) · 빈 글자 = 해당 없음
    $b0 = Test-CysBody
    if ($b0.Body) {
        $have0 = Get-CysInstalledVersion $b0
        if ($have0 -eq $CysVersion) {
            $cs0 = Get-CysContentState $b0
            if ($cs0 -eq 'match') { Say "[6/10] cys 가 이미 설치돼 있습니다 (v$have0 · 지문 확인) — 건너뜁니다."; return 0 }
            $refresh = $cs0
            $upgradeFrom = $have0
            Write-Log ('cys refresh same version ' + $have0 + ' (' + $cs0 + ')')
        }
        if (-not $have0) { Say '[6/10] cys 가 이미 설치돼 있습니다 — 판본을 읽지 못해 있는 것을 그대로 씁니다.'; Write-Log 'cys installed version unknown - keep'; return 0 }
        if (-not $refresh) {
            $upgradeFrom = $have0
            Write-Log ('cys upgrade ' + $have0 + ' -> ' + $CysVersion)
        }
    }
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
    if ($refresh) { Say "[6/10] 같은 판(v$CysVersion)을 이번 판 파일로 덮어 설치합니다 (깔린 파일이 이번 판과 같다고 확인되지 않았습니다)." } elseif ($upgradeFrom) { Say "[6/10] cys 를 v$upgradeFrom 에서 v$CysVersion 으로 덮어 설치합니다." } else { Say '[6/10] cys 를 설치합니다.' }
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
        # 덮어 깔 때는 조용한 설치(/S) 하나만 — 설치 창을 사람에게 띄우지 않는다(이 함수 머리 주석).
        if ($upgradeFrom -and $sw -eq '') { break }
        try {
            if ($sw -eq '') { Say '     조용한 설치가 되지 않아 설치 창을 띄웁니다. 창의 안내대로 [다음]을 눌러 주십시오.' }
            # -Wait 를 쓰지 않는다: 한도 없이 기다리면 경고 창 하나에 영원히 서 있게 된다.
            $p = if ($sw -eq '') { Start-Process -FilePath $dst -PassThru -ErrorAction Stop }
                 else { Start-Process -FilePath $dst -ArgumentList $sw -PassThru -ErrorAction Stop }
            $limit = if ($sw -eq '') { $InstallGuiWaitMs } else { $InstallWaitMs }
            # v0.3.18 텔레메트리 ① — 기다리는 동안 60초마다 「대기」 표지만 보낸다(글·화면은 싣지 않는다 · fail-open).
            #   ⚠상한은 그대로다: 60초 조각의 합이 $limit 에 닿으면 멈춘다(조각마다 상한이 있어 한 번의 대기가 상한을 먹지 않는다).
            $waitedMs = 0; $exited = $false
            while ($waitedMs -lt $limit) {
                $chunk = [Math]::Min(60000, $limit - $waitedMs)
                if ($p.WaitForExit($chunk)) { $exited = $true; break }
                $waitedMs += $chunk
                Send-Progress '6/10' 'wait' ([int]($waitedMs / 1000)) $null $null
                if ($waitedMs -ge 180000) { Send-EvidenceOnce 'stall' }   # 대기 3분 이상 = 정체 증거
            }
            if (-not $exited) {
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
        #   (installer-speed-pin-0320) 1초마다 60번 = 상한 60초 그대로 · 종전 3초 간격은 끝난 뒤 최대 3초를 헛기다렸다.
        for ($i = 0; $i -lt 60; $i++) {
            # 덮어 깔 때는 몸통이 처음부터 있다 — 판본이 바뀌었을 때만 마친 것이다.
            $bNow = Test-CysBody
            # 같은 판을 덮어 깔 때는 판번이 처음부터 같다 — 설치기가 스스로 끝나고 성공(0)을 답했을 때만 마친 것이다.
            if ($bNow.Body -and ((-not $upgradeFrom) -or ((Get-CysInstalledVersion $bNow) -eq $CysVersion)) -and ((-not $refresh) -or ($p.HasExited -and $p.ExitCode -eq 0))) {
                [void](Save-CysPinStamp $bNow)
                Say '[6/10] 설치를 마쳤습니다.'; return 0
            }
            Start-Sleep -Seconds 1
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
    if ($upgradeFrom -and (Test-CysBody).Body) {
        Say "[6/10] 새 판(v$CysVersion)을 넣지 못했습니다 — 쓰시던 v$upgradeFrom 으로 이어 갑니다."
        Write-Log ('cys upgrade failed - continue with ' + $upgradeFrom)
        return 0
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
    if ($ver) {
        Say "[7/10] cys 가 답합니다: $ver"; Say "     부르는 길: $(Redact $script:CysCli)"
        # 🔴v0.3.18 — 새 창의 자비스가 이름만으로 cys 를 부를 수 있게 사용자 PATH 에 cys 자리를 넣는다(Seed-CysPath 머리 주석).
        if ($b.Cli -and ((Split-Path $b.Cli -Leaf) -ieq 'cys.exe')) { [void](Seed-CysPath (Split-Path $b.Cli -Parent)) }
        return 0
    }
    Say '[7/10] 프로그램은 있는데 아직 명령으로 부를 수 없습니다. PowerShell 창을 새로 열고 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
    $script:ShowRerun = $true
    return 7
}

# ── 하는 일 8 — 이 계정에 자리 잡기 ───────────────────────────────
# 관리자 권한을 쓰지 않는다. 마지막 판정은 자가진단이 전부 통과하는가로 한다.
$DaemonPingCapSec = 20    # 데몬 응답을 기다리는 상한(초) — 종전 2초×10회와 같다
$DaemonPingGapMs  = 500   # 다시 묻기 전 간격 — 뜬 것을 보면 곧바로 넘어간다(installer-speed-pin-0320)
$script:DoctorText = $null   # [8/10] 자가진단 출력 — 뒤의 보고 갱신(2단)이 같은 명령을 다시 부르지 않고 이것을 쓴다
function Step-PrepareAccount {
    if ($Mode -eq 'dry') { Say '[8/10] (dry-run) 계정 준비를 하지 않았습니다.'; return 0 }
    $cli = if ($script:CysCli) { $script:CysCli } else { 'cys' }
    Say '[8/10] 이 계정에 자리를 잡습니다.'
    # (installer-speed-pin-0320) 이 단계 안에서 무엇이 오래 걸리는지 기록에 초 단위로 남긴다(실기 비교용 · 화면에는 안 나간다).
    $prepSw = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Logged 'init-pack' $cli @('init-pack') | Out-Null
    Write-Log ('timing 8/10 init-pack t=' + [int]$prepSw.Elapsed.TotalSeconds + 's')
    # 🔴2026-09-15 개정(윈 2차 재설치 실기) — 사전 설정·로그인 이어 두기를 **cys 를 켜기 전에** 한다.
    #   cys 가 켜지는 순간 지난 편성 기록이 있으면 동료 좌석이 곧바로 뜬다. 그 좌석들이 읽는 자리가 전용 자리(~\.cys\claude)인데,
    #   앞 판은 켠 **뒤에** 심었다 ⇒ 셋 다 첫 실행 질문(테마 고르기)·로그인 방법 고르기 앞에 섰다. 떠 있는 좌석은 뒤에 심은 것을 다시 읽지 않는다.
    #   전용 자리는 바로 위 init-pack 이 만든다. 시드는 자가진단 결과와 관계가 없다(2026-09-10 개정) — 갈림길보다 앞이기만 하면 된다.
    Set-AllProfiles | Out-Null
    Copy-LoginToIsolated | Out-Null
    $daemonRc = Invoke-Logged 'daemon install' $cli @('daemon', 'install')
    # ★등록됐는지는 **작업을 직접 보고** 정한다(위 Test-CysAutoStart 의 까닭). 팩이 찍은 줄도,
    #   우리 추정도 아니다. 이 값 하나로 아래 문구가 갈린다 — 그래야 두 줄이 서로 모순되지 않는다.
    $script:AutoStartState = Get-CysAutoStartState $cli
    Write-Log ("daemon install rc=$daemonRc · scheduled task cysd = " + $script:AutoStartState)
    Write-Log ('timing 8/10 daemon-install t=' + [int]$prepSw.Elapsed.TotalSeconds + 's')
    # 한 번 응답을 받았으면 그것으로 판정한다. 다시 물으면 그 순간의 흔들림으로 성공이 실패가 된다.
    #   (installer-speed-pin-0320) 0.5초 간격 · 상한은 시계로 20초 그대로(종전 2초×10회) — 뜬 것을 보면 곧바로 넘어간다.
    $alive = $false
    $pingSw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $pong = (& $cli ping 2>&1) -join ' '
        if ($pong -match 'pong') { $alive = $true; break }
        if ($pingSw.Elapsed.TotalSeconds -ge $DaemonPingCapSec) { break }
        Start-Sleep -Milliseconds $DaemonPingGapMs
    }
    Write-Log ('timing 8/10 ping alive=' + $alive + ' t=' + [int]$prepSw.Elapsed.TotalSeconds + 's')
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
            $pingSw = [System.Diagnostics.Stopwatch]::StartNew()
            while ($true) {
                $pong = (& $cli ping 2>&1) -join ' '
                if ($pong -match 'pong') { $alive = $true; break }
                if ($pingSw.Elapsed.TotalSeconds -ge $DaemonPingCapSec) { break }
                Start-Sleep -Milliseconds $DaemonPingGapMs
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
    $script:DoctorText = $doc
    Write-Log ('timing 8/10 doctor t=' + [int]$prepSw.Elapsed.TotalSeconds + 's')
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
    # 사전 설정을 심는다 — 안 그러면 동료들이 첫 실행 질문 앞에서 멈춰 선다(실측).
    # 🔴2026-09-10 개정 — 앞 판은 이 두 줄이 **자가진단 실패 갈래보다 뒤**에 있었다. 그래서 자가진단이
    #   한 가지라도 못 통과하면 전용 자리에 사전 설정이 **영영 안 심겼고**, 그 뒤 자비스가 부른 동료
    #   좌석들이 전부 첫 실행 질문(폴더 신뢰) 앞에 섰다. ★자가진단 결과와 시드는 아무 관계가 없다 —
    #   자리는 이미 생겼고, 심는 것은 실패해도 잃을 것이 없다. ⇒ 갈림길 **앞**으로 옮긴다.
    # 🔴2026-09-15 — 두 줄(Set-AllProfiles · Copy-LoginToIsolated)은 더 앞, 이 단계 맨 앞(init-pack 바로 뒤 · cys 켜기 전)으로 옮겼다. 그 자리 주석 참조.
    if ($script:TrustJournalFailed) {
        Say ('[8/10] 홈 폴더 신뢰 기록을 남기지 못했습니다 — ' + (Get-TrustRollbackWords) + ' 여기서 멈춥니다.')
        $script:JCode = 'J-PERM-01'
        $script:NextStep = '저장 공간과 백신 알림을 확인하신 뒤 다시 실행해 주십시오.'
        $script:ShowRerun = $true
        return 8
    }
    # 🔴v0.3.18 — 막는 기준은 자가진단의 **총 실패 수가 아니라 자비스 창(cys 좌석)을 여는 데 필요한 항목**이다(2026-09-15 윈 2·3차 재설치 실기).
    #   cys 를 한 번이라도 돌린 기기에서는 좌석과 무관한 항목(런타임 git 폴더의 목록 대조 — git 첫 실행이 만든 파일)이 실패 1 을 냈고,
    #   앞 판은 그 1 을 「계정 준비가 끝나지 않음」으로 올려 [9/10] 이 cys 안 대신 이 창에서 자비스를 띄웠다 — 그 자비스가 창을 차지해
    #   [10/10] 이 영영 나오지 않고 동료도 서지 않았다(재설치 기기 전부가 이 결말 · 1차 깨끗한 기계는 실패 0 이라 드러나지 않았다).
    #   ⇒ 아래 목록의 항목이 실패일 때만 막는다. 나머지 실패는 「주의」로 알리고 이어 간다. 데몬이 답하는지는 위에서 따로 잰다(ping).
    #   목록 = cys v0.14.36 자가진단 항목 가운데 좌석이 서는 데 쓰이는 것: 팩 판본 · 팩 상태 · 설치 목록 · 각성 훅.
    #   ⚠항목 줄을 하나도 못 읽으면(문안이 바뀐 경우) 목록으로 가를 수 없다 — 앞 판대로 실패 수 전체로 막는다(모르는 채 통과시키지 않는다).
    #   ⚠요약의 실패 수보다 읽은 실패 줄이 적으면, 못 읽은 만큼은 막는 쪽으로 센다.
    $SeatFatalItems = @('pack-version', 'pack-state', 'install-manifest', 'hook')
    $items = [regex]::Matches($doc, '(?m)^\s*\[(OK|WARN|FAIL|SKIP)\s*\]\s+(\S+)')
    $fatal = @(); $minor = @()
    foreach ($it in $items) {
        if ($it.Groups[1].Value -ne 'FAIL') { continue }
        $name = $it.Groups[2].Value
        if ($SeatFatalItems -contains $name) { $fatal += $name } else { $minor += $name }
    }
    if ($items.Count -gt 0) { $seatBad = $fatal.Count } else { $seatBad = $bad }
    $unread = $bad - ($fatal.Count + $minor.Count)
    if (($items.Count -gt 0) -and ($unread -gt 0)) { $seatBad += $unread }
    Write-Log ('doctor seat judgment: items=' + $items.Count + ' fail=' + $bad + ' fatal=' + ($fatal -join ',') + ' minor=' + ($minor -join ',') + ' unread=' + [Math]::Max(0, $unread) + ' block=' + $seatBad)
    if ($seatBad -gt 0) {
        Say "[8/10] 자가진단에서 $bad 가지가 통과하지 못했습니다."
        if ($fatal.Count -gt 0) { Say ('     자비스 창을 여는 데 필요한 항목: ' + ($fatal -join ', ')) }
        Say '     아래 자비스가 무엇이 걸렸는지 사람 말로 알려 드립니다.'
        return 8
    }
    if ([int]$nSkip -gt 0) { Say "     ($nSkip 가지는 이 컴퓨터에서 판정할 수 없는 항목입니다 — 고장이 아닙니다.)" }
    if ($minor.Count -gt 0) {
        # 🔴v0.3.18 — 이 갈래는 「실패」가 아니다: 좌석과 무관한 항목(실기 = runtime-sanity · cys 가 품은 git 도구 폴더(runtime\git\etc)의 목록 대조)이다.
        #   앞 문구 「통과하지 못했습니다」가 기록·보고에서 실패로 읽혀 오진을 불렀다 ⇒ 등급을 「참고」로 사실대로 적는다.
        Say ('     참고: 자가진단 ' + $minor.Count + ' 가지는 자비스 창과 무관한 항목이라 이어 갑니다 (' + ($minor -join ', ') + ' · 고장이 아닙니다 — 설치에 영향 없음).')
        Write-Log ('doctor minor (not a failure): ' + ($minor -join ','))
        Say '[8/10] 자리를 잡았습니다 (자비스 창에 필요한 항목 실패 0).'
        return 0
    }
    Say '[8/10] 자리를 잡았습니다 (실패 0).'
    return 0
}

# ── 하는 일 9 — 자비스 깨우기 ─────────────────────────────────────
# cys 안에서 세션을 여는 것이 기본이고, 그것이 안 되면 이 창에서 바로 띄운다.
function Step-Wake {
    # 🔴**cys 에 넘기는 인자**는 ASCII 로만 쓴다(자리 여는 명령 · 창 이름).
    # 까닭(2026-09-05 실측): 우리말이 든 인자를 cys 에 넘겼더니 받는 쪽이 여섯 개의 깨진 글자로 읽고
    #   「알 수 없는 인자」라며 거절했다 — 그래서 창이 열리지 않았다.
    # ★그 규칙이 닿는 자리는 **cys 명령줄**이다. 첫 지시는 cys 를 지나지 않는다 —
    #   wake.ps1(BOM 파일) 안에 적혀 claude 에게 바로 가고, 이 창 폴백에서도 claude 의 인자로 바로 간다.
    #   그 길로 우리말이 온전히 가는 것은 이미 실측됐다: 0.3.21 이 같은 자리로 보낸 선언
    #   「너는 마스터다」가 2026-09-16 샌드박스에서 글자 그대로 모델에 닿았다(모델이 그 지시를 읽고 답했다).
    # 🔴2026-09-16 개정(TICKET=installer-0322-awaken · 정본 = master/reports/awaken-refusal/REPORT-awaken-refusal-2026-09-16.md)
    #   앞 판 문구 = `Read the file <파일> and do exactly what it says. Your first line must be the fixed line specified there.`
    #   그 문구가 거부를 불렀다 — 모델은 지령의 **내용**이 아니라 **요구의 형태**를 거절했다:
    #   ⑴읽어 보기 전에 그대로 실행하라(do exactly what it says) ⑵네 첫마디를 이 대본으로 하라(first line must be).
    #   같은 샌드박스·같은 세션·같은 80KB 주입에서 문구만 의뢰형으로 바꾸자 같은 모델이 같은 파일을 읽고 수행했다
    #   (2026-09-16 13:25 단일 변수 A/B 실측). ⇒ 통과시키는 문구가 아니라 **읽고 판단할 수 있게 사실을 주는 문구**로 바꾼다
    #   (팩 session-start.sh 가 2026-08-01 같은 사건에서 채택한 원칙과 같다).
    # ⛔첫 줄 「너는 마스터다」는 그대로 둔다 — 그것은 인사말이 아니라 **팩 훅의 선언 트리거**다
    #   (UserPromptSubmit → role-bootstrap.sh → javis_detect.py `SUBJECT.{0,n}(마스터|master).{0,n}TERM`).
    #   그 줄을 빼면 동료 자리가 영영 서지 않는다(실측: 의뢰 문구 단독 = 감지기 rc 1 「선언 없음」).
    $firstPrompt = "install-jarvis 폴더의 install-directive.md($DirectiveFile) 를 읽고, 거기 적힌 준비 작업을 해 주세요."
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
    # ★지난 설치가 남긴 표지를 먼저 치운다 — 남아 있으면 이번 마스터가 아무 일도 안 해도 「시작했다」로 읽힌다.
    #   (시각 검사도 함께 두지만, 지우는 쪽이 먼저다 — 검사 하나에만 기대면 그 검사가 눈이 멀 때 거짓 초록이 된다.)
    Clear-MasterMark
    Set-FleetBaseline $cli
    $wakeFile = Join-Path $JarvisHome 'wake.ps1'
    # 앞 단계에서 자리 잡기가 끝나지 않았으면 cys 안에 창을 열 수 없다.
    # 시도해 봐야 실패 줄만 하나 더 보이므로, 사유를 말하고 바로 이 창에서 띄운다.
    if ($script:BlockedStep) {
        Say "     ($($script:BlockedStep) 이(가) 끝나지 않아 cys 안에는 아직 열 수 없습니다. 이 창에서 띄웁니다.)"
    } elseif (Get-Command $cli -ErrorAction SilentlyContinue) {
        # 이 파일은 우리가 쓰고 우리가 부른다. 안에서는 따옴표를 마음껏 쓸 수 있다 —
        # 벗겨질 자리(다른 프로그램의 인자)를 지나지 않기 때문이다.
        # 🔴첫 각성은 자동이다(2026-09-15 결정 · 사람이 치던 「너는 마스터다」 한마디를 없앤다).
        #   선언은 **자비스를 띄울 때 넘기는 첫 프롬프트의 첫 줄**에 싣는다.
        #   ⛔창에 글을 밀어 넣는 길(cys send)은 쓰지 않는다 — 자비스가 그것을 기계 배달로 보고 동료를 부르지 않는다
        #     (2026-09-05 4회차 실측). 첫 프롬프트는 배달 기록에 없어 선언으로 읽힌다(팩 v0.14.36 판정기 2026-09-15 실측).
        #   ★선언은 문장에 섞지 않고 **그 자체 한 줄**로 둔다 — 둘째 줄이 종전 지침 읽기다.
        #   ★우리말은 이 파일(BOM) 안에만 있다 — 여는 명령(다른 프로그램의 인자)에는 여전히 한 글자도 없다.
        #   이것이 닿았는지는 여기서 단정하지 않는다 — [10/10] 이 동료 자리가 서는지로 잰다.
        $wakePrompt = $FleetTrigger + "`n" + $firstPrompt
        # 경로에 작은따옴표가 있으면(사용자 이름 등) 문자열이 거기서 닫혀 wake.ps1 이 안 돈다 ⇒ 두 번 써서 글자로 남긴다(2026-09-15 검토 지적 채택).
        $wakeQuoted = $wakePrompt -replace "'", "''"
        # claude 가 .cmd 래퍼로 풀리면 cmd.exe 가 인자 속 줄바꿈에서 명령을 끊는다 ⇒ 실행 파일(.exe)을 먼저 고르고, 없으면 종전대로 이름으로 부른다.
        #   (제안된 「claude.ps1 로 고정」은 기각 — 공식 설치본에는 .ps1 이 없어 정상 경로가 깨진다.)
        $wakeBody = @(
            "`$c = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Where-Object { `$_.Extension -eq '.exe' })[0]",
            "`$exe = if (`$c) { `$c.Source } else { 'claude' }",
            "& `$exe --dangerously-skip-permissions '$wakeQuoted'"
        ) -join "`r`n"
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
        # 🔴2026-09-15 개정(윈 2차 재설치 실기) — 이 창에서 띄울 때도 선언을 첫 줄로 함께 넘긴다(cys 안에서 여는 wake.ps1 과 같은 두 줄).
        #   앞 판은 지침 읽기 한 줄만 넘겨, 이 길로 온 자비스에게는 「너는 마스터다」가 없었다.
        #   claude 가 .cmd 래퍼로 풀리면 cmd.exe 가 인자 속 줄바꿈에서 명령을 끊는다 ⇒ wake.ps1 과 같이 실행 파일(.exe)을 먼저 고른다.
        $fallbackPrompt = $FleetTrigger + "`n" + $firstPrompt
        $fallbackExe = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.exe' })[0]
        $fallbackExe = if ($fallbackExe) { $fallbackExe.Source } else { 'claude' }
        & $fallbackExe --dangerously-skip-permissions $fallbackPrompt
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
# 자비스는 「너는 마스터다」라는 말을 들어야 깨어나 동료를 부른다.
# 🔴2026-09-15 결정 — 그 말을 사람이 치지 않는다. [9/10] 이 자비스를 띄울 때 첫 프롬프트의 첫 줄로 함께 넘긴다.
#   (09-05 판의 「사람이 직접 친다」 부탁은 폐지됐다 · 사용자가 편해야 한다가 최고 원칙이다.)
# 우리가 하는 일 = ⑴동료 자리가 서는지 **실제로 보고**(최대 4분) ⑵서면 「깨어났습니다」 ⑶안 서면 그때만 사람에게 부탁한다.
#   ★「보냈다」로 성공을 말하지 않는다 — 자식 좌석(cso·worker)이 선 것이 곧 선언이 들어갔다는 증거다.
#     안 섰는데 「깨어났습니다」라고 하면 사용자는 창을 닫고 자비스는 영영 혼자 남는다.
$FleetTrigger = '너는 마스터다'
# ── 마스터 각성 판정(TICKET=installer-0322-awaken · 2026-09-16) ────────────────────────────
# 🔴앞 판의 판정(`Test-DeclarationSeen`)은 **master 자리를 한 글자도 보지 않았다** — 「master 가 아닌 역할이
#   하나라도 살아 있으면 참」이었다. 그런데 자식 자리는 마스터의 순종과 **무관한 경로로도 선다**
#   (cys 가 켜질 때 지난 편성 기록을 보고 `formation-heartbeat` 가 자동 복구한다 · [8/10] 주석 참조).
#   ⇒ 2026-09-16 샌드박스에서 마스터가 첫 지시를 **거절한 그 순간에도** 화면은 「함대가 섰습니다 ·
#     자비스가 깨어났습니다」를 찍었다. 판정의 증거가 판정 대상과 인과적으로 끊겨 있었다.
# ★그래서 마스터 자리를 **직접 잰다**. 축은 둘이고, 둘 다 우리가 만들지 않는 것이다:
#   ⑴그 자리 클로드의 세션 기록(jsonl)에 **답 레코드 ≥1** = 「지시를 받고 말을 했다」
#   ⑵지침의 **첫 준비 작업**이 쓰는 표지 파일 = 「받은 뒤 실제로 일을 시작했다」
#   ⑴∧⑵ 일 때만 「깨어났습니다」라고 말한다. 셋으로 갈리는 답을 한 칸에 담지 않는다(아래 Confirm-MasterAwake).
# ⚠이 축이 새로 만드는 실패 모드 = 「표지를 못 썼다」(권한·경로). 그래서 ⑴만 참인 칸의 문구는
#   원인을 **단정하지 않고 둘 다 적는다**(거절했거나 표지를 쓰지 못했거나). 거짓 적색을 거짓 초록으로 바꾸지 않는다.
$MasterMarkName    = 'awake-master.ok'   # 지침의 준비 작업 1번이 만드는 표지(우리가 만들지 않는다)
$MasterAwakeCapSec = 120                 # 첫 관측 상한(브리프 지정) · 시험이 줄여 쓴다
$MasterAwakePollSec = 3
$MasterRetryCapSec = 60                  # 재시도 뒤 다시 재는 상한
$MasterRetryMax    = 1                   # 재시도는 **한 번**뿐이다(같은 문구를 되풀이해 밀어붙이지 않는다)
$FleetRoles   = @('master', 'cso', 'worker')   # 이 기계에서 세울 수 있는 역할(리뷰어 둘은 고르기 나름)
$FleetPollSec   = 2    # 자리 목록을 몇 초마다 보는가(시험이 줄여 쓴다) · 종전 5초(installer-speed-pin-0320 — 먼저 보고 나서 기다린다)
$FleetAwakeTries = 120 # 2초 × 120 = 240초(4분). 사람 손 없이 동료가 서기를 기다리는 상한.
#   🔴90초였다가 올렸다(2026-09-15 윈 실기) — 자비스의 첫 턴(지침 읽기 + 점검)이 1분 13초 넘게 걸려, 90초가 먼저 끝나
#     폴백 카드가 뜬 뒤에 사람이 아무것도 안 쳤는데 함대가 섰다(카드는 순수 오발 · 손 계수가 거짓으로 늘었다).
$FleetWaitTries = 180  # 2초 × 180 = 6분. (자동이 안 닿았을 때) 사람이 창을 찾아 한 문장 치기에 넉넉한 시간.
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
    $script:ChildAwakeSince = [datetime]::UtcNow   # 자식 자리 세션 기록은 이 시각 뒤에 생긴 것만 센다
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
        # 자리 번호가 없는 줄(경고·오류 글 — 목록 조회는 오류 출력도 섞어 받는다)은 자리가 아니다 ⇒ 역할 글자를 찾지 않는다(2026-09-15 검토 지적 채택).
        if (-not $mid.Success) { continue }
        # 기준선에 있던 자리는 **이번 설치의 것이 아니다** — 세지 않는다.
        if ($script:BaselineSurfaces -contains $mid.Value) { continue }
        foreach ($r in $FleetRoles) {
            if ($live -contains $r) { continue }
            # 목록의 role 칸은 role=master · role=worker-2 처럼 나온다. 앞부분이 맞으면 그 역할로 센다.
            # 칸 경계(줄 머리·탭·공백) 뒤의 role= 만 센다 — 낱말 속에 붙은 「role=」 글자는 세지 않는다.
            if ($ln -match ("(^|\s)role=" + [regex]::Escape($r) + "(\s|-|$)")) { $live += $r }
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
# 기다리는 동안 설치 창에 친 글자는 콘솔 입력 버퍼에 쌓였다가, 설치가 끝나면 PowerShell 이 명령으로 읽는다
#   (예: 카드를 보고 이 창에 「너는 마스터다」+Enter) ⇒ [10/10] 을 떠나기 전에 비우고 개수만 적는다(2026-09-15 검토 지적 채택 · [3/10] 성공 때와 같은 함수).
# 끝났다고 적는다 — 적지 않으면 끝맺음(Write-ClosingNote)이 「예상 못 한 끝」으로 읽고 「다시 실행」 안내를 인쇄한다
#   (2026-09-15 윈 실기: 「함대가 섰습니다」 바로 뒤에 「다음에 할 일: 다시 실행」이 나왔다). 성공 두 자리(자동 · 카드 뒤)에서 부른다.
function Set-FleetFinished {
    $script:NextStep = '없습니다 — 설치가 끝났습니다. 이 창을 닫으셔도 됩니다.'
    $script:ShowRerun = $false
}
function Clear-FleetStrayKeys {
    $n = Get-LoginStrayKeyCount
    Write-Log ('fleet stray keys in installer window cleared=' + $n)
}
# ── 자식 자리 각성 검증(TICKET=installer-awaken-verify · 2026-09-15 → installer-awaken-jsonl · 2026-09-16) ─────────
# 🔴자리가 선 것 ≠ 자리가 깨어난 것(샌드박스 실기 3회/3회 재현). 팩이 자식 자리를 처음 띄울 때 각성 지시를
#   붙여넣기로 보내는데, 막 뜬 클로드가 뒤따르는 Return 을 삼켜 입력줄에 「[Pasted text #1 +529 lines]」 가 실린 채 멈춘다.
# 🔴화면을 읽어 판정하던 첫 판(09dcab0)은 거짓 양성을 냈다(2026-09-16 샌드박스 5차: 「cso·worker 자리 깨움 확인」을 찍었는데
#   두 자리 모두 입력줄에 붙여넣기가 그대로 = 미제출). ⇒ 화면 파싱을 버리고 **그 자리 클로드의 세션 기록(jsonl)** 으로 잰다.
#   실측(맥 2026-09-16): 세션 기록 파일은 첫 지시가 제출되는 순간에 생긴다 — 제출 전에는 파일 자체가 없다.
#   깸(제출 확인) = 이 설치의 기준선 뒤에 생긴 그 자리 폴더의 세션 기록에 사용자 레코드 ≥1. 답 레코드는 요구하지 않는다.
#   🔴installer-awaken-verify-r2(2026-09-16 샌드박스 7차): 답 레코드까지 요구하던 판(9c49720)은 worker 를 child-fail 로 찍었는데
#     같은 시각 그 자리는 이미 답을 쓰는 중이었다 — 느린 기계에서 답 레코드는 제출 뒤 30초+ 늦게 생긴다(거짓 실패).
#   ⇒ 사용자 레코드가 0(파일 없음 포함)이면 Return 을 넣고 5·10·20초 뒤 다시 잰다(최대 3회) · 마지막 뒤에도 0 이면 10초 유예 뒤 한 번 더 잰다.
#   ⛔사용자 레코드가 이미 있으면 Return 을 넣지 않는다 — 그 자리에서 확인으로 끝난다(비워진 입력줄의 Return 은 제안 글을 제출하는 경로다).
#   ★재시작(phoenix) 경로는 이미 깬다 — 이 확인은 첫 설치 [10/10] 에서만 돈다(재설치·재부팅 경로 무접촉).
# ⚠여기서 안 재는 것: ⑴기준선 뒤 같은 폴더에서 다른 클로드 세션이 제출된 경우(그 기록도 깸으로 센다)
#   ⑵세션 기록이 %USERPROFILE%\.cys\claude\projects 밖에 있는 경우(끝까지 0 → 정직 문구로 끝난다 · 거짓 양성 쪽이 아니다)
#   ⑶폴더 이름 규칙이 안 맞고 파일 안 cwd 글자도 cys 목록의 폴더와 글자 그대로 다른 경우(같은 ⑵의 결말)
$ChildAwakeRoles    = @('cso', 'worker')   # 자비스가 선언을 듣고 부르는 자리(우리가 만들지 않는다)
$ChildAwakeCapSec   = 90         # 자리당 상한(5+10+20+유예 10 = 45초 + cys 부르기 3회 상한 여유)
$ChildAwakeGaps     = @(5, 10, 20) # Return 뒤 다시 재기 전 기다림(시험이 줄여 쓴다)
$ChildAwakeGraceSec = 10         # 마지막 Return 뒤에도 기록이 없을 때 한 번 더 재기 전 유예(시험이 줄여 쓴다)
$ChildAwakeMaxRetry = 3          # Return 을 넣는 최대 횟수
$ChildReadCapMs     = 10000      # cys 한 번 부르기의 상한 — 상한 있는 고리 안에 상한 없는 호출을 두지 않는다
$script:ChildAwakeSince = [datetime]::UtcNow   # 이 시각 뒤에 생긴 세션 기록만 센다(지난 설치의 기록 제외) · 기준선을 찍을 때 다시 잡는다
function Invoke-CysCapped([string]$Cli, [string]$ArgLine, [int]$CapMs) {
    # 돌려주는 것 = 표준 출력 글자 · 상한에 닿았거나 실패면 $null(콘솔 입력을 건드리지 않는다)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Cli
        $psi.Arguments = $ArgLine
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
        $psi.CreateNoWindow = $true
        $psi.EnvironmentVariables['CYS_NO_AUTOSTART'] = '1'
        $p = [System.Diagnostics.Process]::Start($psi)
        $so = $p.StandardOutput.ReadToEndAsync()
        [void]$p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($CapMs)) { try { $p.Kill() } catch { }; return $null }
        if (-not $so.Wait(2000)) { return $null }
        if ($p.ExitCode -ne 0) { return $null }
        return $so.Result
    } catch { return $null }
}
function ConvertTo-ClaudeProjectSlug([string]$Cwd) {
    # 클로드가 세션 기록 폴더 이름을 짓는 규칙 = 경로의 영숫자 아닌 글자를 하나씩 - 로(맥 실측 · C:\Users\… → C--Users-…)
    return ($Cwd -replace '[^A-Za-z0-9]', '-')
}
function Read-SessionLines([string]$Path) {
    # 클로드가 쓰는 중인 파일도 읽는다(공유 모드 ReadWrite·Delete) · UTF-8
    $lines = New-Object System.Collections.Generic.List[string]
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]'ReadWrite, Delete')
        $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false)))
        while ($null -ne ($ln = $sr.ReadLine())) { $lines.Add($ln) }
        $sr.Dispose()
    } catch { } finally { if ($fs) { $fs.Dispose() } }
    return ,$lines
}
function Get-NewSessionFiles([string]$Dir) {
    # 그 폴더의 세션 기록 중 기준선 뒤에 생긴 것만 · 새것부터
    if (-not (Test-Path -LiteralPath $Dir)) { return @() }
    return @(Get-ChildItem -LiteralPath $Dir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.CreationTimeUtc -ge $script:ChildAwakeSince } | Sort-Object CreationTimeUtc -Descending)
}
function Get-SeatSessionFile([string]$Cwd) {
    # 돌려주는 것 = 그 자리의 세션 기록 경로 · 없으면 $null
    #   ①폴더 이름 규칙으로 찾는다 ②없으면 projects 아래 전체에서 파일 안 "cwd" 글자가 그 자리 폴더인 것을 찾는다(규칙 추정에 기대지 않는다)
    try {
        $root = Join-Path (Join-Path (Join-Path $env:USERPROFILE '.cys') 'claude') 'projects'
        if (-not (Test-Path -LiteralPath $root)) { return $null }
        $hit = @(Get-NewSessionFiles (Join-Path $root (ConvertTo-ClaudeProjectSlug $Cwd)))
        if ($hit.Count -gt 0) { return $hit[0].FullName }
        $needle = '"cwd":"' + $Cwd.Replace('\', '\\').Replace('"', '\"') + '"'
        $cands = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { Get-NewSessionFiles $_.FullName } |
            Sort-Object CreationTimeUtc -Descending)
        foreach ($f in $cands) {
            foreach ($ln in (Read-SessionLines $f.FullName)) { if ($ln.Contains($needle)) { return $f.FullName } }
        }
    } catch { }
    return $null
}
function Get-SeatSessionCounts([string]$Path) {
    # 사용자 레코드 수 u · 답 레코드 수 a(파일이 없으면 둘 다 0)
    $u = 0; $a = 0
    if ($Path) {
        foreach ($ln in (Read-SessionLines $Path)) {
            if ($ln.Contains('"type":"user"')) { $u++ }
            if ($ln.Contains('"type":"assistant"')) { $a++ }
        }
    }
    return @{ u = $u; a = $a }
}
function Get-ChildSeatRefs([string]$Cli) {
    # 돌려주는 것 = 역할 → @{ ref = 자리 번호; cwd = 자리 폴더(목록 한 줄의 마지막 칸) }
    $out = (Invoke-CysProbe $Cli @('list')) -join "`n"
    $seats = [ordered]@{}
    foreach ($ln in ($out -split "`n")) {
        $mid = [regex]::Match($ln, 'surface:\d+')
        if (-not $mid.Success) { continue }   # 자리 번호 없는 줄(경고 글)은 자리가 아니다
        if ($script:BaselineSurfaces -contains $mid.Value) { continue }   # 지난 설치의 자리는 이번 확인 대상이 아니다
        foreach ($r in $ChildAwakeRoles) {
            if ($seats.Contains($r)) { continue }
            if ($ln -match ("(^|\s)role=" + [regex]::Escape($r) + "(\s|-|$)")) {
                $cols = @($ln.TrimEnd("`r") -split "`t")
                $cwd = if ($cols.Count -ge 6) { $cols[-1].Trim() } else { '' }
                $seats[$r] = @{ ref = $mid.Value; cwd = $cwd }
            }
        }
    }
    return $seats
}
function Confirm-ChildSeat([string]$Cli, [string]$Role, [string]$Ref, [string]$Cwd) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $retry = 0; $graced = $false; $c = @{ u = 0; a = 0 }
    if (-not $Cwd) { return @{ ok = $false; retry = 0; u = 0; a = 0; why = 'no-cwd' } }   # 폴더를 모르면 잴 수 없다 — Return 도 넣지 않는다
    while ($sw.Elapsed.TotalSeconds -lt $ChildAwakeCapSec) {
        $c = Get-SeatSessionCounts (Get-SeatSessionFile $Cwd)
        if ($c.u -ge 1) { return @{ ok = $true; retry = $retry; u = $c.u; a = $c.a; why = 'jsonl' } }   # 제출 확인 — 답 레코드는 늦게 생긴다
        if ($retry -lt $ChildAwakeMaxRetry) {
            $retry++
            [void](Invoke-CysCapped $Cli ('send-key --surface ' + $Ref + ' Return') $ChildReadCapMs)
            Write-Log ('awaken child: role=' + $Role + ' seat=' + $Ref + ' marker=awaken:child-retry ' + $retry)
            Send-Progress '10/10' 'info' $null ('awaken:child-retry ' + $retry) $null
            Send-CaptureEvidence 'retry' ('awaken:child-retry role=' + $Role + ' seat=' + $Ref + ' n=' + $retry)   # ⓕ② v0.3.20
            $gap = $ChildAwakeGaps[[math]::Min($retry, $ChildAwakeGaps.Count) - 1]
            if ($gap -gt 0) { Start-Sleep -Seconds $gap }
        } elseif (-not $graced) {
            $graced = $true   # 마지막 Return 뒤 기록이 늦게 생기는 기계 — 유예 한 번 뒤 다시 잰다(Return 은 더 넣지 않는다)
            if ($ChildAwakeGraceSec -gt 0) { Start-Sleep -Seconds $ChildAwakeGraceSec }
        } else {
            break
        }
    }
    return @{ ok = $false; retry = $retry; u = $c.u; a = $c.a; why = 'no-submit' }
}
function Send-ChildStallEvidence([string]$Role, [string]$Screen) {
    # fail-open · 자리마다 한 번 · 자식 자리 화면 끝부분을 이 기계에서 마스킹한 뒤 보낸다(reason=stall).
    try {
        $key = 'stall-child-' + $Role + '|10/10'
        if ($script:EvidenceSent.ContainsKey($key)) { return }
        $script:EvidenceSent[$key] = $true
        $lines = @(([string]$Screen).TrimEnd() -split "`r?`n")
        $from = [math]::Max(0, $lines.Count - 40)
        $tail = 'seat=' + $Role + "`n" + (($lines[$from..($lines.Count - 1)]) -join "`n")
        $t = Get-RemoteHelpTailBytes (Protect-EvidenceText $tail) $EvidenceTextBytes
        [void](Send-EvidenceEvent 'stall' $t)
        Write-Log ('evidence sent: ' + $key + ' ' + [System.Text.Encoding]::UTF8.GetByteCount($t) + 'B')
    } catch { Write-Log ('evidence error (fail-open): ' + $_.Exception.Message) }
}
function Confirm-ChildSeats([string]$Cli) {
    # 돌려주는 것 = 답이 없는 자리 수(설치는 막지 않는다 — 자비스가 이어서 깨운다)
    $seats = Get-ChildSeatRefs $Cli
    $failed = 0
    foreach ($r in @($seats.Keys)) {
        $ref = $seats[$r].ref
        $res = Confirm-ChildSeat $Cli $r $ref $seats[$r].cwd
        $counts = ' u=' + $res.u + ' a=' + $res.a
        if ($res.ok) {
            # ★이 판정이 재는 것은 **제출**이다(사용자 레코드 ≥1) — 「받아들였다」가 아니다. 문구를 재는 것에 맞춘다
            #   (TICKET=installer-0322-awaken · 앞 판 「깨움 확인」은 순종까지 잰 것처럼 읽혔다).
            Say ('     ' + $r + ' 자리 지시 제출 확인')
            Write-Log ('awaken child: role=' + $r + ' seat=' + $ref + ' marker=awaken:child-verified retries=' + $res.retry + ' evidence=jsonl' + $counts)
            Send-Progress '10/10' 'info' $null 'awaken:child-verified' $null
        } else {
            $failed++
            Say ('     ' + $r + ' 자리는 열렸으나 아직 답이 없습니다 — 자비스가 이어서 깨웁니다(사람 손 0)')
            Write-Log ('awaken child: role=' + $r + ' seat=' + $ref + ' marker=awaken:child-fail retries=' + $res.retry + ' why=' + $res.why + $counts)
            Send-Progress '10/10' 'info' $null 'awaken:child-fail' $null
            $scr = Invoke-CysCapped $Cli ('read-screen --surface ' + $ref) $ChildReadCapMs
            Send-ChildStallEvidence $r ([string]$scr)
        }
    }
    return $failed
}
function Get-MasterMarkPath { return (Join-Path $JarvisHome $MasterMarkName) }
function Clear-MasterMark {
    # 지운다 — 단 **우리 자비스 폴더 안의 그 이름 하나**만. 경로를 짐작하지 않는다.
    $f = Get-MasterMarkPath
    try {
        if (Test-Path -LiteralPath $f) {
            Remove-Item -LiteralPath $f -Force -ErrorAction Stop
            Write-Log ('master mark: cleared stale ' + $f)
        }
    } catch { Write-Log ('master mark: clear failed (이어 간다) ' + $_.Exception.Message) }
}
function Test-MasterMark {
    # 참 = 표지가 있고 **이번 설치의 기준선 뒤에** 쓰였다. 지난 설치의 표지를 이번 각성으로 세지 않는다.
    $f = Get-MasterMarkPath
    try {
        if (-not (Test-Path -LiteralPath $f)) { return $false }
        $t = (Get-Item -LiteralPath $f).LastWriteTimeUtc
        # 5초 여유 = 파일 시각 알갱이·기준선을 찍는 순간의 어긋남만 흡수한다(지난 설치를 흡수할 크기가 아니다).
        return ($t -ge $script:ChildAwakeSince.AddSeconds(-5))
    } catch { return $false }
}
function Get-MasterAssistantCount {
    # 마스터 자리 세션 기록의 **답 레코드** 수. 자식 판정과 같은 읽기 코드를 쓴다(자리 폴더 = 자비스 폴더).
    try { return (Get-SeatSessionCounts (Get-SeatSessionFile $JarvisHome)).a } catch { return 0 }
}
function Wait-MasterSigns([int]$CapSec) {
    # 상한 안에서 두 축을 함께 본다. 둘 다 서면 곧바로 끝낸다(좋은 길에서는 기다리지 않는다).
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $mark = $false; $a = 0
    while ($true) {
        if (-not $mark) { $mark = Test-MasterMark }
        if ($a -lt 1) { $a = Get-MasterAssistantCount }
        if ($mark) { break }   # 표지가 곧 판정이다 — 답 기록을 더 기다리지 않는다(위 Get-MasterStateName 주석)
        if ($sw.Elapsed.TotalSeconds -ge $CapSec) { break }
        Start-Sleep -Seconds $MasterAwakePollSec
    }
    return @{ mark = $mark; a = $a }
}
function Send-MasterRetry([string]$Cli, [string]$Ref) {
    # 같은 문구를 되풀이하지 않는다 — 앞 요청이 무슨 뜻이었는지 한 줄 보태고 다시 청한다.
    #   ⛔선언(「너는 마스터다」)을 다시 보내지 않는다: 그 줄은 이미 첫 프롬프트로 갔고,
    #     창에 밀어 넣은 글은 팩 판정기가 기계 배달로 보아 선언으로 세지 않는다(2026-09-05 실측).
    if (-not $Ref) { return $false }
    $msg = '앞서 보낸 요청은 install-directive.md 를 읽고 판단하신 뒤 준비 작업을 해 달라는 뜻입니다. ' +
           '읽어 보시고 괜찮다면 준비 작업 1번(표지 파일 만들기)부터 해 주세요. 판단해 보시고 못 하겠다면 그 까닭을 한 줄로 적어 주세요.'
    [void](Invoke-CysCapped $Cli ('send --surface ' + $Ref + ' "' + $msg + '"') $ChildReadCapMs)
    Start-Sleep -Seconds 2
    [void](Invoke-CysCapped $Cli ('send-key --surface ' + $Ref + ' Return') $ChildReadCapMs)
    Write-Log ('awaken master: marker=awaken:master-retry seat=' + $Ref)
    Send-Progress '10/10' 'info' $null 'awaken:master-retry' $null
    Send-CaptureEvidence 'retry' ('awaken:master-retry seat=' + $Ref)
    return $true
}
function Get-MasterStateName($r) {
    # ★셋으로 가르는 자리는 **하나**다 — 두 벌이면 한쪽만 고쳐져 판정이 조용히 갈린다.
    # 🔴**표지 하나가 곧 「일을 시작했다」의 증거다** — 답 레코드를 함께 요구하지 않는다(이종 검토 1R 지적 채택 2026-09-16).
    #   까닭 = 같은 병의 두 번째 자리다: 자식 판정도 답 레코드를 요구하던 판(9c49720)이 느린 기계에서
    #   **거짓 실패**를 냈다(installer-awaken-verify-r2 — 답 레코드는 제출 뒤 30초+ 늦게 생긴다).
    #   표지는 쓰였는데 답 기록이 아직 디스크에 안 내려간 찰나를 「판정 못 함」으로 떨어뜨리면 그 병을 여기서 되풀이한다.
    #   그리고 두 축의 증거 힘이 다르다 — 표지는 **일을 시작했다**를, 답 레코드는 **말을 했다**를 말할 뿐이다.
    if ($r.mark) { return 'verified' }                     # 일을 시작했다(이 표지는 마스터만 쓴다 · 우리는 깨우기 전에 지운다)
    if ($r.a -ge 1) { return 'no-start' }                  # 말은 했는데 시작하지 않았다(거절 또는 표지 못 씀)
    return 'unknown'                                       # 우리 관측이 닿지 않았다 — 「거절」이라고 말하지 않는다
}
function Confirm-MasterAwake([string]$Cli, [string]$Ref) {
    # 돌려주는 것 = @{ state; mark; a; retry }  · state 는 셋 중 하나이고 **서로 다른 문구·표지**를 갖는다.
    #   verified  = 답 레코드 ≥1 ∧ 표지 있음      → 「각성 확인」   (여기서만 「깨어났습니다」를 말한다)
    #   no-start  = 답 레코드 ≥1 ∧ 표지 없음      → 「받았으나 시작 안 함」(거절했거나 표지를 못 썼다 — 단정하지 않는다)
    #   unknown   = 답 레코드 0  ∧ 표지 없음      → 「판정 못 함」(우리 관측이 닿지 않았을 수도 있다)
    $r = Wait-MasterSigns $MasterAwakeCapSec
    $retry = 0
    if ((-not $r.mark) -and ($r.a -ge 1) -and ($MasterRetryMax -ge 1)) {
        if (Send-MasterRetry $Cli $Ref) {
            $retry = 1
            $r = Wait-MasterSigns $MasterRetryCapSec
        }
    }
    $state = Get-MasterStateName $r
    Write-Log ('awaken master: marker=awaken:master-' + $state + ' mark=' + $r.mark + ' a=' + $r.a + ' retry=' + $retry)
    Send-Progress '10/10' 'info' $null ('awaken:master-' + $state) $null
    return @{ state = $state; mark = $r.mark; a = $r.a; retry = $retry }
}
function Write-MasterSay($res) {
    # 셋을 **서로 다른 문구**로 찍는다 — 한 문구로 뭉치면 화면이 다시 거짓말을 시작한다.
    switch ($res.state) {
        'verified' { Say '     자비스(master) 각성 확인 — 지시를 받고 준비 작업을 시작했습니다.' }
        'no-start' { Say '     자비스(master)는 지시를 받았으나 준비 작업을 시작하지 않았습니다.'
                     Say '     (요청을 판단해 보고 거절했거나, 표지 파일을 쓰지 못했을 수 있습니다 — 무엇인지 여기서는 단정하지 않습니다.)' }
        default    { Say '     자비스(master)가 깼는지 판정하지 못했습니다 — 세션 기록도 표지 파일도 찾지 못했습니다.' }
    }
}
function Write-MasterRequestCard {
    # 마스터가 지시는 받았는데 시작하지 않은 끝에서만 인쇄한다.
    #   ⛔여기에 「너는 마스터다」를 적지 않는다 — 그 한마디는 이미 들어갔고, 다시 쳐도 같은 자리에 선다.
    #   ★적는 문구는 **2026-09-16 13:25 에 같은 기계에서 실제로 받아들여진 그 문장**이다.
    Human '자비스' '자비스가 아직 준비 작업을 시작하지 않아 한 줄만 부탁드립니다 — cys 창에서 쳐 주십시오'
    Say ''
    Say '   ┌───────────────────────────────────────────────────────────────┐'
    Say '   │   cys 창(제목 jarvis)에 이렇게 쳐 주십시오:                   │'
    Say '   │                                                               │'
    Say '   │     install-jarvis 폴더의 install-directive.md 를 읽고,       │'
    Say '   │     거기 적힌 준비 작업을 해 주세요.                          │'
    Say '   │                                                               │'
    Say '   └───────────────────────────────────────────────────────────────┘'
    Say ''
    Say '   자비스가 그 파일을 읽고 판단한 뒤 준비 작업을 시작합니다. 거절하면 그 까닭을 사람 말로 알려 줍니다.'
}
function Get-MasterStateNow {
    # 기다리지 않고 **지금 한 번**만 본다(재시도 없음) — 카드 뒤에 다시 잴 때 쓴다.
    $r = Wait-MasterSigns 0
    $state = Get-MasterStateName $r
    Write-Log ('awaken master: marker=awaken:master-' + $state + ' mark=' + $r.mark + ' a=' + $r.a + ' retry=0 (recheck)')
    Send-Progress '10/10' 'info' $null ('awaken:master-' + $state) $null
    return @{ state = $state; mark = $r.mark; a = $r.a; retry = 0 }
}
function Write-MasterUnknownCard {
    # 「판정 못 함」은 「거절했다」가 아니다 — 우리 관측이 닿지 않았을 수도 있다. 그래서 문구가 다르다.
    Say ''
    Say '   cys 창(제목 jarvis)을 열어 자비스가 무엇을 하고 있는지 보아 주십시오.'
    Say '   아무 말도 하지 않고 있으면 이렇게 쳐 주시면 됩니다: install-jarvis 폴더의 install-directive.md 를 읽고, 거기 적힌 준비 작업을 해 주세요.'
}
function Set-FleetNeedsMaster {
    # 끝맺음이 「예상 못 한 끝」으로 읽지 않게 하되, 「끝났습니다」라고도 하지 않는다 — 남은 일을 그대로 적는다.
    $script:NextStep = 'cys 창(제목 jarvis)의 자비스에게 위 한 줄을 전해 주십시오. 그것으로 설치가 끝납니다.'
    $script:ShowRerun = $false
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
    # ── ① 마스터가 **실제로** 깼는지 먼저 잰다(TICKET=installer-0322-awaken) ──
    #   왜 먼저인가: 동료 자리는 마스터의 순종과 무관한 경로로도 선다(편성 자동 복구). 마스터를 뒤에 재면
    #   그 사이에 이미 「함대가 섰습니다」가 찍혀, 우리가 고치려는 거짓 초록이 그대로 남는다.
    Say '[10/10] 자비스(master)가 지시를 받고 준비 작업을 시작하는지 봅니다 (최대 2분 · 사람이 하실 일은 없습니다).'
    $mres = Confirm-MasterAwake $cli $SurfaceRef
    Write-MasterSay $mres
    # ── ② 자동 각성 확인(사람 손 0) — 선언은 [9/10] 이 첫 프롬프트로 이미 넘겼다 ──
    Say '[10/10] 자비스가 깨어나 동료들을 부르는지 지켜봅니다 (최대 4분 · 사람이 하실 일은 없습니다).'
    Write-Log "fleet: auto awaken - watching child seats in $SurfaceRef (cap $($FleetAwakeTries * $FleetPollSec)s)"
    $fleetSw = [System.Diagnostics.Stopwatch]::StartNew()   # [10/10] 소요(초)를 진행 전송에 싣는다(installer-speed-pin-0320)
    $live = @()
    for ($i = 0; $i -lt $FleetAwakeTries; $i++) {
        $live = @(Get-LiveRoles $cli)
        if ($live.Count -ge $FleetRoles.Count) { break }
        Start-Sleep -Seconds $FleetPollSec   # 먼저 보고 나서 기다린다 — 이미 섰으면 한 번도 기다리지 않는다
    }
    # ★성공의 근거 = 자식 좌석. 우리가 연 master 자리는 근거가 못 된다(아래 Test-DeclarationSeen 머리 주석).
    if (Test-DeclarationSeen $live) {
        Write-Log ('fleet awaken: auto - seats=' + ($live -join ','))
        Send-Progress '10/10' 'end' ([int]$fleetSw.Elapsed.TotalSeconds) 'awaken:auto' $null   # 자동 각성 성공(master 병합 연결 2026-09-15)
        $missing = @($FleetRoles | Where-Object { $live -notcontains $_ })
        if ($missing.Count -eq 0) {
            Say ("[10/10] 함대가 섰습니다: " + ($live -join ' · '))
        } else {
            Say ("[10/10] 선 자리 = " + ($live -join ' · ') + ' · 남은 자리(' + ($missing -join ' · ') + ')는 자비스가 이어서 세웁니다.')
            Write-Log ("fleet missing at awaken: " + ($missing -join ','))
        }
        # ★자리가 선 것만으로 끝내지 않는다 — 선 자식 자리가 실제로 깼는지 화면으로 확인하고, 멈췄으면 깨운다.
        [void](Confirm-ChildSeats $cli)
        Send-PostInstallEvidence $cli $SurfaceRef   # ⓑ v0.3.20 — 끝난 그 화면을 한 번 보낸다(훅 오류 줄 수 + 앱 창 그림)
        Say ''
        # 🔴「깨어났습니다」는 **마스터 판정이 verified 일 때만** 말한다(TICKET=installer-0322-awaken).
        #   동료 자리가 선 것은 마스터가 일을 시작했다는 증거가 못 된다 — 2026-09-16 샌드박스가 그 둘이 갈리는 것을 실제로 보여 줬다.
        if ($mres.state -eq 'verified') {
            Say '   자비스가 깨어났습니다 — 이제 설치 창을 닫으셔도 됩니다.'
            Set-FleetFinished
            Clear-FleetStrayKeys
            return 0
        }
        Say '   동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다.'
        if ($mres.state -eq 'no-start') { Write-MasterRequestCard } else { Write-MasterUnknownCard }
        Set-FleetNeedsMaster
        Clear-FleetStrayKeys
        return 10
    }
    # 상한 안에 동료 자리가 하나도 안 섰다 = 자동 각성이 닿지 않았다(기술적 실패) ⇒ **그때만** 사람에게 부탁한다.
    #   ⚠원인을 단정하지 않는다 — 우리가 아는 것은 「상한 안에 안 섰다」뿐이다(카드 뒤에 저절로 서는 일도 실기에서 있었다).
    Write-Log "fleet awaken: no child seat within $($FleetAwakeTries * $FleetPollSec)s -> manual fallback card"
    Send-Progress '10/10' 'info' ([int]$fleetSw.Elapsed.TotalSeconds) 'awaken:manual-fallback' $null   # 자동 각성 미도달 → 사람 카드(master 병합 연결 2026-09-15)
    Human '자비스' '자비스가 저절로 깨어나지 않아 한마디만 부탁드립니다 — cys 창에서 쳐 주십시오'
    Say ''
    Say '   ┌─────────────────────────────────────────────┐'
    Say ("   │   cys 창(제목 jarvis)에 이렇게 쳐 주십시오:  │")
    Say ("   │                                             │")
    Say ("   │        " + $FleetTrigger + "                        │")
    Say ("   │                                             │")
    Say '   └─────────────────────────────────────────────┘'
    Say ''
    Say '   그 한마디를 들으면 자비스가 동료들을 부릅니다. 여기서 기다리다가 다 서면 알려 드립니다.'
    Write-Log "fleet: waiting for owner declaration in $SurfaceRef"
    $live = @()
    $waited = 0
    for ($i = 0; $i -lt $FleetWaitTries; $i++) {
        $live = @(Get-LiveRoles $cli)
        if ($live.Count -ge $FleetRoles.Count) { break }
        Start-Sleep -Seconds $FleetPollSec   # 먼저 보고 나서 기다린다(installer-speed-pin-0320)
        $waited += $FleetPollSec
        # 오래 걸리면 얼마나 더 기다리는지 알려 준다 — 말없이 멈춰 있는 것처럼 보이지 않게.
        # 🔴2026-09-10 실기에서 고친 것(5차 검토) — 앞 판은 **판정 없이** 「아직 치지 않으셨다면 지금 쳐 주십시오」를
        #   되풀이했다. 쓰시는 분은 이미 치셨고 자비스는 그 4분 동안 환경 보고를 쓰고 동료를 부르고 있었다.
        #   ⇒ 사용자에게는 「다 됐다」와 「아직 안 쳤다」가 동시에 떠 있었다.
        #   ★판정 축은 이미 손에 있었다 — master 자리가 목록에 서 있으면 **그 한마디는 이미 들어간 것**이다
        #     (선언이 role 등록을 낳는다). 그 뒤로는 사람에게 시킬 일이 없다.
        #   ⚠새 프로브를 만들지 않는다 — 이미 2초마다 부르는 `cys list` 의 답을 그대로 읽는다.
        #   알림은 1분마다(2초 × 30) — 간격을 줄이며 알림이 잦아지지 않게 함께 고쳤다(installer-speed-pin-0320).
        if (($i -gt 0) -and (($i % 30) -eq 0)) {
            $mins = "$([int]($waited / 60))분 지남 · 최대 $([int](($FleetWaitTries * $FleetPollSec) / 60))분"
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
        # 카드 뒤에 선 함대도 성공이다 — 기록 줄이 없으면 로그만 보는 사람은 폴백에서 끝난 줄로 읽는다(2026-09-15 실기 로그).
        Write-Log ('fleet awaken: success after fallback card - seats=' + ($live -join ','))
        [void](Confirm-ChildSeats $cli)
        Send-PostInstallEvidence $cli $SurfaceRef   # ⓑ v0.3.20 — 카드 뒤에 선 끝도 같은 증거를 보낸다
        # 카드 뒤 6분 사이에 마스터가 시작했을 수 있다 ⇒ **한 번만 다시 본다**(재시도는 하지 않는다 · 이미 1회 썼다).
        $mres = Get-MasterStateNow
        Write-MasterSay $mres
        if ($mres.state -ne 'verified') {
            Say '   동료 자리는 섰지만, 자비스(master)가 준비 작업을 시작한 것은 확인하지 못했습니다.'
            if ($mres.state -eq 'no-start') { Write-MasterRequestCard } else { Write-MasterUnknownCard }
            Set-FleetNeedsMaster
            Clear-FleetStrayKeys
            return 10
        }
        Set-FleetFinished
        Clear-FleetStrayKeys
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
    Clear-FleetStrayKeys
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
$InstallerVersion       = '0.3.23'   # 보고의 installer_version · $BootstrapVersion 은 화면 머리글 용도 그대로(보내지 않는다)
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
    # 첨부도 같은 출처 헤더가 필요하다 — 보고를 연 설치기만 그 보고에 자료를 더할 수 있다(계약 1절).
    if ($script:RhClientToken -and ($Path -like '*/attach')) { $headers['x-help-client'] = $script:RhClientToken }
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
    Receive-CaptureRequest $poll.capture   # v0.3.20 — 촬영 요청은 이 답에도 실려 온다(계약 5절 ②)
    Invoke-CaptureRequested
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
    # 기록 파일은 UTF-8 로 쓰였다(Write-Log · v0.3.18) — 같은 글자표로 읽는다
    try { if (Test-Path -LiteralPath $LogFile) { $logText = (@(Get-Content -LiteralPath $LogFile -Tail 200 -Encoding UTF8 -ErrorAction Stop) -join "`n") } } catch { }
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
            Send-EvidenceOnce 'ask'   # v0.3.18 — 도움 요청 증거(보고가 열린 순간의 설치 창 끝부분 · 마스킹 뒤)
            Send-FailAttachments   # 보고가 열린 직후 진단 자료를 붙인다(계약 3절 · 각각 fail-open)
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

# ══ 진행 자동 전송·진단 자료 자동 수집 (계약 v1 2026-09-15 · 이미 있는 흐름에 더하기만 한다) ══════════
#   원칙(계약 1절) = fail-open: 전송 실패·서버 장애·시간 초과(각 요청 3초)는 설치 진행을 절대 막지 않는다(경고 한 줄만).
#   두 갈래를 한 서버(web-install)와 나눠 쓴다:
#     · 진행 전송  POST /api/progress   — 토큰 없음(보고 전 [1/10]부터 나가므로) · 본문 8KB · 단계 시작/끝/대기/실패/살핌
#     · 자료 첨부  POST /api/help/<id>/attach — 보고가 열린 뒤에만(x-help-client 헤더) · 항목 900KB · 보고당 10건까지
$ProgressUrl        = $HelpApiUrl + '/api/progress'
$ProgressTimeoutSec = 3                                   # 요청 하나의 상한(계약 1절)
$InstallIdFile      = Join-Path $JarvisHome 'install-id'  # 첫 실행에 만든 무작위 번호 · 기기·재시도 사슬을 잇는다(계약 1절)
$TranscriptFile     = Join-Path $JarvisHome 'transcript.txt'
$AttachMaxBytes     = 900 * 1024                          # 항목 하나의 상한(계약 2절)
# 첫 화면 고지 = 서버 정본 문안(web-install 의 NOTICE_TEXT)과 글자까지 같다(계약 2절 「정본 1곳」 · 서버 응답의 notice 필드와도 같은 문장).
# v0.3.18 — 고지 정본 1줄 교체(master 릴레이 2026-09-15 20:18 · 서버 NOTICE_TEXT 도 같은 글로 바꾼다 = 732 몫)
$ProgressNotice = '설치가 진행되는 동안 단계와 시각이 자동으로 전송됩니다. 설치가 막히거나 이상이 보이거나 끝났을 때, 그리고 운영팀이 청할 때 설치 창·로그인 창·자비스 창·첫 자리 화면의 글자와 그림이 함께 보내집니다(다른 창은 찍지 않습니다). 글자에서는 로그인 코드·이메일·계정 이름을 가리지만, 그림은 가릴 수 없어 운영팀만 봅니다. 보관 30일 뒤 자동 삭제됩니다.'
$script:InstallId      = ''
$script:ProgressWarned = $false     # 전송 실패 경고는 실행당 한 번만 기록한다(fail-open)
$script:TranscriptOn   = $false
$script:LoginCapCount  = 0          # 로그인 대기 중 창 캡처 수(최대 4 · 계약 3절)
$script:LoginCapFiles  = @()        # 찍어 둔 로그인 창 캡처 파일 — 보고가 열리면 첨부한다

function Get-InstallId {
    # 첫 실행에 무작위 번호를 만들어 두고 이후 재사용한다(영숫자·_·- 8~36자 · 서버 허용 범위).
    if ($script:InstallId) { return $script:InstallId }
    $id = ''
    try {
        if (Test-Path -LiteralPath $InstallIdFile) {
            $first = @(Get-Content -LiteralPath $InstallIdFile -TotalCount 1 -ErrorAction Stop)
            if ($first.Count -gt 0 -and $null -ne $first[0]) { $id = ([string]$first[0]).Trim() }
        }
    } catch { $id = '' }
    if ($id -notmatch '\A[0-9A-Za-z_-]{8,36}\z') {
        $bytes = New-Object byte[] 32
        try { ([System.Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($bytes) } catch { (New-Object System.Random).NextBytes($bytes) }
        $id = ([Convert]::ToBase64String($bytes) -replace '[^0-9A-Za-z]', '')
        if ($id.Length -gt 24) { $id = $id.Substring(0, 24) }
        try { Write-TextNoBom $InstallIdFile ($id + "`r`n") } catch { }
    }
    $script:InstallId = $id
    return $id
}

function Send-Progress($step, $ev, $elapsed, $detail, $envInfo, $extra) {
    # 진행 한 줄을 서버로 보낸다. fail-open — 무슨 일이 있어도 설치를 막지 않는다(계약 1절).
    #   $extra = 추가 칸(v0.3.18 evidence 이벤트의 text·reason·masked · 진행 전송 계약의 증거 절) · 없으면 종전과 같은 본문.
    if ($Mode -ne 'full') { return }
    if ($env:JARVIS_NO_PROGRESS -eq '1') { return }   # 흉내 시험이 실제 서버로 나가지 않게 하는 레버(사람이 쓰는 길이 아니다)
    $url = if ($env:JARVIS_PROGRESS_URL) { $env:JARVIS_PROGRESS_URL } else { $ProgressUrl }
    try {
        $fields = [ordered]@{
            install_id        = (Get-InstallId)
            installer_version = $InstallerVersion
            os                = 'win'
            step              = $step
            event             = $ev
            at                = (Get-Date -Format o)
        }
        if ($null -ne $elapsed) { $fields['elapsed_s'] = [int]$elapsed }
        if ($detail)            { $fields['detail']    = [string]$detail }
        if ($null -ne $envInfo) { $fields['env']       = $envInfo }
        if ($null -ne $extra)   { foreach ($k in @($extra.Keys)) { $fields[[string]$k] = $extra[$k] } }
        $body = ($fields | ConvertTo-Json -Compress -Depth 4)
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $resp = Invoke-WebRequest -Uri $url -Method POST `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -ContentType 'application/json; charset=utf-8' -UseBasicParsing `
            -TimeoutSec $ProgressTimeoutSec -ErrorAction Stop
        # v0.3.20 — 운영팀이 청한 촬영은 이 답에 실려 온다(계약 5절 ① · 보고가 없어도 닿는 길 = 하트비트가 곧 수신함).
        #   ⚠아무것도 출력 스트림에 흘리지 않는다 — 이 함수의 반환값이 부르는 쪽의 종료 코드에 섞이면 안 된다(이 파일 위쪽의 같은 함정).
        try { Receive-CaptureRequest ((ConvertFrom-Json -InputObject ([string]$resp.Content) -ErrorAction Stop).capture) } catch { }
    } catch {
        if (-not $script:ProgressWarned) {
            $script:ProgressWarned = $true
            Write-Log ('progress send failed (fail-open) - ' + $_.Exception.Message)
        }
    }
}

# ══ 증거(evidence) 이벤트 — v0.3.18 (진행 전송 계약의 증거 절 · 계약 확정 2026-09-15 20:0x) ════════════════════════
#   언제: 정체(대기 3분 이상) · 실패(진단 코드 = rc≠0) · 도움 요청(원격 해결 보고가 열림) — (이유 × 단계)마다 한 번.
#   무엇: 설치 창 글자(Start-Transcript 파일 · 없으면 설치 기록)의 마지막 부분 · 보내기 **전에 이 기계에서 마스킹**한다(masked=true).
#   🔴마스킹 규칙의 정본은 서버(web-install src/mask.ts)이고, 여기의 식은 그 대조표 `mask-vectors.json`(web-install 725093c ·
#     사본 = tests/mask-vectors.json)의 ps1_regex 를 **글자 그대로** 옮긴 것이다 — 고치려면 대조표부터 고친다(시험이 식과 대조표를 글자 대조한다).
#   ⚠서버가 받은 뒤 한 번 더 마스킹한다(이중) — 이쪽 마스킹은 「기계 밖으로 나가기 전」의 방어다.
#   ⚠.NET 의 \b·\s 는 유니코드 기준이라 JS 와 한글 바로 옆에서 갈릴 수 있다(예: 「코드aBc…#…」 처럼 한글에 붙은 코드) — 서버 재마스킹이 받친다.
$EvidenceMaskRules = @(
    @('[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63})*\.[A-Za-z]{2,63}', '<EMAIL>'),
    @('(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+', '<TOKEN>'),
    @('\bsk-[A-Za-z0-9_-]{8,}', '<TOKEN>'),
    @('\b[A-Za-z0-9_-]{20,}#[A-Za-z0-9_-]{8,}\b', '<LOGIN_CODE>'),
    @('(?i)(Paste code here if prompted\s*>\s*)(\S+)', '$1<LOGIN_CODE>'),
    @('(?i)\b([A-Za-z]:(?:\\{1,2}|/)Users(?:\\{1,2}|/))([^\\/\r\n"''<>|:*?]+)', '$1<USER>'),
    @('(/Users/)([^/\s"''<>]+)', '$1<USER>')
)
$EvidenceNameLines = '(?i)\b(?:USERNAME|USERPROFILE|LOGNAME|USER|HOME)\b[ \t]*[=:][ \t]*([^\r\n]+)|\bwhoami\b[ \t]*[:=>][ \t]*([^\r\n]+)|(?:^|\n)[ \t]*([A-Za-z][A-Za-z0-9.-]{1,63}\\[A-Za-z0-9._-]{2,63})[ \t]*(?:\r?\n|$)'
$EvidenceMaxNames   = 64       # 서버 scrub.ts MAX_NAMES 와 같은 값
$EvidenceSourceBytes = 60000   # 파일 끝에서 읽는 양
$EvidenceTextBytes   = 32000   # 마스킹 뒤 보내는 양(요청 본문 64KB 안 · ConvertTo-Json 이 < > 를 < 로 늘려도 남는다)
$script:EvidenceSent = @{}

function Protect-EvidenceText([string]$Raw) {
    # 순서 = 서버 maskEvidenceText 와 같다: 표시된 로그인 이름을 먼저 <USER> 로 · 그다음 구조 규칙 일곱.
    if (-not $Raw) { return $Raw }
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($Raw, $EvidenceNameLines)) {
        if ($names.Count -ge $EvidenceMaxNames) { break }
        $v = ''
        foreach ($g in 1..3) { if ($m.Groups[$g].Success) { $v = $m.Groups[$g].Value; break } }
        $v = ($v.Trim() -replace '["'']', '')
        if ($v.Length -ge 2 -and -not $names.Contains($v)) { $names.Add($v) }
        $seg = (($v -split '[\\/]')[-1]).Trim()
        if ($seg.Length -ge 2 -and $names.Count -lt $EvidenceMaxNames -and -not $names.Contains($seg)) { $names.Add($seg) }
    }
    # 🔴서버 정본(web-install mask.ts 8571653)의 4단계를 그대로 옮긴다 — ①이름은 원문에서 뽑아 두고(위) ②구조 규칙이 맞힌 자리에는
    #   표식 대신 자리표(NUL M<번호> NUL)를 심고 ③이름 치환 ④자리표를 표식으로 되돌린다.
    #   왜: 이름을 먼저 지우면 「hong@…」 이 「<USER>@…」 가 되고, 구조 결과 위에서 이름을 지우면 이름이 하필 Users·EMAIL 일 때
    #   C:\Users\ 접두사나 <EMAIL> 표식 자체가 뭉개진다(대조표 order_dependency_1~4).
    $sentinels = New-Object System.Collections.Generic.List[string]
    $text = $Raw
    foreach ($r in $EvidenceMaskRules) {
        $ph = $r[1]
        $text = [regex]::Replace($text, $r[0], [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            $res = [regex]::Replace($ph, '\$(\d)', [System.Text.RegularExpressions.MatchEvaluator]{ param($g) $m.Groups[[int]$g.Groups[1].Value].Value })
            $sentinels.Add($res)
            return ([string][char]0 + 'M' + ($sentinels.Count - 1) + [string][char]0)
        })
    }
    if ($names.Count -gt 0) {
        $alt = (@($names | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) }) -join '|')
        $text = [regex]::Replace($text, $alt, '<USER>')
    }
    $text = [regex]::Replace($text, '\x00M(\d+)\x00', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $sentinels[[int]$m.Groups[1].Value] })
    return $text
}

function Get-EvidenceText {
    # 설치 창 글자 = Start-Transcript 파일(켜져 있을 때) · 아니면 설치 기록(화면 줄을 전부 담는다) — 끝에서 읽어 마스킹한 뒤 자른다.
    $src = if ($script:TranscriptOn -and (Test-Path -LiteralPath $TranscriptFile)) { $TranscriptFile } else { $LogFile }
    $bytes = Get-FileBytesCapped $src $EvidenceSourceBytes
    if ($null -eq $bytes -or $bytes.Length -eq 0) { return '' }
    $cut = $false
    try { $cut = ((Get-Item -LiteralPath $src -ErrorAction Stop).Length -gt $bytes.Length) } catch { }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $raw = [System.Text.Encoding]::Unicode.GetString($bytes, 2, $bytes.Length - 2) }
    else { $raw = [System.Text.Encoding]::UTF8.GetString($bytes); if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) } }
    # 끝에서 잘라 읽었으면 첫 줄은 반쪽이다 — 반쪽 토큰이 규칙에 안 걸린 채 나가지 않게 버린다.
    if ($cut) { $nl = $raw.IndexOf("`n"); if ($nl -ge 0) { $raw = $raw.Substring($nl + 1) } else { $raw = '' } }
    $masked = Protect-EvidenceText $raw
    return (Get-RemoteHelpTailBytes $masked $EvidenceTextBytes)
}

function Send-EvidenceOnce([string]$Reason) {
    # fail-open · (이유 × 단계) 한 번 · 설치를 막지 않는다.
    try {
        $key = $Reason + '|' + (Get-CurrentStep)
        if ($script:EvidenceSent.ContainsKey($key)) { return }
        $script:EvidenceSent[$key] = $true
        $t = Get-EvidenceText
        $slot = Send-EvidenceEvent $Reason $t
        Send-EvidenceImages $slot (Get-DefaultEvidenceKinds)   # v0.3.20 — 글자만으로는 09-16 실기의 정체를 알 수 없었다
        Write-Log ('evidence sent: ' + $key + ' ' + [System.Text.Encoding]::UTF8.GetByteCount([string]$t) + 'B')
    } catch { Write-Log ('evidence error (fail-open): ' + $_.Exception.Message) }
}

function Get-CurrentStep {
    # 지금까지 화면에 찍힌 마지막 [n/10] — 실패 전송이 「어느 단계에서 막혔나」를 싣게 한다.
    for ($i = $script:StepLog.Count - 1; $i -ge 0; $i--) {
        if ([string]$script:StepLog[$i] -match '\[([0-9]{1,2}/[0-9]{1,2})\]') { return $Matches[1] }
    }
    return '0/10'
}

function Get-InstallEnv {
    # 살핌(info) 이벤트에 싣는 환경 값 — 계약 2절 의 env 칸. 못 읽는 값은 넣지 않는다(fail-open).
    $e = @{}
    try { $cv = (& claude --version 2>$null | Select-Object -First 1); if ($cv) { $e['claude_ver'] = [string]$cv } } catch { }
    try { if ($script:CysCli) { $vv = (& $script:CysCli --version 2>$null | Select-Object -First 1); if ($vv) { $e['cys_ver'] = [string]$vv } } } catch { }
    try { $e['win_build'] = [string]([System.Environment]::OSVersion.Version.Build) } catch { }
    try { $e['ps_ver'] = [string]$PSVersionTable.PSVersion } catch { }
    try { $e['admin'] = [bool]$script:IsAdmin } catch { }
    try {
        $av = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop | ForEach-Object { $_.displayName } | Where-Object { $_ })
        if ($av.Count -gt 0) { $e['av'] = ($av -join ', ') } else { $e['av'] = '미상' }
    } catch { $e['av'] = '미상' }
    try {
        $prog = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction Stop).ProgId
        if ($prog) { $e['browser'] = [string]$prog }
    } catch { }
    return $e
}

# ── 화면·창 그림 (윈도우 전용 · 못 찍으면 $null 이라 첨부만 빠지고 설치는 이어간다) ──
function Resize-Bitmap($bmp, $maxW) {
    if ($bmp.Width -le $maxW) { return $bmp.Clone() }
    $w = $maxW; $h = [int]($bmp.Height * ($maxW / $bmp.Width))
    $out = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($out)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($bmp, 0, 0, $w, $h)
    } finally { $g.Dispose() }
    return $out
}
function ConvertTo-Jpeg($image, $quality) {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
    $prm = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $prm.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
    $ms = New-Object System.IO.MemoryStream
    try { $image.Save($ms, $codec, $prm); return $ms.ToArray() } finally { $ms.Dispose(); $prm.Dispose() }
}
function Get-ScreenJpeg {
    # 화면 전체 → JPEG(가로 1280px · 품질 60). 계약 3절 ③.
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $shot = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
        $g = [System.Drawing.Graphics]::FromImage($shot)
        try { $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size) } finally { $g.Dispose() }
        $small = Resize-Bitmap $shot 1280
        $shot.Dispose()
        $bytes = ConvertTo-Jpeg $small 60
        $small.Dispose()
        return $bytes
    } catch { return $null }
}
function Get-LoginWindowJpeg($proc) {
    # 살아 있는 로그인 창 하나 → JPEG(계약 3절 ④ · PrintWindow). 없으면 $null(생략 기록).
    # 🔴v0.3.20 — 찍는 일은 Get-WindowJpeg 하나로 모았다(설치 창·앱 창과 같은 코드를 세 벌 두지 않는다).
    #   이 함수에 남는 일은 **어느 창인가**를 고르는 것뿐이다.
    if ($null -eq $proc) { return $null }
    try {
        $h = [IntPtr]::Zero
        try { $h = $proc.MainWindowHandle } catch { $h = [IntPtr]::Zero }
        if ($h -eq [IntPtr]::Zero) { return $null }
        return (Get-WindowJpeg $h)
    } catch { return $null }
}

# ══ 캡처 증거 — v0.3.20 (TICKET=installer-capture-evidence · 2026-09-16) ═══════════════════════════════════
# 왜: 2026-09-16 실기(07:1x)에서 로그인이 5분 멈췄는데 도착한 것은 **글자 증거뿐**이었고,
#   설치가 끝난 뒤 첫 자리에 떠 있던 훅 오류 3줄은 **어떤 경로로도 오지 않았다**(사람이 손으로 찍은 사진이 유일한 근거였다).
#   ⇒ 「사람이 사진을 안 찍어도 운영팀이 상황을 안다」가 이 블록의 목적이다.
# 🔴🔴찍는 창은 **넷뿐**이고 전부 우리가 연 창이다 — installer_window · login_window · app_window · first_pane.
#   ⛔**전체 화면을 찍지 마라.** 서버에는 그런 종류가 없고(400), 그림은 **가려지지 않은 채** 저장된다.
#   ★그리고 서버는 그 그림이 정말 그 창인지 **재지 못한다** — 전체 화면을 찍어 app_window 라 이름 붙이면 그대로 저장된다.
#     ⇒ 참가자에게 「다른 창은 찍지 않습니다」라고 약속하는 주체가 이 파일이므로 **그 약속을 지키는 코드도 여기뿐이다.**
#     그래서 창 손잡이를 지정해 그 창만 잘라낸다(전체 화면을 찍어 좌표로 오려내면 위에 겹친 남의 창이 함께 찍힌다).
#   Get-ScreenJpeg 함수는 남겨 두되 **부르는 자리가 0** 이고, 시험이 그 0 을 센다(지우면 「왜 안 쓰는가」가 사라진다).
# 계약 정본 = 서버 도움 API 문서 10-2c·d·e 절 — 두 걸음으로 보낸다:
#   ① POST /api/progress (event=evidence) → 201 이 { seq, upload_token, upload{…}, capture } 를 준다
#   ② POST /api/progress/evidence/<seq>/image?kind=&filename= · 머리글 x-progress-upload · 본문 = 그림 바이트
#   토큰은 한 장용이 아니다 — **60분 안에 여러 장**을 같은 토큰으로 올린다.
# ⚠여기서 안 재는 것: 윈도우에서 PrintWindow 가 가려진 창·고DPI 에서 무엇을 담는지 · 한 장이 1.5MB 안에 들어가는지
#   (맥에는 윈도우 콘솔이 없어 이 기계에서는 한 번도 못 찍었다 — 윈 실기 몫).
$EvidenceImageMaxBytes    = 1572864              # 한 장 1.5MB(계약 3절 · 넘으면 413)
$EvidenceImageCap         = 12                   # 설치당 하루 12장(계약 3절 · 넘으면 429 image_cap)
$EvidenceImageKinds       = @('installer_window', 'login_window', 'app_window', 'first_pane')
$EvidenceHookErrorPattern = 'Stop hook error|hook error'
# ⓕ③ 오류 글 — 정해 준 낱말 그대로(대소문자 무관). ⚠우리 자신의 안내문에도 걸릴 수 있어 **이유마다 한 번**으로 막는다.
$CaptureErrorTextPattern  = 'error|exception|failed|denied|not recognized'
$script:EvidenceImageSent = 0
$script:EvidenceImageDone = $false   # 오늘 몫을 다 썼다(429 image_cap) — 더 시도하지 않는다
$script:CaptureSent       = @{}      # 이유|단계 → 이미 보냈다
$script:CaptureInSay      = $false   # Say 안에서 다시 Say 로 들어가는 것을 막는다
$script:CaptureReady      = $false   # 이 블록이 다 읽힌 뒤에만 Say 가 ⓕ③ 을 본다(파일 앞쪽 Say 호출 보호)
$script:CaptureRequested  = $null    # 운영팀이 청한 촬영(계약 5절) — 받은 그 자리에서 쓰고 버린다
# 단계 소요 기준선 — ⛔코드에 고정표를 두지 않는다(지어낸 숫자가 측정을 대신해 버린다 · 계약 4절).
$script:StepBaselineSec   = @{}
$script:StepBaselineNote  = 'not-fetched'   # not-fetched | ok:<칸수> | http:<코드> | empty | error | skip:*

function Get-EvidenceBaseUrl {
    # 진행 전송과 같은 주소를 쓴다 — 흉내가 JARVIS_PROGRESS_URL 로 바꿔치면 그림도 같은 가짜 서버로 간다.
    if ($env:JARVIS_PROGRESS_URL) { return [string]$env:JARVIS_PROGRESS_URL }
    return [string]$ProgressUrl
}
function Update-StepBaselines {
    # [1/10] 에서 한 번 부른다. 못 받으면 표는 비어 있고 「평소의 두 배」 판정은 통째로 잠든다 — 그 사실을 기록에 남긴다.
    if ($Mode -ne 'full') { $script:StepBaselineNote = 'skip:mode'; return }
    if ($env:JARVIS_NO_PROGRESS -eq '1') { $script:StepBaselineNote = 'skip:no-progress'; return }
    try {
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $u = (Get-EvidenceBaseUrl) + '/baseline?os=win'
        $r = Invoke-WebRequest -Uri $u -Method GET -UseBasicParsing -TimeoutSec $ProgressTimeoutSec -ErrorAction Stop
        if ([int]$r.StatusCode -ne 200) { $script:StepBaselineNote = 'http:' + [int]$r.StatusCode; return }
        $j = ConvertFrom-Json -InputObject ([string]$r.Content) -ErrorAction Stop
        $n = 0
        foreach ($row in @($j.steps)) {
            # ⛔median_elapsed_s 가 null 이면 **아직 모른다**는 뜻이다 — 내장 기본값으로 대신하지 않는다(계약 4절).
            if ($null -eq $row) { continue }
            $step = [string]$row.step
            if (-not $step) { continue }
            if ($null -eq $row.median_elapsed_s) { continue }
            $v = 0.0
            if (-not ([double]::TryParse([string]$row.median_elapsed_s, [ref]$v))) { continue }
            if ($v -le 0) { continue }
            $script:StepBaselineSec[$step] = [double]$v
            $n++
        }
        $script:StepBaselineNote = $(if ($n -gt 0) { 'ok:' + $n } else { 'empty' })
    } catch { $script:StepBaselineNote = 'error' }
    Write-Log ('step baseline: ' + $script:StepBaselineNote + ' (빈 칸 = 그 단계 느림 촉발 꺼짐)')
}
function Test-StepSlow([string]$Step, [double]$Sec) {
    # 돌려주는 것 = $true 기준선의 2배를 넘었다. ★칸이 없으면 **거짓**이다 — 「모른다」를 「빠르다」로도 「느리다」로도 읽지 않는다.
    if (-not $script:StepBaselineSec.ContainsKey($Step)) { return $false }
    $b = [double]$script:StepBaselineSec[$Step]
    if ($b -le 0) { return $false }
    return ($Sec -gt ($b * 2))
}

# ── 창 하나를 그림으로 (윈도우 전용 · 못 찍으면 $null 이라 그림만 빠지고 설치는 이어간다) ──
function Get-WindowJpeg($h) {
    if ($null -eq $h -or $h -eq [IntPtr]::Zero) { return $null }
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        if (-not ([System.Management.Automation.PSTypeName]'Jarvis.Win').Type) {
            Add-Type -Namespace Jarvis -Name Win -ErrorAction Stop -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool PrintWindow(System.IntPtr hwnd, System.IntPtr hdc, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr hwnd, out RECT r);
[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool IsHungAppWindow(System.IntPtr hwnd);
[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
'@
        }
        # 🔴먹통 창은 건너뛴다 — PrintWindow 는 대상 창의 실타래에 **동기로** 부탁하고 기다린다.
        #   응답을 멈춘 창이면 그 기다림이 끝나지 않아 **설치기가 통째로 멈춘다**(이종 검토 1R 지적 채택 2026-09-16).
        #   ⚠이것으로 모든 멈춤이 사라지지는 않는다 — 부른 뒤에 먹통이 되는 창은 이 검사 뒤에 있다(잔여 · 윈 실기 몫).
        try { if ([Jarvis.Win]::IsHungAppWindow($h)) { Write-Log 'window capture skip (창이 응답하지 않는다)'; return $null } } catch { }
        $r = New-Object Jarvis.Win+RECT
        if (-not [Jarvis.Win]::GetWindowRect($h, [ref]$r)) { return $null }
        $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
        if ($w -le 0 -or $ht -le 0) { return $null }
        $bmp = New-Object System.Drawing.Bitmap($w, $ht)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $hdc = $g.GetHdc()
            try { [void][Jarvis.Win]::PrintWindow($h, $hdc, 2) } finally { $g.ReleaseHdc($hdc) }
        } finally { $g.Dispose() }
        # 🔴한 장 1.5MB 를 넘으면 서버가 413 으로 돌려보낸다(자르지 않는다) ⇒ **우리가 품질을 낮춰 다시 인코딩한다**.
        #   가로도 함께 줄인다 — 품질만 낮추면 큰 화면에서 상한 안에 못 들어간다.
        foreach ($try in @(@(1280, 60), @(1280, 40), @(960, 40), @(800, 30))) {
            $small = Resize-Bitmap $bmp $try[0]
            $bytes = ConvertTo-Jpeg $small $try[1]
            $small.Dispose()
            if ($null -ne $bytes -and $bytes.Length -le $EvidenceImageMaxBytes) { $bmp.Dispose(); return $bytes }
        }
        $bmp.Dispose()
        Write-Log 'window capture skip (가장 낮은 품질로도 한 장 상한을 못 맞췄다)'
        return $null
    } catch { return $null }
}
function Get-InstallerWindowJpeg {
    # 설치 창 = 우리 콘솔 창 하나. ⛔전체 화면이 아니다 — 쓰시는 분의 다른 창은 담기지 않는다.
    try {
        if (-not ([System.Management.Automation.PSTypeName]'Jarvis.Win').Type) { [void](Get-WindowJpeg ([IntPtr]::Zero)) }
        $h = [Jarvis.Win]::GetConsoleWindow()
        if ($h -eq [IntPtr]::Zero) { return $null }   # 콘솔이 없다(입력 리디렉트·흉내) — 그림 없이 간다
        return (Get-WindowJpeg $h)
    } catch { return $null }
}
function Get-LoginWindowJpegLive {
    # 살아 있는 로그인 창(대기 중일 때만 있다). 없으면 $null.
    if (-not $script:LoginProc) { return $null }
    try { if ($script:LoginProc.HasExited) { return $null } } catch { return $null }
    return (Get-LoginWindowJpeg $script:LoginProc)
}
function Get-AppWindowJpeg {
    # 자비스 앱 창 하나. 없으면 $null.
    # 🔴이름만 보고 고르지 않는다 — 이름이 같은 남의 프로그램이나 쓰시는 분이 따로 띄워 둔 창이 찍힐 수 있다
    #   (이종 검토 1R 지적 채택 2026-09-16). ⇒ **우리가 깐 자리에서 도는 것**만 찍는다.
    #   ⚠창 손잡이를 쥐고 있다가 쓰는 길은 못 쓴다 — 보통은 상시 가동 프로그램이 앱을 띄우고 우리는 그 자리에 없다.
    #   ⚠우리가 깐 자리를 모르면(프로그램을 못 찾은 실행) **찍지 않는다** — 모를 때는 안 찍는 쪽이 맞다.
    try {
        if (-not $script:CysCli) { Write-Log 'app window skip (우리가 깐 자리를 모른다)'; return $null }
        $dir = ''
        try { $dir = (Split-Path $script:CysCli -Parent) } catch { $dir = '' }
        if (-not $dir) { return $null }
        foreach ($n in @('cys-app', 'cysr', 'cys')) {
            foreach ($p in @(Get-Process -Name $n -ErrorAction SilentlyContinue)) {
                if ($p.MainWindowHandle -eq [IntPtr]::Zero) { continue }
                $exe = ''
                try { $exe = [string]$p.Path } catch { $exe = '' }
                if (-not $exe) { continue }
                if (-not $exe.StartsWith($dir.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
                return (Get-WindowJpeg $p.MainWindowHandle)
            }
        }
        Write-Log 'app window skip (우리가 깐 자리에서 도는 창을 못 찾았다)'
        return $null
    } catch { return $null }
}
function Get-EvidenceKindJpeg([string]$Kind) {
    # 종류 이름 → 그림. ⛔모르는 이름에는 **아무것도 주지 않는다**(전체 화면으로 대신하는 길을 만들지 않는다).
    # ⚠first_pane 은 이 판에서 **그림을 만들지 않는다** — 윈도우에서 첫 자리는 자비스 앱 창 **안의 한 칸**이라
    #   따로 잘라낼 창 손잡이가 없다. 그 자리의 내용은 글자 증거(seat=master · 끝 40줄)로 보낸다.
    #   ⇒ 없는 것을 app_window 로 이름만 바꿔 보내지 않는다(서버는 그것을 가려낼 수 없다).
    switch ($Kind) {
        'installer_window' { return (Get-InstallerWindowJpeg) }
        'login_window'     { return (Get-LoginWindowJpegLive) }
        'app_window'       { return (Get-AppWindowJpeg) }
        'first_pane'       { Write-Log 'first_pane skip (윈도우에서는 앱 창 안의 한 칸이라 따로 찍을 창이 없다)'; return $null }
        default            { Write-Log ('evidence image skip (모르는 종류): ' + $Kind); return $null }
    }
}

# ── 두 걸음 보내기 (계약 2절) ─────────────────────────────────────────────
function Send-EvidenceEvent([string]$Reason, [string]$Text) {
    # ① 증거 이벤트. 돌려주는 것 = @{ Seq; Token } (그림 자리) 또는 $null.
    #   ⚠글자는 **선택**이다 — 빈 글을 보내면 400 이라 아예 칸을 빼고 보낸다.
    #   ⚠흉내는 이 함수를 갈아 끼워 줄을 파일에 적는다(그래서 진행 전송과 따로 둔다).
    if ($Mode -ne 'full') { return $null }
    if ($env:JARVIS_NO_PROGRESS -eq '1') { return $null }
    try {
        $fields = [ordered]@{
            install_id        = (Get-InstallId)
            installer_version = $InstallerVersion
            os                = 'win'
            step              = (Get-CurrentStep)
            event             = 'evidence'
            at                = (Get-Date -Format o)
            reason            = $Reason
        }
        if ($Text) { $fields['text'] = [string]$Text; $fields['masked'] = $true }
        $body = ($fields | ConvertTo-Json -Compress -Depth 4)
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $r = Invoke-WebRequest -Uri (Get-EvidenceBaseUrl) -Method POST `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -ContentType 'application/json; charset=utf-8' -UseBasicParsing `
            -TimeoutSec $ProgressTimeoutSec -ErrorAction Stop
        $j = ConvertFrom-Json -InputObject ([string]$r.Content) -ErrorAction Stop
        Receive-CaptureRequest $j.capture   # 운영팀이 청한 촬영은 이 답에 실려 온다(계약 5절 · 하트비트가 곧 수신함)
        if ($null -eq $j.seq -or -not $j.upload_token) { return $null }
        return @{ Seq = [string]$j.seq; Token = [string]$j.upload_token }
    } catch {
        if (-not $script:ProgressWarned) {
            $script:ProgressWarned = $true
            Write-Log ('progress send failed (fail-open) - ' + $_.Exception.Message)
        }
        return $null
    }
}
function Send-EvidenceImage($Slot, [string]$Kind, $Bytes) {
    # ② 그림 한 장. 돌려주는 것 = $true 보냈다. fail-open — 무슨 일이 있어도 설치를 막지 않는다.
    # 🔴바이트 묶음으로 못을 박는다 — 다른 함수를 거쳐 온 그림은 낱개 값들의 묶음(Object[])으로 풀려 있을 수 있고,
    #   그대로 보내면 본문이 「숫자 글자」로 나가 길이가 어긋난다(2026-09-16 실측: 보내기가 통째로 실패했다).
    if ($null -ne $Bytes) { $Bytes = [byte[]]$Bytes }
    if ($null -eq $Slot -or -not $Slot.Token) { return $false }
    if ($script:EvidenceImageDone) { return $false }
    if ($EvidenceImageKinds -notcontains $Kind) { Write-Log ('evidence image skip (계약에 없는 종류): ' + $Kind); return $false }
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { Write-Log ('evidence image skip (그림이 없다): ' + $Kind); return $false }
    if ($Bytes.Length -gt $EvidenceImageMaxBytes) { Write-Log ('evidence image skip (' + $Bytes.Length + 'B > 한 장 상한): ' + $Kind); return $false }
    if ($script:EvidenceImageSent -ge $EvidenceImageCap) { Write-Log ('evidence image skip (설치당 ' + $EvidenceImageCap + '장 상한): ' + $Kind); return $false }
    try {
        $ProgressPreference = 'SilentlyContinue'
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $u = (Get-EvidenceBaseUrl) + '/evidence/' + $Slot.Seq + '/image?kind=' + $Kind + '&filename=' + $Kind + '.jpg'
        # ⛔길이를 손으로 넣지 마라 — 보내는 쪽이 이미 넣는다. 두 번 넣으면 본문과 어긋나 보내기가 거부된다
        #   (2026-09-16 실측 오류: content would exceed Content-Length). 계약이 요구하는 길이 머리글은 그대로 나간다.
        $h = @{ 'x-progress-upload' = $Slot.Token }
        [void](Invoke-WebRequest -Uri $u -Method POST -Body $Bytes -ContentType 'image/jpeg' `
            -Headers $h -UseBasicParsing -TimeoutSec $ProgressTimeoutSec -ErrorAction Stop)
        $script:EvidenceImageSent++
        Write-Log ('evidence image sent: ' + $Kind + ' ' + $Bytes.Length + 'B (' + $script:EvidenceImageSent + '/' + $EvidenceImageCap + ')')
        return $true
    } catch {
        # 🔴429 는 두 종류다 — 오늘 몫을 다 쓴 것(image_cap)이면 더 시도하지 않는다(재시도해도 같은 답이다).
        $code = 0; $errText = ''
        try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 }
        try { $errText = [string]$_.ErrorDetails.Message } catch { $errText = '' }
        if ($code -eq 429 -and $errText -match 'image_cap') {
            $script:EvidenceImageDone = $true
            Write-Log 'evidence image: 오늘 몫을 다 썼다(image_cap) — 이 실행에서는 더 올리지 않는다'
        } elseif (-not $script:EvidenceImageWarned) {
            $script:EvidenceImageWarned = $true
            Write-Log ('evidence image failed (fail-open) ' + $code + ' - ' + $_.Exception.Message)
        }
        return $false
    }
}
function Send-EvidenceImages($Slot, [string[]]$Kinds) {
    foreach ($k in @($Kinds)) { [void](Send-EvidenceImage $Slot $k (Get-EvidenceKindJpeg $k)) }
}
function Get-DefaultEvidenceKinds {
    # 정체·이상 징후에 함께 보내는 것 = 설치 창 + (살아 있으면) 로그인 창.
    $kinds = @('installer_window')
    if ($script:LoginProc) {
        $alive = $false
        try { $alive = -not $script:LoginProc.HasExited } catch { $alive = $false }
        if ($alive) { $kinds += 'login_window' }
    }
    return ,([string[]]$kinds)
}

# ── 운영팀 촬영 요청 (계약 5절 · 받는 쪽만 만든다) ─────────────────────────
function Receive-CaptureRequest($Req) {
    # 받으면 그 자리에서 쓰고 버린다. ⛔받았다는 확인을 서버에 돌려주지 않고, 재시도·영속화도 만들지 않는다
    #   (들고 있다가 어긋나는 쪽이 더 나쁘다 — 운영팀이 다시 걸면 된다). sig 는 우리가 검사하지 않는다(키가 없다).
    if ($null -eq $Req) { return }
    try {
        $kinds = @(@($Req.kinds) | Where-Object { $EvidenceImageKinds -contains [string]$_ })   # 모르는 이름은 **그것만** 건너뛴다
        if ($kinds.Count -eq 0) { Write-Log 'capture request: 찍을 수 있는 종류가 없다'; return }
        $script:CaptureRequested = [string[]]$kinds
        Write-Log ('capture request 받음: ' + ($kinds -join ','))
    } catch { }
}
function Invoke-CaptureRequested {
    # 받아 둔 촬영 요청이 있으면 그 자리에서 찍어 보낸다(reason=requested).
    if ($null -eq $script:CaptureRequested) { return }
    $kinds = $script:CaptureRequested
    $script:CaptureRequested = $null   # 1회성
    try {
        $slot = Send-EvidenceEvent 'requested' ''
        Send-EvidenceImages $slot $kinds
        Write-Log ('capture requested 처리: ' + ($kinds -join ','))
    } catch { Write-Log ('capture requested error (fail-open): ' + $_.Exception.Message) }
}

function Send-CaptureEvidence([string]$Reason, [string]$Detail) {
    # ⓕ 이상 징후 촉발(slow·retry·error-text) — 글자 증거 + 그림. (이유 × 단계)마다 한 번 · fail-open.
    try {
        $step = Get-CurrentStep
        $key = $Reason + '|' + $step
        if ($script:CaptureSent.ContainsKey($key)) { return }
        $script:CaptureSent[$key] = $true
        $t = Get-EvidenceText
        if ($Detail) {
            # 🔴사유 글도 **반드시** 마스킹한다 — ⓕ③ 은 콘솔 줄을 통째로 넘기고 그 줄에는 경로·메일이 들어 있다.
            $head = Get-RemoteHelpTailBytes (Protect-EvidenceText ('[' + $Reason + '] ' + $Detail)) 400
            $t = $head + "`n" + [string]$t
        }
        $slot = Send-EvidenceEvent $Reason $t
        Send-EvidenceImages $slot (Get-DefaultEvidenceKinds)
        # 🔴여기도 마스킹한다 — 이 기록 파일(bootstrap.log)은 실패 때 통째로 붙여 보낸다.
        Write-Log ('capture evidence: ' + $key + ' ' + (Protect-EvidenceText ([string]$Detail)))
    } catch { Write-Log ('capture evidence error (fail-open): ' + $_.Exception.Message) }
}

# ── 설치 완료 뒤(post-install) 증거 — [10/10] 각성 판정 직후 한 번 ────────────────────────────
# 왜: 09-16 실기에서 설치는 성공으로 끝났는데 **첫 자리 화면에 훅 오류 3줄이 떠 있었다.** 설치기는 그것을 본 적이 없다.
function Get-PostInstallText([string]$Cli, [string]$Ref) {
    # 돌려주는 것 = 마스킹·상한을 거친 글자(못 읽으면 '')
    if (-not $Ref) { return '' }
    $scr = Invoke-CysCapped $Cli ('read-screen --surface ' + $Ref) $ChildReadCapMs
    if ($null -eq $scr) { return '' }
    $lines = @(([string]$scr).TrimEnd() -split "`r?`n")
    $from = [math]::Max(0, $lines.Count - 40)
    $hook = @($lines | Where-Object { $_ -match $EvidenceHookErrorPattern }).Count
    $body = 'seat=master' + "`n" + 'hook_errors=' + $hook + "`n" + (($lines[$from..($lines.Count - 1)]) -join "`n")
    return (Get-RemoteHelpTailBytes (Protect-EvidenceText $body) $EvidenceTextBytes)
}
function Send-PostInstallEvidence([string]$Cli, [string]$Ref) {
    # fail-open · 설치당 한 번 · 설치를 막지 않는다(성공 끝맺음 뒤에 부른다).
    try {
        $key = 'post-install|10/10'
        if ($script:CaptureSent.ContainsKey($key)) { return }
        $script:CaptureSent[$key] = $true
        $t = Get-PostInstallText $Cli $Ref
        $slot = Send-EvidenceEvent 'post-install' $t
        Send-EvidenceImages $slot @('app_window')
        Write-Log ('evidence sent: ' + $key + ' text=' + [System.Text.Encoding]::UTF8.GetByteCount([string]$t) + 'B')
    } catch { Write-Log ('post-install evidence error (fail-open): ' + $_.Exception.Message) }
}
$script:CaptureReady = $true

# ── 첨부 (보고가 열린 뒤에만 · 각각 실패해도 다음으로 · 계약 3절 순서) ──
function Get-FileBytesCapped($path, $max) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        $bytes = [System.IO.File]::ReadAllBytes($path)
        if ($bytes.Length -le $max) { return $bytes }
        # 기록·화면 글자는 끝이 중요하다 — 끝에서 $max 바이트만 남긴다.
        $tail = New-Object byte[] $max
        [Array]::Copy($bytes, ($bytes.Length - $max), $tail, 0, $max)
        return $tail
    } catch { return $null }
}
function Get-ProcTreeBytes {
    try {
        $tree = @(Get-ProcTree $PID)
        $lines = @('# 실행 중인 프로그램(뿌리 ' + $PID + ')')
        foreach ($t in $tree) { $lines += (('  ' * [int]$t.Depth) + [string]$t.Id + ' ' + [string]$t.Name) }
        return [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`r`n"))
    } catch { return $null }
}
function Send-Attachment($kind, $filename, $bytes) {
    # 돌려주는 것 = $true 보냈다. 보고가 없으면(x-help-client 없음) 아무것도 안 한다.
    if (-not $script:RhId) { return $false }
    if ($null -eq $bytes -or $bytes.Length -eq 0) { Write-Log ('attach skip (empty): ' + $kind); return $false }
    if ($bytes.Length -gt $AttachMaxBytes) { Write-Log ('attach skip (' + $bytes.Length + 'B > cap): ' + $kind); return $false }
    try {
        $fields = [ordered]@{ kind = $kind; filename = $filename; content_b64 = [Convert]::ToBase64String($bytes) }
        $r = Invoke-RemoteHelpHttp 'POST' ('/api/help/' + $script:RhId + '/attach') ($fields | ConvertTo-Json -Compress)
        if ($r.Code -eq 201) { Write-Log ('attach ok: ' + $kind + ' ' + $bytes.Length + 'B'); return $true }
        Write-Log ('attach failed (' + $r.Code + '): ' + $kind); return $false
    } catch { Write-Log ('attach error (fail-open): ' + $kind + ' - ' + $_.Exception.Message); return $false }
}
function Send-FailAttachments {
    # 보고가 열린 직후 부른다 — 계약 3절 순서 · 각각 fail-open. 로그인 창 그림은 대기 중 찍어 둔 것을 쓴다.
    if (-not $script:RhId) { return }
    [void](Send-Attachment 'log_full' 'bootstrap.log' (Get-FileBytesCapped $LogFile $AttachMaxBytes))
    if ($script:TranscriptOn) { try { Stop-Transcript | Out-Null } catch { }; $script:TranscriptOn = $false }
    [void](Send-Attachment 'console_text' 'transcript.txt' (Get-FileBytesCapped $TranscriptFile $AttachMaxBytes))
    # 🔴v0.3.20 — 전체 화면을 붙이던 자리다. 쓰시는 분의 다른 창이 함께 나가므로 **찍는 것만 설치 창 한정**으로 바꿨다.
    #   Get-ScreenJpeg 함수는 남겨 두되 **부르는 자리는 0** 이다(시험이 그 0 을 센다).
    #   ⚠칸 이름(kind)은 'screen_png' 그대로 둔다 — 첨부 6종과 그 순서는 **서버 계약(3절)**이고 우리가 혼자 바꿀 자리가 아니다.
    #     이름이 내용과 어긋나는 것은 알고 둔 것이다(서버가 계약을 손볼 때 함께 고칠 항목 · 보고서 2절에 올렸다).
    #     파일 이름만 사실대로 바꿨다 — 받는 사람이 무엇을 보고 있는지 알 수 있게.
    [void](Send-Attachment 'screen_png' 'installer-window.jpg' (Get-InstallerWindowJpeg))
    if ($script:LoginCapFiles.Count -gt 0) {
        foreach ($f in $script:LoginCapFiles) { [void](Send-Attachment 'login_window_png' (Split-Path -Leaf $f) (Get-FileBytesCapped $f $AttachMaxBytes)) }
    } else {
        Write-Log 'attach: login window capture 없음(로그인 창이 살아 있지 않았거나 못 찍었다)'
    }
    [void](Send-Attachment 'proc_tree' 'proc-tree.txt' (Get-ProcTreeBytes))
    [void](Send-Attachment 'env_full' 'env-report.md' (Get-FileBytesCapped $ReportFile $AttachMaxBytes))
}

# ── 콘솔 빠른 편집(QuickEdit) 끄기 (TICKET=installer-awaken-verify-r2 · 2026-09-16) ─────────
# 🔴샌드박스 실측: 설치 창을 한 번 클릭하면 콘솔이 「선택」 모드로 들어가 출력이 멈추고, 그동안 설치가 13분 멈췄다
#   (사람이 Esc·Enter 를 누를 때까지 화면 쓰기가 막힌다 · 창 제목 앞에 「선택」 이 붙는다).
#   ⇒ 설치기가 도는 동안만 빠른 편집을 끄고, 끝맺음 뒤 원래 값으로 되돌린다(창을 닫지 않은 사람이 글을 복사할 수 있게).
# ⚠fail-open — 콘솔이 아니거나(입력 리디렉트·맥 흉내) 형식 등록·호출이 실패하면 아무 일도 하지 않는다(설치는 막지 않는다).
# ⚠여기서 안 재는 것: 맥에는 윈도우 콘솔이 없어 이 함수는 흉내로 못 돈다(정적 축만) · 윈도우 터미널(ConPTY) 창은 이 설정과 무관하다.
$script:QuickEditSaved = $null
function Disable-ConsoleQuickEdit {
    try {
        if ($env:OS -ne 'Windows_NT') { return }
        if ([Console]::IsInputRedirected) { return }
        if (-not ([System.Management.Automation.PSTypeName]'Jarvis.ConMode').Type) {
            Add-Type -Namespace Jarvis -Name ConMode -ErrorAction Stop -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)] public static extern System.IntPtr GetStdHandle(int nStdHandle);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetConsoleMode(System.IntPtr hConsole, out uint mode);
[System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleMode(System.IntPtr hConsole, uint mode);
'@
        }
        $h = [Jarvis.ConMode]::GetStdHandle(-10)   # STD_INPUT_HANDLE
        [uint32]$m = 0
        if (-not [Jarvis.ConMode]::GetConsoleMode($h, [ref]$m)) { return }
        if ((([int64]$m) -band 0x40) -eq 0) { return }   # ENABLE_QUICK_EDIT_MODE 가 이미 꺼져 있다
        $new = [uint32]((([int64]$m) -bor 0x80) -band 4294967231)   # ENABLE_EXTENDED_FLAGS 켜고 0x40 끔
        if ([Jarvis.ConMode]::SetConsoleMode($h, $new)) {
            $script:QuickEditSaved = $m
            Write-Log ('console quickedit off (was 0x' + ('{0:X}' -f $m) + ')')
        }
    } catch { try { Write-Log ('console quickedit untouched (fail-open): ' + $_.Exception.Message) } catch { } }
}
function Restore-ConsoleQuickEdit {
    try {
        if ($null -eq $script:QuickEditSaved) { return }
        $h = [Jarvis.ConMode]::GetStdHandle(-10)
        [void][Jarvis.ConMode]::SetConsoleMode($h, [uint32]$script:QuickEditSaved)
        $script:QuickEditSaved = $null
    } catch { }
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

    if ($Mode -eq 'full') {
        [void](Get-InstallId)   # 이 실행의 설치 번호를 자리에 만들어 둔다(기기·재시도 사슬)
        # 설치 창의 글자를 통째로 파일에 담는다 — 막혔을 때 그 파일을 진단 자료로 붙인다(계약 3절 ②).
        try { Start-Transcript -LiteralPath $TranscriptFile -Force -ErrorAction Stop | Out-Null; $script:TranscriptOn = $true } catch { }
    }
    Disable-ConsoleQuickEdit   # 창 클릭 → 「선택」 모드 → 출력 정지(설치 멈춤)를 막는다 · 끝맺음 뒤 되돌린다(함수 머리 주석)
    # 머리글 앞머리 「=== 자비스 설치 도우미 」 는 지난 실행 읽기(Show-PrevRunNote)의 경계 표지다 — 앞머리는 바꾸지 않는다.
    Say "=== 자비스 설치 도우미 — $CysDisplayName $CysVersion · 설치 도우미 $InstallerVersion (모드: $Mode) ==="
    Show-PrevRunNote
    Say '[1/10] 이 컴퓨터를 살펴봅니다.'
    Say ('     ' + $RemoteHelpNotice)
    $script:NoticeShown = $true
    Say ('     ' + $ProgressNotice)   # 첫 화면 고지 = 서버 정본 문안(계약 2절 · 정본 1곳)
    Send-Progress '1/10' 'start' $null $null $null
    Update-StepBaselines   # ⓕ① v0.3.20 — 단계 소요 기준선을 서버에서 한 번 받는다(못 받으면 그 축은 잠든다 · 기록 1줄)
    Invoke-DetectStage1
    Invoke-DetectStage2
    Write-Report
    Show-OldCysNote
    Send-Progress '1/10' 'end' $null $null $null
    Send-Progress '1/10' 'info' $null $null (Get-InstallEnv)   # 환경 전체(계약 3절 · [1/10] 뒤 info)

    if ($Mode -eq 'detect') {
        Say '감지만 하고 끝냅니다.'
        # 끝맺음 한 줄은 그 끝에 맞아야 한다 — 「살펴보기만 한 끝」에 「이어서 갑니다」는 맞지 않는다.
        Set-NextStepRerun '실제로 설치하시려면 -DetectOnly 없이 아래 「다시 하시는 법」대로 다시 실행해 주십시오.'
        exit 0
    }

    Send-Progress '2/10' 'start' $null $null $null
    $rc = Step-InstallClaude; Send-Progress '2/10' 'end' $null ('rc=' + $rc) $null; if ($rc -ne 0) { exit $rc }
    Send-Progress '3/10' 'start' $null $null $null
    # 🔴(installer-speed-pin-0320 ⓔ' · 샌드박스 실기 2026-09-16 적색) 빠른 편집이 꺼져 있으면 마우스로 글을 긁을 수 없다 —
    #   브라우저가 저절로 안 열리는 기계에서 사람이 로그인 주소를 복사하지 못했다. ⇒ 로그인 대기 구간에서만 원래 값으로 켜 두고, 끝나면 다시 끈다.
    #   (실패로 끝나 exit 하면 본문 finally 가 되돌린다 — 켜진 채로 남는 쪽이다.)
    Restore-ConsoleQuickEdit   # [3/10] 로그인 대기 — 빠른 편집 켜짐(주소를 긁을 수 있게)
    Step-Login; $rc = $script:LoginRc; if ($rc -ne 0) { exit $rc }   # 반환값을 받지 않는다(Step-Login 머리 주석 · v0.3.17)
    Disable-ConsoleQuickEdit   # [3/10] 로그인이 끝났다 — 다시 끈다(창 클릭 멈춤 방지)
    Send-Progress '3/10' 'end' $null ('rc=' + $script:LoginRc) $null

    $Rows.Clear()
    Invoke-DetectStage1
    Invoke-DetectStage2
    Write-Report        # 기동 직전 값으로 보고를 갱신한다

    Send-Progress '4/10' 'start' $null $null $null
    $rc = Step-Prepare; Send-Progress '4/10' 'end' $null ('rc=' + $rc) $null; if ($rc -ne 0) { exit $rc }

    # 여기서부터는 한 단이 막혀도 멈추지 않는다.
    # 앞 단계(클로드 설치·로그인·자비스 준비)는 이미 성립했고, 막힌 자리를 사람에게 설명해 주는 것이
    # 그 다음으로 할 수 있는 가장 쓸모 있는 일이기 때문이다. 막힌 단을 적어 두고 자비스를 깨운다.
    foreach ($st in @(
        @{ Name = 'cys 설치 파일 받기'; Step = '5/10'; Fn = { Step-DownloadCys } },
        @{ Name = 'cys 설치';           Step = '6/10'; Fn = { Step-InstallCys } },
        @{ Name = 'cys 확인';           Step = '7/10'; Fn = { Step-VerifyCys } },
        @{ Name = '계정 준비';          Step = '8/10'; Fn = { Step-PrepareAccount } })) {
        Send-Progress $st.Step 'start' $null $null $null
        $stepSw = [System.Diagnostics.Stopwatch]::StartNew()
        # 함수가 화면 말고 출력 스트림에 무언가를 흘리면 반환값이 배열이 된다(이 파일 위쪽의 같은 함정).
        # 그러면 성공한 단계도 막힌 것으로 읽힌다 ⇒ 마지막 값 하나만 종료 코드로 본다.
        $rc = @(& $st.Fn)[-1]
        $stepSec = [double]$stepSw.Elapsed.TotalSeconds
        Send-Progress $st.Step 'end' ([int]$stepSec) ('rc=' + $rc) $null
        # ⓕ① v0.3.20 — 기준선(서버가 준 중앙값)의 2배를 넘으면 찍는다. ★표에 그 칸이 없으면 **아무 일도 하지 않는다**.
        if (Test-StepSlow $st.Step $stepSec) { Send-CaptureEvidence 'slow' ($st.Step + ' ' + [int]$stepSec + 's > 2x ' + [int]$script:StepBaselineSec[$st.Step] + 's') }
        Invoke-CaptureRequested   # ⓕ④ v0.3.20 — 진행 답으로 받아 둔 촬영 요청을 여기서 처리한다(1회성 · 안 오면 아무 일도 안 한다)
        # ⓕ② v0.3.20 — 비치명 rc(여기서 안 멈추는 값)도 징후다. 멈추는 rc 는 아래 BlockedStep 이 받고 실패 증거가 따로 간다.
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
    try { Write-ClosingNote } finally { Restore-ConsoleQuickEdit }   # 끝맺음(원격 해결 대기 포함)이 끝난 뒤 빠른 편집을 되돌린다
}
