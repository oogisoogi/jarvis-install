# ⓐⓒ [6/10] Step-InstallCys — 이어 갑니다 삭제 · 마법사 폴백 삭제 · /D 한 문자열 · 끝 확인 두 갈래 · 건너뛰기 3파일 (설계 DESIGN-defect-0930 3절 ⓐ·ⓑ·ⓒ)
param([string]$Src, [string]$Sb, [string]$Case)
. (Join-Path $PSScriptRoot 'lib.ps1') -Src $Src -Sb $Sb
$L = $env:LOCALAPPDATA
$script:Calls = New-Object System.Collections.ArrayList   # 설치기 실행 기록(인자 원문)
$script:InstallerDoes = { param($argLine) }                 # 칸마다 바꾼다: 가짜 설치기가 할 일
$script:InstallerExit = 0
function Start-Process {
    param($FilePath, $ArgumentList, [switch]$PassThru, [switch]$Wait, [switch]$NoNewWindow, $ErrorAction)
    $line = if ($null -eq $ArgumentList) { '' } elseif ($ArgumentList -is [array]) { '<ARRAY>' + ($ArgumentList -join '|') } else { [string]$ArgumentList }
    [void]$script:Calls.Add($line)
    & $script:InstallerDoes $line
    $ex = $script:InstallerExit
    $o = [pscustomobject]@{ HasExited = $true; ExitCode = $ex }
    $o | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($ms) $true }
    return $o
}
function Start-Sleep { }
$script:Said = New-Object System.Collections.ArrayList
function Say($t) { [void]$script:Said.Add([string]$t) }
function Write-JCode($c, $w) { $script:JCode = $c; [void]$script:Said.Add('JCODE ' + $c) }
function Save-CysPinStamp($b) { $script:Stamped = $true; return $true }
$Mode = 'full'; $script:Stamped = $false; $script:ShowRerun = $false
New-Item -ItemType Directory -Force -Path $DlDir | Out-Null
Set-Content -Path (Join-Path $DlDir $CysWinFile) -Value 'setup' -NoNewline
function Said-All { $script:Said -join ' | ' }
# 설치 자리 기억(HKCU\Software\cysjavis\cys 기본값) — 레지스트리 읽기·지우기만 가짜로 준다(판정은 실물 함수)
$script:Mem = $null; $script:MemRemoved = 0
function Get-CysInstallMemory { return $script:Mem }
function Remove-CysInstallMemory { $script:MemRemoved++ }
function Log-All { try { Get-Content -LiteralPath $LogFile -Raw -ErrorAction Stop } catch { '' } }
switch ($Case) {
    'upgrade-fail' {
        # 노트북 모양: 옛 0.14.29 가 %LOCALAPPDATA%\cys · 가짜 설치기 = 등록만 쓰고 파일 0 · 종료 4
        Put-Bins (Join-Path $L 'cys') '0.14.29' @('cys.exe', 'cysd.exe')
        $script:InstallerExit = 4
        $script:InstallerDoes = { param($a) $script:FakeUninstall = @((Entry 'cysr' '1.1.6' '"C:\Users\cys"')) }
        $rc = @(Step-InstallCys)[-1]; $s = Said-All
        T ($rc -eq 6) 'ⓐ 판올림 실패 = rc 6(이어 가지 않음)' ('rc=' + $rc + ' · ' + $s)
        T (($s -notmatch '이어 갑니다') -and ($s -notmatch '제거하지 않음')) 'ⓐ 「이어 갑니다」 · 「제거하지 않음」 안내 0' $s
        T (($s -match '프로그램을 넣지 못했습니다') -and ($s -match '쓰시던 프로그램은 그대로 남아 있습니다') -and ($s -match 'JCODE J-CYS-01')) 'ⓐ 한 문장 + 쓰시던 파일 실재 → 남아 있다는 말 + J-CYS-01' $s
        T (-not $script:ShowRerun) 'ⓐ 다시 하시는 법 깃발 0(다음 할 일 = 원격 해결 하나)' ('ShowRerun=' + $script:ShowRerun)
    }
    'first-fail-no-wizard' {
        # 빈 기기 · 조용한 설치 실패 → 설치 창(마법사)을 띄우지 않는다
        $script:InstallerExit = 2
        $rc = @(Step-InstallCys)[-1]; $s = Said-All
        T (($script:Calls.Count -eq 1) -and ($rc -eq 6)) 'ⓒ 조용한 설치 실패 뒤 설치 창 폴백 0 · rc 6' ('calls=' + ($script:Calls -join ' ; ') + ' rc=' + $rc)
        T (($s -notmatch '설치 창을 띄웁니다') -and ($s -notmatch '쓰시던 프로그램')) 'ⓒ 마법사 안내 0 · 쓰시던 파일 없으면 남아 있다는 말 0' $s
    }
    'd-arg' {
        # 인자 = 한 문자열 「/S /D=<자리>」 · 따옴표 0 · 공백 든 자리도 그대로 · 성공하면 rc 0
        $env:LOCALAPPDATA = (Join-Path $Sb 'Local Data'); New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
        $want = Join-Path $env:LOCALAPPDATA 'cys'
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6'; $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + (Join-Path $env:LOCALAPPDATA 'cys') + '"'))) }
        $rc = @(Step-InstallCys)[-1]
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + $want)) 'ⓒ 설치 인자 = 한 문자열 /S /D=<%LOCALAPPDATA%\cys>(공백 자리 · 따옴표 0)' ('arg=[' + $a0 + ']')
        T ($rc -eq 0) 'ⓒ /D 자리에 파일 셋 + 판 1.1.6 → 설치를 마쳤습니다 rc 0' ('rc=' + $rc + ' · ' + (Said-All))
    }
    'd-cysr-elsewhere' {
        # 사용자가 다른 폴더에 제대로 깐 cysr(1.1.5) → /D = 그 폴더 · 옛 0.14 가 ProgramFiles\cys 에만 있으면 /D = %LOCALAPPDATA%\cys
        $d = Join-Path $Sb 'apps/cysr'; Put-Bins $d '1.1.5'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.5' ('"' + $d + '"')))
        $script:InstallerDoes = { param($a) }
        [void](Step-InstallCys)
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + (Resolve-Path $d).Path)) 'ⓒ /D = cysr 항목이 가리키고 파일 셋이 있는 폴더(두 번째 설치 방지)' ('arg=[' + $a0 + ']')
    }
    'd-cysr-partial' {
        # cysr 항목이 가리키는 폴더에 cys.exe 만 있다(파일 셋 아님) → 그 폴더를 설치 자리로 이어 쓰지 않는다 · /D = %LOCALAPPDATA%\cys
        $d = Join-Path $Sb 'apps/cysr'; Put-Bins $d '1.1.5' @('cys.exe')
        $script:FakeUninstall = @((Entry 'cysr' '1.1.5' ('"' + $d + '"')))
        [void](Step-InstallCys)
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + (Join-Path $L 'cys'))) 'ⓑⓒ cysr 항목 폴더에 파일 셋이 없으면 /D = %LOCALAPPDATA%\cys' ('arg=[' + $a0 + ']')
    }
    'd-cysr-gone-fixed' {
        # cysr 항목은 빈 폴더를 가리키고, 본체는 고정 후보(Programs\cys)에서 찾았다 → 그 고정 후보를 /D 로 이어 쓰지 않는다 · /D = %LOCALAPPDATA%\cys
        $gone = Join-Path $Sb 'apps/cysr-gone'; New-Item -ItemType Directory -Force -Path $gone | Out-Null
        Put-Bins (Join-Path $L 'Programs/cys') '1.1.5'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.5' ('"' + $gone + '"')))
        [void](Step-InstallCys)
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + (Join-Path $L 'cys'))) 'ⓑⓒ cysr 항목 폴더 ≠ 본체 폴더(고정 후보) → /D = %LOCALAPPDATA%\cys' ('arg=[' + $a0 + ']')
    }
    'install-partial' {
        # 설치기는 끝났는데 창 실행 파일(cys-app.exe)이 안 생김 → 「설치를 마쳤습니다」 0 · 지문 저장 0 · rc 6
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' @('cys.exe', 'cysd.exe') }
        $rc = @(Step-InstallCys)[-1]
        T (($rc -eq 6) -and (-not $script:Stamped) -and ((Said-All) -notmatch '설치를 마쳤습니다')) 'ⓐ 설치 뒤 파일 셋이 다 없으면 완료 아님 → rc 6' ('rc=' + $rc + ' stamped=' + $script:Stamped + ' · ' + (Said-All))
    }
    'd-oldpf' {
        Put-Bins (Join-Path $env:ProgramFiles 'cys') '0.14.29' @('cys.exe', 'cysd.exe')
        $script:FakeUninstall = @((Entry 'cys' '0.14.29' ('"' + (Join-Path $env:ProgramFiles 'cys') + '"')))
        [void](Step-InstallCys)
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + (Join-Path $L 'cys'))) 'ⓒ 옛 0.14 가 ProgramFiles\cys → /D = %LOCALAPPDATA%\cys(권한 불요 · 상태 폴더)' ('arg=[' + $a0 + ']')
    }
    'd-localcysr' {
        $d = Join-Path $L 'cysr'; Put-Bins $d '1.1.5'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.5' ('"' + $d + '"')))
        [void](Step-InstallCys)
        $a0 = if ($script:Calls.Count) { $script:Calls[0] } else { '' }
        T ($a0 -ceq ('/S /D=' + (Join-Path $L 'cys'))) 'ⓒ cysr 항목 = %LOCALAPPDATA%\cysr → /D = %LOCALAPPDATA%\cys(훅이 그 값을 옮기므로)' ('arg=[' + $a0 + ']')
    }
    'refresh-fail' {
        # 같은 판 덮어 깔기: 파일은 이미 1.1.6 · 지문 표지 없음 · 가짜 설치기 비0 → 설치를 마쳤습니다 · 지문 저장 0 · rc 6
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        $script:InstallerExit = 5
        $rc = @(Step-InstallCys)[-1]
        T (($rc -eq 6) -and (-not $script:Stamped)) 'ⓑ 같은 판 덮어 깔기 + 설치기 비0 종료 → 거짓 성공·지문 저장 0 · rc 6' ('rc=' + $rc + ' stamped=' + $script:Stamped + ' · ' + (Said-All))
    }
    'skip-missing-app' {
        # 지문 일치 · 판 같음 · 그러나 cys-app.exe 가 없다 → 건너뛰지 않고 다시 깐다 · 사유 문구 = 파일 일부 없음
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6' @('cys.exe', 'cysd.exe')
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        function Get-CysContentState($b) { return 'match' }
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        $rc = @(Step-InstallCys)[-1]; $s = Said-All
        T (($script:Calls.Count -eq 1) -and ($s -match '창을 여는 파일') -and ($s -notmatch '건너뜁니다')) 'ⓑ 지문 일치여도 cys-app.exe 없으면 다시 설치 · 사유 = 파일 일부 없음' ('calls=' + $script:Calls.Count + ' · ' + $s)
    }
    'mem-stale-removed' {
        # 09-30 노트북 뒤처리: 기억 값 = 없는 드라이브(Q:\cys) · 설치 성공 → \cys 키를 지우고 지우기 전 값을 기록에 1줄
        $script:Mem = 'Q:\cys'
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        $rc = @(Step-InstallCys)[-1]; $lg = Log-All
        T (($rc -eq 0) -and ($script:MemRemoved -eq 1)) '⑵ 설치 성공 + 기억 값이 다른 자리·cys.exe 없음(없는 드라이브) → \cys 키 지움' ('rc=' + $rc + ' removed=' + $script:MemRemoved)
        T ($lg -match [regex]::Escape('was=Q:\cys')) '⑵ 지우기 전 값을 설치 기록에 1줄(되돌리기용)' $lg
    }
    'mem-gone-dir-removed' {
        # 기억 값 = 있는 드라이브의 없는 폴더 → 지움
        $script:Mem = '"' + (Join-Path $Sb 'nowhere/cys') + '"'
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        [void](Step-InstallCys)
        T ($script:MemRemoved -eq 1) '⑵ 기억 값 = 없는 폴더(따옴표 든 값) → 지움' ('removed=' + $script:MemRemoved)
    }
    'mem-same-kept' {
        # 기억 값 = 실제 설치 자리(끝 역슬래시·대소문자 차이) → 지우지 않는다
        $script:Mem = (Join-Path $L 'CYS') + '/'
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        [void](Step-InstallCys); $lg = Log-All
        T (($script:MemRemoved -eq 0) -and ($lg -notmatch 'install memory')) '⑵ 기억 값 = 설치 자리 → 그대로 · 기록 0(같은 자리는 살피지도 않는다)' ('removed=' + $script:MemRemoved + ' · ' + $lg)
    }
    'mem-exe-kept' {
        # 기억 값이 다른 자리지만 그 자리에 cys.exe 가 있다 → 지우지 않는다
        $o = Join-Path $Sb 'other/cys'; Put-Bins $o '1.1.5' @('cys.exe')
        $script:Mem = $o
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        [void](Step-InstallCys)
        T ($script:MemRemoved -eq 0) '⑵ 기억 값 자리에 cys.exe 있음 → 그대로' ('removed=' + $script:MemRemoved)
    }
    'mem-unread-kept' {
        # 기억 값 자리를 못 읽는다(권한) → 「없음」이 아니므로 지우지 않는다 · 기록 1줄
        $o = Join-Path $Sb 'locked/cys'; Put-Bins $o '1.1.5' @('cys.exe')
        & chmod 000 $o
        $script:Mem = $o
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        [void](Step-InstallCys); $lg = Log-All
        & chmod 755 $o
        T (($script:MemRemoved -eq 0) -and ($lg -match 'unread')) '⑵ 기억 값 자리를 못 읽음 → 그대로 · 기록에 못 읽음' ('removed=' + $script:MemRemoved + ' · ' + $lg)
    }
    'mem-none' {
        # 기억 키 없음 · 빈 기본값 → 아무것도 지우지 않는다
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        [void](Step-InstallCys)
        $script:Mem = ''; $script:Calls.Clear(); Remove-Item -Recurse -Force (Join-Path $L 'cys')
        [void](Step-InstallCys)
        T ($script:MemRemoved -eq 0) '⑵ 기억 키 없음·빈 값 → 지우기 0' ('removed=' + $script:MemRemoved)
    }
    'mem-fail-kept' {
        # 설치 실패 → 기억 값을 건드리지 않는다
        $script:Mem = 'Q:\cys'; $script:InstallerExit = 2
        $rc = @(Step-InstallCys)[-1]
        T (($rc -eq 6) -and ($script:MemRemoved -eq 0)) '⑵ 설치 실패면 기억 값 무접촉' ('rc=' + $rc + ' removed=' + $script:MemRemoved)
    }
    'mem-skip-removed' {
        # 같은 판·지문 일치로 [6/10] 건너뜀(이미 %LOCALAPPDATA%\cys 에 성공 설치된 노트북 재실행) + 옛 기억 값 → 지움
        $d = Join-Path $L 'cys'; Put-Bins $d '1.1.6'
        $script:FakeUninstall = @((Entry 'cysr' '1.1.6' ('"' + $d + '"')))
        function Get-CysContentState($b) { return 'match' }
        $script:Mem = 'Q:\cys'
        $rc = @(Step-InstallCys)[-1]
        T (($rc -eq 0) -and ($script:Calls.Count -eq 0) -and ($script:MemRemoved -eq 1)) '⑵ 건너뜀(이미 설치) 뒤에도 옛 기억 값 지움' ('rc=' + $rc + ' calls=' + $script:Calls.Count + ' removed=' + $script:MemRemoved)
    }
    'mem-remove-throws' {
        # 지우기가 실패해도 설치 성공(rc 0)은 뒤집히지 않는다 · 기록 1줄
        $script:Mem = 'Q:\cys'
        function Remove-CysInstallMemory { throw 'denied' }
        $script:InstallerDoes = { param($a) Put-Bins (Join-Path $env:LOCALAPPDATA 'cys') '1.1.6' }
        $rc = @(Step-InstallCys)[-1]; $lg = Log-All
        T (($rc -eq 0) -and ($lg -match 'not removed')) '⑵ 지우기 실패 → rc 0 유지 · 기록에 못 지움' ('rc=' + $rc + ' · ' + $lg)
    }
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
