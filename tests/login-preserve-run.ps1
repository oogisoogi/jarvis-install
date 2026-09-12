# 로그인 보존 축 — 윈도우 쪽 실행 입구 (씨앗 → 지우기 → 대조)
#
# ★이 파일이 유일한 입구다. reset-clean.ps1 을 시험 목적으로 직접 부르지 마라.
#
# 🔴왜 입구를 하나로 좁혔는가 (2026-09-08 사고 · 맥에서 났고, 윈도우도 같은 병을 갖고 있다)
#   HOME(윈도우에서는 %USERPROFILE%) 만 바꿔 놓으면 격리된 줄 알기 쉽다. 아니다.
#   제거기가 손대는 자리 가운데 **사용자 폴더를 안 보는 것**이 윈도우에도 있다:
#     · 작업 스케줄러 등록 (`Get-ScheduledTask *cys*` → `Unregister-ScheduledTask`)
#     · 사용자 Path 환경변수 (레지스트리 · 폴더가 아니다)
#     · 돌고 있는 cys 프로세스 강제 종료
#   ⇒ 아래 두 가지는 **환경변수를 갈아 끼워도 격리되지 않는다**(정직하게 적는다):
#       ⑴ 스케줄러 등록  ⑵ 사용자 Path 레지스트리 값
#     그래서 살아 있는 기계에서는 아예 시작하지 않는다. 거절 판정은 `login-seed.py` 안에 있고,
#     이 입구는 **씨앗을 가장 먼저** 부른다 — 씨앗 없이는 잴 것이 없으므로 모든 길이 그 거절을 먼저 지난다.
#
# 쓰는 법
#   pwsh -File tests\login-preserve-run.ps1 -Dir install-master -Sandbox <자리> [-ExpectFail] [-Seeder <경로>]
param(
    [Parameter(Mandatory=$true)][string]$Dir,
    [Parameter(Mandatory=$true)][string]$Sandbox,
    [string]$Seeder = "",
    [string]$ExpectFailAt = "",
    [string]$ExpectCleanerSays = "",
    [switch]$ExpectFail
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Seeder) { $Seeder = Join-Path $here 'login-seed.py' }

if (Test-Path $Sandbox) { Remove-Item $Sandbox -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $Sandbox | Out-Null
$Sandbox = (Resolve-Path $Sandbox).Path

Write-Host '-- 씨앗 -----------------------------------------'
& python "$Seeder" --home "$Sandbox" --os win --jarvis-home (Join-Path $Sandbox 'install-jarvis') --out (Join-Path $Sandbox 'expect.json')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "-- 지운다 (USERPROFILE=$Sandbox) -----------------"
# 자식 프로세스가 물려받는다. LOCALAPPDATA 도 함께 옮긴다 — 제거기의 cys 자리가 거기다.
$oldUser  = $env:USERPROFILE
$oldLocal = $env:LOCALAPPDATA
$env:USERPROFILE = $Sandbox
$env:LOCALAPPDATA = Join-Path $Sandbox 'AppData\Local'
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
try {
    # ⚠`powershell` 로 부른다(pwsh 아님) — 실제 사용자가 밟는 것이 Windows PowerShell 5.1 이고,
    #   왕복 손실·BOM 같은 이 축의 관심사가 정확히 5.1 에서 난다. 7 로 재면 딴 기계를 재는 것이다.
    # ⚠파이프로 받지 않는다. 자식이 띄운 손자가 stdout 을 물고 남으면 `| Out-String` 이 EOF 를
    #   못 받고 잡 전체가 멈춘다(러너 첫 실행 실측 2026-09-08 · 20분+). 출력은 파일로, 기다림은
    #   프로세스 자체에만 걸고 상한을 둔다.
    $log = Join-Path $Sandbox 'reset-clean.out'
    $ps1 = Join-Path $Dir 'reset-clean.ps1'
    $p = Start-Process -FilePath cmd -ArgumentList '/c', "powershell -ExecutionPolicy Bypass -File `"$ps1`" -Yes > `"$log`" 2>&1" -NoNewWindow -PassThru
    if (-not $p.WaitForExit(600000)) {
        Write-Host '::error::지우개가 10분 안에 안 끝났습니다'
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        exit 1
    }
    Get-Content $log -ErrorAction SilentlyContinue | Write-Host
    Write-Host ("지우개 종료 코드 = " + $p.ExitCode)
    # 지우개가 해야 할 말이 지정됐으면 그 말을 했는지 본다 —
    #   「방어가 발화해서 안 고쳤다」와 「그냥 안 돌았다」는 붉어지는 자리가 같아 구별되지 않는다.
    if ($ExpectCleanerSays) {
        $txt = (Get-Content $log -Raw -Encoding UTF8 -ErrorAction SilentlyContinue)
        if ($txt -and $txt.Contains($ExpectCleanerSays)) {
            Write-Host ("지우개가 해야 할 말을 했습니다: " + $ExpectCleanerSays)
        } else {
            Write-Host ("::error::지우개가 이 말을 하지 않았습니다: " + $ExpectCleanerSays)
            exit 1
        }
    }
} finally {
    $env:USERPROFILE = $oldUser
    $env:LOCALAPPDATA = $oldLocal
}

Write-Host '-- 대조 -----------------------------------------'
$args2 = @("$here\login-verify.py", '--home', $Sandbox, '--expect', (Join-Path $Sandbox 'expect.json'))
if ($ExpectFail) { $args2 += '--expect-fail' }
if ($ExpectFailAt) { $args2 += @('--expect-fail-at', $ExpectFailAt) }
& python @args2
exit $LASTEXITCODE
