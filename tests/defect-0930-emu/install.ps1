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
}
Write-Output ('RESULT pass=' + $script:Pass + ' fail=' + $script:Fail)
