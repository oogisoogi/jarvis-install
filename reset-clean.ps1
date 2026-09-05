# 깨끗이 지우기 — 처음 설치하는 상태로 되돌린다
#
# 무엇을 하는가
#   이 컴퓨터에서 자비스 설치 도우미가 놓은 것과 cys·클로드를 모두 지운다.
#   깨끗한 상태에서 설치를 다시 해 보기 위한 것이다.
#
# 쓰는 법
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1
#   powershell -ExecutionPolicy Bypass -File reset-clean.ps1 -WhatIf   무엇을 지울지 보기만 한다
#
# 받아서 바로 돌리는 한 줄 (명령 프롬프트 창에서도 같다)
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://jarvis.godmeyou.kr/install/reset-clean.ps1 -OutFile ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1'); powershell -ExecutionPolicy Bypass -File ([Environment]::GetFolderPath('UserProfile')+'\reset-clean.ps1')"
#   내려받는 자리를 임시 폴더가 아니라 사용자 폴더로 둔 까닭은 설치 도우미와 같다:
#   임시 폴더는 언제든 비워지고, 회사 컴퓨터는 그 자리에서의 실행 자체를 막아 두는 설정이 흔하다.
#   그 설정에 걸리면 지우기 도구조차 못 돌아 아무것도 시작할 수 없다.
#
# 되돌릴 수 없다. 지우기 전에 목록을 보여 주고 한 번 묻는다.
#
# cys 프로그램 자체는 이 스크립트가 지우지 않는다 — 윈도우 설정 앱에서 지우시게 안내한다.
#   왜: 제거 프로그램을 이 스크립트가 직접 띄우면 백신이 그 행위를 막고 PowerShell 을 통째로
#   종료시키는 일이 실제로 있었다(2026-09-05 · V3 · 진단명 Execution/MDP.Powershell.M1201).
#   그때 스크립트는 아무 말도 남기지 못하고 사라지며 아무것도 지워지지 않는다.
#   설정 앱은 사람이 원래 쓰는 길이고, 같은 일을 막히지 않고 한다. 우리는 백신을 피해 가는 것이
#   아니라 원래 길로 되돌린 것이다. (예전 방식이 필요하면 -UseUninstaller 를 붙이면 된다.)
# 창이 갑자기 닫히면 백신이 PowerShell 을 종료한 것일 수 있다. 다시 돌리면 이어서 진행된다.

param([switch]$WhatIf, [switch]$UseUninstaller)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$CysDir     = Join-Path $env:LOCALAPPDATA 'cys'
$UninstExe  = Join-Path $CysDir 'uninstall.exe'
$RegKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\cys'
$JarvisDir  = Join-Path $env:USERPROFILE 'install-jarvis'
$CysHome    = Join-Path $env:USERPROFILE '.cys'
$ClaudeDir  = Join-Path $env:USERPROFILE '.claude'
$ClaudeJson = Join-Path $env:USERPROFILE '.claude.json'
$ClaudeExe  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
# 받아 둔 설치기 사본 — 2026-09-06 부터 사용자 폴더에 받는다.
# 옛 자리(임시 폴더)도 함께 지운다: 그 전에 한 번이라도 돌린 컴퓨터에는 거기에 남아 있다.
$HomePs1    = Join-Path $env:USERPROFILE 'install-jarvis.ps1'
$TempPs1    = Join-Path $env:TEMP 'install-jarvis.ps1'

function Show($label, $path) {
    $mark = if (Test-Path $path) { '있음' } else { '없음' }
    $shown = ([string]$path).Replace($env:USERPROFILE, '~')
    Write-Host ("  [{0}] {1}  {2}" -f $mark, $label, $shown)
}

Write-Host '=== 깨끗이 지우기 — 지울 목록 ==='
Show 'cys 프로그램'            $CysDir
Show 'cys 설치 목록 항목'      $RegKey
Show 'cys 계정 준비(팩·설정)'  $CysHome
Show '클로드 프로그램'         $ClaudeExe
Show '클로드 설정 폴더'        $ClaudeDir
Show '클로드 설정 파일'        $ClaudeJson
Show '자비스 작업 폴더'        $JarvisDir
Show '내려받은 설치 스크립트'      $HomePs1
Show '내려받은 설치 스크립트(옛 자리)' $TempPs1
Write-Host ''
Write-Host '이 일은 되돌릴 수 없습니다.'
Write-Host '로그인 정보도 함께 지워지므로, 다시 설치할 때 로그인을 한 번 더 하셔야 합니다.'
Write-Host ''

if ($WhatIf) { Write-Host '(보기만 했습니다. 아무것도 지우지 않았습니다.)'; exit 0 }

$answer = Read-Host '정말 지우시겠습니까? 지우려면 「지웁니다」 라고 쳐 주십시오'
if ($answer -ne '지웁니다') { Write-Host '아무것도 지우지 않았습니다.'; exit 0 }

Write-Host ''
Write-Host '지우는 중입니다...'

# cys 프로그램 지우기 — 기본은 사람이 설정 앱에서 한다(위 머리글의 이유).
if (Test-Path $UninstExe) {
    if ($UseUninstaller) {
        Write-Host '  cys 제거 프로그램을 실행합니다. (백신이 이 행위를 막을 수 있습니다)'
        try {
            $u = Start-Process -FilePath $UninstExe -ArgumentList '/S' -PassThru -ErrorAction Stop
            if (-not $u.WaitForExit(180000)) {
                Write-Host '    제거 프로그램이 180초 안에 끝나지 않았습니다. 기다리기를 멈추고 나머지를 지웁니다.'
            }
        } catch {
            Write-Host "    제거 프로그램을 실행하지 못했습니다: $($_.Exception.Message)"
            Write-Host '    백신이 막았을 수 있습니다. 그 화면의 이름, 대상 파일, 조치(차단·격리·종료)를 알려 주십시오.'
        }
        Start-Sleep -Seconds 3
    } else {
        Write-Host ''
        Write-Host '  cys 프로그램은 윈도우 설정 앱에서 지워 주십시오 (이 스크립트가 직접 지우지 않습니다).'
        Write-Host '    시작 단추 > 설정 > 앱 > 설치된 앱 > cys > 제거'
        Write-Host '    제거 창이 뜨면 안내대로 진행하시고, 끝나면 이 창으로 돌아오십시오.'
        Write-Host ''
        Read-Host '  제거를 마치셨으면 Enter 를 눌러 주십시오 (건너뛰려면 그냥 Enter)' | Out-Null
    }
}
# cys 가 돌고 있으면 폴더가 지워지지 않는다 — 먼저 멈춘다.
foreach ($n in @('cys-app', 'cysd', 'cys')) {
    Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

foreach ($p in @($CysDir, $CysHome, $ClaudeDir, $JarvisDir)) {
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}
foreach ($f in @($ClaudeJson, $ClaudeExe, $HomePs1, $TempPs1)) {
    if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}
if (Test-Path $RegKey) { Remove-Item $RegKey -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host '=== 남은 것 확인 ==='
Show 'cys 프로그램'            $CysDir
Show 'cys 설치 목록 항목'      $RegKey
Show 'cys 계정 준비(팩·설정)'  $CysHome
Show '클로드 프로그램'         $ClaudeExe
Show '클로드 설정 폴더'        $ClaudeDir
Show '클로드 설정 파일'        $ClaudeJson
Show '자비스 작업 폴더'        $JarvisDir
Show '내려받은 설치 스크립트'      $HomePs1
Show '내려받은 설치 스크립트(옛 자리)' $TempPs1
Write-Host ''
Write-Host '모두 「없음」이면 깨끗한 상태입니다.'
Write-Host '「있음」이 남아 있으면 그 줄을 알려 주십시오. 까닭은 보통 셋 중 하나입니다:'
Write-Host '  · 프로그램이 아직 돌고 있다  · 백신이 그 파일을 붙들고 있다  · cys 제거를 아직 안 하셨다'
