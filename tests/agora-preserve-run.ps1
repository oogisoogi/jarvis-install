# 토론장 참가 자리 보존 축 - 윈도우 쪽 실행 입구 (씨앗 -> 지우기 -> 대조)
#
# ★이 파일이 유일한 입구다. 시험 목적으로 reset-clean.ps1 을 직접 부르지 마라.
#   거절 판정은 씨앗(agora-preserve.py -> login-seed.py) 안에 있고 이 입구는 씨앗을 가장 먼저 부른다.
#   왜 거절하는가는 login-preserve-run.ps1 머리말과 같다(스케줄러 등록·사용자 Path 는 환경변수로 격리되지 않는다).
#
# 쓰는 법
#   pwsh -File tests\agora-preserve-run.ps1 -Dir install-master -Sandbox <자리> [-ExpectFail]
#                                            [-Shape plain|dotseg|symlink] [-OutsideLink]
#                                            [-LinkInSubdir] [-DanglingLink] [-StaleOut] [-Unreadable]
#                                            [-ExpectCysKept] [-ExpectPartial] [-ExpectClean]
#                                            [-Chain N] [-ExpectCleanerSays <문구>]
#   -ExpectCleanerSays = -ExpectCysKept 와 **짝**이다. 그 갈래만 찍는 문구를 화면에서 확인한다 —
#                        종료값만 보면 「아무것도 안 하고 exit 7」 하는 가짜 지우개도 통과한다.
#   -OutsideLink = 삭제 루트 안에 바깥 폴더를 가리키는 링크(junction·symlink)를 놓는다.
#                  지우개는 링크만 지우고 바깥 폴더·파일은 바이트 그대로 남겨야 한다.
#                  ⚠5.1 이 링크를 뚫는지는 **판본에 따라 다르다**(2026-09-09 러너 실측: 그 러너의
#                  `Remove-Item -Recurse` 는 junction 을 안 뚫었다). 본체 축은 「뚫었는가」가 아니라
#                  **「열거하지 못한 자리를 지웠는가」**다 — 그쪽은 판본과 무관하다.
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [Parameter(Mandatory=$true)][string]$Sandbox,
    [switch]$ExpectFail,
    [switch]$OutsideLink,
    [switch]$LinkInSubdir,
    [switch]$DanglingLink,
    [switch]$RootLink,
    [int]$Chain = 0,
    [string]$ExpectCleanerSays = '',
    [switch]$StaleOut,
    [switch]$Unreadable,
    [switch]$ExpectCysKept,
    [switch]$ExpectPartial,
    [switch]$ExpectClean,
    [ValidateSet('plain','dotseg','symlink')][string]$Shape = 'plain'
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

if (Test-Path $Sandbox) { Remove-Item $Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $Sandbox | Out-Null
$Sandbox = (Resolve-Path $Sandbox).Path

Write-Host '-- 씨앗 (중첩 설정: AGORA_HOME 을 삭제 루트 안에 둔다) --'
$seedArgs = @((Join-Path $here 'agora-preserve.py'), 'seed', '--home', $Sandbox, '--os', 'win', '--shape', $Shape)
if ($OutsideLink)   { $seedArgs += '--outside-link' }
if ($LinkInSubdir)  { $seedArgs += '--link-in-subdir' }
if ($DanglingLink)  { $seedArgs += '--dangling-link' }
if ($RootLink)      { $seedArgs += '--root-link' }
if ($Chain -gt 0)   { $seedArgs += @('--chain', "$Chain") }
if ($StaleOut)      { $seedArgs += '--stale-out' }
if ($Unreadable)    { $seedArgs += '--unreadable' }
& python @seedArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "-- 지운다 (USERPROFILE=$Sandbox) -----------------"
$oldUser  = $env:USERPROFILE
$oldLocal = $env:LOCALAPPDATA
$oldAgora = $env:AGORA_HOME
$env:USERPROFILE = $Sandbox
$env:LOCALAPPDATA = Join-Path $Sandbox 'AppData\Local'
# ★이것이 이 축의 전부다 - 참가 자리를 삭제 루트(.cys) 안에 둔 설정으로 돌린다.
#   씨앗이 「이 모양으로 넘기라」고 적어 준 값을 그대로 넘긴다(같은 곳을 가리키되 글자가 다르다).
$expectJson = Get-Content -LiteralPath (Join-Path $Sandbox 'agora-expect.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$env:AGORA_HOME = $expectJson.handed
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
try {
    # 실제 사용자가 밟는 것이 Windows PowerShell 5.1 이므로 powershell 로 부른다(pwsh 아님).
    # 파이프로 받지 않는다 - 손자 프로세스가 stdout 을 물면 잡이 멈춘다(2026-09-08 실측).
    $log = Join-Path $Sandbox 'reset-clean.out'
    $ps1 = Join-Path $Dir 'reset-clean.ps1'
    $p = Start-Process -FilePath cmd -ArgumentList '/c', "powershell -ExecutionPolicy Bypass -File `"$ps1`" -Yes > `"$log`" 2>&1" -NoNewWindow -PassThru
    if (-not $p.WaitForExit(600000)) {
        Write-Host '::error::지우개가 10분 안에 안 끝났습니다'
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Get-Content $log -ErrorAction SilentlyContinue | Write-Host
    $cleanerRc = $p.ExitCode
    Write-Host ("지우개 종료 코드 = " + $cleanerRc)
} finally {
    $env:USERPROFILE = $oldUser
    $env:LOCALAPPDATA = $oldLocal
    $env:AGORA_HOME = $oldAgora
}

# 심어 둔 「못 여는 자리」의 거부 ACE 를 걷어 낸다 - 안 그러면 다음 실행이 이 자리를 못 치운다.
if ($Unreadable) {
    $ex = Get-Content -LiteralPath (Join-Path $Sandbox 'agora-expect.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($ex.unreadable) { & icacls $ex.unreadable /remove:d $env:USERNAME | Out-Null }
}
# ★「지웠다」가 아니라 「일부 남음」이라고 말했는가 - 실패를 주입한 실행에서만 본다.
if ($ExpectPartial) {
    # 🔴**정확히 7** 이어야 한다(6차 지적 채택) - 「0 만 아니면 통과」는 다른 까닭으로 죽은 실행도 통과시킨다.
    if ($cleanerRc -ne 7) {
        Write-Host ("::error::「일부 남음」 실행의 종료값은 7 이어야 하는데 " + $cleanerRc + " 다")
        exit 1
    }
    if (-not (Select-String -LiteralPath $log -Pattern '일부 남음' -Quiet)) {
        Write-Host '::error::비영으로 끝나긴 했으나 화면에 「일부 남음」이 없다'
        exit 1
    }
    Write-Host ("지우개가 실패를 실패라고 말했습니다(종료 코드 " + $cleanerRc + " · 화면에 「일부 남음」).")
}
# ★반대쪽도 잰다 - 깨끗이 끝났어야 하는데 [남음]이 나는 것도 결함이다.
if ($ExpectClean) {
    if ($cleanerRc -ne 0) {
        Write-Host ("::error::깨끗이 끝났어야 하는 실행인데 지우개가 " + $cleanerRc + " 로 끝났다")
        exit 1
    }
    Write-Host '지우개가 0 으로 끝났습니다(못 지운 것 없음).'
}

# 🔴「원본이 그대로다」만으로는 부족하다 - 지우개가 시작하자마자 죽어도 원본은 그대로다.
if ($ExpectCysKept) {
    # 🔴🔴종료값만으로 「그 갈래가 돌았다」고 말하지 마라(7차 지적 채택) - 아무것도 안 하고 exit 7 만
    #   하는 가짜 지우개도 통과했다. 그 갈래만 찍는 문구를 함께 본다. 문구가 없으면 축을 거절한다.
    if (-not $ExpectCleanerSays) {
        Write-Host '::error::-ExpectCysKept 에는 -ExpectCleanerSays <그 갈래만 찍는 문구> 가 함께 있어야 한다'
        exit 2
    }
    if ($cleanerRc -ne 7) {
        Write-Host ("::error::fail-closed 로 멈춘 실행의 종료값은 7 이어야 하는데 " + $cleanerRc + " 다(그 갈래가 안 돌았을 수 있다)")
        exit 1
    }
    if (-not (Select-String -LiteralPath $log -Pattern ([regex]::Escape($ExpectCleanerSays)) -Quiet)) {
        Write-Host ("::error::지우개가 그 갈래의 말을 안 했다(찾던 문구: " + $ExpectCleanerSays + ")")
        exit 1
    }
    Write-Host ("fail-closed 갈래가 실제로 돌았습니다(종료 코드 7 · 화면에 「" + $ExpectCleanerSays + "」).")
}

Write-Host '-- 대조 (열쇠 바이트 · 나머지 삭제 · 안내 이전) --'
$args2 = @((Join-Path $here 'agora-preserve.py'), 'verify', '--home', $Sandbox)
if ($ExpectFail)     { $args2 += '--expect-fail' }
if ($ExpectCysKept)  { $args2 += '--expect-cys-kept' }
& python @args2
exit $LASTEXITCODE
