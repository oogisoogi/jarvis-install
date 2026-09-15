# 재설치 안의 「powershell -File reset-clean.ps1 …」 한 번을 받는 자식 호스트 (pwsh 7 · 맥) — 실물 지우개를 스위치 그대로 부르고 종료 코드를 넘긴다
#   ⚠문자열 '-KeepApp' 를 배열로 펼쳐 넘기면 스크립트 스위치에 안 묶인다 — 이름표 묶음(@{KeepApp=$true})으로 펼친다
param([string]$Target, [string]$Log, [string]$Switches, [string]$Sb)
$ErrorActionPreference = 'Continue'
$h = @{}
foreach ($n in ($Switches -split ',')) { if ($n) { $h[$n] = $true } }

# ── 윈도우 모양 경로 흉내 ──
#   지우개의 Drop 은 「D:\…」·「\\서버」 모양만 파일 자리로 받는다(맥 경로 /… 는 [남음] 으로 끝난다) — 그래서 USERPROFILE = C:\Users\emu 로 둔다.
#   C: 드라이브 = 샌드박스의 「cdrv」(→ 「C:」 폴더를 가리키는 링크) · 드라이브 뿌리 이름에 「:」 가 들면 pwsh 가 경로를 못 푼다(실측).
#   작업 자리 = 샌드박스 — Canon-Path 의 GetFullPath('C:\…') 가 「<작업 자리>/C:\…」 로 풀려 실제 「C:」 폴더에 닿는다(링크를 안 거친다).
New-PSDrive -Name C -PSProvider FileSystem -Root "$Sb/cdrv" -Scope Global | Out-Null
[Environment]::CurrentDirectory = $Sb
# 설치 목록 항목(HKCU:\…\Uninstall\cys) = 샌드박스 폴더 — 설치가 끝난 윈도우 기계에는 이 항목이 있다(뮤턴트가 설정 앱 갈래를 타게 한다)
New-PSDrive -Name HKCU -PSProvider FileSystem -Root "$Sb/reg" -Scope Global | Out-Null
# 진짜 cys·claude 를 PATH 에서 못 찾게 한다 — Get-CysCmd 가 제자리 가짜(cys.exe)를 못 찾는 변이에서도 실물 「cys daemon uninstall」 이 불리지 않게
$env:PATH = '/usr/bin:/bin'

# ── 바꿔 끼우는 것 (지우개가 정의하지 않는 명령만 — 지우개 안의 함수는 덮이지 않는다) ──
# 사람에게 묻는 자리 = 기록하고 빈 답 — 멈추지 않고 「물었다」가 남는다
function Read-Host {
    param([Parameter(Position = 0)] $Prompt, [switch]$AsSecureString)
    Add-Content -LiteralPath $Log -Value ([string]$Prompt)
    return ''
}
# 🔴끄기 = 기록만 — 지우개는 이름(cys-app · cysd · cys)으로 Stop-Process -Force 한다(reset-clean.ps1 Stop-CysProcesses).
#   이 맥에서 도는 cys 터미널 프로세스 이름이 정확히 그것이라 실물을 부르면 시험을 돌린 창이 꺼진다.
function Stop-Process {
    [CmdletBinding()] param([Parameter(ValueFromPipeline = $true)] $InputObject, [int[]]$Id, [switch]$Force)
    process {
        $what = if ($InputObject) { [string]$InputObject.ProcessName + '#' + $InputObject.Id } else { 'id ' + ($Id -join ',') }
        Add-Content -LiteralPath "$Sb/stop-process.log" -Value ('would-stop ' + $what)
    }
}

& $Target @h
$rc = $LASTEXITCODE
if ($null -eq $rc) { $rc = 0 }
exit $rc
