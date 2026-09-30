# 0.3.38 윈 설치기 결함 묶음 — 실제 cys 설치 파일(NSIS)로 재는 러너 시험(윈도우 러너 전용 · 사람 기기에서 돌리지 않는다)
#   흉내 시험(tests/defect-0930-run.sh)이 못 재는 것 = 실제 설치 파일이 우리가 준 자리(/D)에 까는가 · 옛 기억 값을 이기는가 · 마법사 0.
#   칸(-Case):
#     laptop-0930     2026-09-30 노트북 상태 = 설치 자리 기억 값(HKCU\Software\cysjavis\cys 기본값)이 쓸 수 없는 자리(없는 드라이브)를
#                     가리킨 채 남아 있음 · 설치 목록(Uninstall\cys · \cysr) 없음 · %LOCALAPPDATA%\cys-old 있음
#     stale-uninstall 설치 목록 Uninstall\cysr 만 남아 없는 폴더를 가리킴
#     raw-no-d        대조군(판정에 안 씀): 같은 laptop-0930 상태에서 설치 파일을 /S 만으로 돌려 어디에 까는지 적는다
#   기대(laptop-0930 · stale-uninstall) = 우리 설치기 [5/10]~[7/10] 이 전부 0 · %LOCALAPPDATA%\cys 에 cys.exe · cysd.exe · cys-app.exe ·
#     cys.exe 판 3자리 = 설치기의 핀 판 · 설치 기록에 「/S /D=<%LOCALAPPDATA%\cys>」 · cys-old 그대로.
#   ⚠러너는 관리자 권한이라 「표준 사용자가 C:\Users 아래 폴더를 못 만듦」 자체는 재현하지 못한다 — 그래서 기억 값을 없는 드라이브로 둔다.
param([Parameter(Mandatory = $true)][ValidateSet('laptop-0930', 'stale-uninstall', 'raw-no-d')][string]$Case)
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$script:Pass = 0; $script:Fail = 0
function T([bool]$ok, [string]$name, [string]$why) {
    if ($ok) { $script:Pass++; Write-Host ('  ok   ' + $name) } else { $script:Fail++; Write-Host ('  FAIL ' + $name + '  <- ' + $why); Write-Host ('::error::' + $name + ' <- ' + $why) }
}
$L = $env:LOCALAPPDATA
$dest = Join-Path $L 'cys'
$old = Join-Path $L 'cys-old'
$unKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'

# ── 상태 심기 ──────────────────────────────────────────────
$drive = ''
foreach ($c in @('Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')) { if (-not (Test-Path -LiteralPath ($c + ':\'))) { $drive = $c; break } }
if (-not $drive) { Write-Host '::error::없는 드라이브 문자를 찾지 못했다'; exit 2 }
$memo = $drive + ':\cys'
if (Test-Path -LiteralPath $dest) { Write-Host "::error::시작 전에 $dest 가 이미 있다(깨끗한 러너가 아니다)"; exit 2 }
foreach ($n in @('cys', 'cysr')) { Remove-Item -LiteralPath (Join-Path $unKey $n) -Recurse -Force -ErrorAction SilentlyContinue }
if ($Case -ne 'stale-uninstall') {
    New-Item -Path 'HKCU:\Software\cysjavis\cys' -Force | Out-Null
    Set-ItemProperty -LiteralPath 'HKCU:\Software\cysjavis\cys' -Name '(default)' -Value $memo
    New-Item -ItemType Directory -Force -Path $old | Out-Null
    foreach ($n in @('cys.exe', 'cysd.exe')) { Set-Content -LiteralPath (Join-Path $old $n) -Value 'old' -NoNewline }
} else {
    $gone = Join-Path $env:SystemDrive 'gone-0930\cysr'
    New-Item -Path (Join-Path $unKey 'cysr') -Force | Out-Null
    Set-ItemProperty -LiteralPath (Join-Path $unKey 'cysr') -Name 'DisplayName' -Value 'cysr'
    Set-ItemProperty -LiteralPath (Join-Path $unKey 'cysr') -Name 'DisplayVersion' -Value '1.1.5'
    Set-ItemProperty -LiteralPath (Join-Path $unKey 'cysr') -Name 'InstallLocation' -Value ('"' + $gone + '"')
}
Write-Host ('심은 상태: 기억 값=' + $(if ($Case -ne 'stale-uninstall') { $memo } else { '(없음)' }) + ' · 설치 목록=' + (@(Get-ChildItem $unKey | Where-Object { $_.PSChildName -in @('cys', 'cysr') } | ForEach-Object { $_.PSChildName }) -join ',') + ' · cys-old=' + (Test-Path $old))

# ── 설치기 함수 묶음 읽기(바깥 전송은 닫힌 로컬 주소로) ──────────────────
$env:JARVIS_LIB_ONLY = '1'
. (Join-Path $root 'install-master\bootstrap.ps1')
$env:JARVIS_LIB_ONLY = ''
$Mode = 'full'
function Show-Ver($p) { try { $v = (Get-Item -LiteralPath $p -ErrorAction Stop).VersionInfo; return ([string]$v.ProductVersion + ' / ' + [string]$v.FileVersion) } catch { return '(못 읽음)' } }

if ($Case -eq 'raw-no-d') {
    # 대조군 — 우리 설치기와 같은 핀 설치 파일을 받아 /S 만으로 돌린다(판정 0 · 기록만)
    $r5 = Step-DownloadCys
    $exe = Join-Path $DlDir $CysWinFile
    Write-Host ('[대조군] 받기 rc=' + $r5 + ' · 파일=' + (Test-Path -LiteralPath $exe))
    $p = Start-Process -FilePath $exe -ArgumentList '/S' -PassThru
    $done = $p.WaitForExit(240000)
    if (-not $done) { try { $p.Kill() } catch { } }
    Write-Host ('[대조군] /S 만 · 끝남=' + $done + ' · 종료 코드=' + $(if ($done) { $p.ExitCode } else { '-' }))
    Write-Host ('[대조군] %LOCALAPPDATA%\cys 의 cys.exe=' + (Test-Path (Join-Path $dest 'cys.exe')) + ' · 판=' + (Show-Ver (Join-Path $dest 'cys.exe')))
    foreach ($n in @('cys', 'cysr')) {
        $k = Join-Path $unKey $n
        if (Test-Path $k) { Write-Host ('[대조군] 설치 목록 ' + $n + ' InstallLocation=' + (Get-ItemProperty $k).InstallLocation) }
    }
    try { Write-Host ('[대조군] 기억 값 뒤=' + (Get-ItemProperty 'HKCU:\Software\cysjavis\cys').'(default)') } catch { }
    exit 0
}

$r5 = Step-DownloadCys
$r6 = Step-InstallCys
$r7 = Step-VerifyCys
T (($r5 -eq 0) -and ($r6 -eq 0) -and ($r7 -eq 0)) '[5/10]~[7/10] 전부 0' ('r5=' + $r5 + ' r6=' + $r6 + ' r7=' + $r7 + ' j=' + $script:JCode)
$miss = @(@('cys.exe', 'cysd.exe', 'cys-app.exe') | Where-Object { -not (Test-Path -LiteralPath (Join-Path $dest $_)) })
T ($miss.Count -eq 0) '설치 자리(%LOCALAPPDATA%\cys)에 실행 파일 3종' ('없음=' + ($miss -join ','))
$ver = Show-Ver (Join-Path $dest 'cys.exe')
$v3 = ([regex]::Match($ver, '\d+\.\d+\.\d+')).Value
T ($v3 -eq $CysVersion) ('cys.exe 판 3자리 = ' + $CysVersion) ('판=' + $ver)
$log = ''
try { $log = Get-Content -LiteralPath $LogFile -Raw -ErrorAction Stop } catch { $log = '' }
T ($log.Contains('cys install target (/D) = ' + (Redact $dest))) '설치 파일에 준 자리 = %LOCALAPPDATA%\cys (기록의 /D 줄)' ('기록에 /D 줄 없음 또는 다른 자리')
# 마법사 0 = 조용한 설치(/S)가 상한 안에 끝났다는 뜻 — 창이 떴다면 러너에는 누를 사람이 없어 [6/10] 이 상한에 닿아 0 이 아니다(위 칸).
if ($Case -eq 'laptop-0930') {
    T ((Test-Path (Join-Path $old 'cys.exe')) -and ((Get-Content -LiteralPath (Join-Path $old 'cys.exe') -Raw) -eq 'old')) 'cys-old 는 그대로' 'cys-old 가 바뀌었다'
}
foreach ($n in @('cys', 'cysr')) {
    $k = Join-Path $unKey $n
    if (Test-Path $k) { Write-Host ('설치 목록 ' + $n + ' 뒤: InstallLocation=' + (Get-ItemProperty $k).InstallLocation + ' · 판=' + (Get-ItemProperty $k).DisplayVersion) }
}
try { Write-Host ('기억 값 뒤=' + (Get-ItemProperty 'HKCU:\Software\cysjavis\cys' -ErrorAction Stop).'(default)') } catch { Write-Host '기억 값 뒤=(없음)' }
Write-Host ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0
