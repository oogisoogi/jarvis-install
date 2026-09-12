# 등록 안 된 잔재 축 — 윈도우 실행 입구 (가짜 상태 만들기 → 지우개 → 대조)
#
# 무엇을 재는가 (2026-09-09 실사용자 3호 실기의 재현)
#   그 기계는 **cys 폴더는 있는데 설치 목록 항목이 없었다.** 설정 앱은 그 항목을 보므로 cys 가
#   보이지 않았고, 그런데 지우개는 「설정 앱에서 지우고 오라」를 8번 요구했다 — 사람이 할 수 없는 일이다.
#   ⇒ 두 상태를 각각 만들어 놓고 지우개가 **갈라서 행동하는지** 잰다.
#     no-entry     = 폴더 + 제거 프로그램, 목록 항목 없음 → 스스로 지우고 rc 0
#     with-entry   = 폴더 + 제거 프로그램 + 목록 항목      → 설정 앱 안내 · [남음] · rc 7
#     entry-no-exe = 폴더 + 목록 항목, 제거 프로그램 없음  → 스스로 지우되 **까닭을 다르게** 말해야 한다
#                    (설정 앱에 항목은 보이지만 눌러도 실패하는 자리 · 외부 검토 1차 [1] 지적으로 생긴 축)
#
# ⛔살아 있는 기계에서는 시작하지 않는다. 이 스크립트는 레지스트리(HKCU)에 항목을 만들고 지우며,
#   그 자리는 환경변수를 갈아 끼워도 격리되지 않는다. 진짜 cys 가 있으면 그 자리를 건드리게 된다.
#
# 쓰는 법
#   pwsh -File tests\win-stale-cys-run.ps1 -Dir install-master -Sandbox <자리> -State no-entry|with-entry
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [Parameter(Mandatory=$true)][string]$Sandbox,
    [ValidateSet('no-entry','with-entry','entry-no-exe')][string]$State = 'no-entry'
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$RegKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys'

# ── 거절 판정 — 살아 있는 기계면 여기서 멈춘다 ────────────────────
if (Test-Path (Join-Path $env:LOCALAPPDATA 'cys')) {
    Write-Host '::error::이 기계에 진짜 cys 폴더가 있습니다 — 시험을 시작하지 않습니다.'
    exit 4
}
# ★이 항목이 「진짜 설치」인지 「지난 시험이 남긴 것」인지 갈라야 한다.
#   시험이 강제 종료되면 finally 가 안 돌아 우리 항목이 남는다. 그것까지 「진짜」로 읽으면 다음 실행이
#   영영 거절된다. 그래서 우리가 만든 것에는 표를 달아 두고, 그 표가 있을 때만 치우고 계속한다.
#   (외부 검토 1차 [4] 지적 채택 2026-09-09 — 표가 없으면 거절이 정답이다. 남의 항목은 절대 덮어쓰지 않는다.)
$FixtureMark = 'JarvisTestFixture'
if (Test-Path $RegKey) {
    $mark = (Get-ItemProperty -Path $RegKey -Name $FixtureMark -ErrorAction SilentlyContinue)
    if ($mark) {
        Write-Host '  (지난 시험이 남긴 목록 항목을 치우고 계속합니다)'
        Remove-Item $RegKey -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path $RegKey) {
    Write-Host '::error::이 기계에 진짜 cys 설치 목록 항목이 있습니다 — 시험을 시작하지 않습니다.'
    exit 4
}
if (Test-Path (Join-Path $env:LOCALAPPDATA 'Programs\cys')) {
    Write-Host '::error::이 기계에 진짜 cys 폴더(옛 자리)가 있습니다 — 시험을 시작하지 않습니다.'
    exit 4
}
# ★환경변수를 갈아 끼워도 격리되지 않는 자리가 하나 더 있다 — 작업 스케줄러 등록이다.
#   지우개는 이름에 cys 가 들어간 등록을 찾아 **해제**한다. 그 자리는 사용자 폴더를 안 본다
#   ⇒ 살아 있는 기계에서 이 시험을 돌리면 남의 등록이 실제로 풀린다. 그래서 여기서 거절한다.
$cysTasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -imatch 'cys' })
if ($cysTasks.Count -gt 0) {
    Write-Host ('::error::이 기계에 cys 관련 작업 스케줄러 등록이 ' + $cysTasks.Count + '개 있습니다 — 시험을 시작하지 않습니다.')
    exit 4
}

if (Test-Path $Sandbox) { Remove-Item $Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $Sandbox | Out-Null
$Sandbox = (Resolve-Path $Sandbox).Path

Write-Host "-- 가짜 상태 ($State) ---------------------------"
$oldUser  = $env:USERPROFILE
$oldLocal = $env:LOCALAPPDATA
$oldApp   = $env:APPDATA
$env:USERPROFILE  = $Sandbox
$env:LOCALAPPDATA = Join-Path $Sandbox 'AppData\Local'
$env:APPDATA      = Join-Path $Sandbox 'AppData\Roaming'
$cysDir = Join-Path $env:LOCALAPPDATA 'cys'
$madeKey = $false
try {
    New-Item -ItemType Directory -Force -Path $cysDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs') | Out-Null
    # 공식 제거기 자리와 프로그램 파일 하나를 흉내낸다(내용은 상관없다 — 있는가만 본다).
    if ($State -ne 'entry-no-exe') { Set-Content -Path (Join-Path $cysDir 'uninstall.exe') -Value 'fake' -Encoding ascii }
    Set-Content -Path (Join-Path $cysDir 'cys.exe') -Value 'fake' -Encoding ascii
    # 시작 메뉴 바로가기 잔재도 흉내낸다 — 우리가 지우는 길에서 함께 지워져야 하는 것이다.
    Set-Content -Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\cys.lnk') -Value 'fake' -Encoding ascii
    if ($State -eq 'with-entry' -or $State -eq 'entry-no-exe') {
        New-Item -Path $RegKey -Force | Out-Null
        New-ItemProperty -Path $RegKey -Name 'DisplayName' -Value 'cys' -Force | Out-Null
        # 우리가 만든 것이라는 표. 강제 종료로 finally 를 못 지나가도 다음 실행이 이 표를 보고 치운다.
        New-ItemProperty -Path $RegKey -Name $FixtureMark -Value 1 -Force | Out-Null
        $madeKey = $true
    }
    Write-Host ("  폴더 = " + $cysDir + " · 목록 항목 = " + $(if ($madeKey) { '있음' } else { '없음' }))

    Write-Host '-- 지운다 ---------------------------------------'
    # ⚠파이프로 받지 않는다(자식의 손자가 stdout 을 물면 잡이 멈춘다 · 2026-09-08 러너 실측).
    # ⚠`powershell`(5.1)로 부른다 — 실제 사용자가 밟는 것이 그것이다.
    $log = Join-Path $Sandbox 'reset-clean.out'
    $ps1 = Join-Path $Dir 'reset-clean.ps1'
    $p = Start-Process -FilePath cmd -ArgumentList '/c', "powershell -ExecutionPolicy Bypass -File `"$ps1`" -Yes > `"$log`" 2>&1" -NoNewWindow -PassThru
    if (-not $p.WaitForExit(600000)) {
        Write-Host '::error::지우개가 10분 안에 안 끝났습니다'
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Get-Content $log -ErrorAction SilentlyContinue | Write-Host
    $rc  = $p.ExitCode
    $txt = (Get-Content $log -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
    if (-not $txt) { $txt = '' }
    Write-Host ("지우개 종료 코드 = " + $rc)

    Write-Host '-- 대조 -----------------------------------------'
    $bad = 0
    if ($State -eq 'no-entry') {
        # ★사람에게 할 수 없는 일을 요구하지 않았는가 — 이 축의 존재 이유다.
        if ($txt.Contains('설정 앱에서 지워 주십시오')) { Write-Host '::error::항목이 없는데 설정 앱 제거를 요구했다(교착 재발)'; $bad = 1 }
        if (-not $txt.Contains('설치 목록에는 항목이 없습니다')) { Write-Host '::error::등록 안 된 잔재라고 말하지 않았다'; $bad = 1 }
        if (Test-Path $cysDir) { Write-Host '::error::폴더가 그대로 남았다 — 스스로 지우지 않았다'; $bad = 1 }
        if (Test-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\cys.lnk')) { Write-Host '::error::시작 메뉴 바로가기가 고아로 남았다'; $bad = 1 }
        if ($rc -ne 0) { Write-Host ("::error::rc 가 0 이 아니다(" + $rc + ") — 재설치로 넘어가지 못한다"); $bad = 1 }
    } elseif ($State -eq 'entry-no-exe') {
        # ★말이 사실과 맞는가를 잰다. 항목이 있는데 「항목이 없습니다」라고 적으면, 사람이 설정 앱을 열어
        #   항목을 보는 순간 우리 말이 거짓이 된다(그 한 줄에 나머지 안내의 신뢰가 같이 걸린다).
        if ($txt.Contains('설치 목록에는 항목이 없습니다')) { Write-Host '::error::항목이 있는데 없다고 말했다'; $bad = 1 }
        if (-not $txt.Contains('제거 프로그램이 없습니다')) { Write-Host '::error::까닭(제거 프로그램 부재)을 말하지 않았다'; $bad = 1 }
        if (Test-Path $cysDir) { Write-Host '::error::폴더가 그대로 남았다 — 스스로 지우지 않았다'; $bad = 1 }
        if ($rc -ne 0) { Write-Host ("::error::rc 가 0 이 아니다(" + $rc + ")"); $bad = 1 }
    } else {
        # 등록 항목이 있으면 종전 그대로 — 우리가 억지로 뜯지 않는다.
        if (-not $txt.Contains('설정 앱에서 지워 주십시오')) { Write-Host '::error::항목이 있는데 정식 제거 경로를 안내하지 않았다'; $bad = 1 }
        if (-not (Test-Path $cysDir)) { Write-Host '::error::항목이 있는데 폴더를 억지로 지웠다'; $bad = 1 }
        if ($rc -eq 0) { Write-Host '::error::못 지운 것이 있는데 rc 0 으로 끝났다'; $bad = 1 }
    }
    if ($bad -ne 0) { exit 1 }
    Write-Host '확인: 기대대로입니다.'
    exit 0
} finally {
    if ($madeKey -and (Test-Path $RegKey)) { Remove-Item $RegKey -Recurse -Force -ErrorAction SilentlyContinue }
    $env:USERPROFILE  = $oldUser
    $env:LOCALAPPDATA = $oldLocal
    $env:APPDATA      = $oldApp
}
